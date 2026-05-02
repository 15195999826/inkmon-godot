# Current State — 2026-05-02(RTS M1 Phase 2 ✅ 全部完成 — P2.1-P2.8 8/8 + AC 10/10 全过)

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
**Active phase**: Phase 2 (Core Systems) ✅ **全部完成 — 8/8 子任务 + 10/10 AC**(2026-05-02; P2.8 收口)
**完整规划**: `task-plan/architecture-baseline.md` + `phase-1/2/3-*.md` 全部就位
**Phase 1 状态**: ✅ 已完成 9/9 AC(2026-05-01); 不归档(同一 feature 早期 phase)
**Phase 2 状态**: ✅ 全部完成
- P2.1 ✅ Activity 系统替代 string FSM
- P2.2 ✅ Spatial Hash + Steering(避障 1+2 层)
- P2.3 ✅ Stuck Detection + Local Repath + abandon_command(避障 3 层)
- P2.4 ✅ AutoTargetSystem(priority + stance + 集中扫敌)
- P2.5 ✅ Production System + Building Factory(工厂模式建筑 / 周期 spawn / footprint 写 pathing map)
- P2.6 ✅ Player Command + Building Placement + 胜负判定改写(PlaceBuildingCommand + RtsTeamConfig + crystal-tower 模式 + override-strategy flag)
- P2.7 ✅ Frontend BattleDirector + RtsWorldView + 升级 UnitVisualizer + 新 BuildingVisualizer + smoke_director_streaming + smoke_replay_bit_identical(AC6 frontend 0 处 actor.position_2d 直读 + AC10 bit-identical event_timeline 验证)
- P2.8 ✅ AIR Layer + target_layer_mask + 飞行单位 + 单位攻击建筑(MovementLayer mask 常量 + RtsWeaponConfig + RtsBattleActor 共享攻击协议 + flying_scout/archer_tower anti-air + AutoTargetSystem 含建筑 + 飞行 8px 上空 + demo 城堡战争升级 + smoke_flying_units + smoke_castle_war_minimal)

**Phase 3 状态**: 待用户明确决定是否启动(`task-plan/phase-3-advanced.md` 已规划)

### 13 条锁定决策(详见 `task-plan/architecture-baseline.md`)

| 决策 | 内容 | 落地状态 (Phase 2 收口) |
|---|---|---|
| D1 | 玩法 = 城堡战争(玩家 + AI 混合驱动)| ✅ P2.5 (production) + ✅ P2.6 (player command + crystal-tower 胜负判定) + ✅ P2.8 (单位攻击建筑端到端 + flying vs anti-air) |
| D2 | 流式 sim,**不能算完再渲染** | ✅ P2.7 (BattleDirector + 0 处 polling) |
| D3 | 自研逻辑层寻路 + 形状碰撞,**不用 NavigationServer2D** | ✅ P1.2 |
| D3-A | 30Hz fixed-tick + 渲染插值 + 全局 RNG seed | ✅ P1.7(default 1000/30 ms) |
| D3-B | 2D grid + A*(不用 navmesh)| ✅ P1.2 |
| D3-C | 单位 = 圆,建筑 = AABB(3D 仅 frontend)| ✅ P1.1 (unit.collision_radius); ✅ P2.5 (building footprint AABB cells + 写 pathing map) |
| D3-D | Layer-based 多层(GROUND / AIR)+ target_layer_mask | ✅ P2.8 (MovementLayer mask 常量 + RtsWeaponConfig.matches; AIR 层走 _direct_path 不调 A*; archer_tower mask=AIR; flying_scout layer=AIR + mask=GROUND) |
| D3-E | 离散 tile.height + 命中/视野 resolver | Phase 3 P3.1 |
| D3-F | ultra-grid-map plugin(不动)+ RTS wrapper | ✅ P1.2(`RtsBattleGrid`)|
| D3-G | cell_size = 32 + 标准 collision_radius = 14(MELEE 12 / RANGED 10 / FLYING_SCOUT 10)| ✅ P1.2 + ✅ P2.8 (FLYING_SCOUT 沿用 ranged 的 10 px) |
| E | RtsBuildingActor + building_kind 工厂模式 | ✅ P2.5 (RtsBuildings.create_*; building_kind 字符串区分; AABB footprint); ✅ P2.8 (archer_tower 升级 anti-air 武器字段) |
| F | collision_radius 用连续 float | ✅ P1.1 |
| G | 4 层避障(hash + steering + stuck + formation)| ✅ P2.2 (hash + steering 1+2 层) + ✅ P2.3 (stuck + local repath + abandon 3 层); 层 4 (formation) Phase 3 P3.2 |
| H | AutoTargetSystem 集中扫敌 + priority + stance | ✅ P2.4 + ✅ P2.8 扩到 RtsBattleActor (movers + candidates 含建筑; layer mask 过滤) |

## 现有 LGF 示例(2 个,Phase 1 完成态)

### hex-atb-battle(既有;hex grid + ATB)

`addons/logic-game-framework/example/hex-atb-battle/{core,logic,frontend,skill-preview,tests}/`(Phase 1 不动)

### rts-auto-battle(Phase 2 P2.1-P2.8 全部完成 + AC 10/10 全过)

```
rts-auto-battle/
├── core/        RtsWorldGameplayInstance(start_rts_battle 工厂) + RtsAutoBattleProcedure(内化主循环 + P2.2 movement 三段管线 + P2.4 AutoTargetSystem step 2.5 + P2.5 start() 注册 building footprint + step 4e production_system.tick + add_unit_to_team API + **P2.6** _team_configs / _team_resources / _player_command_queue / _player_commands_log + step 1.5 apply_due + 重写 _check_battle_end 走 _is_team_lost crystal-tower 模式) +
│                RtsDemoWorldGameplayInstance(demo subclass)
├── logic/       Actor 三层基类 + 模块化目录:
│   ├── rts_battle_actor.gd                              (P1.1 基类: position_2d/velocity/collision_radius/movement_layer/team_id/ability_set; **P2.8 共享攻击协议**: current_target_id / target_layer_mask / unit_tags / target_priorities / _cached_target_id 上推 + virtual get_atk/def/attack_range/attack_speed + can_attack/start_attack_cooldown 共用)
│   ├── rts_unit_actor.gd                                (P1.1; 持 unit_class + RtsUnitAttributeSet; P2.4 stance; **P2.8 删去重复字段, override accessor 走 attribute_set; _init 从 stats 拷 default_movement_layer + target_layer_mask**)
│   ├── rts_building_actor.gd                            (P2.5 完整 actor; **P2.8 加 atk_value/def_value/attack_range_value/attack_speed_value plain float 字段 + override accessor; 防空塔走此路径 attack**)
│   ├── movement_layer.gd                                (P1.1 GROUND/AIR enum; **P2.8 加 MASK_NONE/MASK_GROUND/MASK_AIR/MASK_BOTH 常量 + mask_for_layer/mask_matches static helpers**)
│   ├── weapons/rts_weapon_config.gd                    (**P2.8 新**: RtsWeaponConfig — `matches(mask, candidate_layer)` + `can_hit(attacker, target)` static helpers; attacker.target_layer_mask 命中候选 layer 的统一查询入口)
│   ├── rts_rng.gd                                       (P1.7 autoload, set_seed/randf/randi/...)
│   ├── activity/{activity, idle, move_to, attack, attack_move}_activity.gd  (P2.1 新; P2.2 微调: tick 不再调 nav.tick — 移动归 procedure step 4)
│   ├── grid/{rts_battle_grid, rts_pathfinding}.gd       (P1.2 wrap GridMapModel + GridPathfinding.astar)
│   ├── movement/rts_minimal_push_out.gd                 (P1.2 O(N²) 妥协; P2.2 procedure 不再调用, 仅 smoke_minimal_push_out 自验证算法)
│   ├── movement/rts_spatial_hash.gd                     (P2.2 新: cell_size=64 桶索引 + sorted query_radius)
│   ├── movement/rts_unit_steering.gd                    (P2.2 新: separation + deflection, MAX_SEP_FRACTION=0.7 防反向; 静止单位仍施 sep)
│   ├── movement/rts_stuck_detector.gd                   (P2.3 新: per-actor stuck_ticks/repath_failures, 1s 未动 → local repath, 3 次失败 → controller.abandon_command)
│   ├── controller/rts_unit_controller.gd                (P2.1 重写: current_activity: RtsActivity 替代 _last_intent_action 字符串; reconcile + advance; P2.3 加 abandon_command / is_command_abandoned / clear_command_abandon API; **P2.6** 加 _player_command_active flag + set_activity_chain(chain, override_strategy=false) 第 2 参数 + clear_player_command_override / is_player_command_active)
│   ├── ai/rts_ai_strategy.gd                            (P2.1 重写: decide 返回 RtsActivity; 通用工具 _get_enemies / _select_nearest 留给子类参考)
│   ├── ai/rts_basic_attack_strategy.gd                  (P2.1+P2.4 重写; **P2.8 _resolve_cached_target 返回 RtsBattleActor 让单位可选 building 当目标**)
│   ├── ai/rts_ai_strategy_factory.gd                    (P1.5 共享无状态 strategy 实例)
│   ├── ai/rts_auto_target_system.gd                     (P2.4; **P2.8 重写: tick 入参 alive_actors 含建筑; movers/candidates 都是 RtsBattleActor; 候选过滤加 layer mask; stance 仅 RtsUnitActor**)
│   ├── actions/rts_basic_attack_action.gd               (P1.4 extends Action.BaseAction; **P2.8 重写: attacker/target = RtsBattleActor; virtual accessor 取数值; target_attrs.get_raw().get_current_value("hp") 兼容; can_hit 防御性 layer mask 检查**)
│   ├── target_selectors.gd                              (P1.4; **P2.8 attacker/target cast 都 RtsBattleActor**)
│   ├── activity/attack_activity.gd                      (**P2.8 target 类型放宽 RtsBattleActor — 单位可选 building 当目标**)
│   ├── components/rts_nav_agent.gd                      (P1.2 去 NavigationAgent2D; P2.2 拆 movement; P2.3 加访问器)
│   ├── grid/rts_pathfinding.gd                          (**P2.8 AIR 层早 return _direct_path 不调 A* — 飞行单位穿地面建筑 footprint**)
│   ├── config/rts_unit_class_config.gd                  (P1.2 collision_radius; P2.4 unit_tags + target_priorities; **P2.8 加 default_movement_layer + target_layer_mask; 新 UnitClass.FLYING_SCOUT (Layer.AIR + MASK_GROUND, hp=90/atk=15/move_speed=100/range=80)**)
│   ├── config/rts_unit_attribute_set.gd                 (P1.2 既有)
│   ├── config/rts_building_config.gd                    (P2.5 + P2.6 cost; **P2.8 StatBlock 加 atk/def/attack_range/attack_speed/target_layer_mask/unit_tags; archer_tower 升级 anti-air (atk=25, range=140, mask=MASK_AIR)**)
│   ├── config/rts_team_config.gd                        (**P2.6 新**: RtsTeamConfig — team_id / faction_id / starting_resources / build_zone Rect2 / crystal_tower_id; `unconfigured(team_id)` + `create(...)` 工厂; `has_build_zone / contains_position / has_crystal_tower` 查询)
│   ├── commands/rts_player_command.gd                   (**P2.6 新**: 玩家命令基类 — tick_stamp + team_id + apply 钩子 + serialize 录像支持)
│   ├── commands/rts_place_building_command.gd          (**P2.6 新**: PlaceBuildingCommand — building_kind + position_2d; apply 走 placement.validate → factory → add_actor → place_building → spend_team_resources → add_unit_to_team → 自动绑 ct_id)
│   ├── commands/rts_player_command_queue.gd            (**P2.6 新**: 队列 — enqueue / apply_due (按 tick_stamp 升序, 同 tick 保 insertion-order, 决定性) / history append / get_failed_history)
│   ├── commands/rts_building_placement.gd              (**P2.6 新**: 静态校验 — build_zone / 地图边界 / cells 阻挡 / cells 占用 / 资源充足; 返回 reason 枚举 + footprint + cost)
│   ├── commands/README.md                              (**P2.6 新**: commands/ 目录使用说明)
│   ├── buildings/rts_buildings.gd                       (P2.5 工厂 module; **P2.8 _create_from_kind 注入 atk/def/attack_range/attack_speed/target_layer_mask/unit_tags 给 building actor**)
│   ├── buildings/rts_building_attribute_set.gd          (P2.5 新: hp / max_hp / production_speed_multiplier; cross-clamp hp ≤ max_hp)
│   ├── production/rts_production_system.gd              (P2.5 新: 纯 RefCounted; tick(dt_ms, world, spawner) 走全部 alive 建筑累加 progress, 满周期触发 spawner.call(building); 不调 randf 决定性安全)
│   ├── logger/rts_battle_logger.gd                      (M0 既有, 不动)
│   └── rts_battle_events.gd                             (M0 既有, 不动)
├── frontend/   **Phase 2 P2.7 重构 + P2.8 飞行渲染 + 城堡战争 demo 升级**
│   ├── core/rts_battle_director.gd                      (P2.7 Node 实时 sim + tick boundary capture render state + 4 signals)
│   ├── world_view.gd                                    (P2.7 监听 actor lifecycle 路由 visualizer; **P2.8 spawn 时 hydrate actor.get_render_height() 给 unit visualizer**)
│   ├── scene/rts_battle_map.gd                          (P1.2 去 NavigationRegion2D 改 grid 标 cells (6..9, 6..9) blocking)
│   ├── visualizers/rts_unit_visualizer.gd               (P2.7 push 模式 + alpha 插值; **P2.8 bind 加 p_render_height 参数; _process 减 Vector2(0, render_height) 让 AIR 单位上抬 8px**)
│   ├── visualizers/rts_building_visualizer.gd           (P2.7 AABB footprint + hp bar + 水晶塔金色边框)
│   └── demo_rts_frontend.{gd,tscn}                      (**P2.8 升级城堡战争最小可玩 demo**: 双方 ct + archer_tower (anti-air) + 4 ground unit + 1 flying_scout / 方; HUD Label 显示 resources + ct hp; 鼠标左键点击 build_zone → enqueue PlaceBuildingCommand barracks; spawner 让 barracks spawn melee 朝对方 ct 进军)
└── tests/
    ├── battle/smoke_*.tscn (15+ smoke):
    │   - skeleton, navigation, ai, attack (P1)
    │   - rts_auto_battle (4v4 主 acceptance smoke), grid_pathfinding, minimal_push_out (P1)
    │   - activity_chain, steering, stuck_recovery, auto_target (P2.1-P2.4)
    │   - production, player_command, crystal_tower_win, player_command_production (P2.5-P2.6)
    │   - **flying_units** (P2.8 新; AC7), **castle_war_minimal** (P2.8 新; AC8 headless)
    │   全部 P1+P2.1-P2.8 smokes PASS, 4v4 主 smoke ticks=347 不退化
    ├── replay/smoke_determinism.{gd,tscn}                (P1.7 同 seed → 同 winner + ticks; P2.8 后仍 tick_diff=0 bit-equal)
    ├── replay/smoke_replay_bit_identical.{gd,tscn}      (P2.7 AC10: 同 seed=42 + 同 2 commands → timeline + commands_log bit-identical; P2.8 后仍 PASS, frames=9, events=20)
    └── frontend/smoke_frontend_main.{gd,tscn}            (**P2.8 EXPECTED_VISUALIZERS 8 → 10**: 4 ground + 1 flying / 方) + smoke_director_streaming.{gd,tscn} (P2.7 4v4 director path 验证 render_emits / attack_emits 流动)
```

两示例都遵循三层依赖方向 `core ← logic ← frontend`。

| 维度 | hex-atb-battle | rts-auto-battle (Phase 2 P2.8 末态) |
|---|---|---|
| 坐标系 | 离散 HexCoord(UGridMap)| 连续 Vector2 + grid index via `RtsBattleGrid` SQUARE |
| 节奏 | ATB 累积 → 满后放技能 | Fixed 30Hz tick(default; smokes 兼容 50ms 50Hz)+ tag-duration cooldown |
| 移动 | UGridMap 单格 | A* on grid + nav 拆 compute/integrate + spatial_hash + steering sep/deflection (P2.2) + stuck detection + local repath + abandon (P2.3) |
| 兵种 | 6 职业 + 完整技能池 | 3 兵种(melee/ranged/flying_scout)+ basic attack only; melee=GROUND only, ranged=BOTH (anti-air), flying_scout=AIR + GROUND-only attack |
| 单位规模 | 6v6(demo)| 4v4(M0/M1 起步)+ P2.5 起 building spawn 增 (双 barracks 30s @ 50ms 各 spawn 7 个) |
| 建筑 | 单 EnvironmentActor 子类 (StoneWall) | P2.5: RtsBuildingActor 工厂 (crystal_tower / barracks / archer_tower) + AABB footprint 写 pathing map + 周期 production; **P2.8: archer_tower 升级 anti-air (mask=AIR); 建筑作为 AutoTargetSystem mover/candidate; 单位可攻击建筑 (ct 死判胜负 走端到端)** |
| 玩家命令 | 无(回合制无玩家命令)| P2.6: RtsPlayerCommand + RtsPlayerCommandQueue tick-stamped + RtsTeamConfig (faction / starting_resources / build_zone / crystal_tower_id); PlaceBuildingCommand 走 RtsBuildingPlacement.validate, 失败 reason 进 history, override-strategy flag 让玩家命令链不被 strategy.decide 替换 |
| 胜负判定 | hex 战斗专属 | P2.6 改写: crystal-tower-死亡优先 (`_check_battle_end` 走 `_is_team_lost` per team; team_config.has_crystal_tower 走 ct 模式, 否则 fallback team-wipeout 兼容 Phase 1); 4v4 主 smoke 不传 team_configs → fallback 0 行为差 |
| AI | AIStrategy 无状态 ✓ | RtsAIStrategy 无状态 + RtsUnitController 持 runtime + AutoTargetSystem (P2.4) 集中扫敌, priority + stance ✓ |
| 决定性 | 内置 | RtsRng autoload + procedure rng_seed + AutoTargetSystem insertion-order iter (light determinism, P2.7 进一步 bit-equal 验证 — smoke_replay_bit_identical 同 seed + 同 commands → timeline events 逐字段 deep equal) ✓ |
| 前端 | hex BattleDirector 离线 replay + Animator + RenderWorld + 4 层 visualizer | **P2.7: 实时 sim 模式 — RtsBattleDirector (Node, _process tick 推 procedure + tick boundary capture render state + emit signals); RtsWorldView (actor_added/removed 路由 + signal → visualizer 分发); visualizer 0 处 actor 直读 (push 模式 + alpha 插值)**; 视觉特效 stub (圆圈 + hp; 完整 BattleAnimator 管线留后续 milestone) |
| 录像 | hex 完整 ReplayData / BattleRecorder | RTS 走 stdlib BattleRecorder 输出 timeline; **P2.7: procedure.finish 注 player_commands + rng_seed 进 record dict** — RtsRecording wrapper 类 deferred 到 Phase 3, 当前 dict 注入足以支撑 AC10 |

## 测试基线(Phase 2 P2.8 验收时全过 — AC 10/10)

| 入口 | 用途 | Phase 2 P2.8 末态 |
|---|---|---|
| `addons/logic-game-framework/tests/run_tests.tscn` | LGF 核心单元测试 | **73/73 PASS** |
| `addons/logic-game-framework/example/hex-atb-battle/logic/demo_headless.tscn` | hex ATB 战斗 headless smoke | **跑出 left_win, exit 0**(既有 segfault 没复现) |
| `addons/logic-game-framework/example/hex-atb-battle/tests/battle/smoke_skill_scenarios.tscn` | skill 数值/tag/effect 契约 |(LGF 73/73 间接覆盖)|
| `addons/logic-game-framework/example/hex-atb-battle/tests/frontend/smoke_frontend_main.tscn` | hex 前端 demo 冒烟(~80% 回归面)| 同上 |
| `addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_skeleton.tscn` | 兵种 stats / cooldown(tag-duration)/ procedure 收尾 | **PASS** |
| `addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_navigation.tscn` | 单位绕障(grid + A*)| **PASS** |
| `addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_ai.tscn` | 1v1 AI controller 接敌 | **PASS** |
| `addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_attack.tscn` | Action.BaseAction 三段管线 | **PASS** |
| `addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_rts_auto_battle.tscn` | 4v4 主 acceptance smoke | **PASS** (P2.7 后仍: left_win, ticks=347, melee_max_dist=24.00, ranged_max_dist=125.75, detoured=4; 不传 team_configs → fallback 全灭判定 0 行为差) |
| `addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_grid_pathfinding.tscn` | P1.2 新: grid 寻路 + nav agent 链路 | **PASS** |
| `addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_minimal_push_out.tscn` | P1.2 新: O(N²) push-out 散开重叠单位 (procedure 不再调用, 仅自验证算法) | **PASS** |
| `addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_activity_chain.tscn` | P2.1 新: Activity primitive — 链顺序 + cancel 传播 + nav cleanup | **PASS** |
| `addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_steering.tscn` | P2.2 新: 8 单位 converging on (400, 100), 200 ticks 后 pair dist ≥ 2r-0.5 | **PASS** |
| `addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_stuck_recovery.tscn` | P2.3 新: 3 单位塞中央障碍内, 200 ticks 后 ≥ 2 abandon (Idle, drift < 5px) | **PASS** |
| `addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_auto_target.tscn` | P2.4 新: 5 子测试 — priority over distance / HOLD_FIRE / DEFENSIVE / no-priority fallback / dead-cache immediate rescan | **PASS** |
| `addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_production.tscn` | P2.5 新: 双 barracks 对称 30s @ 50ms = 600 ticks; assert ≥ 5 spawn / team + 至少 1 left spawn 朝东 ≥ 50px + footprint blocking 验证 | **PASS** (left_spawned=7 right_spawned=7 max_left_eastward=118.51 px) |
| `addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_player_command.tscn` | P2.6 新: 3 phase 玩家命令 — 放兵营 ok + 同位置二次 fail (cells_blocked) + 建造区外 fail (out_of_build_zone) | **PASS** (log 3 entries; resources 200→100; placed_id=Building_4) |
| `addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_crystal_tower_win.tscn` | P2.6 新: 双 ct 起手 → procedure.start() 自动绑 ct_id; 手动 mark_dead 右方 ct → result=left_win (验证新胜负规则) | **PASS** (ticks=2; 右方 ct 死 → left_win; 自动绑定生效) |
| `addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_player_command_production.tscn` | P2.6 新: P2.5+P2.6 联动 — tick 30 玩家命令放兵营 → 600 ticks 后 spawn ≥ 3 melee + override-strategy SpawnLane | **PASS** (left_spawned=7, max_eastward=254.74 px, resources=100) |
| `addons/logic-game-framework/example/rts-auto-battle/tests/replay/smoke_determinism.tscn` | P1.7 新: 同 seed → 同 winner + ticks ± 1 | **PASS** (P2.7 后: seed=12345, run1=run2=(left_win, 347), tick_diff=0; bit-equal) |
| `addons/logic-game-framework/example/rts-auto-battle/tests/frontend/smoke_frontend_main.tscn` | 前端 visualizer 冒烟(8 visualizer) | **PASS** (P2.7 升级走 director path: visualizers=8 alive_after_3.0s=8) |
| `addons/logic-game-framework/example/rts-auto-battle/tests/frontend/smoke_director_streaming.tscn` | **P2.7 新**: 4v4 走 director path 跑 4s; 验证 render_emits > 0 + attack_emits > 0 + 至少 1 visualizer moved 离 spawn x | **PASS** (visualizers=8 render_emits=648 attack_emits=16 moved=8 ticks=80) |
| `addons/logic-game-framework/example/rts-auto-battle/tests/replay/smoke_replay_bit_identical.tscn` | **P2.7 新 (AC10)**: 同 seed=42 + 同 2 commands tick 5/10 跑 2 次 100 ticks; 验证 timeline events 逐字段 deep equal (HexCoord q/r 比对) + player_commands_log entry-by-entry deep equal + rng_seed 一致 | **PASS** (P2.8 后仍 bit-identical, frames=9, events=20) |
| `addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_flying_units.tscn` | **P2.8 新 (AC7)**: archer_tower (mask=AIR) + melee (mask=GROUND, HOLD_FIRE) + barracks 障碍 + flying_scout (AIR, AttackMove) + ground_melee (AttackMove); 验证 anti-air 命中飞行 / GROUND 命不到 AIR / 飞行直线穿建筑 | **PASS** (ticks=200, scout_hp=15, archer_hits=3, melee_hits_scout=0, scout 飞达 (50, 100)) |
| `addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_castle_war_minimal.tscn` | **P2.8 新 (AC8 headless)**: 双方 ct + archer_tower; 玩家 tick 1 enqueue PlaceBuildingCommand barracks; 600 ticks 主循环验证 result=*_win + unit→building 攻击 ≥1 + archer→scout 命中 ≥1 | **PASS** (ticks=193 result=left_win unit_to_building_attacks=4 archer_anti_air=1 spawn_count=2) |

Phase 2 全部 sub-tasks 完成 — 不再有 forward-looking smoke 计划。Phase 3 (P3.1 height/LOS, P3.2 group formation, P3.3 ScenarioHarness, P3.4 Fog of War) 待用户决定启动。

## Git 状态(Phase 2 P2.8 验收完封板时, commit 前)

主仓 `master` ahead origin/master 4 commit(P2.5 文档 + P2.6 文档 + P2.7 + 历史 M0 归档),P2.8 改动尚未 commit:
- `M .feature-dev/Current-State.md / Next-Steps.md / Progress.md / task-plan/phase-2-core-systems.md`(本轮 P2.8 文档更新)
- `m addons`(submodule pointer 待 bump 进 P2.8)

Submodule `addons/logic-game-framework/example/rts-auto-battle/` 累计改动 (跨 Phase 1 + P2.1-P2.8):
- `M` 多处既有文件: P1+P2.1-P2.7 改动; **P2.8 改动**: `logic/movement_layer.gd` (mask 常量) / `logic/rts_battle_actor.gd` (共享攻击协议) / `logic/rts_unit_actor.gd` (删重复字段, override accessor) / `logic/rts_building_actor.gd` (武器字段) / `logic/config/rts_unit_class_config.gd` (FLYING_SCOUT + 字段) / `logic/config/rts_building_config.gd` (武器字段 + archer_tower 升级) / `logic/buildings/rts_buildings.gd` (注入字段) / `logic/grid/rts_pathfinding.gd` (AIR 短路) / `logic/ai/rts_auto_target_system.gd` (重写) / `logic/ai/rts_basic_attack_strategy.gd` (target 类型放宽) / `logic/actions/rts_basic_attack_action.gd` (重写 RtsBattleActor) / `logic/activity/attack_activity.gd` (target 类型放宽) / `logic/target_selectors.gd` (放宽) / `core/rts_auto_battle_procedure.gd` (建筑攻击循环 + alive_actors_for_target) / `frontend/visualizers/rts_unit_visualizer.gd` (render_height) / `frontend/world_view.gd` (hydrate render_height) / `frontend/demo_rts_frontend.gd` (城堡战争升级) / `tests/frontend/smoke_frontend_main.gd` (10 visualizers)
- `?? ` 新文件 (P2.8): `logic/weapons/rts_weapon_config.gd` + `tests/battle/smoke_flying_units.{gd,tscn}` + `tests/battle/smoke_castle_war_minimal.{gd,tscn}`

所有改动均为 untracked / unstaged;按 Autonomous-Work-Protocol 阶段性即提 — 本轮 P2.8 收口同步提交 (submodule 先, 主仓 bump pointer 后)。

## 关键约束(Phase 2 期间继续遵守)

来自 `Autonomous-Work-Protocol.md`,跨 phase 不变:

1. **不修改 LGF submodule core / stdlib**(只在 example 目录下扩展; P2.7 procedure.finish wrap + P2.8 全部新增类 / 字段都在 example 目录下; BattleRecorder / Action / EventProcessor 等 stdlib 接口没动)
2. **三层架构**: `core ← logic ← frontend`,frontend 不能被 core/logic 引用 (P2.7-P2.8: BattleDirector / WorldView / visualizer 全在 frontend; 仅向下读 logic 类型 + 一次性 hydrate; demo 鼠标点击通过 procedure.enqueue_player_command 反向调 logic API, 单向依赖)
3. **Headless 测试入口规范**: `SMOKE_TEST_RESULT: PASS|FAIL - <reason>` + 退出码 0
4. **跑 headless 不要 pipe**: redirect 到 `/tmp/*.txt` 再读
5. **不要 `godot --script`**: 永远用 `.tscn` 入口
6. **修改 `project.godot` autoload 需用户确认**(P1.7 已用过 RtsRng; P2.7 没加新 autoload; 后续 P2.8 飞行单位预计也不需要)

## 决策来源

- M0 架构审查报告: `.feature-dev/archive/2026-04-30-rts-auto-battle/Summary.md`
- M1 重构决策讨论: `task-plan/architecture-baseline.md` + Phase 1 实施期 collision_radius 拆 (per-unit-class 12/10 让 2r ≤ atk_range × tolerance)
- Phase 1 9 条 acceptance 详细 evidence: `Progress.md`
