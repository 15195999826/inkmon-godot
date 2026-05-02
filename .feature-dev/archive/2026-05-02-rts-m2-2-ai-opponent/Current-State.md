# Current State — 2026-05-02 (RTS M2.2 — AI 对手 ✅ 已归档; 等待用户确认下一个 feature)

inkmon-godot baseline 事实快照。开新 phase / sub-feature 前对齐用。

> **Active feature**: 无 — 等待用户确认下一个 feature (M2.3 UI / build panel / 关卡 是 deferred 候选; 见 `task-plan/m2-roadmap.md`)
> **上一个 sub-feature**: M2.2 AI 对手 ✅ done + archived (1 phase 4 子任务 全过, 6/6 AC, 14/14 validation PASS, bit-identical 0 漂移; archive `archive/2026-05-02-rts-m2-2-ai-opponent/`)
> **更前的 sub-feature**: M2.1 Economy ✅ done + archived (archive `archive/2026-05-02-rts-m2-1-economy/`)

## M2.1 末态(M2.2 出发点)

4 phase 全部收口 (2026-05-02), 25/25 AC PASS, 18/18 validation 全套 PASS, bit-identical 0 漂移:
- **Phase A** (Multi-Resource Foundation): cost / starting_resources 全链路 dict 化
- **Phase B** (Resource Nodes + Worker Class): RtsResourceNode + UnitClass.WORKER + StatBlock carry_capacity/harvest_speed
- **Phase C** (Harvest Activity + Drop-off Loop): RtsHarvestActivity / RtsReturnAndDropActivity / RtsHarvestStrategy + crystal_tower 兼 drop-off
- **Phase D** (Cost Rebalance + smoke_economy_demo): barracks {gold:80, wood:50} / archer_tower {gold:60, wood:100}; demo_rts_frontend 起手 5 worker + 1 ct + 4 中立 node / 方

## 工程结构

- 主仓 `C:\GodotPorjects\inkmon-godot`, Godot 4.6 项目
- `addons/` 是单一 git submodule (→ `godot-addons.git`), 含三个 addon:
  - `logic-game-framework` (核心 LGF: Actor / AbilitySet / Action / Event / Buff / Timeline / Replay)
  - `lomolib` (工具库)
  - `ultra-grid-map` (RTS 例子用 SQUARE grid_type, cell_size=32)
- 主仓 entry: `scenes/Simulation.tscn` + `scripts/SimulationManager.gd` (Web/headless 桥接)
- **`project.godot` autoload 列表**: `Log` / `IdGenerator` / `GameWorld` / `TimelineRegistry` / `WaitGroupManager` / `ItemSystem` / `UGridMap` / `RtsRng` (M2.2 不预期加新 autoload)

## RTS 示例当前状态

### RTS M1 已归档 (2026-05-02)

完整重构 → 归档在 `.feature-dev/archive/2026-05-02-rts-m1-refactor/`。

末态能力:
- Actor 三层基类 (RtsBattleActor / RtsUnitActor / RtsBuildingActor) + 共享攻击协议 + AIR/GROUND layer 系统
- 30Hz fixed-tick + RtsRng 决定性 + bit-identical replay
- Activity 系统 (Idle / MoveTo / Attack / AttackMove)
- 4 层避障 (spatial hash + steering + stuck detection + group formation)
- AutoTargetSystem (priority + stance, 含建筑作为目标候选)
- Production System (RtsBuildingActor 工厂 — crystal_tower / barracks / archer_tower; 周期 spawn unit)
- Player Command (RtsPlayerCommand + RtsPlayerCommandQueue tick-stamped) — PlaceBuildingCommand + MoveUnitsCommand
- 胜负判定: crystal-tower-死亡优先 (RtsTeamConfig.crystal_tower_id) + fallback team-wipeout
- Frontend BattleDirector (流式 push 模式, 0 处 actor 直读, alpha 插值)
- RtsScenarioHarness (声明式测试框架; 已 4 个寻路 scenario)

### RTS M2.1 已归档 (2026-05-02)

完整 Economy → 归档在 `.feature-dev/archive/2026-05-02-rts-m2-1-economy/`。

末态能力(M2.2 出发点):
- 双资源 (gold + wood) cost 全链路 dict 化 (`RtsBuildingConfig.cost: Dictionary[String, int]`)
- starting_resources 也 dict 化 (`{"gold":100, "wood":100}`)
- RtsResourceNode actor (中立 team_id=-1; FieldKind GOLD/WOOD; max_amount=1500)
- UnitClass.WORKER (=3) + StatBlock carry_capacity=10 / harvest_speed=5.0
- RtsHarvestActivity / RtsReturnAndDropActivity 单 Activity 自管 nav (类似 AttackActivity)
- RtsActivity 基类抽 NAV_REFRESH helper (attack/harvest/return 三 Activity 共用)
- RtsHarvestStrategy (carry > 0 → ReturnAndDrop; 否则找最近未耗尽 ResourceNode → Harvest; 找不到 → Idle)
- RtsAIStrategyFactory.WORKER 切到 _harvest_strategy
- RtsBuildingActor.is_drop_off + RtsBuildingConfig.StatBlock.is_drop_off (crystal_tower 起手 true)
- RtsUnitActor.carrying: Dictionary[String, int] + get_carry_total() helper
- RtsAutoBattleProcedure.add_team_resources(team_id, delta) 对称 spend
- RtsWorldGameplayInstance.bind_procedure(p) (世界引用 procedure, Activity 通过 world.procedure 改资源)
- Cost 重平衡: barracks {gold:80, wood:50} / archer_tower {gold:60, wood:100} / crystal_tower {} (不可建造)
- demo_rts_frontend 经济闭环 (5 worker + 1 ct + 4 中立 node / 方)

### RTS M2.2 已归档 (2026-05-02)

完整 AI 对手 → 归档在 `.feature-dev/archive/2026-05-02-rts-m2-2-ai-opponent/`。

末态能力 (现行 baseline; 下一 sub-feature 出发点):
- `RtsComputerPlayer` (logic/ai/, RefCounted, team-level) — 每 30 tick 决策一次
- `_try_build_barracks` — barracks 1 cap, 资源足 ≥ {gold:80, wood:50}, 在 ct 偏移点 (左 +96 east / 右 -96 west) enqueue PlaceBuildingCommand; placement 失败 stateless 天然 retry
- `_try_attack` — alive non-worker unit ≥ 3 触发 once, enqueue MoveUnitsCommand 攻敌方 ct (走纯 RtsMoveToActivity, 抵达后 RtsBasicAttackStrategy + AutoTargetSystem 接管)
- `RtsAutoBattleProcedure._computer_players` + `attach_computer_player(team_id)` — 显式 attach (E10 — 默认不创建, 保旧 12 项 smoke 不破)
- tick_once step 6.5 (record_current_frame_events 之后, 胜负判定之前) `for cp in _computer_players: cp.think(world, _current_tick)` — AI enqueue 命令在下一 tick step 1.5 apply_due 应用
- demo_rts_frontend 双方 AI (E9 AI vs AI; F6 看采集 → 放 barracks → 出兵 → 攻 ct 完整链路自跑)
- AI 走 RtsPlayerCommandQueue 与玩家同接口 — bit-identical replay 不破

实测数字:smoke_ai_vs_player_full_match 600 tick @ 30Hz, ai_barracks=1 / ai_units_spawned=4 / ai_unit_to_ct_attacks=9 (≥ {1,3,1} 阈值全过)。

## 现有 LGF 示例

### hex-atb-battle (既有; hex grid + ATB)

`addons/logic-game-framework/example/hex-atb-battle/{core,logic,frontend,skill-preview,tests}/` (M2.2 期间不动)

### rts-auto-battle (M2.1 末态; M2.2 即将增量)

```
rts-auto-battle/
├── core/        RtsWorldGameplayInstance + RtsAutoBattleProcedure
│                ← M2.2 落地: _computer_players: Array[RtsComputerPlayer] + attach_computer_player(team_id) + tick step 6.5 cp.think(world, _current_tick)
├── logic/       Actor 三层基类 + 模块化目录:
│   ├── rts_battle_actor.gd / rts_unit_actor.gd / rts_building_actor.gd / movement_layer.gd
│   ├── rts_resource_node.gd
│   ├── weapons/rts_weapon_config.gd
│   ├── rts_rng.gd  (autoload)
│   ├── activity/   (Idle / MoveTo / Attack / AttackMove / Harvest / ReturnAndDrop)
│   ├── grid/       (RtsBattleGrid / RtsPathfinding)
│   ├── movement/   (push_out / spatial_hash / steering / stuck_detector / group_formation)
│   ├── controller/rts_unit_controller.gd
│   ├── ai/         (RtsAIStrategy / RtsBasicAttackStrategy / RtsHarvestStrategy / RtsAutoTargetSystem / factory)
│   │                ← M2.2 落地: rts_computer_player.gd team-level (与 strategy 平级独立子类)
│   ├── actions/rts_basic_attack_action.gd
│   ├── target_selectors.gd
│   ├── components/rts_nav_agent.gd
│   ├── config/     (rts_unit_class_config / rts_unit_attribute_set / rts_building_config / rts_team_config / rts_resource_node_config)
│   ├── commands/   (rts_player_command / rts_place_building_command / rts_move_units_command / queue / building_placement)
│   │                (M2.2 沿用; RtsComputerPlayer 走现有 player_command_queue 接口, 与玩家同链路)
│   ├── buildings/  (rts_buildings 工厂 / rts_building_attribute_set / rts_resource_nodes 工厂)
│   ├── production/rts_production_system.gd
│   ├── scenario/   (RtsScenario / RtsScenarioHarness / RtsScenarioAssertContext)
│   ├── logger/rts_battle_logger.gd
│   └── rts_battle_events.gd
├── frontend/
│   ├── core/rts_battle_director.gd
│   ├── world_view.gd
│   ├── scene/rts_battle_map.gd
│   ├── visualizers/rts_unit_visualizer.gd / rts_building_visualizer.gd / rts_base_visualizer.gd
│   ├── demo_rts_frontend.{gd,tscn}                    ← M2.2 E.4 落地: procedure setup 后 attach_computer_player(0/1) 双方启 AI (E9 — F6 看 AI vs AI 自跑)
│   └── demo_rts_pathfinding.{gd,tscn}
└── tests/
    ├── battle/smoke_*.tscn
    │                ← M2.2 E.4 落地: smoke_ai_vs_player_full_match.{gd,tscn} (左 AI vs 右站桩, 600 tick @ 30Hz, 实测 ai_barracks=1 ai_units_spawned=4 ai_unit_to_ct_attacks=9 ≥ 阈值 {1,3,1})
    ├── battle/scenarios/scenario_*.gd
    ├── replay/smoke_determinism.{gd,tscn} + smoke_replay_bit_identical.{gd,tscn}
    │                (M2.2 沿用; E10 — 既有 smoke 不 attach AI 走旧路径, 数字 bit-identical M2.1 末态)
    └── frontend/smoke_frontend_main.{gd,tscn} + smoke_director_streaming.{gd,tscn}
```

两示例都遵循三层依赖方向 `core ← logic ← frontend`。

## 测试基线 (M2.2 末态; 14 项全过 0 漂移 M2.1 末态)

| 入口 | 用途 | M2.2 末态 (post-simplify 重跑后) |
|---|---|---|
| `addons/logic-game-framework/tests/run_tests.tscn` | LGF 核心单元测试 | **73/73 PASS** |
| `addons/logic-game-framework/example/hex-atb-battle/logic/demo_headless.tscn` | hex ATB 战斗 | right_win, exit 0 |
| `tests/battle/smoke_rts_auto_battle.tscn` | 4v4 主 acceptance | left_win, ticks=347, attacks=74 (melee=32 ranged=42), melee_max=24.00 (bit-identical) |
| `tests/battle/smoke_castle_war_minimal.tscn` | 城堡战争端到端 | left_win, ticks=193, unit_to_building_attacks=4, archer_anti_air=1 |
| `tests/battle/smoke_player_command.tscn` | placement + 资源扣减 | gold_remaining=20 wood_remaining=50 log_entries=3 |
| `tests/battle/smoke_player_command_production.tscn` | 玩家命令 → production | ticks=600 left_spawned=7 max_eastward=254.74 gold_remaining=20 |
| `tests/battle/smoke_production.tscn` | 生产周期 | ticks=600 left_spawned=7 right_spawned=7 max_left_eastward=118.51 |
| `tests/battle/smoke_crystal_tower_win.tscn` | 水晶塔胜负 | ticks=2 left_win |
| `tests/battle/smoke_resource_nodes.tscn` | HarvestStrategy fallback to IdleActivity | ticks=200 alive_workers=5 max_drift=0.00 |
| `tests/battle/smoke_harvest_loop.tscn` | worker harvest cycle | ticks=600 alive=5 team_gold=140 team_wood=212 cycle_workers=5 |
| `tests/battle/smoke_economy_demo.tscn` | full cycle 经济闭环 | ticks=900 alive_workers=5 cycle_workers=5 barracks_enqueued_tick=348 melee_spawned=4 melee_to_ct_attacks=31 |
| `tests/replay/smoke_replay_bit_identical.tscn` | bit-identical replay | seed=42 commands=2 frames=9 events=20 (deep-equal) |
| `tests/replay/smoke_determinism.tscn` | 同 seed → 同结果 | tick_diff=0 |
| `tests/frontend/smoke_frontend_main.tscn` | 前端 visualizer 冒烟 | visualizers=10 alive_after_3.0s=10 |
| **`tests/battle/smoke_ai_vs_player_full_match.tscn` (M2.2 新)** | AI 自主 build + attack-move | PASS, ai_barracks=1 ai_units_spawned=4 ai_unit_to_ct_attacks=9 (≥ {1,3,1} 阈值) |

**M2.2 收口 gate (已通过)**: 13 项 M2.1 末态全过 + 1 新 smoke PASS + simplify pass clean + AC-doc consistency aligned + 6 AC [x] + commit + 主仓 bump + archive 创建。

## Git 状态 (M2.2 收口后)

主仓 `master` ahead origin 多 commit (M1 完整 + M2.1 4 phase + M2.2 1 phase 4 子任务). 工作树:
- `M .claude/skills/autonomous-feature-runner/SKILL.md` (历史改动, 不属本次 sub-feature; 待用户 commit / discard)
- `?? .claude/scheduled_tasks.lock` (运行时 lock 文件, 不入版本控制)
- 工作树就绪, 等待用户确认下一个 feature。

## 关键约束 (跨 phase / sub-feature 不变)

来自 `Autonomous-Work-Protocol.md`:

1. **不修改 LGF submodule core / stdlib** (新代码进 `addons/logic-game-framework/example/rts-auto-battle/`)
2. **三层架构**: `core ← logic ← frontend`, frontend 不能被 core/logic 引用
3. **Headless 测试入口规范**: `SMOKE_TEST_RESULT: PASS|FAIL - <reason>` + 退出码 0
4. **跑 headless 不要 pipe**: redirect 到 `/tmp/*.txt` 再读
5. **不要 `godot --script`**: 永远用 `.tscn` 入口
6. **修改 `project.godot` autoload 需用户确认** (M2.2 不预期加新 autoload)

## 决策来源

- M2.2 完整 archive: `archive/2026-05-02-rts-m2-2-ai-opponent/` (含 E1-E10 决策表 + 6 AC 收口 evidence + Summary.md)
- M2 整体路线图: `task-plan/m2-roadmap.md` (M2.1 + M2.2 ✅ done; M2.3 deferred)
- M2.1 完整 archive: `archive/2026-05-02-rts-m2-1-economy/`
- RTS M1 完整决策: archive `archive/2026-05-02-rts-m1-refactor/task-plan/architecture-baseline.md`
