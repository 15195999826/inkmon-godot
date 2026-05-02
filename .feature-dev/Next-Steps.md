# Next Steps — 2026-05-02 (Phase 2 全部完成 — 8/8 sub-tasks; AC 10/10 全过)

## 当前目标

**RTS Auto-Battle M1 架构重构 — Phase 2 (Core Systems) ✅ 已完成**

在 Phase 1 修好的骨架上,搭建**城堡战争核心玩法支柱**(含飞行单位)。

**Feature 总目标**: 把 RTS M0(功能 spike)演进为遵守 LGF 根原则的、支持城堡战争玩法的、流式 simulation + 决定性 replay 的工业级架构。
**总目标分三个 phase**, Phase 1 ✅ 已完成(2026-05-01), Phase 2 ✅ 已完成(2026-05-02), Phase 3 待用户明确决定。

> 完整决策与架构总图: [`task-plan/architecture-baseline.md`](task-plan/architecture-baseline.md)
> Phase 2 详细子任务: [`task-plan/phase-2-core-systems.md`](task-plan/phase-2-core-systems.md)
> Phase 3 已规划落盘([`task-plan/phase-3-advanced.md`](task-plan/phase-3-advanced.md)), 启动前需用户明确决定。

## Phase 2 完成态 — 8/8 sub-tasks + 10/10 AC

- ✅ P2.1 — Activity 系统(OpenRA 风, 替代 string FSM)
- ✅ P2.2 — Spatial Hash + Steering(避障 1+2 层)
- ✅ P2.3 — Stuck Detection + Local Repath(避障第 3 层)
- ✅ P2.4 — AutoTargetSystem(Mindustry + OpenRA 合璧)
- ✅ P2.5 — Production System + Building Factory
- ✅ P2.6 — Player Command + Building Placement + 胜负判定改写
- ✅ P2.7 — Frontend BattleDirector 接入流式 events
- ✅ P2.8 — AIR Layer + target_layer_mask + 飞行单位 + 单位攻击建筑

详细 evidence 见 [`Progress.md`](Progress.md) 各 AC checklist (AC1-AC10 全 PASS)。

## Phase 2 关键交付

- **Activity 系统**: OpenRA-风 actor.activity 链, 替代 string FSM
- **完整避障管线**: spatial hash + steering separation/deflection + stuck local repath/abandon (避障 1+2+3 层; 第 4 层 group formation 留 Phase 3)
- **AutoTargetSystem**: 集中扫敌 (20 tick rescan + 失效即时重扫), priority + stance, P2.8 扩到含建筑作 mover + candidates
- **Production System**: 建筑周期 spawn 单位; 工厂模式建筑 (crystal_tower / barracks / archer_tower)
- **Player Command + Crystal-tower 胜负**: PlaceBuildingCommand + RtsTeamConfig (build_zone / resources) + 胜负判定改 ct 死亡优先
- **Frontend BattleDirector 流式**: visualizer 0 处 actor.position_2d 直读, push 模式 + alpha 插值
- **Bit-identical Replay (AC10)**: 同 seed + 同 player_commands → timeline events + commands_log 全 bit-identical
- **AIR Layer + Anti-Air (P2.8)**: target_layer_mask bitmask + RtsWeaponConfig; 飞行单位走 _direct_path 穿地面建筑; archer_tower 防空; 单位可攻击建筑 (城堡战争最小可玩 demo 完整链路)

## 非目标(Phase 2 期间不做; Phase 3 范围)

来自 [`task-plan/phase-2-core-systems.md`](task-plan/phase-2-core-systems.md) 的非目标 + Phase 3 的全部内容。

- ❌ 离散 tile.height + LOS(Phase 3 P3.1)
- ❌ Group formation(Phase 3 P3.2; 避障第 4 层)
- ❌ RtsScenarioHarness(Phase 3 P3.3)
- ❌ Fog of War(Phase 3 P3.4)

## 下一步

**等待用户明确决定**:

### 选项 A — 启动 Phase 3 (Advanced 高级特性)

> 详见 [`task-plan/phase-3-advanced.md`](task-plan/phase-3-advanced.md)

Phase 3 子任务**独立可选** (用户按项目需要选做哪些, 不强制全做):
- P3.1 离散 tile.height + LOS
- P3.2 Group Formation (避障第 4 层)
- P3.3 RtsScenarioHarness (声明式测试)
- P3.4 Fog of War / Vision System

启动前用户需明确: 做哪几个? 优先级? 时间窗口?

### 选项 B — RTS M1 重构整体收尾 (跳过 Phase 3)

直接把整个 RTS M1 重构 feature (Phase 1+2) 归档到 `.feature-dev/archive/<YYYY-MM-DD>-rts-m1-refactor/`, 切回 "等待用户确认下一个 feature" 状态。

Phase 2 的"功能可玩"已经满足 RTS M1 milestone 范围 (用户最初目标: 把 M0 功能 spike 演进为合规架构 + 支持城堡战争玩法), Phase 3 是"锦上添花"的高级特性, 不是 M1 必需。

## F6 视觉验证 (AC8 user sign-off)

Phase 2 收口前用户应在编辑器中 F6 跑 `demo_rts_frontend.tscn` 验证视觉效果:
- 双方 crystal_tower + archer_tower + 4 ground unit + 1 flying_scout / 方
- 玩家点击左方 build_zone (50,50)~(250,450) → 放置 barracks (HUD 显示 resources 扣减)
- barracks 周期 spawn melee 朝右方 ct 进军
- archer_tower (左方) 击退 right_scout 飞行单位
- 战斗以一方 ct 死亡结束 (HUD 显示 ct hp 归 0)

如果上述视觉链路有 bug (而 headless smoke 没捕获), 启动 hotfix 在 Phase 3 启动前修。

## 启动新 feature 流程

要在 RTS M1 重构整体完成后开新的 feature(非本 feature 的延续), 调 `/next-feature-planner`:
- 整个 feature(含 Phase 1+2[+3])归档至 `.feature-dev/archive/<YYYY-MM-DD>-rts-m1-refactor/`
- 重写本文件、`Current-State.md`、`Progress.md`、`task-plan/` 为新 feature
