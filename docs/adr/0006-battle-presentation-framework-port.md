# 0006: 战斗表演层 = 平移 hex frontend 表演框架（拷进 inkmon 做等轴 2D）

[adr/0005](0005-presentation-true-2d-isometric-hex.md) 决定战斗表现走真 2D 等轴并"新写 2D battle animator"。落地的首版（`inkmon/presentation/battle_2d/`）是个**扁平占位 animator**：`match`-on-kind 直接操作 2D 节点，没有可扩展的表演框架。

本 ADR 决定：把 hex-atb-battle frontend 那套**数据无关的表演框架**（visualizer 注册表 / action_scheduler / render_world 快照 / 声明式 VisualAction / actor render_state）**拷进 inkmon 改成等轴 2D**，取代扁平 animator。用户已在 hex frontend 设计好整套表演原语（伤害飘字、受击闪白、移动缓动、弹道、buff/盾条、朝向…），平移即复用这份设计，让逻辑层每出一个新事件机制，只需在框架槽位补对应原语，而非改 animator。

## Considered Options

- **保留扁平 animator** — 弃。每加一种表演都要改 `_apply_event` 的 match，无原语复用、无平滑插值层（hp 瞬变）、无调度层。
- **抽数据无关核心到 `stdlib/frontend/` 共享，hex(3D)+inkmon(2D) 共用一套引擎** — 暂弃。要改 submodule + 重构正在工作的 hex 示例（回归风险），且需抽象 2D/3D 坐标与视图工厂。当前仅 2 个消费者，未到 rule-of-three；留作日后出现第 3 个 2D 消费者时再评估。
- **拷进 inkmon 改 2D** — **选**。自包含、不动 submodule、不碰 hex 示例、风险最低，符合项目"取形不取器/防过度设计"惯例。代价 = 框架代码两份，未来框架改进需各自同步。

## Consequences

- **零 submodule 改动**：数据无关核心（render_world/scheduler/registry/context/animation_config/VisualAction）逐文件拷入 `inkmon/presentation/battle_2d/{core,actions}/`，`class_name` 统一改 `InkMonBattle2D*`（GDScript class_name 全项目唯一，必须避开 hex 的 `Frontend*`），`Vector3→Vector2`。
- **事件词汇耦合锁在 visualizer 层（Strategy B，不动逻辑层）**：visualizer 绑 inkmon 的 `inkmon_*` kind、**直接读序列化事件 dict 字段**（`InkMonBattleEvents` 多数事件无 `from_dict`，读 raw dict 更彻底不碰逻辑层，且 visualizer 只依赖 dict 契约而非逻辑类）；`damage` 缺的 `shield_absorbed/is_critical/is_reflected` 在 visualizer 内给默认值——逻辑层 `ink_mon_battle_events.gd` 不为表演层造字段。
- **首版打通 active 4 件**：move/damage/heal/death 跑通新管线；其余 9 个机制（displacement/push_blocked/regeneration/projectile/stageCue/buff/shield/facing）是 **dormant slot**，逻辑层出对应事件时按"visualizer + VisualAction + 2D 子视图"三件套 JIT 补，hex 示例留作设计参照源。
- **无向后兼容**：扁平 animator 旧实现整体删除，不留 shim/双路径；契约（`play_replay`/`playback_ended`/animator API）按需重设计并锁步改所有 call site（presentation/host/测试）。
- **表现升级**：hp 经 render_world 的 `visual_hp→target_hp` lerp 平滑过渡（旧版瞬变）；移动经 scheduler + MoveAction 缓动（旧版只认 move_complete 直接 snap）。
- `docs/main-game-architecture.md` / `docs/L2-ARCHITECTURE.md` 战斗表演段落同步指向本 ADR 与新框架结构。
