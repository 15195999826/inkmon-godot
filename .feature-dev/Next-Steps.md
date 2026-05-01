# Next Steps — 2026-05-01 (P2.7 完成, 进入 P2.8)

## 当前目标

**RTS Auto-Battle M1 架构重构 — Phase 2 (Core Systems)**

在 Phase 1 修好的骨架上,搭建**城堡战争核心玩法支柱**(含飞行单位)。

**Feature 总目标**: 把 RTS M0(功能 spike)演进为遵守 LGF 根原则的、支持城堡战争玩法的、流式 simulation + 决定性 replay 的工业级架构。
**总目标分三个 phase**, Phase 1 ✅ 已完成(2026-05-01), 当前 Phase 2 进行中(7/8 子任务完成: P2.1 + P2.2 + P2.3 + P2.4 + P2.5 + P2.6 + P2.7)。

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
- ✅ P2.7 — Frontend BattleDirector 接入流式 events
  - 详细 evidence: [`Progress.md`](Progress.md) AC6 + AC9 + AC10 (bit-identical replay 一并验证)
- ⏳ P2.8 — AIR Layer + target_layer_mask + 飞行单位 ← **下一个 (Phase 2 最后一个子任务)**

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

**P2.8 — AIR Layer + target_layer_mask + 飞行单位 (Phase 2 最后一个子任务)**

> 详见 [`task-plan/phase-2-core-systems.md`](task-plan/phase-2-core-systems.md) §P2.8

主要改动:
- 新增 `logic/units/flying/` (飞行 unit_class 配置 — 至少 1 个 AIR 单位, 如 flying_scout)
- 修改 `RtsUnitController` movement 分支: layer == AIR 不调 A* (直线朝目标飞 + 同层飞行单位间软排斥); 不写 pathing map; is_passable callback 对 ground 阻挡 return true
- 新增 `logic/weapons/rts_weapon_config.gd` 含 `target_layer_mask: int` (GROUND / AIR / BOTH bitmask)
- 修改 `RtsAutoTargetSystem`: 扫描时按 `mover.weapon.target_layer_mask` 过滤候选 (防空塔只挑 AIR; 普通弓兵 BOTH; 纯地面武器 GROUND-only)
- 修改 `RtsBasicAttackAction.can_hit(attacker, defender)`: 检查 layer mask, 不匹配 → invalid target (防御性检查)
- 修改 unit spawn 配置加 `default_movement_layer` + `weapon.target_layer_mask`
- 新增至少 1 个 anti-air weapon 配置 (archer_tower 升级或新塔)
- 新 smoke `tests/battle/smoke_flying_units.tscn`: 地面单位 + 防空塔 + 飞龙
  - 防空塔 (`target_layer_mask = AIR`) 只打飞龙
  - 普通地面单位 (`target_layer_mask = GROUND`) 打不到飞龙
  - 飞龙穿过地面建筑 footprint
- 升级 `frontend/visualizers/rts_unit_visualizer.gd` 让飞行单位画在 8px 上空 (走 actor.get_render_height — RtsBattleActor 已有 API, P1.1 接口预留)
- 单位攻击建筑能力一并接入 (P2.6 留在 P2.7+ 的 limitation, AC8 城堡战争最小可玩 demo 依赖此): AutoTargetSystem 候选扩到 RtsBuildingActor; BasicAttackAction target cast 兼容 building; building 受击事件 wiring

**关键约束**:
- 不修改 LGF submodule core / stdlib (硬约束 1)
- 飞行单位的 RtsUnitActor 子类化 vs 字段配置: 倾向后者 (movement_layer = AIR, 字段已在 RtsBattleActor)
- AC7 (smoke_flying_units) + AC8 (城堡战争最小可玩 demo) 联动验收
- bit-identical replay (AC10) 不能因 P2.8 引入随机回退 — 飞行单位与防空单位的目标筛选必须 deterministic (与 P2.4 AutoTargetSystem 同 by-team-key insertion-order 保证)

## Phase 2 完成后

Phase 2 acceptance 全过 → **不归档**(同一 feature 仍未完结) → 用户**明确决定**是否启动 Phase 3:
- 启动 Phase 3: 切 Next-Steps / Progress 到 P3.1+
- 跳过 Phase 3: 直接进归档流程, 整个 RTS M1 重构 feature 收尾

## 启动新 feature 流程

要在 RTS M1 重构整体完成后开新的 feature(非本 feature 的延续), 调 `/next-feature-planner`:
- 整个 feature(含 Phase 1+2+3)归档至 `.feature-dev/archive/<YYYY-MM-DD>-rts-m1-refactor/`
- 重写本文件、`Current-State.md`、`Progress.md`、`task-plan/` 为新 feature
