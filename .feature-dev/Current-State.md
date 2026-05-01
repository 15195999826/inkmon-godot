# Current State — 2026-05-01(RTS M1 Phase 2 进行中, P2.1 + P2.2 + P2.3 + P2.4 完成)

inkmon-godot baseline 事实快照。开新 phase 前对齐用。

## 工程结构

- 主仓 `C:\GodotPorjects\inkmon-godot`,Godot 4.6 项目
- `addons/` 是单一 git submodule(→ `godot-addons.git`),含三个 addon:
  - `logic-game-framework`(核心 LGF: Actor/AbilitySet/Action/Event/Buff/Timeline/Replay)
  - `lomolib`(工具库)
  - `ultra-grid-map`(**Phase 1 起 RTS 例子也开始用** SQUARE grid_type, cell_size=32; 原本仅 hex-atb-battle 在用)
- 主仓 entry: `scenes/Simulation.tscn` + `scripts/SimulationManager.gd`(Web/headless 桥接)
- **`project.godot` autoload 列表**: `Log` / `IdGenerator` / `GameWorld` / `TimelineRegistry` / `WaitGroupManager` / `ItemSystem` / `UGridMap` / **`RtsRng`(Phase 1 P1.7 加入,用户授权)**

## RTS M1 架构重构当前状态

**Active feature**: RTS Auto-Battle M1 架构重构
**Active phase**: Phase 2 (Core Systems) — **进行中, 4/8 子任务完成 (P2.1 Activity + P2.2 Spatial Hash + Steering + P2.3 Stuck Recovery + P2.4 AutoTargetSystem)**
**完整规划**: `task-plan/architecture-baseline.md` + `phase-1/2/3-*.md` 全部就位
**Phase 1 状态**: ✅ 已完成 9/9 AC(2026-05-01); 不归档(同一 feature 早期 phase)
**Phase 2 状态**: P2.1 ✅ (Activity 系统替代 string FSM); P2.2 ✅ (Spatial Hash + Steering, 避障层 1+2); P2.3 ✅ (Stuck Detection + Local Repath + abandon_command, 避障层 3); P2.4 ✅ (AutoTargetSystem: priority + stance + 集中扫敌); P2.5-P2.8 待启动

### 13 条锁定决策(详见 `task-plan/architecture-baseline.md`)

| 决策 | 内容 | Phase 1 落地状态 |
|---|---|---|
| D1 | 玩法 = 城堡战争(玩家 + AI 混合驱动)| Phase 2 P2.5/P2.6 |
| D2 | 流式 sim,**不能算完再渲染** | Phase 2 P2.7 |
| D3 | 自研逻辑层寻路 + 形状碰撞,**不用 NavigationServer2D** | ✅ P1.2 |
| D3-A | 30Hz fixed-tick + 渲染插值 + 全局 RNG seed | ✅ P1.7(default 1000/30 ms) |
| D3-B | 2D grid + A*(不用 navmesh)| ✅ P1.2 |
| D3-C | 单位 = 圆,建筑 = AABB(3D 仅 frontend)| ✅ P1.1(actor.collision_radius)|
| D3-D | Layer-based 多层(GROUND / AIR)+ target_layer_mask | 接口预留 P1.1; 完整 Phase 2 P2.8 |
| D3-E | 离散 tile.height + 命中/视野 resolver | Phase 3 P3.1 |
| D3-F | ultra-grid-map plugin(不动)+ RTS wrapper | ✅ P1.2(`RtsBattleGrid`)|
| D3-G | cell_size = 32 + 标准 collision_radius = 14(MELEE 12 / RANGED 10)| ✅ P1.2 |
| E | RtsBuildingActor + building_kind 工厂模式 | 骨架 P1.1; 工厂 Phase 2 P2.5 |
| F | collision_radius 用连续 float | ✅ P1.1 |
| G | 4 层避障全要(hash + steering + stuck + formation)| ✅ P2.2 (hash + steering, 层 1+2) + ✅ P2.3 (stuck + local repath + abandon, 层 3); 层 4 Phase 3 P3.2 |
| H | AutoTargetSystem 集中扫敌 + priority + stance | ✅ P2.4 (RESCAN_INTERVAL_TICKS=20 + 失效即时重扫 + score=weight×1e5-dsq + HOLD_FIRE/DEFENSIVE/AGGRESSIVE) |

## 现有 LGF 示例(2 个,Phase 1 完成态)

### hex-atb-battle(既有;hex grid + ATB)

`addons/logic-game-framework/example/hex-atb-battle/{core,logic,frontend,skill-preview,tests}/`(Phase 1 不动)

### rts-auto-battle(Phase 2 P2.1 + P2.2 + P2.3 + P2.4 完成态)

```
rts-auto-battle/
├── core/        RtsWorldGameplayInstance(start_rts_battle 工厂) + RtsAutoBattleProcedure(内化主循环 + P2.2 movement 三段管线 + P2.4 AutoTargetSystem step 2.5) +
│                RtsDemoWorldGameplayInstance(demo subclass)
├── logic/       Actor 三层基类 + 模块化目录:
│   ├── rts_battle_actor.gd                              (P1.1 基类: position_2d/velocity/collision_radius/movement_layer/team_id/ability_set)
│   ├── rts_unit_actor.gd                                (P1.1, 重命名自 character; 持 unit_class + RtsUnitAttributeSet; **P2.4 加** Stance enum + unit_tags + target_priorities + _cached_target_id)
│   ├── rts_building_actor.gd                            (P1.1 骨架, Phase 2 P2.5 填工厂)
│   ├── movement_layer.gd                                (P1.1, GROUND/AIR enum)
│   ├── rts_rng.gd                                       (P1.7 autoload, set_seed/randf/randi/...)
│   ├── activity/{activity, idle, move_to, attack, attack_move}_activity.gd  (P2.1 新; P2.2 微调: tick 不再调 nav.tick — 移动归 procedure step 4)
│   ├── grid/{rts_battle_grid, rts_pathfinding}.gd       (P1.2 wrap GridMapModel + GridPathfinding.astar)
│   ├── movement/rts_minimal_push_out.gd                 (P1.2 O(N²) 妥协; P2.2 procedure 不再调用, 仅 smoke_minimal_push_out 自验证算法)
│   ├── movement/rts_spatial_hash.gd                     (P2.2 新: cell_size=64 桶索引 + sorted query_radius)
│   ├── movement/rts_unit_steering.gd                    (P2.2 新: separation + deflection, MAX_SEP_FRACTION=0.7 防反向; 静止单位仍施 sep)
│   ├── movement/rts_stuck_detector.gd                   (P2.3 新: per-actor stuck_ticks/repath_failures, 1s 未动 → local repath, 3 次失败 → controller.abandon_command)
│   ├── controller/rts_unit_controller.gd                (P2.1 重写: current_activity: RtsActivity 替代 _last_intent_action 字符串; reconcile + advance; P2.3 加 abandon_command / is_command_abandoned / clear_command_abandon API)
│   ├── ai/rts_ai_strategy.gd                            (P2.1 重写: decide 返回 RtsActivity; 通用工具 _get_enemies / _select_nearest 留给子类参考)
│   ├── ai/rts_basic_attack_strategy.gd                  (P2.1 + **P2.4 重写**: decide 直接读 actor._cached_target_id, 不再扫描; 失效 → IdleActivity 等下个 AutoTargetSystem 周期)
│   ├── ai/rts_ai_strategy_factory.gd                    (P1.5 共享无状态 strategy 实例)
│   ├── ai/rts_auto_target_system.gd                     (**P2.4 新**: RESCAN_INTERVAL_TICKS=20 全量 + 失效单位即时重扫; 评分 score=weight×1e5-dsq, 退化最近兼容; stance HOLD_FIRE/DEFENSIVE/AGGRESSIVE 处理)
│   ├── actions/rts_basic_attack_action.gd               (P1.4 extends Action.BaseAction)
│   ├── target_selectors.gd                              (P1.4 RtsTargetSelectors.CurrentUnitTarget)
│   ├── components/rts_nav_agent.gd                      (P1.2 去 NavigationAgent2D + GDScript path follower; P2.2 拆 movement: compute_desired_velocity / integrate / tick backwards-compat; P2.3 加 has_target / is_at_final_target / get_final_target / has_empty_path 访问器)
│   ├── config/rts_unit_class_config.gd                  (P1.2 加 collision_radius; **P2.4 加** StatBlock.unit_tags + target_priorities; MELEE/RANGED 默认 unit_tags)
│   ├── config/rts_unit_attribute_set.gd                 (P1.2 既有)
│   ├── logger/rts_battle_logger.gd                      (M0 既有, 不动)
│   ├── rts_battle_events.gd                             (M0 既有, 不动)
│   └── buildings/README.md                              (P1.1 占位, Phase 2 P2.5 填)
├── frontend/   最简 stub(Phase 1 不重构, Phase 2 P2.7 接 BattleDirector)
│   ├── scene/rts_battle_map.gd                          (P1.2 去 NavigationRegion2D 改 grid 标 cells (6..9, 6..9) blocking)
│   ├── visualizers/rts_unit_visualizer.gd               (M0 既有)
│   └── demo_rts_frontend.{gd,tscn}                      (P1.3 走 world.start_rts_battle)
└── tests/
    ├── battle/{smoke_skeleton, smoke_navigation, smoke_ai, smoke_attack, smoke_rts_auto_battle, smoke_grid_pathfinding, smoke_minimal_push_out, smoke_activity_chain, smoke_steering, smoke_stuck_recovery, smoke_auto_target}.{gd,tscn}
    │             (P1.2/P1.3/P1.4/P1.5/P1.6/P2.1/P2.2/P2.3/P2.4 全适配; smoke_auto_target 是 P2.4 新加 — 5 子测试: priority/HOLD_FIRE/DEFENSIVE/fallback/dead-cache)
    ├── replay/smoke_determinism.{gd,tscn} + README.md   (P1.7 新加, 同 seed 跑 2 次比对; P2.4 后仍 tick_diff=0 bit-equal, ticks=347)
    └── frontend/smoke_frontend_main.{gd,tscn}           (M0 既有)
```

两示例都遵循三层依赖方向 `core ← logic ← frontend`。

| 维度 | hex-atb-battle | rts-auto-battle (Phase 2 P2.4 末态) |
|---|---|---|
| 坐标系 | 离散 HexCoord(UGridMap)| 连续 Vector2 + grid index via `RtsBattleGrid` SQUARE |
| 节奏 | ATB 累积 → 满后放技能 | Fixed 30Hz tick(default; smokes 兼容 50ms 50Hz)+ tag-duration cooldown |
| 移动 | UGridMap 单格 | A* on grid + nav 拆 compute/integrate + spatial_hash + steering sep/deflection (P2.2) + stuck detection + local repath + abandon (P2.3) |
| 兵种 | 6 职业 + 完整技能池 | 2 兵种(melee/ranged)+ basic attack only |
| 单位规模 | 6v6(demo)| 4v4(M0/M1 起步) |
| AI | AIStrategy 无状态 ✓ | RtsAIStrategy 无状态 + RtsUnitController 持 runtime + **AutoTargetSystem (P2.4) 集中扫敌**, priority + stance ✓ |
| 决定性 | 内置 | RtsRng autoload + procedure rng_seed + AutoTargetSystem insertion-order iter (light determinism, bit-equal P2.4 验证 tick_diff=0) ✓ |

## 测试基线(Phase 2 P2.4 验收时全过)

| 入口 | 用途 | Phase 2 P2.4 末态 |
|---|---|---|
| `addons/logic-game-framework/tests/run_tests.tscn` | LGF 核心单元测试 | **73/73 PASS** |
| `addons/logic-game-framework/example/hex-atb-battle/logic/demo_headless.tscn` | hex ATB 战斗 headless smoke | **跑出 right_win, exit 0**(M0 既有 segfault 没复现) |
| `addons/logic-game-framework/example/hex-atb-battle/tests/battle/smoke_skill_scenarios.tscn` | skill 数值/tag/effect 契约 |(LGF 73/73 间接覆盖)|
| `addons/logic-game-framework/example/hex-atb-battle/tests/frontend/smoke_frontend_main.tscn` | hex 前端 demo 冒烟(~80% 回归面)| 同上 |
| `addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_skeleton.tscn` | 兵种 stats / cooldown(tag-duration)/ procedure 收尾 | **PASS** |
| `addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_navigation.tscn` | 单位绕障(grid + A*)| **PASS** (max_y_dev=74) |
| `addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_ai.tscn` | 1v1 AI controller 接敌 | **PASS** |
| `addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_attack.tscn` | Action.BaseAction 三段管线 | **PASS** |
| `addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_rts_auto_battle.tscn` | 4v4 主 acceptance smoke | **PASS** (P2.4 后: left_win, ticks=347, melee_max_dist=24.00, ranged_max_dist=125.75, detoured=4; AutoTarget 重评目标让战斗时长从 P2.3 239 → 347, 仍在 MAX_TICKS=1200 内分胜负) |
| `addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_grid_pathfinding.tscn` | P1.2 新: grid 寻路 + nav agent 链路 | **PASS** |
| `addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_minimal_push_out.tscn` | P1.2 新: O(N²) push-out 散开重叠单位 (procedure 不再调用, 仅自验证算法) | **PASS** |
| `addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_activity_chain.tscn` | P2.1 新: Activity primitive — 链顺序 + cancel 传播 + nav cleanup | **PASS** (phase1_ticks=26, drift=0.00) |
| `addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_steering.tscn` | P2.2 新: 8 单位 converging on (400, 100), 200 ticks 后 pair dist ≥ 2r-0.5 | **PASS** (movers=8/8, total_traveled=2746.7) |
| `addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_stuck_recovery.tscn` | P2.3 新: 3 单位塞中央障碍内, 200 ticks 后 ≥ 2 abandon (Idle, drift < 5px) | **PASS** (3/3 abandon, intents=idle, wants_to_attack=false) |
| `addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_auto_target.tscn` | **P2.4 新**: 5 子测试 — priority over distance / HOLD_FIRE / DEFENSIVE / no-priority fallback / dead-cache immediate rescan | **PASS** (5/5 子测试) |
| `addons/logic-game-framework/example/rts-auto-battle/tests/replay/smoke_determinism.tscn` | P1.7 新: 同 seed → 同 winner + ticks ± 1 | **PASS** (P2.4 后: seed=12345, run1=run2=(left_win, 347), tick_diff=0; bit-equal) |
| `addons/logic-game-framework/example/rts-auto-battle/tests/frontend/smoke_frontend_main.tscn` | 前端 visualizer 冒烟(8 visualizer) | **PASS** |

Phase 2 剩余将新增的 smoke:
- `tests/battle/smoke_production.tscn`(P2.5,建筑 spawn 单位)
- `tests/battle/smoke_player_command.tscn` + `smoke_crystal_tower_win.tscn`(P2.6, 玩家命令 + 胜负条件)
- `tests/frontend/smoke_director_streaming.tscn`(P2.7, frontend 流式 events)
- `tests/replay/smoke_replay_bit_identical.tscn`(P2.6+P2.7,完整流式 event_timeline)
- `tests/battle/smoke_flying_units.tscn`(P2.8,飞行单位 vs 防空)
- ……(详见 `phase-2-core-systems.md`)

## Git 状态(Phase 2 P2.4 验收完封板时)

主仓 `master` ahead origin/master 1 commit(M0 归档后),新增改动:
- `M project.godot`(P1.7 加 RtsRng autoload)
- `M .feature-dev/Current-State.md / Next-Steps.md / Progress.md / task-plan/README.md`(本轮 P2.4 文档更新)
- `?? .feature-dev/task-plan/architecture-baseline.md / phase-*.md`(规划阶段产出)
- `m addons`(submodule pointer 待 bump)

Submodule `addons/logic-game-framework/example/rts-auto-battle/` 累计改动 (跨 Phase 1 + P2.1-P2.4):
- `M` 12+ 处既有文件(actor / procedure / world / nav agent / map / smokes / config / strategy / controller / activity / etc.)
- `D` 4 处文件(`rts_basic_ai.gd` + `rts_character_actor.gd` + 各自 .uid, P1.1/P1.5 删)
- `?? ` 多处新文件: P1 (strategy / controller / grid / pathfinding / movement / building / rng / target_selectors); P2.1 (activity dir); P2.2 (spatial_hash / steering); P2.3 (stuck_detector); **P2.4 (auto_target_system)**; 各自 smoke 与 README

所有改动均为 untracked / unstaged;未 commit / push(按硬约束,不主动 commit)。

## 关键约束(Phase 2 期间继续遵守)

来自 `Autonomous-Work-Protocol.md`,跨 phase 不变:

1. **不修改 LGF submodule core / stdlib**(只在 example 目录下扩展)
2. **三层架构**: `core ← logic ← frontend`,frontend 不能被 core/logic 引用
3. **Headless 测试入口规范**: `SMOKE_TEST_RESULT: PASS|FAIL - <reason>` + 退出码 0
4. **跑 headless 不要 pipe**: redirect 到 `/tmp/*.txt` 再读
5. **不要 `godot --script`**: 永远用 `.tscn` 入口
6. **修改 `project.godot` autoload 需用户确认**(P1.7 已用过, Phase 2 P2.5 production system 若加 autoload 仍需重新确认)

## 决策来源

- M0 架构审查报告: `.feature-dev/archive/2026-04-30-rts-auto-battle/Summary.md`
- M1 重构决策讨论: `task-plan/architecture-baseline.md` + Phase 1 实施期 collision_radius 拆 (per-unit-class 12/10 让 2r ≤ atk_range × tolerance)
- Phase 1 9 条 acceptance 详细 evidence: `Progress.md`
