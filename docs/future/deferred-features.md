# 待实现 / 占位功能（待 lab 内容落地时补全）

> 本文记录主游戏 v1 里**有意留作占位 / 尚未实现**的机制:① 刻印 per-skill scoping ② 技能进化 X→X2 ③ lab 内容导入契约。
> 目的是把「当前是什么 / 设计本意是什么 / 为何延后 / 将来怎么补」一次说清,避免又被当成「已完成」。
> 关联:[`main-game-architecture.md`](../main-game-architecture.md) §8c(数据模型);历史决策轨迹见 git。
>
> 另见未来专用能力:[`AI Runtime Control Service`](ai-runtime-control-service.md) —— WebSocket + JSON 的主游戏 AI 控制面、`PlayerActionPort` 分层、FIFO 执行队列与 ASCII observation projection。

---

## 1. 刻印 per-skill scoping（= Progress F1，**该做未做**的真缺口）

### 当前实现（占位）
- `inkmon/logic/battle/abilities/passives/ink_mon_engraving_passive.gd`
  - hook `PRE_DAMAGE`，条件只判 `source_actor_id == owner`（`:32-33`），命中就把**所有** outgoing damage ×1.25（`:36-42`）。
  - 结果：普攻 + 任意技能都吃加成，**不区分 target_slot 指向的技能**。
- `inkmon/logic/battle/ink_mon_unit_actor.gd:119-122` 每条 engraving grant 一个**同款** passive，`target_slot` 没传进 ability。
- `target_slot` 数据全程存在（entry→snapshot→actor 都带），只是被 passive 忽略。

### 设计本意（见 `main-game-architecture.md` §8c）
- 「v1 **只强化指定 `skill_slot` 的技能**」；`target_slot` 对应 `skill_slots[].slot_index`。
- 即「给火球开小灶」应只让火球更疼，普攻和其它技能不变。

### 为何与 F3/X→X2 不同 —— 这是真亏欠
- Goal 字面要求 v1 就做到 per-slot，**没做到** → 属真 divergence（用户已拍板 v1 接受占位，但记录在案）。

### 将来怎么补（grill 已估，成本中等）
1. **给伤害事件加技能身份**：`ink_mon_battle_pre_events.gd` 的 `PreDamageEvent` 增字段 `source_ability_config_id`；在 `ink_mon_damage_action.gd:24/38` 用 `ctx.ability_ref` 的 config_id 填入（开火 ability 身份当场可拿）。
2. **passive 改无状态过滤**：engraving passive 改为**每 actor grant 一次**（不再每条 engraving 一个）；handler 内读 `owner.engravings → target_slot → owner.skill_slots[target_slot].skill_id`，与事件的 `source_ability_config_id` 比对，命中才 ×BONUS（多条命中同 slot → 叠乘/叠加）。保持 stateless 共享 config（守 enforcing-lgf）。
3. **测**：`smoke_progression` 或战斗 smoke 加断言「火球 slot + 刻印 → 火球伤害↑、普攻伤害不变」。

### 已知边界（即便补 per-slot 仍存在）
- PreEvent 系统**只有 `PRE_DAMAGE`，无 `PRE_HEAL`**。挂在治疗/纯辅助技能 slot 上的刻印**拦不到**，v1 即便做 per-slot 也只覆盖伤害类技能。要覆盖治疗需先加 `PRE_HEAL` 钩子（更大工程，归 lab）。

---

## 2. 技能进化 X→X2（= 设计点名要的占位，**按规格已做**，非缺口）

### 当前实现
- `inkmon/logic/services/content/ink_mon_species_catalog.gd`
  - `SKILL_EVOLUTIONS`（`:17-20`）：目前**只配一条** `inkmon_fireball → inkmon_chain_lightning`。
  - `evolve_entry`（`:104-108`）：进化时遍历旧 slot，凡 skill_id 命中 SKILL_EVOLUTIONS 就改写为进化后 skill_id。
- 机制通、确定性、有测：`smoke_progression.gd:137-138` 断言「cinder_kit lv5 进化 → slot0 火球升级成 chain_lightning」。

### 设计本意（`main-game-architecture.md` §8c / species_catalog 头注 :8-9）
- 「v1 X2 目标**复用现有真实技能（占位）**；真正独立的 X2 ability 随 lab 内容落地。」
- 即：现在的「进化后技能」是**借现成技能冒充**，不是真·进化技能；映射也只有一条。

### 为何不是缺口
- 设计**明写** v1 就用现成技能占位 → 占位**正是规格** → 属「按规格做了」，与刻印（该做未做）性质不同。

### 将来怎么补
1. lab 内容提供**真正独立的 X2 ability**（如「炽炎火球」而非借 chain_lightning）。
2. 扩 `SKILL_EVOLUTIONS` 覆盖更多 X→X2 对（目前仅 fireball）。
3. 评估「多段进化二次套用」是否要收敛（见下）。

### 已知 quirk（已记 Progress，可接受 / 语义可辩）
- 多段链 `cinder_kit → cinder_fox → cinder_drake`：fox 阶段 slot1 若 roll 到火球，会在 drake 进化时**再被** SKILL_EVOLUTIONS 升级一次（后期才长出的技能也吃升级）。
- 非崩溃、结果在合法池内、语义可辩（进一步进化继续强化）；仅 cinder 这一条两段链触发。
- 将来定 X→X2 是否**只作用于「出生原始携带槽」**时再收敛。

---

## 3. lab 内容导入契约（stub → lab 导出的边界，**尚未接入**）

> ⚠️ **本节关于 item 的部分已过时**。下文"schema v1 / items 必填非空 / canon Equipment 映射待定"是 stub 自描述期的旧形状假设。item 数据的归属/编号/导入流与装备数值生效方式现以 [`adr/0003`](../adr/0003-item-config-lab-canon-static-import.md) + [`adr/0004`](../adr/0004-equipment-stat-via-granted-ability.md) 为准（itemconfig 归 lab canon、`item_NNNN` 数字发号、editor-tool 静态导入、装备数值靠 grant ability 进加成层）。当前冻结契约形状见 [`content-contract-v2-spec`](../reference/content-contract-v2-spec.md)（schema v2）。units/skills 部分下文仍有效。

当前主游戏跑在**项目本地手写 stub 配置**(`InkMonUnitConfig` / `InkMonItemCatalog` / `inkmon/logic/battle/` 下技能类)。这是**有意**的,直到 lab 仓 inkmon-lab 完成 canon schema + exporter。在那之前主游戏**绝不消费部分迁移的 canon 数据** —— lab 导出要么整体通过校验、要么留在运行时之外。

### 校验入口
- `InkMonL2ContentContract.validate_export(data) -> Array[String]`(返回错误列表,空 = 通过)。
- `InkMonL2ContentContract.build_current_stub_export()` 把当前 stub 打成同一 JSON 形状,用同一 validator 自检。
- smoke:`./tools/run_tests.ps1 inkmon/content`(含 `JSON.stringify` / `parse_string` 往返 + 断言旧 canon key 如 `bst` / `special_attack` 不出现)。

### 必需导出形状(schema 以 [content-contract-v2-spec](../reference/content-contract-v2-spec.md) 为准 = `inkmon.l2.content.v2` / version `2`;item 形状已移出本节,见 [adr/0003](../adr/0003-item-config-lab-canon-static-import.md))
- 顶层:`schema`(`inkmon.l2.content.v2`)/ `version`(2)/ 非空数组 `units` / `skill_pools` / `skills`(⚠️ `items` **不再**属本节"必填非空"——v2 里 item 是 lab canon 承载段、可空 `[]`,归属/形状见 [adr/0003](../adr/0003-item-config-lab-canon-static-import.md))。
- unit:`id` / `display_name` / `species` / `stage`(baby|mature|adult)/ `elements`(fire|water|wind|light|dark,一个或多个)/ `base_stats`(max_hp,ad,ap,armor,mr,speed)/ `skill_slots`(slot 号 + pool_id)/ `fallback_active_skill_id`(当前单技能运行时的临时桥)。(⚠️ `role` 已删 —— lab adr/0008 彻底废弃战斗定位字段;AI 行为未来走 canon `personality`,见 glossary 2.3。)

### 显式 deferred 字段(必须留文档,不许悄悄出现在运行时数据里)
多槽 active kit 选择 / 技能 variance 值 / 进化表 / 刻印·勋章效果 payload。(~~canon Equipment 映射~~ 已由 [adr/0003](../adr/0003-item-config-lab-canon-static-import.md) / [adr/0004](../adr/0004-equipment-stat-via-granted-ability.md) 定案,不再 deferred。)

### 将来替换步骤
1. lab exporter 写出 `inkmon.l2.content.v1`。2. 从 inkmon-lab 拿一份 fixture 导出。3. 运行时导入前先跑 `validate_export()` smoke。4. 校验通过后,才加 mapper 把导出的 units/skills 映射进项目运行时 config(item 走 [adr/0003](../adr/0003-item-config-lab-canon-static-import.md) editor-tool 静态导入流,不经此 v1 mapper)。
