# L2 主世界 → WorldHost 同步 Tick 重构

## Objective

把 L2 主世界从「Host(原 `InkMonGameDirector`)持游戏逻辑/数据 + 即时同步 `move_actor_to`」重构成 `docs/L2-ARCHITECTURE.md §0.5` 定稿的**三层架构**:Host(`InkMonWorldHost`,composition root)只 boot / 接线 / tick 泵 / lifecycle;Logic(`GameWorld → InkMonWorldGI`)持世界运行时并经固定 30Hz tick 推进;Presentation 据 mutation signal 渲染。主世界移动改 **command → tick 逐格推进**(dota2-auto-battle 式),UI↔逻辑走 **CQRS**(读 query / 写 command+event)。**唯一设计真相 = `docs/L2-ARCHITECTURE.md §0.5` + `CONTEXT.md` 术语;本文件只列落地相位与验收,不复述设计。**

## Deliverables(9 相位)

- **P1 改名**:`InkMonOverworld* → InkMonWorld*`(Grid/MoveController/View3D + 全部引用 + .tscn + smoke 名);`InkMonGameDirector → InkMonWorldHost`。纯机械,行为不变。
- **P2 actor 层级**:新增 `InkMonWorldActor extends Actor`(持 `hex_position`,从 `InkMonBattleActor` 上移);`InkMonBattleActor extends InkMonWorldActor`;玩家/NPC 建成 `InkMonWorldActor` 进 GI registry。
- **P3 所有权内移**:world 数据 / session / npc 表 / overworld grid / near-npc 从 Host 搬进 `InkMonWorldGI`;Host 改 delegate。**移动暂仍同步(包一层),行为不变**。
- **P4 tick + command + 逐格移动(核心反转)**:Host 30Hz 定步泵(`GameWorld.tick_all(FIXED_DT)`);`InkMonWorldGI` 注册 CommandDrain + Movement System;world actor 逻辑态 `{cell, moving_to, progress, pending_path}`,每 tick 逐格 + emit `actor_position_changed`;View3D 改据 signal 补间(退出 `play_player_path` 整路 tween);连点 latest-wins **方案 A**(走完当前格 → 换 `astar(moving_to, target)`);CQRS:读 = 同步 query,写 = async command + event 回流。
- **P5 战斗触发 + 结果内移**:`request_battle` + `apply_battle_result` 进 `InkMonWorldGI`;training intent 内部解释起 procedure;双 grid 边界加固(Movement 读 `overworld_grid`,不读会翻转的 base `grid`)。
- **P6 NPC 服务内移**:`_npc_handlers` + `run_npc_action` / `buy` 进 `InkMonWorldGI`(或其持的 NpcService);Host 转发 UI 点击为 command / 调用。
- **P7 lifecycle 进 Host**:`InkMonWorldGI.capture_to_session()` / `hydrate_from_session()` + `InkMonSaveFile` helper;save / load / new-game / reset = Host **控台操作(非 command)**,单写不双写。
- **P8 表演抽离**:UI build/refresh 从 Host 抽到订阅 signal 的 view 脚本;拆 `app_state`(战斗 MODE 归 WorldGI / 面板态归表演);Host 只 instantiate + 连线。
- **P9 架构文档蒸馏**:把 `CONTEXT.md` + `docs/L2-ARCHITECTURE.md` **蒸馏成当前架构状态** —— 删掉过渡/计划性文本(§0.5 的「反转/将改/旧表述按此理解」、§1①/§4 的 supersede 标记、「待重命名」、「现状=错」等),把已落地的模型写成 present-state 真相;不留「曾经怎样/计划怎样」轨迹(历史归 git)。

## Non-Goals

- 不改 `addons/`(submodule:LGF / lomolib / ultra-grid-map;不动 hex-atb / dota2 example 参考实现)。
- 不改战斗数值 / 平衡(M1 双通道伤害 / 6 元素 / AI / action / passive 全保留);battle 仍 record-then-playback,不改战斗呈现。
- 双 grid 切 active 仍是第一版临时方案(只加固边界,不做最终形态)。
- 不接 lab 真数据(物种 / 技能池 / NPC 仍 stub)。
- 不做 PvP / 网络 / 出生属性变异。
- 不引入全局 EventBus autoload(上行仍用 WorldGI mutation signal)。

## Validation(均 transcript 可观察)

- `./tools/run_tests.ps1 inkmon/m1 inkmon/session inkmon/content inkmon/app-root inkmon/overworld-3d` 退出 0。
- `./tools/run_tests.ps1 -Required` 退出 0(无 hex/core/dota2 回归)。
- 改名彻底:`InkMonOverworld` 在 `scenes/` 下零类名/引用命中;`class_name InkMonGameDirector` 零命中;`InkMonWorldActor` 存在且 `InkMonBattleActor extends InkMonWorldActor`、`hex_position` 在 `InkMonWorldActor`。
- tick 模型落地(新 smoke,inkmon/overworld 组):同一 move command 序列两次跑出**位级一致**世界态;move 跨 N tick 推进(0 tick 不在终点,N tick 到);move 事件由 tick 产;表演据 snapshot/event 渲染(非 imperative 整路 tween);无 world-runtime↔save 双写。
- save/load 往返:`session.to_dict → from_dict → to_dict` 深相等;move → save → reset → load 还原位置。
- 文档蒸馏(P9 后):`待重命名|§0.5|反转|现状 ?= ?错|旧表述按` 等过渡语在 `docs/L2-ARCHITECTURE.md` + `CONTEXT.md` 对已落地项零命中;两文档为当前架构 present-state 描述。
- `git status` 工作树 clean。

## Completion Gate

- 上述 Validation 全部命令在 transcript 中退出 0 / 断言通过。
- `git log --oneline <goal-start-ref>..HEAD` 每个 commit 在 Progress.md 有对应 checkpoint,`/code-review max`(全 goal 范围 diff)标 `pass` 或 `findings fixed`,最近一次无未处理 high/critical。
- Final Consistency Review 记入 Progress.md:重读本文件,Deliverables/Non-Goals/Completion Gate 逐项与实现比对(file:line 证据),无未解决 divergence。
- Progress.md 末尾含一行 `Consistency review: no divergence`(或 `N items resolved`)。
