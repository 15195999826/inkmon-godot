# Current State — 2026-05-02 (RTS M2.1 Phase A + B ✅ 收口; Phase C 启动等待用户确认)

inkmon-godot baseline 事实快照。开新 phase 前对齐用。

> **Active feature**: RTS Auto-Battle M2.1 — Economy (Worker Harvest, gold + wood)
> **Active phase**: 等待用户确认是否启动 Phase C (Harvest Activity + Drop-off Loop)
> **Phase A 已收口** (2026-05-02): multi-resource cost 字段全链路 dict 化, 7/7 AC PASS, bit-identical replay 0 漂移
> **Phase B 已收口** (2026-05-02): RtsResourceNode actor + UnitClass.WORKER + idle 行为, 6/6 AC PASS, 11/11 validation 全套 PASS, 0 行为漂移 (既有 6 smoke + 2 replay smoke + frontend smoke 数字与 Phase A 末态完全一致)

## 工程结构

- 主仓 `C:\GodotPorjects\inkmon-godot`, Godot 4.6 项目
- `addons/` 是单一 git submodule (→ `godot-addons.git`), 含三个 addon:
  - `logic-game-framework` (核心 LGF: Actor / AbilitySet / Action / Event / Buff / Timeline / Replay)
  - `lomolib` (工具库)
  - `ultra-grid-map` (RTS 例子用 SQUARE grid_type, cell_size=32)
- 主仓 entry: `scenes/Simulation.tscn` + `scripts/SimulationManager.gd` (Web/headless 桥接)
- **`project.godot` autoload 列表**: `Log` / `IdGenerator` / `GameWorld` / `TimelineRegistry` / `WaitGroupManager` / `ItemSystem` / `UGridMap` / `RtsRng` (RTS M1 P1.7 起加入; M2.1 不预期加新 autoload)

## RTS 示例当前状态

### RTS M1 已归档 (2026-05-02)

完整重构 (Phase 1 9/9 + Phase 2 10/10 + Phase 3 8/9 + Phase 3 P3.1/P3.4 not-pursued) → 归档在 `.feature-dev/archive/2026-05-02-rts-m1-refactor/`。

末态能力:
- Actor 三层基类 (RtsBattleActor / RtsUnitActor / RtsBuildingActor) + 共享攻击协议 + AIR/GROUND layer 系统
- 30Hz fixed-tick + RtsRng 决定性 + bit-identical replay
- Activity 系统 (Idle / MoveTo / Attack / AttackMove / 即将加 Harvest / ReturnAndDrop)
- 4 层避障 (spatial hash + steering + stuck detection + group formation)
- AutoTargetSystem (priority + stance, 含建筑作为目标候选)
- Production System (RtsBuildingActor 工厂 — crystal_tower / barracks / archer_tower; 周期 spawn unit)
- Player Command (RtsPlayerCommand + RtsPlayerCommandQueue tick-stamped) — PlaceBuildingCommand + MoveUnitsCommand
- 胜负判定: crystal-tower-死亡优先 (RtsTeamConfig.crystal_tower_id) + fallback team-wipeout
- Frontend BattleDirector (流式, push 模式, 0 处 actor 直读, alpha 插值)
- RtsScenarioHarness (声明式测试框架; 已 4 个寻路 scenario)

### RTS M2.1 — Economy 进度

**Phase A ✅ done (2026-05-02)**: Multi-Resource Foundation

完成内容:
- `RtsBuildingConfig.cost: Dictionary[String, int]` — barracks `{"gold": 100}`, archer_tower `{"gold": 50}`, crystal_tower `{}` (不可建造来源)
- `RtsTeamConfig.starting_resources: Dictionary[String, int]` + `create(team_id, faction_id, starting_resources: Dictionary, build_zone)` 第三参数同步
- `RtsAutoBattleProcedure._team_resources: Dictionary[int, Dictionary]` + `spend_team_resources(team_id, cost: Dictionary)` 逐 key 扣 + `get_team_resources(team_id) -> Dictionary` 返深拷贝
- `RtsBuildingPlacement.validate(grid, team_config, team_remaining: Dictionary, kind, pos)` 逐 key check, 任一不足 → `reason="not_enough_<kind>"` (例 `not_enough_gold` / `not_enough_wood`)
- 6 个既有 smoke + replay smoke 硬迁 fixture, 数字与 RTS M1 末态完全一致 (smoke_rts_auto_battle ticks=347 / melee_max_dist=24.00; smoke_castle_war_minimal ticks=193 / unit_to_building_attacks=4 / archer_anti_air=1; bit-identical replay frames=9 events=20; det tick_diff=0)
- `demo_rts_frontend.gd` HUD Label 升级 "Gold: %d | Wood: %d"

**Phase B ✅ done (2026-05-02)**: Resource Nodes + Worker Class

完成内容:
- 新 `RtsResourceNodeConfig` (FieldKind enum GOLD=0/WOOD=1 + StatBlock + raw const _GOLD_NODE_STATS / _WOOD_NODE_STATS + static `get_stats(field_kind)` 与 `field_kind_to_resource_key(field_kind) -> String`)
- 新 `RtsResourceNode` actor (extends RtsBattleActor 与 RtsBuildingActor 平级; 字段 field_kind / max_amount / amount / field_kind_key; override `is_dead()` 返 `_is_dead or is_depleted()`; check_death/can_attack 永远 false; team_id 默认 -1 中立, 不阻挡 footprint)
- 新 `RtsResourceNodes` 工厂 (`create_gold_node` / `create_wood_node`)
- `RtsUnitClassConfig.UnitClass.WORKER` (=3 by 顺序声明位置) + StatBlock 新字段 `carry_capacity: int = 0` / `harvest_speed: float = 0.0` (worker 设 10 / 5.0, 其它兵种默认 0); WORKER 数值: max_hp=50, move_speed=80, atk=0, attack_range=0, attack_speed=0, collision_radius=12, movement_layer=GROUND, target_layer_mask=MASK_NONE, unit_tags=["worker"]
- `RtsAIStrategyFactory.get_strategy(WORKER)` 复用 `_basic_attack` 实例 (worker mask=NONE → AutoTargetSystem 永不写 cached_target → decide 返 IdleActivity 自然 idle)
- 新 `smoke_resource_nodes.{gd,tscn}` PASS (ticks=200 alive_workers=5 gold_amount=1500 wood_amount=1500 max_drift=0.00); 既有 6 smoke + 2 replay smoke + frontend smoke 全过 0 行为漂移 (与 Phase A 末态完全一致)

**Phase C/D 🔒 pending** (详见 `task-plan/m2-1-economy/README.md`):
- Phase C — Harvest Activity + Drop-off Loop (HarvestActivity + ReturnAndDropActivity + crystal_tower 兼 drop-off + HarvestStrategy; smoke_harvest_loop)
- Phase D — Cost Rebalance + smoke_economy_demo (multi-resource cost 配方调整 + 经济闭环 full cycle smoke + 编辑器 F6 视觉验证)

**M2 整体路线图** (见 `task-plan/m2-roadmap.md`):
- M2.1 — Economy (本轮 active, Phase B 进行中)
- M2.2 — AI 对手 (computer player) — deferred
- M2.3 — UI HUD / Build Panel / 关卡 — deferred

## 现有 LGF 示例

### hex-atb-battle (既有; hex grid + ATB)

`addons/logic-game-framework/example/hex-atb-battle/{core,logic,frontend,skill-preview,tests}/` (本轮不动)

### rts-auto-battle (RTS M1 末态 + M2.1 Phase A + B 收口)

```
rts-auto-battle/
├── core/        RtsWorldGameplayInstance + RtsAutoBattleProcedure (M2.1 Phase A 完成: _team_resources Dictionary[int, Dictionary] + spend/get signature dict)
├── logic/       Actor 三层基类 + 模块化目录:
│   ├── rts_battle_actor.gd / rts_unit_actor.gd / rts_building_actor.gd / movement_layer.gd
│   ├── rts_resource_node.gd                          ← M2.1 Phase B 完成: extends RtsBattleActor 平级, 中立资源节点
│   ├── weapons/rts_weapon_config.gd
│   ├── rts_rng.gd  (autoload)
│   ├── activity/   (Idle / MoveTo / Attack / AttackMove)  ← M2.1 Phase C 待加 Harvest / ReturnAndDrop
│   ├── grid/       (RtsBattleGrid / RtsPathfinding)
│   ├── movement/   (push_out / spatial_hash / steering / stuck_detector / group_formation)
│   ├── controller/rts_unit_controller.gd
│   ├── ai/         (RtsAIStrategy / RtsBasicAttackStrategy / RtsAutoTargetSystem / factory)
│   │                ← M2.1 Phase B 完成: RtsAIStrategyFactory.get_strategy(WORKER) 复用 _basic_attack
│   │                ← M2.1 Phase C 待加 RtsHarvestStrategy
│   ├── actions/rts_basic_attack_action.gd
│   ├── target_selectors.gd
│   ├── components/rts_nav_agent.gd
│   ├── config/     (rts_unit_class_config / rts_unit_attribute_set / rts_building_config / rts_team_config / rts_resource_node_config)
│   │                ← M2.1 Phase A 完成: rts_building_config.cost dict 化 + rts_team_config.starting_resources dict 化
│   │                ← M2.1 Phase B 完成: rts_resource_node_config (FieldKind enum + get_stats + field_kind_to_resource_key) + UnitClass.WORKER + StatBlock 加 carry_capacity / harvest_speed (Phase C 消费)
│   ├── commands/   (rts_player_command / rts_place_building_command / rts_move_units_command / queue / building_placement)
│   │                ← M2.1 Phase A 完成: rts_building_placement.validate 走 multi-resource check (not_enough_<kind>); rts_place_building_command.apply 走 dict spend
│   ├── buildings/  (rts_buildings 工厂 / rts_building_attribute_set / rts_resource_nodes 工厂)
│   │                ← M2.1 Phase B 完成: rts_resource_nodes (create_gold_node / create_wood_node)
│   ├── production/rts_production_system.gd
│   ├── scenario/   (RtsScenario / RtsScenarioHarness / RtsScenarioAssertContext)
│   ├── logger/rts_battle_logger.gd
│   └── rts_battle_events.gd
├── frontend/   RTS M1 P2.7 + P2.8 末态 + M2.1 Phase A HUD 升级:
│   ├── core/rts_battle_director.gd
│   ├── world_view.gd
│   ├── scene/rts_battle_map.gd
│   ├── visualizers/rts_unit_visualizer.gd / rts_building_visualizer.gd
│   ├── demo_rts_frontend.{gd,tscn}                  ← M2.1 Phase A 完成: HUD Label "Gold: X | Wood: Y" 拆分 + cfg 走 dict; Phase D 加 smoke_economy_demo 链路
│   └── demo_rts_pathfinding.{gd,tscn}                (不显示 resources, Phase A/B 不动)
└── tests/
    ├── battle/smoke_*.tscn (17 个 P1+P2+P3 + Phase B; M2.1 Phase A 6 个 fixture 适配 dict 全过 + Phase B smoke_resource_nodes 加入)
    ├── battle/scenarios/scenario_*.gd (4 个 P3.3 寻路 scenario)
    ├── replay/smoke_determinism.{gd,tscn} + smoke_replay_bit_identical.{gd,tscn}
    │                                                 ← M2.1 Phase A 完成: bit-identical fixture 适配 dict 仍 0 漂移
    │                                                 ← M2.1 Phase B 验证: 仍 0 漂移 (Phase B 不动 4v4 main path)
    └── frontend/smoke_frontend_main.{gd,tscn} + smoke_director_streaming.{gd,tscn}
                                                       ← M2.1 Phase C 待加 smoke_harvest_loop
                                                       ← M2.1 Phase D 待加 smoke_economy_demo
```

两示例都遵循三层依赖方向 `core ← logic ← frontend`。

## 测试基线 (M2.1 Phase B 收口时 11/11 全过, 0 漂移)

| 入口 | 用途 | M2.1 Phase B 末态 |
|---|---|---|
| `addons/logic-game-framework/tests/run_tests.tscn` | LGF 核心单元测试 | **73/73 PASS** |
| `addons/logic-game-framework/example/hex-atb-battle/logic/demo_headless.tscn` | hex ATB 战斗 | right_win, exit 0 |
| `addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_rts_auto_battle.tscn` | 4v4 主 acceptance | left_win, ticks=347, melee_max=24.00 (与 RTS M1 末态完全一致, Phase B 0 漂移) |
| `tests/battle/smoke_castle_war_minimal.tscn` | 城堡战争端到端 | left_win, ticks=193, archer_anti_air=1 (与 Phase A 末态一致) |
| `tests/battle/smoke_player_command.tscn` | placement + 资源扣减 | gold_remaining=100 wood=0 log_entries=3 |
| `tests/battle/smoke_player_command_production.tscn` | 玩家命令 → production 链路 | ticks=600 left_spawned=7 max_eastward=254.74 gold_remaining=100 |
| `tests/battle/smoke_production.tscn` | 生产周期 | ticks=600 left_spawned=7 right_spawned=7 max_left_eastward=118.51 |
| `tests/battle/smoke_crystal_tower_win.tscn` | 水晶塔胜负 | ticks=2 left_win |
| `tests/battle/smoke_resource_nodes.tscn` (M2.1 Phase B 新加) | worker idle + ResourceNode 起手验证 | ticks=200 alive_workers=5 gold_amount=1500 wood_amount=1500 max_drift=0.00 |
| `tests/replay/smoke_replay_bit_identical.tscn` | bit-identical replay | seed=42 commands=2 frames=9 events=20 (deep-equal) |
| `tests/replay/smoke_determinism.tscn` | 同 seed → 同结果 | tick_diff=0 |
| `tests/frontend/smoke_frontend_main.tscn` | 前端 visualizer 冒烟 | visualizers=10 alive_after_3s=10 |
| 其余 P1+P2 smokes (skeleton/nav/ai/attack/grid_pathfinding/minimal_push_out/activity_chain/steering/stuck_recovery/auto_target/player_command_production/flying_units/move_units_command/director_streaming/pathfinding_validation) | 单元 / 集成 smoke | 全 PASS |

**M2.1 Phase C 收口 gate**: 上面全部仍 PASS + 新 `smoke_harvest_loop.tscn` PASS。

## Git 状态 (M2.1 Phase B 收口时)

主仓 `master` ahead origin 9 commit (RTS M1 + M2.1 Phase A 已 commit; Phase B 待 commit):
- 工作树: `?? .claude/scheduled_tasks.lock` (运行时 lock 文件, 不入版本控制)
- M2.1 Phase B 代码改动 + .feature-dev 文档同步 已完成, 待 commit (submodule + 主仓 bump pointer)

Submodule `addons/logic-game-framework` HEAD 待 bump (Phase B 改动在 submodule 内, 待 commit submodule + 主仓 bump pointer)。

## 关键约束 (M2.1 期间继续遵守)

来自 `Autonomous-Work-Protocol.md`, 跨 phase 不变:

1. **不修改 LGF submodule core / stdlib** (新代码进 `addons/logic-game-framework/example/rts-auto-battle/`)
2. **三层架构**: `core ← logic ← frontend`, frontend 不能被 core/logic 引用
3. **Headless 测试入口规范**: `SMOKE_TEST_RESULT: PASS|FAIL - <reason>` + 退出码 0
4. **跑 headless 不要 pipe**: redirect 到 `/tmp/*.txt` 再读
5. **不要 `godot --script`**: 永远用 `.tscn` 入口
6. **修改 `project.godot` autoload 需用户确认** (M2.1 不预期加新 autoload)

## 决策来源

- M2.1 Phase A 收口决策: 见 `task-plan/m2-1-economy/phase-a-multi-resource.md` + Progress.md §Phase A
- M2.1 Phase B 收口决策 (D1-D5): 见 `task-plan/m2-1-economy/phase-b-resource-nodes.md` §设计决策 + Progress.md §Phase B
- M2 整体路线图: `task-plan/m2-roadmap.md`
- RTS M1 完整决策: archive `.feature-dev/archive/2026-05-02-rts-m1-refactor/task-plan/architecture-baseline.md`
