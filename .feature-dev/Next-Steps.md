# Next Steps

## 当前目标

**RTS Auto-Battle M1 架构重构 — Phase 2 (Core Systems)**

在 Phase 1 修好的骨架上,搭建**城堡战争核心玩法支柱**(含飞行单位)。

**Feature 总目标**: 把 RTS M0(功能 spike)演进为遵守 LGF 根原则的、支持城堡战争玩法的、流式 simulation + 决定性 replay 的工业级架构。
**总目标分三个 phase**, Phase 1 ✅ 已完成(2026-05-01), 当前 Phase 2 进行中(6/8 子任务完成: P2.1 + P2.2 + P2.3 + P2.4 + P2.5 + P2.6)。

> 完整决策与架构总图: [`task-plan/architecture-baseline.md`](task-plan/architecture-baseline.md)
> Phase 2 详细子任务: [`task-plan/phase-2-core-systems.md`](task-plan/phase-2-core-systems.md)
> Phase 3 已规划落盘([`task-plan/phase-3-advanced.md`](task-plan/phase-3-advanced.md)), 本轮**不执行**。

## Phase 2 当前进度

- ✅ P2.1 — Activity 系统(OpenRA 风, 替代 string FSM)
  - 详细 evidence: [`Progress.md`](Progress.md) AC1 + AC9
- ✅ P2.2 — Spatial Hash + Steering(避障 1+2 层)
  - 详细 evidence: [`Progress.md`](Progress.md) AC2 + AC9
- ✅ P2.3 — Stuck Detection + Local Repath(避障第 3 层)
  - 详细 evidence: [`Progress.md`](Progress.md) AC2 + AC9
- ✅ P2.4 — AutoTargetSystem(Mindustry + OpenRA 合璧)
  - 详细 evidence: [`Progress.md`](Progress.md) AC3 + AC9
- ✅ P2.5 — Production System + Building Factory
  - 详细 evidence: [`Progress.md`](Progress.md) AC4 + AC9
- ✅ P2.6 — Player Command + Building Placement + 胜负判定改写
  - 详细 evidence: [`Progress.md`](Progress.md) AC5 + AC9
- ⏳ P2.7 — Frontend BattleDirector 接入流式 events ← **下一个**
- ⏳ P2.8 — AIR Layer + target_layer_mask + 飞行单位

## 非目标(本轮 Phase 2 不做)

来自 [`task-plan/phase-2-core-systems.md`](task-plan/phase-2-core-systems.md) 的非目标 + Phase 3 的全部内容。

- ❌ 离散 tile.height + LOS(Phase 3 P3.1)
- ❌ Group formation(Phase 3 P3.2)
- ❌ RtsScenarioHarness(Phase 3 P3.3)
- ❌ Fog of War(Phase 3 P3.4)

## 验收准则(Phase 2)

详见 [`task-plan/phase-2-core-systems.md`](task-plan/phase-2-core-systems.md) §收口条件 — **10 条 acceptance**, 含:
- bit-identical event_timeline replay(同 seed + 同 player_commands → 同事件流)
- 飞行 vs 防空对位验证
- 城堡战争最小可玩 demo: 玩家放兵营 → 周期生产 → 单位自动出击 → 水晶塔判胜负

## 下一步

**P2.7 — Frontend BattleDirector 接入流式 events**

> 详见 [`task-plan/phase-2-core-systems.md`](task-plan/phase-2-core-systems.md) §P2.7

主要改动:
- 重构 `frontend/visualizers/rts_unit_visualizer.gd` (不再 `sync()` 拉 position; 改为订阅 `MoveCompleteEvent / DamageEvent / DeathEvent`)
- 新增 `frontend/visualizers/rts_building_visualizer.gd` (建筑 view, 含 hp bar / footprint outline / production progress 显示)
- 新增 `frontend/core/rts_battle_director.gd` (参照 hex `battle_director.gd`; 流式消费 procedure 当前 tick events; `_tick(delta)` 累积 logic_accumulator, 按 SIM_DT 推进)
- 新增 `frontend/world_view.gd` (响应 `actor_added / actor_removed / position_changed` signal)
- 新增插值层 — 每个 visualizer 持 prev_pos / curr_pos, `_process(alpha)` 插值到平滑位移
- 修改 `demo_rts_frontend.tscn` 接入 BattleDirector 替代直接 polling
- 新 smoke `tests/frontend/smoke_director_streaming.tscn` (跑 5 秒战斗, verify visualizer 收到 N 个 events 并表演)
- 编辑器 F6 验证 `demo_rts_frontend.tscn` 视觉流畅 (用户肉眼)

**关键约束**:
- frontend 不再有 0 处 `actor.position_2d` 直读 (state polling 全废, AC6 主断言)
- BattleDirector 的 SIM_DT (33.33ms @ 30Hz) 与 procedure 的 _tick_interval 对齐, 渲染 `_process` 走 alpha 插值
- 复用 hex `BattleDirector` 抽象基类时若有 hex_position 硬编码需要适配 (设计风险已在 phase-2-core-systems.md §已知风险 列出)
- Phase 2 P2.7 完成后 BattleRecorder 会持续 append `_player_commands_log` (P2.6 已铺好的字段) 到 `RtsRecording.player_commands`, 配合 AC10 bit-identical replay

## Phase 2 完成后

Phase 2 acceptance 全过 → **不归档**(同一 feature 仍未完结) → 用户**明确决定**是否启动 Phase 3:
- 启动 Phase 3: 切 Next-Steps / Progress 到 P3.1+
- 跳过 Phase 3: 直接进归档流程, 整个 RTS M1 重构 feature 收尾

## 启动新 feature 流程

要在 RTS M1 重构整体完成后开新的 feature(非本 feature 的延续), 调 `/next-feature-planner`:
- 整个 feature(含 Phase 1+2+3)归档至 `.feature-dev/archive/<YYYY-MM-DD>-rts-m1-refactor/`
- 重写本文件、`Current-State.md`、`Progress.md`、`task-plan/` 为新 feature
