# 0007: 统一主世界 + 战斗 2D 表演 —— overworld 接上共享 render_world 管线（live 事件源）

> **退役标注（2026-07-02，T2 G2 迁移）**：本 ADR 的共享视图件 `InkMonRender2DIsoHexGrid`
> （pointy-top 线框网格 + ISO_SQUISH 0.55 压扁）已随主世界/战斗两场景迁移到
> **flat-top baked tile 地图层** `InkMonRender2DBakedHexMap`（静态地图 JSON `content/maps/`
> + Lab 发布的 tile set，契约见 inkmon-lab `docs/architecture/godot-contract.md` Art Asset 章
> + ADR-0003）而**退役删除**。本 ADR 的其余决策（统一 render_world 管线 / live driver /
> view-local 边界 / MoveAction 移动统一）继续有效——换掉的只是网格视图件与其 pointy 几何。

[adr/0006](0006-battle-presentation-framework-port.md) 把 hex frontend 表演框架拷进 `battle_2d/`，事件源是冻结的 `ReplayData` 时间线。主世界 `InkMonOverworldView` 当时是另一套命令式 live 反应视图（presentation 在 WorldGI 信号上直接调 `step_player` + 自管 tween）。

本 ADR 决定：**让主世界与战斗走同一套 `事件→visualizer→render_world→2D 视图` 管线,只换事件源**。共享框架从 `battle_2d/` 提到 `render2d/`,battle 与 overworld 各自的 driver 喂同一套 render_world 核心。

## Considered Options

- **只共享视图件**（IsoHexGrid + Avatar），overworld 保留 live 反应式驱动 — 弃（用户明确选大投入）。回报小投入(拿到统一渲染 + Seedance 一次到位)但不统一架构。
- **全管线统一** — **选**。battle + overworld 同一 render_world/scheduler/visualizer 核心,overworld 移动也经 visualizer 注册表。最高一致性 / 单一心智模型。

## Consequences

- **模块重组（零 submodule 改动）**:
  - `render2d/`（前缀 `InkMonRender2D*`，从 `battle_2d` 提取 + 重命名）= 共享框架:`core/`(render_world/scheduler/registry/context/actor_render_state/render_data/animation_config/summary) + `actions/` + `visualizers/`(base + 共享 move) + `views/`(iso_hex_grid / avatar_2d / floating_text_2d)。
  - `battle_2d/` = battle 专属:replay driver(`InkMonBattle2DAnimator`) + battle view + damage/heal/death visualizer + battle registry。
  - `overworld/` = overworld 专属:`InkMonOverworldLiveDriver` + overworld registry + 重写的 `InkMonOverworldView`。
- **两事件源喂同一核心**:battle = replay drainer（按帧 drain 冻结时间线,有回放时钟/`playback_ended`）；overworld = **live driver**（订阅 `actor_position_changed` 等 WorldGI 信号 → `enqueue_move`，每帧 pump scheduler，无回放时钟/无 total_frames/无 end）。
- **RenderWorld 加 live 入口**（`seed_actor`/`despawn_actor`，与 replay 路径并行、共用 `_install_actor_state`），不污染 replay 路径。
- **共享视图件 = Seedance 落点**:`InkMonRender2DAvatar`（Style 描述 battle 单位 / overworld 玩家 / NPC 三态）的 `Body` 占位 `Polygon2D` 日后一处换 `AnimatedSprite2D`，两个表面都受益。
- **view-local 边界（不进 render_world）**:相机跟随 / idle 浮动（avatar 内部）/ 点击脉冲 / 目标 marker / 屏幕拾取 / 坐标几何 / NPC 高亮缩放。依赖 viewport/canvas transform 或纯装饰，无 render-state 语义。
- **移动统一**:overworld 逐格 Tween → 共享 `MoveAction`（220ms，scheduler 插值），latest-wins 去重（`scheduler.cancel_for_actor`）。
- **契约保持**:`InkMonOverworldView` 的公开方法 + dev-agent debug 面逐字不变 → `InkMonWorldPresentation` 零改。
- **诚实记账**:全管线下 ActionScheduler / VisualizerRegistry / RenderWorld 的 hp/伤害/调度对 overworld actor（无 hp）**闲置** —— 为 uniformity 付的价,非新债。真正高回报是 grid+avatar 共享 与 移动统一。
- **dormant**:overworld actor 无 hp（dormant 默认 + avatar style 关血条）；NPC despawn 暂 dormant。
- 重命名也使 [adr/0006](0006-battle-presentation-framework-port.md) 中「`InkMonBattle2D*`」对**共享类**的描述过时（现为 `InkMonRender2D*`）；battle 专属类仍 `InkMonBattle2D*`。
