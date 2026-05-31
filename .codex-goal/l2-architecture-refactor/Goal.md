# L2 主游戏架构重构

## Objective

把 codex/claude 自由发挥造出的 L2 主游戏(app_root 1593 行 God object + 错位的 battle 实例 + 全代码 UI + 错误数据模型)重构成 `docs/L2-ARCHITECTURE.md` 定稿的目标架构:三块(主世界 hex / 战斗 procedure / session)+ 深度英雄数据模型 + ngnl 职责纪律。**唯一设计真相 = `docs/L2-ARCHITECTURE.md`**(本会话 grill 拍板),本文件只列落地相位与验收,不复述设计。

## Deliverables(8 相位,详细设计见 docs/L2-ARCHITECTURE.md)

- **P1 数据模型**:`InkMonRosterEntry` 改 `{entry_id, species, stage, level, exp, skill_slots:[{slot_index,skill_id}], engravings:[{engraving_id,target_slot}], equipment_container}`;删 `persistent_stats`(改 `f(species,level)` 派生)/ `learned_skill_id`(改 skill_slots);`medals` 移到 `InkMonPlayerState`;`to_dict/from_dict` 同步。
- **P2 出生+进化**:手搓 per-(species,stage,slot) 技能池;确定性出生 roll;进化链表(species 改写)+ X→X2(独立技能条目 + `evolves_to`)。
- **P3 战斗注入**:`project_to_battle_snapshot` 改投影 skill_slots + 派生 stats;`InkMonUnitActor.from_battle_snapshot` 吸收新形状;保留 M1 unit-key fallback。
- **P4 战斗合并**:`InkMonBattleWorldGI`(独立 world 实例)职责并入唯一 `InkMonWorldGI`(World-owns-Battle),战斗只留 `InkMonBattleProcedure`;双 grid 切 active 用第一版临时方案。
- **P5 God object 拆解**:5 个纯数据 NPC handler 收 `session` 自含规则(切断 `run_action(app_root)`);薄场景 Node(外层 screen 路由 + 内层游戏导播)。training handler 的"触发战斗"返回机制 = 相位开始时用 `game-architecture-patterns` skill 小决策并记 Progress。
- **P6 主世界**:寻路从自写 BFS 换 `ultra-grid-map` 插件 astar;玩家位置不双写(只住运行层);复核 baseline 已修的 UI race bug(drawer ghost / overlay 层级 / load-during-move)。
- **P7 UI .tscn**:HUD / drawer / modal / 动态列表全 `.tscn`(组件场景 instantiate),presentation 层只订阅 signal / 调窄 API,不直接改逻辑。
- **P8 装备+刻印+存档**:弃 `InkMonItemDomain.get_item_stat_mods` stub,接 lomolib Phase-G(`EquipmentManager`/`StatAggregator`/`AbilityGrantor`,数值+grant 技能);刻印生效(v1 只强化指定 skill_slot 的技能,实现框架相位开始小决策);存档改多槽 + save 菜单。
- **入口切换**:`project.godot run/main_scene` 切到 `InkMonMain`(薄场景);`Simulation.tscn` 退为纯 web 桥。

## Non-Goals

- 不改 `addons/`(submodule;若确需则在 submodule 内单独 commit 再 bump 指针)。
- 不动 `addons/logic-game-framework/example/hex-atb-battle/`(参考实现)。
- 不接 lab 真数据(技能池/物种手搓 stub;import 契约另立)。
- 不做技能数值变异(用户明确砍;个体独特性靠技能选择/刻印/装备)。
- 不做 PvP / 网络 / 出生属性变异(IV)。
- 不调战斗数值平衡;`f(species,level)` 用占位线性即可(公式 lab 待定)。
- 不写存档向后兼容/迁移(`from_dict` 遇旧版丢弃重开)。

## Validation(均 transcript 可观察)

- `./tools/run_tests.ps1 inkmon/m1` 退出 0(战斗核心 + snapshot 注入 + unit-key fallback 都过)。
- `./tools/run_tests.ps1 inkmon/session inkmon/content inkmon/app-root inkmon/overworld-3d` 退出 0。
- `./tools/run_tests.ps1 -Required` 退出 0(无 hex/core 回归)。
- save/load 往返单测:`session.to_dict()→from_dict()→to_dict()` 深相等(player + inventory 逻辑内容)。
- `grep` 证明 `InkMonRosterEntry` 不再含 `persistent_stats` / `learned_skill_id` / `medals` 字段。
- 玩家级 UI flow:DevAgent real-input run 跑通 v1 loop(移动→NPC→战斗→奖励→存档→读档),贴 session 目录/截图路径。

## Completion Gate

- 上述 Validation 全部命令在 transcript 中退出 0 / 断言通过。
- `git status` 工作树 clean(除既有 addons 指针漂移,如未处理需在 Progress 记明)。
- `docs/L2-ARCHITECTURE.md` §1-§8 的每条 ✅/❌/🔧 改动在实现中可逐项指认(Final Consistency Review 列出 file:line 证据)。
- 8 相位每个 commit 在 Progress.md 有对应 checkpoint,review 标 `pass` 或 `findings fixed`。
- Final Consistency Review 记入 Progress.md,无未解决 divergence;末行含 `Consistency review: no divergence` 或 `N items resolved`。
