# Current State — 2026-05-02 (RTS M2.1 Economy ✅ 完整收口; 待 archive)

inkmon-godot baseline 事实快照。开新 phase / sub-feature 前对齐用。

> **Active feature**: 无 (RTS M2.1 Economy 完整收口待 archive; 等待用户确认下一个 feature)
> **RTS M2.1 Economy ✅ done** (2026-05-02): 4 phase 全过 (A 7/7 + B 6/6 + C 7/7 + D 5/5 = 25/25 AC PASS); Phase D 收口时 18/18 validation 全套 PASS, 0 行为漂移 (除 4 fixture cost/starting 数字漂); simplify pass clean
> **Phase A** (Multi-Resource Foundation): cost / starting_resources 全链路 dict 化, bit-identical replay 0 漂移
> **Phase B** (Resource Nodes + Worker Class): RtsResourceNode / RtsResourceNodeConfig / UnitClass.WORKER + StatBlock carry_capacity/harvest_speed
> **Phase C** (Harvest Activity + Drop-off Loop): RtsHarvestActivity / RtsReturnAndDropActivity / RtsHarvestStrategy + crystal_tower 兼 drop-off; smoke_harvest_loop 经济闭环 cycle PASS; nav refresh helper 上推 RtsActivity 基类
> **Phase D** (Cost Rebalance + smoke_economy_demo): barracks {gold:80, wood:50} / archer_tower {gold:60, wood:100} / crystal_tower {} / starting {gold:100, wood:100}; 新 smoke_economy_demo (full cycle 经济闭环 PASS); demo_rts_frontend 起手 5 worker + 1 ct + 4 中立 node / 方

## 工程结构

- 主仓 `C:\GodotPorjects\inkmon-godot`, Godot 4.6 项目
- `addons/` 是单一 git submodule (→ `godot-addons.git`), 含三个 addon:
  - `logic-game-framework` (核心 LGF: Actor / AbilitySet / Action / Event / Buff / Timeline / Replay)
  - `lomolib` (工具库)
  - `ultra-grid-map` (RTS 例子用 SQUARE grid_type, cell_size=32)
- 主仓 entry: `scenes/Simulation.tscn` + `scripts/SimulationManager.gd` (Web/headless 桥接)
- **`project.godot` autoload 列表**: `Log` / `IdGenerator` / `GameWorld` / `TimelineRegistry` / `WaitGroupManager` / `ItemSystem` / `UGridMap` / `RtsRng` (RTS M1 P1.7 起加入; M2.1 不加新 autoload)

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

### RTS M2.1 — Economy ✅ done (2026-05-02; 待 archive)

**4 phase 全部收口** — 25/25 AC PASS, 18/18 validation 全套 PASS

**Phase A** (Multi-Resource Foundation) — `archive 文档:` task-plan/m2-1-economy/phase-a-multi-resource.md:
- `RtsBuildingConfig.cost: Dictionary[String, int]` (Phase A 默认 占位; Phase D 重平衡)
- `RtsTeamConfig.starting_resources: Dictionary[String, int]` + `create(team_id, faction_id, starting_resources, build_zone)`
- `RtsAutoBattleProcedure._team_resources: Dictionary[int, Dictionary]` + `spend_team_resources(team_id, cost: Dictionary)` + `get_team_resources(team_id) -> Dictionary` (深拷防外部污染)
- `RtsBuildingPlacement.validate(grid, team_config, team_remaining: Dictionary, kind, pos)` 逐 key check, `not_enough_<kind>` reason
- `demo_rts_frontend.gd` HUD Label 升级 "Gold: %d | Wood: %d"

**Phase B** (Resource Nodes + Worker Class) — task-plan/m2-1-economy/phase-b-resource-nodes.md:
- 新 `RtsResourceNodeConfig` (FieldKind enum GOLD=0/WOOD=1 + StatBlock + raw const + get_stats + field_kind_to_resource_key)
- 新 `RtsResourceNode` actor (extends RtsBattleActor 平级独立子类; 字段 field_kind / max_amount / amount / field_kind_key; team_id 默认 -1 中立)
- 新 `RtsResourceNodes` 工厂 (create_gold_node / create_wood_node)
- `RtsUnitClassConfig.UnitClass.WORKER` (=3) + StatBlock 加 carry_capacity / harvest_speed (worker 10/5.0)
- 新 `smoke_resource_nodes.{gd,tscn}`

**Phase C** (Harvest Activity + Drop-off Loop) — task-plan/m2-1-economy/phase-c-harvest-activity.md:
- 新 `RtsHarvestActivity` (extends RtsActivity; 单 Activity 自管 nav 类似 AttackActivity; on_first_run cache stats)
- 新 `RtsReturnAndDropActivity` (找己方最近 is_drop_off 建筑; 抵达调 procedure.add_team_resources + carrying.clear)
- 新 `RtsHarvestStrategy` (carry > 0 → ReturnAndDrop; 否则找最近未耗尽 ResourceNode → Harvest; 找不到 → Idle)
- `RtsAIStrategyFactory.WORKER` 切到 `_harvest_strategy` (melee/ranged 仍 _basic_attack)
- `RtsBuildingActor.is_drop_off: bool` + `RtsBuildingConfig.StatBlock.is_drop_off` (crystal_tower stats 起手 true; 工厂统一注入)
- `RtsUnitActor.carrying: Dictionary[String, int]` + `get_carry_total()` helper
- `RtsAutoBattleProcedure.add_team_resources(team_id, delta)` 对称 spend
- `RtsWorldGameplayInstance.bind_procedure(p)` 让 Activity 通过 world.procedure 改资源
- 基类 `RtsActivity` 抽 nav refresh helper (NAV_REFRESH_INTERVAL / 4 fields / 2 methods) — attack/harvest/return 三 Activity 共用
- 新 `smoke_harvest_loop.{gd,tscn}`; smoke_resource_nodes 重定位为"HarvestStrategy fallback to IdleActivity"

**Phase D** (Cost Rebalance + smoke_economy_demo) — task-plan/m2-1-economy/phase-d-cost-rebalance.md:
- `RtsBuildingConfig.cost` Phase D 重平衡: barracks `{"gold":80, "wood":50}` (gold-rich 偏 melee 推 ct); archer_tower `{"gold":60, "wood":100}` (wood-rich 偏防空); crystal_tower `{}` (不可建造)
- starting_resources (D17): `{"gold":100, "wood":100}` 起手能造 1 个 building 不能两个; smoke setup / demo 直接传 (rts_team_config.gd 默认 `{}` 不动)
- 新 `smoke_economy_demo.{gd,tscn}` (full cycle: 5 worker + 1 gold + 1 wood + 双方 ct, 跑 900 tick @ 30Hz; harvest → enqueue barracks → spawn melee → ≥1 melee 攻 ct)
- `demo_rts_frontend.gd` 完全重写 (起手 5 worker + 1 ct + 4 中立 node / 方; 删 archer / 4 ground / flying_scout); HUD 文字更新 cost (gold 80 + wood 50)
- 4 个 smoke fixture 数字漂适配: smoke_player_command (gold/wood 100/0 → 20/50), smoke_player_command_production (gold 100 → 20), smoke_castle_war_minimal (加 wood 100 行为 0 漂移), smoke_replay_bit_identical (wood 0 → 500 双方加, bit-identical 0 漂移)

**M2 整体路线图** (见 `task-plan/m2-roadmap.md`):
- M2.1 — Economy ✅ done (本轮完成; 2026-05-02)
- M2.2 — AI 对手 (computer player) — deferred
- M2.3 — UI HUD / Build Panel / 关卡 — deferred

## 现有 LGF 示例

### hex-atb-battle (既有; hex grid + ATB)

`addons/logic-game-framework/example/hex-atb-battle/{core,logic,frontend,skill-preview,tests}/` (M2.1 期间不动)

### rts-auto-battle (RTS M1 末态 + M2.1 全 4 phase 收口)

```
rts-auto-battle/
├── core/        RtsWorldGameplayInstance + RtsAutoBattleProcedure
│                ← M2.1 Phase A: _team_resources Dictionary[int, Dictionary] + spend/get/add 三 signature dict
│                ← M2.1 Phase C: World.procedure 字段 + bind_procedure(p), Procedure.add_team_resources 对称 spend
├── logic/       Actor 三层基类 + 模块化目录:
│   ├── rts_battle_actor.gd / rts_unit_actor.gd / rts_building_actor.gd / movement_layer.gd
│   │                ← M2.1 Phase C: RtsUnitActor.carrying: Dictionary[String, int] + get_carry_total() helper; RtsBuildingActor.is_drop_off: bool (StatBlock 注入)
│   ├── rts_resource_node.gd                          ← M2.1 Phase B: extends RtsBattleActor 平级, 中立资源节点
│   ├── weapons/rts_weapon_config.gd
│   ├── rts_rng.gd  (autoload)
│   ├── activity/   (Idle / MoveTo / Attack / AttackMove / Harvest / ReturnAndDrop)
│   │                ← M2.1 Phase C: 基类 RtsActivity 抽 NAV_REFRESH helper (attack/harvest/return 三共用); 新 RtsHarvestActivity + RtsReturnAndDropActivity
│   ├── grid/       (RtsBattleGrid / RtsPathfinding)
│   ├── movement/   (push_out / spatial_hash / steering / stuck_detector / group_formation)
│   ├── controller/rts_unit_controller.gd
│   ├── ai/         (RtsAIStrategy / RtsBasicAttackStrategy / RtsHarvestStrategy / RtsAutoTargetSystem / factory)
│   │                ← M2.1 Phase C: 新 RtsHarvestStrategy + factory WORKER 切换
│   ├── actions/rts_basic_attack_action.gd
│   ├── target_selectors.gd
│   ├── components/rts_nav_agent.gd
│   ├── config/     (rts_unit_class_config / rts_unit_attribute_set / rts_building_config / rts_team_config / rts_resource_node_config)
│   │                ← M2.1 Phase A: cost / starting_resources dict 化
│   │                ← M2.1 Phase B: rts_resource_node_config + UnitClass.WORKER + StatBlock carry_capacity/harvest_speed
│   │                ← M2.1 Phase C: rts_building_config.StatBlock.is_drop_off (crystal_tower stats 起手 true)
│   │                ← M2.1 Phase D: cost 重平衡 (barracks 80g+50w / archer_tower 60g+100w)
│   ├── commands/   (rts_player_command / rts_place_building_command / rts_move_units_command / queue / building_placement)
│   │                ← M2.1 Phase A: rts_building_placement.validate 走 multi-resource check (not_enough_<kind>); rts_place_building_command.apply 走 dict spend
│   ├── buildings/  (rts_buildings 工厂 / rts_building_attribute_set / rts_resource_nodes 工厂)
│   │                ← M2.1 Phase B: rts_resource_nodes (create_gold_node / create_wood_node)
│   │                ← M2.1 Phase C: rts_buildings._create_from_kind 统一从 stats.is_drop_off 注入 actor
│   ├── production/rts_production_system.gd
│   ├── scenario/   (RtsScenario / RtsScenarioHarness / RtsScenarioAssertContext)
│   ├── logger/rts_battle_logger.gd
│   └── rts_battle_events.gd
├── frontend/
│   ├── core/rts_battle_director.gd
│   ├── world_view.gd                                  ← 注: ResourceNode 不在 visualizer 分支 (Phase D 后续可加 RtsResourceNodeVisualizer)
│   ├── scene/rts_battle_map.gd
│   ├── visualizers/rts_unit_visualizer.gd / rts_building_visualizer.gd / rts_base_visualizer.gd
│   ├── demo_rts_frontend.{gd,tscn}                  ← M2.1 Phase D: 完全重写为经济闭环 demo (5 worker + 1 ct + 4 中立 node / 方; HUD cost gold 80 + wood 50)
│   └── demo_rts_pathfinding.{gd,tscn}
└── tests/
    ├── battle/smoke_*.tscn (P1+P2+P3 + Phase B/C/D)
    │                ← M2.1 Phase D: smoke_economy_demo 新加 (full cycle 经济闭环, 900 tick @ 30Hz); 4 fixture 适配 (smoke_player_command / smoke_player_command_production / smoke_castle_war_minimal cost+starting; smoke_replay_bit_identical wood 加)
    ├── battle/scenarios/scenario_*.gd
    ├── replay/smoke_determinism.{gd,tscn} + smoke_replay_bit_identical.{gd,tscn}
    │                ← M2.1 Phase D: bit-identical 0 漂移 (frames=9 events=20)
    └── frontend/smoke_frontend_main.{gd,tscn} + smoke_director_streaming.{gd,tscn}
                                                       ← M2.1 Phase D: visualizers=10 (5 worker × 2) alive=10 不崩
```

两示例都遵循三层依赖方向 `core ← logic ← frontend`。

## 测试基线 (M2.1 Phase D 收口时 18/18 全过, 0 行为漂移)

| 入口 | 用途 | M2.1 Phase D 末态 |
|---|---|---|
| `addons/logic-game-framework/tests/run_tests.tscn` | LGF 核心单元测试 | **73/73 PASS** |
| `addons/logic-game-framework/example/hex-atb-battle/logic/demo_headless.tscn` | hex ATB 战斗 | right_win, exit 0 |
| `tests/battle/smoke_rts_auto_battle.tscn` | 4v4 主 acceptance | left_win, ticks=347, attacks=74 (melee=32 ranged=42), melee_max=24.00 (bit-identical 0 漂移) |
| `tests/battle/smoke_castle_war_minimal.tscn` | 城堡战争端到端 | left_win, ticks=193, unit_to_building_attacks=4, archer_anti_air=1 |
| `tests/battle/smoke_player_command.tscn` | placement + 资源扣减 | gold_remaining=20 wood_remaining=50 log_entries=3 (D17 cost 80/50 + starting 100/100) |
| `tests/battle/smoke_player_command_production.tscn` | 玩家命令 → production 链路 | ticks=600 left_spawned=7 max_eastward=254.74 gold_remaining=20 |
| `tests/battle/smoke_production.tscn` | 生产周期 | ticks=600 left_spawned=7 right_spawned=7 max_left_eastward=118.51 |
| `tests/battle/smoke_crystal_tower_win.tscn` | 水晶塔胜负 | ticks=2 left_win |
| `tests/battle/smoke_resource_nodes.tscn` | HarvestStrategy fallback to IdleActivity | ticks=200 alive_workers=5 max_drift=0.00 |
| `tests/battle/smoke_harvest_loop.tscn` | worker harvest cycle 经济闭环 | ticks=600 alive=5 team_gold=140 team_wood=212 cycle_workers=5 |
| **`tests/battle/smoke_economy_demo.tscn` (Phase D 新)** | **full cycle 经济闭环** | **ticks=900 alive_workers=5 cycle_workers=5 barracks_enqueued_tick=348 melee_spawned=4 melee_to_ct_attacks=31** |
| `tests/replay/smoke_replay_bit_identical.tscn` | bit-identical replay | seed=42 commands=2 frames=9 events=20 (deep-equal) |
| `tests/replay/smoke_determinism.tscn` | 同 seed → 同结果 | tick_diff=0 |
| `tests/frontend/smoke_frontend_main.tscn` | 前端 visualizer 冒烟 | visualizers=10 (5 worker × 2) alive_after_3.0s=10 |
| 其余 P1+P2 smokes | 单元 / 集成 smoke | 全 PASS |

**RTS M2.1 完整收口 gate**: 上面 18 项全 PASS + simplify pass clean + AC-doc consistency review 完成 + 4 phase plan 全部 [x] 收口 + Phase D commit + 主仓 bump + archive 创建。

## Git 状态 (M2.1 整体收口待 commit)

主仓 `master` ahead origin (前面 18 commit 已 push 到 RTS M1 + M2.1 Phase A/B/C):
- 工作树:
  - `M .claude/skills/autonomous-feature-runner/SKILL.md` (历史改动, 不属本次)
  - `?? .claude/scheduled_tasks.lock` (运行时 lock 文件, 不入版本控制)
  - `m addons` (submodule 有 Phase D 改动待 commit)
- Phase D commit 待做:
  - submodule `addons/logic-game-framework`: Phase D 6 改 + 2 新文件 + 1 .uid (smoke_economy_demo) — `feat(rts-m21): Phase D done — cost rebalance + smoke_economy_demo + demo 起手 spawn 改 + 4 fixture 适配`
  - 主仓 bump pointer + .feature-dev 文档同步 + archive 创建 — `feat(rts-m21): bump addons + 同步 .feature-dev (Phase D 收口 + M2.1 Economy 整体 archive)`

## 关键约束 (跨 phase / sub-feature 不变)

来自 `Autonomous-Work-Protocol.md`:

1. **不修改 LGF submodule core / stdlib** (新代码进 `addons/logic-game-framework/example/rts-auto-battle/`)
2. **三层架构**: `core ← logic ← frontend`, frontend 不能被 core/logic 引用
3. **Headless 测试入口规范**: `SMOKE_TEST_RESULT: PASS|FAIL - <reason>` + 退出码 0
4. **跑 headless 不要 pipe**: redirect 到 `/tmp/*.txt` 再读
5. **不要 `godot --script`**: 永远用 `.tscn` 入口
6. **修改 `project.godot` autoload 需用户确认** (M2.1 不预期加新 autoload)

## 决策来源

- M2.1 Phase A/B/C/D 决策 (D1-D19): 见各 phase 文档 + Progress.md
- M2 整体路线图: `task-plan/m2-roadmap.md`
- RTS M1 完整决策: archive `.feature-dev/archive/2026-05-02-rts-m1-refactor/task-plan/architecture-baseline.md`
- M2.1 完整 archive (待创建): `.feature-dev/archive/2026-05-02-rts-m2-1-economy/`
