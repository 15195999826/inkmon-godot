# Next Steps

## 当前目标

**RTS Auto-Battle M1 架构重构 — Phase 2 (Core Systems)**

在 Phase 1 修好的骨架上,搭建**城堡战争核心玩法支柱**(含飞行单位)。

**Feature 总目标**: 把 RTS M0(功能 spike)演进为遵守 LGF 根原则的、支持城堡战争玩法的、流式 simulation + 决定性 replay 的工业级架构。
**总目标分三个 phase**, Phase 1 ✅ 已完成(2026-05-01), 当前 Phase 2 进行中(4/8 子任务完成: P2.1 + P2.2 + P2.3 + P2.4)。

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
- ⏳ P2.5 — Production System + Building Factory ← **下一个**
- ⏳ P2.6 — Player Command + Building Placement + 胜负判定改写
- ⏳ P2.7 — Frontend BattleDirector 接入流式 events
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

**P2.5 — Production System + Building Factory**

> 详见 [`task-plan/phase-2-core-systems.md`](task-plan/phase-2-core-systems.md) §P2.5

主要改动:
- 新增 `logic/buildings/rts_buildings.gd`(工厂 module)
  - `create_crystal_tower() / create_barracks() / create_archer_tower()`(building_kind 字符串区分)
- 新增 `logic/config/rts_building_config.gd`(建筑数值表: hp / footprint / production_period / spawn_unit_kind)
- 新增 `logic/production/rts_production_system.gd`
  - `tick(dt)`: 每个生产建筑累积 progress, 到点 spawn unit + 设 SpawnLane intent(去打对方水晶塔)
- 新增 `logic/buildings/rts_building_attribute_set.gd`(hp / max_hp + 可能的 production_speed_multiplier)
- 修改 `RtsBuildingActor` override `writes_to_pathing_map() = true`、`get_footprint_cells()` 返回 AABB cells
- 新 smoke `tests/battle/smoke_production.tscn`: 用 scripted `world.add_actor(barracks)` 直接放置, 跑 30 秒, 验证至少生成 N 个单位
- 单位 spawn 后立即向对方水晶塔进发(验证 SpawnLane intent)
- P2.6 落地后再加 `smoke_player_command_production.tscn` 验证"玩家命令 → placement → production"完整链路

**关键约束**:
- 建筑工厂模式 = `building_kind: String` 字段区分(决策 E from architecture-baseline.md)
- 建筑用 AABB collision_profile + 写 pathing map(单位绕过), 与 unit 的圆形 collision 不同
- production_system 是 system (放 logic/production/), 不是建筑组件 — 走 LGF system tick 路径
- spawn 出来的单位走 AutoTargetSystem 找目标 (P2.4 已就位); SpawnLane intent 是初始 attack-move 链头

## Phase 2 完成后

Phase 2 acceptance 全过 → **不归档**(同一 feature 仍未完结) → 用户**明确决定**是否启动 Phase 3:
- 启动 Phase 3: 切 Next-Steps / Progress 到 P3.1+
- 跳过 Phase 3: 直接进归档流程, 整个 RTS M1 重构 feature 收尾

## 启动新 feature 流程

要在 RTS M1 重构整体完成后开新的 feature(非本 feature 的延续), 调 `/next-feature-planner`:
- 整个 feature(含 Phase 1+2+3)归档至 `.feature-dev/archive/<YYYY-MM-DD>-rts-m1-refactor/`
- 重写本文件、`Current-State.md`、`Progress.md`、`task-plan/` 为新 feature
