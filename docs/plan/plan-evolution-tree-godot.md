# 实现计划 · 进化树（godot 侧）

> 决策依据：lab `adr/0010` + `CONTEXT.md`「进化树 / species_id / 进化 trigger」+ **冻结接口 `../reference/content-contract-v2-spec.md`**（消费端 100% 照它写）。lab 侧另见 `plan-evolution-tree-lab.md`。
> 本文按 **inkmon-godot 当前真实代码**（0007/8/9 已落地后）写。计划暂存于 lab L2 目录，可整份拷进 godot 仓 `docs/plan/` 给 godot 会话用。
> 涉及 LGF / `.gd` 改动，开工前 godot 那边会自动触发 `gdscript-coding` / `enforcing-lgf` skill，遵其规范。

## 当前现状（核对代码，非记忆）

内容管线：`tools/ink_mon_content_import_tool.gd` 从 `https://lomo.inkmon.cloud/inkmon/contract`（Basic Auth）fetch → `logic/content/ink_mon_content_importer.gd` + `ink_mon_l2_content_contract.gd::validate_creature_base` 校验 → 写 `res://data/inkmon_content.json` → runtime 由 `InkMonSpeciesCatalog` 首次读取本地静态 content，`ink_mon_content_loader.gd::load_static_content` 只负责把文件规范化成 `{species_table, evolution_edges}`（**无 runtime server fetch / 无 dynamic override API**）。

- **身份键 = `species` 字符串**（name_en 风格 `cinder_kit`）。loader（`:49,55` 读 `unit.get("species")`）/ catalog / `core/ink_mon_roster_entry.gd`（`entry.species`）全靠它寻址。`unit.id` 字段存在但 **godot 不用于身份**（stub 里恰好等于 species）。无 `species_id` 概念。
- **进化拓扑 = per-unit 内嵌**：硬编码在 `ink_mon_species_catalog.gd::_build_table()`（如 `cinder_kit→cinder_fox level 5`、`cinder_fox→cinder_drake level 10`）。`get_evolution(species)` **单子**查询；`evolve_entry()`（`:161-187`）检查 `entry.level >= evo.level` → 改写 `entry.species`/`stage`、套 `SKILL_EVOLUTIONS`（X→X2）、补槽 roll、保 `entry_id`。**当前是线性链，不支持分支**。
- **阈值硬编码在 godot stub**（`_build_table` 的 `evolves_to.level`），**不来自 contract**。contract 的 per-unit `evolves_to`（裸字符串数组）只被结构校验、**运行时根本没接**。
- 进化触发是手动的：`logic/npc/ink_mon_cultivation_npc_handler.gd:31-33` 自增 `entry.level` 后调 `evolve_entry()`。

## 所有权边界（ADR-0010 后）

**godot 仍持有**：单位**运行时 current level**（`entry.level` 自增/exp/成长缩放）、**condition 语义评估**、**技能代码**（adr/0009）。
**改由 canon 提供（经 contract）**：`species_id` 身份、进化拓扑（edge-list）、进化**阈值** `trigger.level`。

## 关键纠偏（务必先读）

1. **species_id 装在 contract 的 `units[].id` 字段里，字段名仍是 `id`**（lab `godot-contract.ts` 投影 `id = species_id`、`display_name = name_en`）。godot 要做的是「**把当前当身份用的 `unit.species` 改成 `unit.id`**」，**不要新建 `species_id` 字段**，否则与 server 投影不一致。
2. **godot 现在用 `unit.species` 当 key（`loader:49,55`）而非 `unit.id`**——只改 contract 字段名不改 loader 取键逻辑会**静默错位**。
3. **stub 与 contract 双真相源**：`_build_table` 的 `evolves_to`/`level` 仅作「无 contract」fallback；**有 contract 时必须被 edge-list 完全取代**，`get_evolution` 必须优先查 edge-list，否则读到 stub 旧阈值。

## 有序工作项

- [ ] **1 · contract schema**（`ink_mon_l2_content_contract.gd`）：删 `_validate_evolves_to`（`:121-129`）与 `_validate_creature_units`/`_validate_units` 对 per-unit `evolves_to` 的接受（`:117-118`）；新增顶层 `evolution_edges` 校验 `_validate_evolution_edges()`：每行 `parent_species_id`/`child_species_id` 非空 string、`trigger.level` 必填正整数、`trigger.condition` 可选且仅结构校验（`type` 非空 string、`params` 是 object，**不校验枚举/语义**）。`validate_creature_base`（`:86-93`）增调；`build_current_stub_export`（`:11-62`）加 `evolution_edges` 键。SCHEMA_ID/VERSION bump（`:4`）标 schema break。`unit.id` 校验为 `mon_NNNN` 形状、`display_name` 必填、`species` 字段从 creature-base 校验移除。
- [ ] **2 · catalog edge-list 真相源**（`ink_mon_species_catalog.gd`）：新增 `static _static_evolution_edges`/forest（`{parent_species_id → [{child_species_id, trigger}]}`），由本地静态 content source 装载；`get_evolution()`（`:127-131`）改查 edge-list、**支持多子**、无静态 content 时回退 stub；`_build_table()`（`:206-266`）各 `evolves_to` 降级为纯 fallback。静态 content 按 **species_id** 键；**删 `normalize_species_key()` 双写**（`:85-95,73-76,99-109`）——mon_NNNN 唯一规范键、无大小写歧义。
- [ ] **3 · catalog 进化逻辑改森林 + 阈值取 contract + condition 评估**（`ink_mon_species_catalog.gd`）：`evolve_entry()`（`:161-187`）从「单子」改「遍历出边 → `entry.level >= trigger.level` 过滤 → 调 `evaluate_evolution_condition` 选第一条满足的子」；比较表达式形状不变，`trigger.level` 数据源从 stub 改 contract。新增 `evaluate_evolution_condition(condition, entry) -> bool`：按 `condition.type` 分派 —— `stat`（读 `derive_battle_stats`/base 比阈值）、`element`（查 `entry.elements`）真评估；`item` **先 stub**（见阻塞项）；无 condition 视为满足。**确定性选边规则**要定死（如：有 condition 且满足者优先 → 否则无 condition 默认枝），否则 smoke 不稳。`SKILL_EVOLUTIONS`（X→X2，adr/0009）与 condition 分派**正交、勿混**。
- [ ] **4 · loader**（`ink_mon_content_loader.gd`）：units 循环（`:44-58`）改读 `unit.get("id")` 当 species_id 键、`unit.get("display_name")` 当显示名（**别再读 `unit.species`**）；循环后提取 `data.get("evolution_edges", [])`，返回 normalized `evolution_edges` 给 catalog。
- [ ] **5 · roster entry re-key**（`core/ink_mon_roster_entry.gd`）：`var species`（`:13`）→ `species_id`（身份）+ `name_en`（显示）；三工厂 `from_unit_config/from_birth/from_dict` + `to_dict` + `derive_battle_stats()`（`:87-93`）+ `project_to_battle_snapshot()` 全改用 species_id 寻址。`entry.level`/`exp` 不动（godot 持有）。
- [ ] **6 · 调用点跟随 re-key**：`logic/npc/ink_mon_cultivation_npc_handler.gd`（message 用 name_en 显示、`evolve_entry` 调用不变）、`ink_mon_world_host.gd`、`ui/ink_mon_world_panel_view.gd`、`logic/npc/ink_mon_release_adopt_npc_handler.gd` 里读 `entry.species` 处改 species_id / name_en。**全量 grep `entry.species` / `\.species` 兜底，别漏读者。**
- [ ] **7 · importer / import tool**（`ink_mon_content_importer.gd` / `tools/ink_mon_content_import_tool.gd`）：`parse_and_validate` 与 `import_contract`/`_write_output` 形状无关、透传即可；`_species_of`（`:99-106`）改读 `unit.id` 做报告。**无逻辑改动**。
- [ ] **8 · 测试 fixture + smoke**：`tests/fixtures/sample_creature_contract.json` 移除 unit 上 `evolves_to`、加根级 `evolution_edges`、`unit.id` 用 `mon_NNNN`；`smoke_content_contract.gd`（断言拒 per-unit evolves_to、接 evolution_edges、id=species_id 形状）、`smoke_content_loader.gd`（静态 content 按 id 命中）、`smoke_progression.gd`（进化走 static content/stub 边、断言阈值来自 trigger、`entry_id` 不变、X→X2 + 补槽不变）。
- [ ] **9 · 文档同步**：`docs/main-game-architecture.md` §8c（`:181-188`）进化模型从 per-unit `evolves_to` 改 edge-list、`species`→`species_id`、阈值住 canon；`ink_mon_species_catalog.gd` 头注释删「阈值/拓扑由 godot 持有」措辞。

## 阻塞 / 依赖

- ⛔ **`condition {type:item}` 真评估 BLOCKED**：`logic/item/ink_mon_item_catalog.gd` 是纯元数据（StringName 键、无库存/归属），`ink_mon_item_domain.gd` 无「按 entry 查持有」接口。type:item 只能先 stub（返回 false 或软警告），真评估待 **item 域 server 同步**（ADR-0010 / CLAUDE.md 已知遗留 #1）。`evaluate_evolution_condition` 要明确 stub 行为，避免假进化。
- 🔗 **与 server 投影同步上线**：server 未发 `species_id`/`edge-list` 前，若 contract 校验强制新形状，旧 fixture/线上投影全 fail。dev 无向后兼容、走清 `res://data/inkmon_content.json` 重导；上线需确认 lab+server 投影端已发 `evolution_edges` + `units[].id = mon_NNNN`。

## 风险（来自现状核对）

- 身份键迁移易漏：loader 用 `unit.species` 非 `unit.id`；`entry.species` 还有 world host/panel/release-adopt 三读者，必须全量 grep。
- 多子森林改变 `evolve_entry` 语义（单子→选边）：同 level 多 condition 互斥 canon 不校验，godot 须定确定性选边规则。
- stub/contract 双真相源混用：`get_evolution` 未优先查 edge-list 会读 stub 旧阈值。

## 顺带发现（不在本计划范围）

~~`core/ink_mon_roster_entry.gd` 仍有 `role` 字段 + `InkMonUnitConfig.get_role_for_species()` 调用——与 lab `adr/0008`（role 彻底废弃、非 godot 持有）不一致。~~ **已清理(2026-06-02)**:role 概念整个从 godot 删除(entry/config/UI/snapshot);AI 选策改由 **interim `personality`**(由 species 派生,godot-internal)接管,保留 per-unit AI 差异。adr/0008 的 proper canon `personality` 字段仍 deferred(见 glossary 2.3)。
