# inkmon/ 主游戏模块架构优化方案（backlog，未执行）

> 本文 = 对 `inkmon/` 主游戏模块的一次**架构深度调研**产出的优化 backlog：战略主题 + 带 `file:line` 的战术清单 + 落地顺序。
> **状态：仅记录，暂不执行**（2026-06-13 用户拍板"先放着"）。动手前回本文取条目。
> **两轮调研**：R1 = Claude 多 agent fan-out（§1-§4）；R2 = 5 个 OpenAI Codex (gpt-5.5 xhigh) 分析师独立再审做跨模型交叉验证（§5），R2 净增项已并入 §2 backlog 并标 `(R2)`。
> 范围只限 `inkmon/`（host / logic / presentation / services），不含 addons/ LGF 框架、example、scripts/ web 桥。
> 关联：[`main-game-architecture.md`](../main-game-architecture.md)（架构真相）· [`adr/0001`](../adr/0001-unified-live-actor-model.md)–[`adr/0007`](../adr/0007-unified-2d-presentation-pipeline.md)（被对照的设计意图）· [`deferred-features.md`](deferred-features.md)（占位功能，与本文正交）。
> ⚠️ **快照性质**：所有 `file:line` 是 2026-06-13 调研时的行号，代码改动后会漂移——动手前以 `class_name` / 方法名 re-grep 为准。调研方法与可信度见 §4；第二轮 Codex 跨模型交叉验证见 §5。
> 🔁 **2026-07-02 fable 复核**（队列 2a 启动）：快照后 `inkmon/` 逻辑层仅 a5b22ef（item v1 stub slug → v2 `item_NNNN`）一个提交触及，headline 逐锚点抽查**基本全部成立、行号几乎无漂移**。两处修订已就地标注：shop stub 半边已被 a5b22ef 根治（§2 对应条目缩为 adopt-only、量降 S）；进化 gate 的 `LEVEL_GROWTH` **常量**已共享引用（缩放公式仍两处手抄、本地重算绕装备加成仍在——P0 核心成立）。
> ✅ **2026-07-02 三波落地**（用户拍板"三波全推"后 fable 执行，`inkmon/all` 21 smoke 全绿）：**Wave 1 全部**——`smoke_battle_math` 数值锚定（克制逐对+光暗双向 1.3+element fallback+减伤精确值+纯成长 gate）· 进化 gate 纯成长钉死 + `growth_scale` 共享纯函数 · 技能单清单派生（`_find_config` 线性扫）+ export↔runtime 一致性断言 · `drain_commands` 战斗守卫 + 冻结 smoke · `get_player_coord` fail-fast · command 基类 assert · `damage_mod_seen` 探针拆除。**Wave 2 全部**——`InkMonNpcRegistry` 单一清单（npc_defs/handlers 同源派生）· `InkMonRosterSetup`（config/save/adopt 三路径 `_install` 归一，容器 helper 收编）· `InkMonAIDecision` typed（替 `{type:...}` dict）· `InkMonBattleTargeting`（`can_use_skill_on` 下沉 + `nearest_enemy` 归一含 chain 弹跳）· footprint 三处归一（`clear_actor_footprint`）· `_axial_distance` 删 + `NPC_PROXIMITY` · adopt 接 `SpeciesCatalog.list_adoptable_species` 池 · item `as_int_strict` 类型门 + loader 兜底 + malformed smoke。**Wave 3 headless 面全部**——Host `_advance_active_battle` 双路径收敛 · `IWorldQuery` → 纯 snapshot DTO（含 R3 净增的 `npc_defs`；presentation/panel_view 消费面锁步；`main-game-architecture.md` §1 措辞同步为结构级）· Host introspection 剥离（`_with_state` 删除，控制面纯 `{ok,message}`）· facade smoke 白名单结构断言 + snapshot 写穿断言。**下放亦已完成**（同日续轮）：save/load modal → `InkMonSaveLoadModal`、right drawer → `InkMonRightDrawer` 两个子场景控制器（§6 pattern：行为/动画/停靠布局内聚子场景，root 只填内容+接线），root 从 972 行减到 776 行；验证 = 21 smoke 全绿 + 开窗截图 harness（`inkmon/tests/shot_ui_states.tscn`）7 状态自截自比（期间抓到并根治 autowrap Label min-height 撑爆 PanelContainer 的视觉回归——headless smoke 不可见，截图一眼见）；`smoke_overworld_iso` 对 `_dim_overlay`/`_npc_panel` 的私有穿透改走 public layout_state。§2 表格条目未逐条勾选，以本记录为准。副产物：发现并记忆化 GDScript static var 持 RefCounted 的退出段错误坑（`all_skills`/`npc_registry` 因此刻意用 static func 重建）。
> 🗳️ **2026-07-02 R3 独立验证**（fable 第三票：逻辑层 headline 逐条亲读 + 2 个只读 agent 核查 presentation/low 尾巴，覆盖 44/47）：绝大多数成立。**1 条证伪**：save/load close 3× connect（R2 codex-4 F6，缩进误读，connect 在循环外只连一次）。**修正**：progression 裸 key 实为 3 handler 非 4；"几十个 get_node" 实为 19；`resolve_target_for_actor` 的 999999 是内部 min 初值、不进返回值（message 无消费方成立）；R2 "先 refresh 再 evolve" 在现状下是 no-op（gate 不读 attribute_set）；技能 match 漏项有 `assert_crash` 兜底（调用即崩非静默，静默漂移的是 export 清单）。**两项用户拍板**：进化 stat gate = **纯成长不含装备**；执行策略 = **按 §3 三波全推**。**R3 净增**：`IWorldQuery.npc_defs` getter 同样泄露可变 Dict（两轮均漏）；battle math smoke 须锚定光暗互克**双向 1.3** 与 element 空时 fallback 攻击者主元素两个隐藏语义；~~contract :286 `\r` 转义 bug~~（勘误：实为 `/`，fable 从 grep 输出误读，撤回）；drain 修法备选——GI 覆写 `base_tick` 战斗期只推 logic_time（根因是 procedure 调 base_tick 只为推时间、捎带跑了全部 systems；该案把冻结不变量钉在一处）。

---

## 0. 总评 — 地基稳，风险在边角纪律渗漏

**架构铁律执行得异常干净，主梁没问题；待优化项全在"边角的纪律渗漏"。**

生产路径上 **adr/0001/0002/0004/0005/0006/0007 零 high 违规**：三层单向 DAG（logic grep 零 UI/Node 引用）、Presentation 只经 `IWorldQuery` facade（无 `get_gi` 逃逸口）、存档唯一从 `InkMonWorldGI.to_dict/from_dict` 走、统一 live-actor 无投影回写、Command 对象多态、无私建 EventBus。持久化脊柱（序列化往返 / 装备加成层 / downed 存活）的回归覆盖是全套测试最强的部分。

**风险集中三处**：
1. **测试探针逆向渗进生产逻辑层** —— 测试可观测性需求焊进序列化根 GI 字段 + 伤害热路径。
2. **content 扩展的注册 seam 退化成多份手抄并行清单** —— 加技能 / 加 NPC 都是 shotgun surgery，编译器零保护。
3. **唯一的战斗数值层 + 进化 gate 完全裸奔且互相分叉** —— 确定性纯函数极易测却零数值断言，可静默回归。

> 🔬 **R2 补充（§5）**：第二轮 Codex 交叉验证**确认并加固**上述三处（尤其进化 gate 与战斗数值层是两模型双盖章），并净增**第 4 簇风险**——**隔离 / 存档完整性的结构缺口**（facade 暴露可变 actor、战斗 tick 抽干 command 队列、存档坐标静默污染、command 基类 fail-open），这是 R1 的盲区。

---

## 1. 战略层 — 主题（R1 八条 + R2 两条）

> 优先级：**P0** 立即（解锁正确性护栏）· **P1** 近期（扩展税 + 测试纪律）· **P2** 机会性（结构债）。

### 🔴 P0 — 战斗数值层与进化 gate 的正确性裸奔
整个游戏**唯一**的伤害公式（元素克制 1.3/0.7 + `100/(100+armor)` 减伤）是确定性纯函数、极易测，却**零数值断言**：克制写反、系数调反、physical/magical 取错属性，现有 smoke 全绿（`smoke_m1_battle` 只看 `base≠final` 一个布尔）。更糟：进化 stat-gate 在 `ink_mon_species_catalog.gd:314-334` **本地重算** `species_base×level`（注释自承"无装备"），刻意丢弃装备 modifier——与玩家战斗里看到的同名属性给出**两套答案**（装 +ad 凑过门会静默判不通过），且 `LEVEL_GROWTH` 缩放公式两处手抄，docs §9 一旦把线性改 `f(species,level)` 必分叉。
**方向**：① 加 `smoke_battle_math` 锚定数值基线（纯逻辑，不起整场战斗）；② 进化 gate 改读 actor 的派生真相（含装备 `attribute_set`）+ 抽共享缩放函数；若设计上确要"不含装备纯成长"则注释钉死 + assert + 仍消重复。
（相关 finding：teststools-1 / services-1 / teststools-2。**R2 双确认**：codex-2 F5 / 5 F4 / 3 F2 独立同点。）

### 🟡 P1 — content 注册 seam 退化为并行手抄清单
- **技能**：加一个 active 要改 技能文件 + `_build_manifest` + `get_skill_config` match **三处**，已实测 `_build_manifest` **10 项** vs `get_skill_config` match **6 项** 漂移（漏 Move/PoisonBuff/StunBuff/DamageMathPassive）。R2 加码：还有**第三份**手抄清单——`l2_content_contract` 的 metadata export（`_skill_exports`），且 smoke 不验证"导出 id 能被 runtime resolve"。
- **NPC**：`npc_defs` 与 `_build_npc_handlers` **两份硬编码 Dict** + `display_name` 重复，id/type 漂移已埋隐性 bug 面。

编译器零保护，漏改一处出半残 content。**方向**：建"单一清单派生"范式——`get_skill_config` 从 `_build_manifest` 按 `config_id` 建缓存字典派生（删 match 阶梯，加技能只 append 一行）+ metadata export 也从同一清单派生 + 补 smoke 断言每个导出 id 能 runtime resolve；NPC 抽单一注册表（`{id,display_name,type,coord,handler_factory}`），两份 Dict 都从它派生 + 启动断言 `npc_defs.keys()==_npc_handlers.keys()`。
（相关 finding：xext-1 / abilities-1 / xadr-2 / xext-3；**R2**：codex-2 F4 / 5 F2 / 1 F3 / 3 F5 / 5 F3。注：abilities-1 原报"崩溃 seam"已证伪——move 走 `Ability.new` 硬授予不经 `get_skill_config`，实际是漂移税而非立即崩溃；收敛单一清单同时根治漂移面。）

### 🟡 P1 — 测试探针逆向污染生产逻辑层
`damage_mod_seen` 布尔既挂在序列化根 GI 字段上（`ink_mon_world_gi.gd:47,719`）、又写在每次伤害结算的热路径里（`ink_mon_damage_action.gd:52-53`），纯为满足一条 smoke 断言——违反 adr/0002（此 bool 非游戏态、不该跨调用保留），让 GI 多背 transient 调试态、让 DamageAction 持对 GI 的写副作用、reset 时还要记得清它。
**方向**：逻辑层不得为测试可观测性预留生产字段/副作用；测试断言**可观测产物**（精确 `final_damage` 公式值 / 事件流里的 `actual_life_damage`），而非窥探生产标志——天然并入 P0 的数值层覆盖。
（相关 finding：battlecore-2 / actions-1 / xadr-1。注：此"测试探针污染序列化根"的 adr/0002 纪律视角是 **R1 独有**，R2 只点了 smoke 弱、未触及污染角度。）

### 🟡 P1 — 战斗隔离 / 存档完整性的结构缺口（R2 新增）✅
R2 已核实的两个 latent 但破不变量的结构缺口：
- **战斗 tick 抽干 world command 队列**：`InkMonBattleProcedure.tick_once()` 直调 `world.base_tick()`（`ink_mon_battle_procedure.gd:48`），跑注册的 `InkMonCommandDrainSystem` → `gi.drain_commands()`（`ink_mon_world_gi.gd:301-303`），而 `drain_commands` **缺 `has_active_battle()` 守卫**（隔壁 Movement 的 `advance_world_movement` 在 `:339-340` **有**守卫，非对称）。战斗期若队列有 command 会被抽干、改 player/roster/world，破文档 §2② 承诺的"战斗期 base_tick 不跑、世界冻结"（该承诺只对 host pump 的 `GI.tick()` 成立，procedure 自调 `base_tick` 绕过了它）。**当前 latent**（战斗同步跑完、队列通常空），但结构缺口真实、修法极便宜。
- **存档坐标静默污染**：`get_player_coord()` 找不到 occupant 静默返 `(0,0)`（`ink_mon_world_grid.gd`），`to_dict()` 又把它回写进 `player_actor.hex_position` 序列化（`ink_mon_world_gi.gd:159`）→ grid 一坏，存档**静默把玩家钳到原点**，且分不清真在原点还是 invariant 破了。
**方向**：`drain_commands` 加 `has_active_battle` 守卫（对称 Movement）或 `CommandDrainSystem.tick` 战斗期早返；player 坐标查询 fail-fast（缺失即 `assert_crash` / `{ok=false}`，`to_dict` 不回写哨兵）。

### 🟢 P2 — IWorldQuery facade 暴露可变 actor（R2 五人共识）
R2 的 **5 个 codex 分析师独立全部报 high**：`IWorldQuery` 虽无 `get_gi` 逃逸口，但 `player_actor`/`roster`/`get_world_actor` **返回可变 live actor**（`i_world_query.gd:24-49`），Presentation 拿到同一个可变对象（`ink_mon_world_presentation.gd:94`）、UI builder 直接读 actor 字段与 `ItemSystem` → UI 物理上能 `query.player_actor.gold += 1` 绕过 command 写。这揭示 main-game-architecture.md §1 吹的 **"结构隔离（非纯约定级）、表演物理上够不到"** 对**写** over-claim 了：facade 挡住 concrete GI/flow/lifecycle，但没挡住经 actor 引用的域写。
**裁决（本文）**：定 **medium 非 high**——现行 UI 没越界写，是 latent + 文档措辞夸大；但 codex 是对的，这是 R1 的真盲区（R1 只挑了 `PLAYER_ID` 那一处缝）。**方向**：facade 转只读 DTO/snapshot（`get_player_summary`/`get_roster_snapshot`/`get_bag_snapshot`），Presentation 不再 import actor 类型；**与 P2 胖根下放并入同一波**做；顺手把文档 §1 那句"物理够不到"收敛为"够不到 concrete GI/flow/lifecycle；域 actor 的写隔离当前是约定级"。

### 🟢 P2 — Host 控制面被 dev-agent introspection 双重绑架
Host 用 14 个薄转发（`ink_mon_world_host.gd:310-363`）把整个 Presentation 输入/UI 表面二次暴露，且每个生产控制面方法（`save_game`/`reset`…）的返回 shape 被 `_with_state`/`_scene_result` 强塞一份完整 dev-agent 快照（`:394-405`）。**不是 CQRS 铁律违反**（运行时数据流仍走 Presentation↔Logic），是测试表面寄生进生产控制面的维护成本：新增一个 Presentation 操作要在两处各加签名、无编译期同步保证，且每次 lifecycle 调用全量序列化一遍 UI/world 调试态。
**方向**：introspection 推到 `ink_mon_main_agent_ops` 边缘（它本为此而生、作为 WorldHost 子树可直接持 Presentation 引用），控制面只返回 `{ok,message}`；顺带把同步 `run_to_completion` 与异步 `_process` 两条 battle 推进路径收敛成单一 `_advance_active_battle()` 防行为分叉。
（相关 finding：host-1 / host-2 / host-3）

### 🟢 P2 — Presentation root 胖根与子场景化落差
`ink_mon_world_presentation.gd` **970 行**，既是接线员又是 drawer/modal/hud 的 controller，违反 docs §6"UI 行为住子场景脚本、root 只接线"（文档已自标增量下放，但落差仍是子系统最大维护负担）：互斥 tween 交织、几十个硬编码 `get_node` 路径与 `.tscn` 结构强耦合（改场景树即静默断）。配套：硬编码 logic 内部常量 `InkMonWorldGrid.PLAYER_ID`（facade 缝隙漏出对 logic 实现的依赖）、布局挂每帧 `_process` 全量重算（触发时机站错层）。
**方向**：按 §6 增量下放，先搬最自包含的 `save_load_modal`（3 槽）验证 pattern 再搬 drawer；在 `IWorldQuery` 补 `get_player_world_actor()`/`is_player_moving()` 把 `PLAYER_ID` 知识收回 logic 侧。
（相关 finding：present-1 / present-2 / present-4 / present-5。**R2 双确认**：codex-4 F2 / 5 F6。）

### 🟢 P2 — 几何 / 目标筛选 / footprint 清理逻辑跨层重复
axial 距离手写 `_axial_distance` 重复 `HexCoord.distance_to`；grid footprint 清理**三处各写一遍**（`ink_mon_battle_setup.gd` / `ink_mon_world_gi.gd._clear_battle_grid_state` / `ink_mon_battle_damage_utils.gd._clear_grid_footprint`），reservation 存储语义一变 `damage_utils` 漏改 → 死者 footprint 残留（grid 占用类最隐蔽 bug）；nearest-enemy 在 AI 基类与 chain action 两处距离最小化循环重复。
**方向**：收敛成无状态 static helper（符合 adr/0002 三叉）——距离统一走 `HexCoord` + 抽 `NPC_PROXIMITY` 常量；`InkMonBattleSetup.clear_actor_footprint(gi,actor)` 三处归一；`InkMonBattleTargeting.nearest_in(candidates,from,exclude)` 参数化复用。
（相关 finding：worldgi-2 / worldrest-3 / battlecore-4 / ai-1）

### 🟢 P2 — 无类型 Dict 内部契约缺类型 seam
AI→procedure 决策走 `{type:...}` dict + switch-on-string；`IWorldQuery.get_npc_actions` 透传无类型 Array；`progression` key 裸字符串散在 4 个 handler；shop action dict 偷塞 `item_config_id`/`price` 超基类声明；`resolve_target_for_actor` 返回含 `999999` 哨兵的弱 Dict。**非持久内部 intent，不触发 Command 铁律**，但是扩展时的弱 seam。
**方向**：真实流动的内部契约升轻量 typed data shape（RefCounted/inner class，不进存档故合三叉），如 `InkMonAIDecision`（kind 枚举 + ability_id + target）；低成本先行项 `InkMonProgressionKeys` 常量集中点（不破 §9 Dict 存储挂起约定）。
（相关 finding：battlecore-3 / ai-2 / worldgi-3 / services-2 / services-4 / worldrest-4。**R2 双确认**：codex-2 F6。）

---

## 2. 战术层 — 优先 backlog（带 file:line）

> 严重度：🔴 high · 🟡 medium · ⚪ low。工作量：S（<半天）· M（半天~1天）· L（多天）。✅ = 已亲自重读真实代码核实。`(R2)` = 第二轮 Codex 净增（见 §5）。

### 🔴 P0 — 正确性护栏

| 严重 | 问题 | 位置 | 改法 | 量 |
|---|---|---|---|---|
| 🔴 | 战斗数值层零数值断言，可静默回归 | `inkmon/logic/battle/config/ink_mon_element_chart.gd:25-32` + `inkmon/logic/battle/abilities/passives/ink_mon_damage_math_passive.gd:40-54` | 新增 `inkmon/tests/smoke_battle_math.tscn`（group=`inkmon/m1`）：逐对断言克制乘子（1.3/0.7/1.0）、armor=100→减免 0.5、magical 用 mr、火打风 `final=base×0.5×1.3`。R3 补：必须锚定光暗互克**双向 1.3**（`_ADVANTAGE` 第一分支先命中、永不到 0.7）与 element 空时 fallback 攻击者主元素两个隐藏语义。纯逻辑无需起整场战斗 | S |
| 🔴 ✅ | 进化 stat-gate 本地重算属性、绕过 actor 派生真相、丢装备加成 | `inkmon/logic/services/content/ink_mon_species_catalog.gd:314-334`（lhs 计算 320-325） | **07-02 拍板：纯成长语义（不含装备）**——保留本地"纯成长"口径，抽共享缩放纯函数（`InkMonUnitActor.growth_scale(level)` 之类）消公式两处手抄，注释钉死语义 + 补 smoke 锚定"装备不影响 gate 判定"。R2 的"先 refresh 再 evolve"（codex-3 F2）在纯成长口径下无意义（gate 不读 attribute_set），**不采纳** | M |

### 🟡 P1 — 扩展税 + 测试纪律 + 隔离/存档缺口

| 严重 | 问题 | 位置 | 改法 | 量 |
|---|---|---|---|---|
| 🔴 ✅ | 技能双清单漂移（manifest 10 vs match 6）+ R2 揭示第三份 metadata export | `inkmon/logic/battle/abilities/shared/ink_mon_all_skills.gd:15-52` + `inkmon/logic/services/content/ink_mon_l2_content_contract.gd:532` | `get_skill_config` 从 `_build_manifest()` 按 `config_id` 建 static 缓存字典派生，删 match 阶梯；metadata export 也从同一清单派生；新增技能只 append 一行 `_Entry`；补 smoke 断言每个导出 id `get_skill_config(id)!=null` | S |
| 🟡 ✅ | 测试探针 `damage_mod_seen` 焊进序列化根 GI + 伤害热路径 | `inkmon/logic/world/ink_mon_world_gi.gd:47,719` + `inkmon/logic/battle/actions/ink_mon_damage_action.gd:52-53` + `inkmon/tests/smoke_m1_battle.gd:44` | 删字段及回写，smoke 改断 `DamageEvent.final_damage` 精确值（并入 `smoke_battle_math`） | S |
| 🟡 ✅ (R2) | 战斗 tick 抽干 world command 队列：`drain_commands` 缺 `has_active_battle` 守卫（Movement 有，非对称），破"战斗期世界冻结"不变量 | `inkmon/logic/battle/ink_mon_battle_procedure.gd:48` + `inkmon/logic/world/ink_mon_world_gi.gd:301-303`（对照 `:339-340` Movement 守卫） | `drain_commands` 开头加 `if has_active_battle(): return`（对称 Movement）；或 `InkMonCommandDrainSystem.tick` 战斗期早返。R3 备选：GI 覆写 `base_tick` 战斗期只推 logic_time 不跑 systems（不变量钉一处，未来新增 system 自动安全）。补 smoke：战斗期入队 command 不生效 | S |
| 🟡 (R2) | `get_player_coord` 找不到 occupant 静默返 `(0,0)`，`to_dict` 回写 → 存档坐标静默污染 | `inkmon/logic/world/ink_mon_world_grid.gd`（PLAYER_ID 缺失返 `Vector2i.ZERO`）+ `inkmon/logic/world/ink_mon_world_gi.gd:159`（to_dict 回写） | player 专用查询 fail-fast（缺失 `Log.assert_crash` 或返 `{ok=false}`）；`to_dict` 遇缺失不回写坐标；泛用 `find_actor_coord` 返 invalid result 而非默认零点 | S |
| 🟡 | 6 NPC 由 2/3 处平行硬编码 Dict 各自登记 | `inkmon/logic/world/ink_mon_world_gi.gd:62-93,607-615` | 建单一 NPC 注册表（static 数据表，每项 `{id,display_name,type,coord,handler_factory:Callable}`），`npc_defs` 与 `_build_npc_handlers` 都从它派生 + 启动断言 `npc_defs.keys()==_npc_handlers.keys()` | M |
| 🟡 | GI 承接 roster/容器装配杂活，三条 `_add_roster_unit` 高度重复 | `inkmon/logic/world/ink_mon_world_gi.gd:174-267` | 比照 `InkMonBattleSetup` 抽 `InkMonRosterSetup`/`InkMonContainerSetup` static service（收 gi 当参），三 `_add_roster_unit` 合并 `build_roster_actor(gi,data,base_hp)`，GI 留薄 wrapper | M |

### 🟢 P2 — 结构债（机会性）

| 严重 | 问题 | 位置 | 改法 | 量 |
|---|---|---|---|---|
| 🟡 (R2) | `IWorldQuery` 返回可变 live actor/roster → 写隔离仅约定级，文档 §1 over-claim（codex 五人共识 high，本文裁 medium） | `inkmon/logic/world/i_world_query.gd:24-49` + `inkmon/presentation/ink_mon_world_presentation.gd:94,98` + `inkmon/presentation/ui/ink_mon_world_panel_view.gd:17,77` | facade 转只读 DTO/snapshot（`get_player_summary`/`get_roster_snapshot`/`get_bag_snapshot`，Dict 深拷贝），Presentation/PanelView 不再 import `InkMonPlayerActor`/`InkMonUnitActor`；R3 净增：`npc_defs` getter 泄露可变 Dict 引用，一并收进 snapshot；`ItemSystem` 读收进 query；**与胖根下放同波做**；纠正文档 §1 措辞 | M |
| 🟡 | Host 控制面返回塞 dev-agent 全量快照 + 14 转发 | `inkmon/host/ink_mon_world_host.gd:310-363,394-405` | 控制面只返 `{ok,message}`，introspection 移到 `ink_mon_main_agent_ops` 层（直接持 Presentation 引用） | M |
| 🟡 | AI→procedure 决策走 `{type:...}` dict + switch-on-string | `inkmon/logic/battle/ai/ink_mon_ai_strategy.gd:104-113` + `ink_mon_battle_procedure.gd:138-153` | 引入 `InkMonAIDecision`（RefCounted，字段 `ability_instance_id`/`target_actor_id`/`target_coord` + `is_skip()`），procedure 按字段派发；strategy 可单测 | M |
| 🟡 (R2) | ~~shop~~/领养硬编码 stub id（**07-02 复核：shop 半边已由 a5b22ef 根治**——现 data-driven 从 `ItemCatalog.list_config_ids` 过滤 `price>0` 生成 `buy:<item_id>`；仅剩 adopt stub） | `inkmon/logic/services/npc/ink_mon_release_adopt_npc_handler.gd:5`（`adopt_stub_inkmon`） | adopt 从 `SpeciesCatalog.list_adoptable_species` 取池，fallback 现有 stub | S |
| 🟡 (R2) | item contract `price`/`max_stack` 用 `int()` 强转吞错类型（`"price":"free"` 被转成数字混进 runtime） | `inkmon/logic/services/content/ink_mon_l2_content_contract.gd:276` + `inkmon/logic/services/content/ink_mon_content_loader.gd:144-146` | 加 `_require_non_negative_int`/`_require_positive_int` 类型门，只接受 int（或明确允许 integral float），拒 String/bool/NaN/inf；补 malformed item fixture | S |
| 🟡 (R2) | damage post-event 用 pre-damage alive list，死者仍收 post-damage/death 事件（未来 lifesteal/thorns/death-reaction 会污染） | `inkmon/logic/battle/actions/ink_mon_damage_action.gd:28` | `apply_damage` 后重算 `post_alive_actor_ids`；death 事件如需含 dying actor 单独显式传 `dead_actor_id`，不复用 alive list | S |
| 🟡 (R2) | `InkMonWorldCommand.apply` 基类 no-op `pass`，新 command 忘覆写静默吞（fail-open） | `inkmon/logic/world/commands/ink_mon_world_command.gd:13-14` | 基类 `apply` 改 `Log.assert_crash(false, "InkMonWorldCommand", "apply() must be overridden: %s" % get_class())`，漏覆写第一时间炸出 | S |
| 🟡 | Presentation 硬编码 `InkMonWorldGrid.PLAYER_ID`（facade 缝隙漏） | `inkmon/presentation/ink_mon_world_presentation.gd:406,894` | `IWorldQuery` 加 `get_player_world_actor()`/`is_player_moving()`，Presentation 改调语义方法、删对 `InkMonWorldGrid` 的依赖 | S |
| 🟡 | grid footprint 清理三处重复（`damage_utils` 自写 O(n) 扫描） | `inkmon/logic/battle/utils/ink_mon_battle_damage_utils.gd:57-65`（vs `ink_mon_battle_setup.gd:104-111`、`ink_mon_world_gi.gd:537-548`） | 收敛 `InkMonBattleSetup.clear_actor_footprint(gi,actor)` 三处归一 | S |
| 🟡 | `IWorldQuery` 隔离断言用 `has_method` 黑名单 | `inkmon/tests/smoke_world_command.gd:146-147` | 改白名单结构式断言：遍历 `get_method_list`/`get_property_list` 断言无白名单外 public 成员，新增逃逸口默认 fail（与上面 facade-DTO 改造互补） | S |
| 🟡 | AI 策略路由 + 目标选择零冒烟覆盖（INTERIM 行为层） | `inkmon/logic/battle/ai/ink_mon_ai_strategy_factory.gd` + frontline/support/aggressive | 加 `smoke_ai_strategy.tscn`：factory 路由逐项断言（含未知 personality→aggressive fallback）+ 每策略喂固定小战场断言确定性输出 | M |
| 🟡 | `can_use_skill_on` 无状态战斗规则却住 GI | `inkmon/logic/world/ink_mon_world_gi.gd:660-678` | 下沉 static `InkMonBattleTargeting.can_use_skill_on(actor,skill,target)`，三处 AI 调用锁步改，GI 删该方法 | S |
| 🟡 | 逻辑热路径散布裸 `print()`（每帧伤害/治疗/buff） | `inkmon/logic/battle/utils/ink_mon_battle_damage_utils.gd:33,36` + `actions/ink_mon_damage_action.gd:54-56` + `ink_mon_heal_action.gd:31` + `ink_mon_apply_buff_action.gd:26` | 统一 `Log.debug`（受 level 开关）或抽 `InkMonBattleLog` helper 集中格式化；避免每帧无条件查 registry 取 display_name | S |
| 🟡 | `inkmon_move_start` 裸字符串散布，overworld live 未复用 `MoveStartEvent` 类 | `inkmon/presentation/overworld/overworld_live_driver.gd:73` + `render2d/visualizers/move_visualizer.gd:14` | live driver 调已有 `MoveStartEvent.create(...).to_dict()`，visualizer 引用其 kind 常量，对齐 battle replay / overworld live 两入口 | S |
| 🟡 | `InkMonWorldActor` 移动态混用 `Array[Vector2i]` 路径 + `HexCoord` 当前格 | `inkmon/logic/world/ink_mon_world_actor.gd:13-21` | `pending_path` 统一 `Array[HexCoord]`（逻辑真相类型），消 advance 里的 new/to_axial 噪声与轴系反 bug 温床 | M |
| 🟡 | `progression` 字段读写散在 4 个 handler 裸 string key | `inkmon/logic/services/npc/ink_mon_advancement_npc_handler.gd:27-28`（及 cultivation/guild） | 加 `InkMonProgressionKeys` 常量集中点（或挂 `InkMonPlayerActor`），保持 Dict 存储不破 §9 挂起 | S |
| 🟡 | battle 入口同步/异步两条推进路径并存，结算微序列各跑一遍 | `inkmon/host/ink_mon_world_host.gd:60-67`（异步 `_process`）与 `104-118`（同步 `run_to_completion`） | 抽 `_advance_active_battle()->bool`（tick 一步 + `_complete_battle_if_ready`），两路都调它，dt 来源显式参数化 | S |
| 🟡 | `InkMonWorldGrid` 膨胀 wrapper：6+ 公开方法零生产调用方 | `inkmon/logic/world/ink_mon_world_grid.gd:58-112` | 砍零调用方 pass-through，内部 helper 加 `_` 前缀，收敛为"overworld 移动/寻路/重定向"单一职责面 | S |
| 🟡 | contract 校验双 idiom（`is` 守卫 vs `as`/null）易误用 | `inkmon/logic/services/content/ink_mon_l2_content_contract.gd:120-124` | untrusted-safe 的 `is`-门写法统一到全部 validate 路径，或 internal-only helper 加 `_internal_` 前缀显式分组 | M |

<details>
<summary>低严重度尾巴（⚪，可与相邻改动顺手做）</summary>

| 问题 | 位置 | 改法 | 量 |
|---|---|---|---|
| `_axial_distance` 手写距离重复 `HexCoord`，阈值硬编码 | `inkmon/logic/world/ink_mon_world_gi.gd:445-448` | 直接用 `HexCoord.distance_to` ≤ `NPC_PROXIMITY` 常量，删私有公式 | S |
| 5 个非 shop NPC handler 缺失败路径单测（回滚/门槛/确定性） | `inkmon/logic/services/npc/ink_mon_shop_npc_handler.gd:34-37`（及 cultivation/advancement/release_adopt） | 加 `smoke_npc_handlers`：gold=0 后返回 ok=false 且 gold 不变、create_bag_item 失败回滚、roll_seed 确定性 | S |
| actor 两条平行序列化面（`to_dict` 存档 vs `serialize` 录像）+ 死字段 `source_entry_id` | `inkmon/logic/battle/ink_mon_unit_actor.gd:442-448` + `ink_mon_battle_actor.gd:81-85` | 删 `source_entry_id`（grep 确认仅 self-ref）；`serialize()` 注释钉死"录像专用·非存档"或改名 `record_snapshot()`。注：录像管道未接入，风险未实质化 | S |
| `resolve_target_for_actor` 返回弱契约 Dict（含 999999 哨兵 + 未消费 message） | `inkmon/logic/world/ink_mon_world_grid.gd:115-160` | 换具名结构或直接返 `Vector2i`；砍未消费 message；用 `found_candidate` bool 替哨兵；补 retarget 单测。注：原报 `get('taget')` typo 证据不成立（实际拼写正确） | M |
| shop handler action dict 注入 `item_config_id`/`price` 超基类契约 | `inkmon/logic/services/npc/ink_mon_shop_npc_handler.gd:51-52` | 提为命名常量（`ACTION_ITEM_CONFIG_ID`/`ACTION_PRICE`）+ 注释"kind 特定可选扩展" | S |
| 回放进出态切成 root 三方法、与 overworld 隐藏耦合 | `inkmon/presentation/ink_mon_world_presentation.gd:158-170,194-200` | 收口成 `InkMonBattle2DView` 一对 enter/leave + emit mode 信号，root 只在 mode_exited 恢复；或抽 `_set_replay_mode(active)` | M |
| `_layout_ui` 挂每帧 `_process` 全量重算几何 | `inkmon/presentation/ink_mon_world_presentation.gd:124-125,593-612` | 隐藏面板早返；布局改 `viewport.size_changed` 信号 + 状态变更显式驱动；删重复调用 | M |
| `call_deferred` 字符串方法名，rename 静默断链 | `inkmon/host/ink_mon_world_host.gd:133`（load-bearing） | 改 Callable：`_begin_training_battle_flow.bind(_world_generation).call_deferred()`。注：`:377` 是纯调试日志可选修 | S |
| `ink_mon_main.gd` 路由 `instantiate as` 强转无 null 守卫 | `ink_mon_main.gd:21-29` | `add_child` 前加 `Log.assert_crash(_game_director != null, ...)`，与内层 host 断言风格对齐 | S |
| `InkMonBattleActor.get_attribute_set` 用 `push_error` 占位而非 `assert_crash` | `inkmon/logic/battle/ink_mon_battle_actor.gd:9-11` | 改 `Log.assert_crash` 表达"抽象方法必须覆写"，漏覆写第一时间清晰崩溃 | S |
| 7 个 active 技能 cooldown/lock gating 样板逐技能手抄 | `inkmon/logic/battle/abilities/active/ink_mon_fireball.gd:26-39`（及同构兄弟） | `ink_mon_skill_helpers` 加 `with_standard_gating(builder,cooldown_ms)`，各技能链调一行 | S |
| battle-2d 回放 smoke 自造 fake record，与真实录制无契约绑定 | `inkmon/tests/smoke_battle_2d_replay.gd:89-112` | 抽共享 `InkMonBattleEventKeys` 常量表，录制端/fake/visualizer 都引用。注：kind 重命名已会破 visualizer，静默分叉风险有限 | M |
| `data_inspector` 内联 `_click_control` 是唯一 push_input 用例，UI 交互 smoke 模板缺位 | `inkmon/tests/smoke_data_inspector.gd:74-83` | 提成本地 `InkMonInputHelper`（CLAUDE.md 已给约定 API）供后续 UI 交互 smoke 复用 | S |
| `SKILL_EVOLUTIONS` 为 const 内联表，物种进化拓扑已走 JSON 通道 | `inkmon/logic/services/content/ink_mon_species_catalog.gd:27-29` | 技能映射随物种 content 走 `evolution_edges` 数据通道。注：engraving 单态被动属 §9 挂起，不并入 | M |
| (R2) NPC 视觉同步一次性 init（`_npcs_initialized`），动态 NPC/读档差异留 stale avatar | `inkmon/presentation/ink_mon_world_presentation.gd:134` + `overworld/ink_mon_overworld_view.gd:76-93` | `set_npcs` 改 reconciliation（按 defs diff seed/despawn，或先 clear 后重建）；`bind_world` 每次传当前 NPC read model | S |
| ~~(R2) save/load close 按钮在 slot 循环里重复 `connect` 3 次~~ **R3 证伪**：connect 在 for 循环外（与循环同级缩进）只连一次，R2 缩进误读 | `inkmon/presentation/ink_mon_world_presentation.gd:553-558` | 无需修 | — |
| (R2) smoke 直接访问 Presentation 私有字段（`root._presentation._modal_layer/_hud_layer/_battle_2d_view`），锁死胖根私有结构 | `inkmon/tests/smoke_overworld_iso.gd:300-323` + `smoke_app_root.gd:139` | 需要的状态补进 `get_dev_agent_state()` / 子 view debug API；smoke 只走 host/dev-agent public facade | S |
| (R2) `drain_commands` 无界抽干（`while not empty`），apply 期间新入队会同 tick 连锁 | `inkmon/logic/world/ink_mon_world_gi.gd:301-303` | drain 开头 snapshot 当前队列长度只处理本 tick 已存在 command；新入队留下个 tick；加 max guard + 锁定语义测试 | S |

</details>

---

## 3. 建议落地顺序（三波）

🌊 **Wave 1 — 正确性 / 隔离护栏（半天，全 S/M）**
`smoke_battle_math`（含吸收 `damage_mod_seen` 断言）→ 进化 gate 走派生真相 → 技能单清单收敛 →（R2）`drain_commands` 加战斗守卫 + `get_player_coord` fail-fast + command 基类 `apply` 改 assert。
*先把"能静默回归的数值层 + 隐性存档/隔离缺口"用测试和守卫钉死，再动后面任何重构都有网。*

🌊 **Wave 2 — 扩展 seam 收敛（1-2 天，M 为主）**
NPC 单一注册表 → `InkMonRosterSetup` 抽出 → `InkMonAIDecision` typed → footprint/距离/nearest-enemy 三处 helper 归一 →（R2）shop/adopt 接 content seam + item contract 类型门。
*消掉 shotgun surgery 税，让"加一只 InkMon / 一个技能 / 一个 NPC / 一个 item"回到改一处。*

🌊 **Wave 3 — 表演层下放 + facade 收紧（机会性，含唯一的 L）**
Host introspection 剥离 →（R2）`IWorldQuery` 转只读 DTO/snapshot（堵 mutable-actor 泄露 + 补语义方法 + 纠正文档 §1）→ Presentation 970 行按 §6 增量下放（先 modal 后 drawer）+ smoke 改走 public facade。
*不搞一次性大拆，与 adr/0002 否决大重构的理由一致。*

---

## 4. 调研方法与可信度（R1 — Claude）

- **方法**：10 个 reader agent 三 lens（可维护性/边界 · 可扩展性/扩展点 · 可测性/正确性）fan-out 扫 `inkmon/` 各子系统 + 横切铁律核对，对着 adr/0001-0007 的设计意图找漂移 → 逐 finding 一个怀疑者重读引用代码对抗式验证 → 综合（2026-06-13，59 agents）。
- **产量**：48 候选 → 验证保留 **47**（剔 1）。
- **已亲自重读真实代码核实的 headline**（标 ✅）：技能双清单 10 vs 6 漂移、进化 gate 本地重算丢装备加成、`damage_mod_seen` 焊进伤害热路径；**R2 新增已核实**：战斗 tick 抽干 command 队列（drain 缺战斗守卫）、`InkMonWorldCommand.apply` 基类 no-op fail-open。
- **已校正/证伪**（保留诚实记录）：host-1 由 high 降 medium（dev-agent 测试表面非 CQRS 铁律违反）；abilities-1 "崩溃 seam" 证伪为漂移税（move 不经 `get_skill_config`）；worldrest-4 的 `get('taget')` typo 证据不成立（实际拼写正确）。
- **范围外（本次未审）**：性能维度（用户排除）；addons/ LGF 框架；example；scripts/ web 桥。
- **已对照的"已决策/已知挂起"未当问题报**：`InkMonWorldGI` 中心 hub 不拆域对象（adr/0002）、双 grid 临时方案、`progression` 无类型 Dict、`f(species,level)` 线性公式、刻印实现框架——这些是有意设计或 §9 追踪项，本文只在代码**违反**它们时才记。

---

## 5. 第二轮 Codex 跨模型交叉验证（R2，2026-06-13）

> 用 **5 个 OpenAI Codex (gpt-5.5, xhigh) 分析师**对同一份 ADR 设计意图独立再审一轮（各自不知道 R1 的结论），产出 ~30 finding，与 R1 交叉比对。fan-out 组织同 R1（host+world / battle / services / presentation / 横切+测试 五块）。方法学意义：两个不同模型独立都点的 = 几乎必真；分歧的 = 暴露各自盲区。

### 🤝 跨模型共识（两轮独立都中 → 最高置信）
进化 stat-gate 丢装备加成（R1 P0 = codex-3 F2）· 战斗数值层零精确断言（R1 P0 = codex-2 F5 / 5 F4）· 技能注册多份手抄（R1 P1 = codex-2 F4 / 5 F2，**codex 加码第三份** metadata export）· NPC defs/handlers 多处硬编码（R1 = codex-1 F3 / 3 F5 / 5 F3）· AI 策略零覆盖（R1 = codex-5 F5）· Presentation 970 行胖根（R1 present-1 = codex-4 F2 / 5 F6）· `can_use_skill_on` 下沉（R1 = codex-1 F2）· AI decision 无类型 dict（R1 ai-2 = codex-2 F6）。
→ 这些是铁打的 P0/P1，已被两模型双盖章。

### 🆕 Codex 净增（R1 漏，已并入 §2 backlog 标 `(R2)`）
- ✅ 战斗 tick 抽干 command 队列（隔离破）— codex-2 F2，已核实 → **提 §1 P1**
- `get_player_coord` 静默 (0,0) + `to_dict` 回写（存档污染）— codex-1 F4 → **提 §1 P1**
- ✅ `InkMonWorldCommand.apply` 基类 no-op fail-open — codex-1 F5，已核实
- item contract `int()` 强转吞错类型 — codex-3 F4
- shop/领养硬编码 stub id，content 进不了 NPC 玩法 — codex-3 F3
- damage post-event 用 pre-damage alive list（死者仍收事件）— codex-2 F3
- NPC stale avatar / save close 3× 连接 / smoke 碰 Presentation 私有字段 / drain 无界抽干 — codex-4 F4·F6·F5 / codex-1 F6

### 🔵 Claude 独有（codex 这轮没点 → R1 净增）
`damage_mod_seen` 探针污染的 adr/0002 纪律角度（codex 提了 smoke 弱但没点污染序列化根）· `_add_roster_unit` 三处重复 · footprint/几何重复 · 裸 `print` 热路径 · 一批 low 尾巴（`call_deferred` 字符串 / `main.gd` null 守卫 / `get_attribute_set` push_error / 7 技能 gating 样板 / `SKILL_EVOLUTIONS` const 表）。

### ⚔️ 核心分歧 — IWorldQuery facade
R1 判 clean（无 `get_gi` 逃逸口 + 文档本就有意暴露 `player_actor`/`roster` 当 Query 通道）；R2 **五人独立判 high**（返回可变 actor = 写隔离仅约定级）。**裁决见 §1 新增 P2 主题"IWorldQuery facade 暴露可变 actor"**：两边各对一半，codex 的洞更根本，定 **medium**，揭示文档 §1 "结构隔离、物理够不到" 对**写** over-claim。

### 📊 总评 — 哪轮更强
- **R1（Claude 47 finding）赢在广度 + 纪律 + 验证严**：每条对抗式 verify，覆盖 low 尾巴 + adr/0002 routing 细节 + 测试探针污染的纪律视角。
- **R2（Codex 5 分析师）赢在深度 + 正确性/隔离结构**：facade 可变泄露 / 战斗隔离 / 存档坐标污染 / command fail-open / 契约强转 / content seam 这些**会真出 bug 的结构面**比 R1 尖；但广度窄、漏 R1 的纪律视角与多数 low。
- **结论：互补，并集才完整。** 共识项（进化 gate / battle math / 注册清单 / NPC table / 胖根）是双模型盖章的 P0/P1；R2 净增的隔离/正确性结构缺口已并入 backlog。**诚实自评**：R1 在 IWorldQuery 判得偏宽松、漏了 `base_tick→drain` 隔离链，codex 这两点扎实补强。
- **方法学备注**：R2 各 analyst 原始报告留档于 `tmp-design/codex-round/out-{1..5}.md`（未提交，git 历史外）。
