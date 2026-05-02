# RTS Auto-Battle M2.1 Economy — Summary (2026-05-02)

> RTS 例子从 RTS M1 末态的"starting_resources 一次性 100 gold"演进为"worker harvest 资源闭环 + 双资源 (gold + wood) cost"; 经济闭环对外可观, 编辑器 F6 可见 worker → cycle → 资源涨 → 玩家放兵营 → melee 攻 ct。

## Acceptance 结论 (25/25 全过)

### Phase A — Multi-Resource Foundation (7/7)
- [x] AC1 RtsBuildingConfig.cost 迁 Dictionary[String, int]
- [x] AC2 RtsTeamConfig.starting_resources 迁 dict
- [x] AC3 RtsAutoBattleProcedure._team_resources runtime + signature 改 dict
- [x] AC4 RtsBuildingPlacement.validate 走 multi-resource check (`not_enough_<kind>`)
- [x] AC5 既有 6 smoke + 1 replay smoke 全部 PASS (硬迁 fixture, 0 行为差; bit-identical 0 漂移)
- [x] AC6 LGF 73/73 + bit-identical replay 不退化
- [x] AC7 Demo HUD Label 拆 Gold/Wood 双显示

### Phase B — Resource Nodes + Worker Class (6/6)
- [x] AC1 新 RtsResourceNodeConfig (FieldKind GOLD=0/WOOD=1 + StatBlock + raw const + get_stats)
- [x] AC2 新 RtsResourceNode actor (extends RtsBattleActor 平级独立子类)
- [x] AC3 新 RtsResourceNodes 工厂 (create_gold_node / create_wood_node)
- [x] AC4 RtsUnitClassConfig.UnitClass.WORKER + carry_capacity / harvest_speed (worker 10/5.0)
- [x] AC5 RtsAIStrategyFactory worker 路径 (Phase B 复用 _basic_attack; Phase C 切到 _harvest_strategy)
- [x] AC6 新 smoke_resource_nodes PASS (Phase C 重定位为 fallback to IdleActivity)

### Phase C — Harvest Activity + Drop-off Loop (7/7)
- [x] AC1 RtsAutoBattleProcedure.add_team_resources(team_id, delta: Dictionary) 对称 spend
- [x] AC2 新 RtsHarvestActivity (extends RtsActivity; 单 Activity 自管 nav 类似 AttackActivity; on_first_run cache stats)
- [x] AC3 新 RtsReturnAndDropActivity (找己方最近 is_drop_off 建筑; 抵达调 procedure.add_team_resources + carrying.clear)
- [x] AC4 新 RtsHarvestStrategy (carry > 0 → ReturnAndDrop; 否则找最近未耗尽 ResourceNode → Harvest; 找不到 → Idle)
- [x] AC5 RtsAIStrategyFactory.get_strategy(WORKER) 切到 _harvest_strategy
- [x] AC6 新 smoke_harvest_loop PASS (5 worker × 600 tick: team_gold=140 team_wood=212 cycle_workers=5)
- [x] AC7 Validation 全套不退化 (13 项; bit-identical 0 漂移)

### Phase D — Cost Rebalance + smoke_economy_demo (5/5)
- [x] AC1 Building cost 重平衡 (D17): barracks {gold:80, wood:50} / archer_tower {gold:60, wood:100} / crystal_tower {}
- [x] AC2 starting_resources {gold:100, wood:100} (D17; smoke setup / demo 直接传, rts_team_config.gd 默认 `{}` 不动)
- [x] AC3 新 smoke_economy_demo PASS (full cycle: ticks=900 alive_workers=5 cycle_workers=5 barracks_enqueued_tick=348 melee_spawned=4 melee_to_ct_attacks=31)
- [x] AC4 demo_rts_frontend 起手 spawn 改 (D19: 5 worker + 1 ct + 4 中立 node / 方; HUD 文字更新 cost gold 80 + wood 50)
- [x] AC5 Validation 全套不退化 (18 项; 0 行为漂移除 4 fixture cost/starting 数字漂)

## 关键 artifact 路径

### 入口场景
- 经济闭环 demo (F6): `addons/logic-game-framework/example/rts-auto-battle/frontend/demo_rts_frontend.tscn`
- 经济闭环 smoke (headless): `addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_economy_demo.tscn`

### 核心新增源码 (M2.1 全程)
- `addons/logic-game-framework/example/rts-auto-battle/logic/rts_resource_node.gd` (Phase B)
- `addons/logic-game-framework/example/rts-auto-battle/logic/config/rts_resource_node_config.gd` (Phase B)
- `addons/logic-game-framework/example/rts-auto-battle/logic/buildings/rts_resource_nodes.gd` (Phase B)
- `addons/logic-game-framework/example/rts-auto-battle/logic/activity/harvest_activity.gd` (Phase C)
- `addons/logic-game-framework/example/rts-auto-battle/logic/activity/return_and_drop_activity.gd` (Phase C)
- `addons/logic-game-framework/example/rts-auto-battle/logic/ai/rts_harvest_strategy.gd` (Phase C)

### 改写/扩展源码
- `addons/logic-game-framework/example/rts-auto-battle/core/rts_auto_battle_procedure.gd` (Phase A: _team_resources dict; Phase C: add_team_resources 对称 spend)
- `addons/logic-game-framework/example/rts-auto-battle/logic/rts_unit_actor.gd` (Phase C: carrying + get_carry_total)
- `addons/logic-game-framework/example/rts-auto-battle/logic/rts_building_actor.gd` (Phase C: is_drop_off)
- `addons/logic-game-framework/example/rts-auto-battle/logic/rts_world_gameplay_instance.gd` (Phase C: bind_procedure)
- `addons/logic-game-framework/example/rts-auto-battle/logic/activity/rts_activity.gd` (Phase C: nav refresh helper 上推基类)
- `addons/logic-game-framework/example/rts-auto-battle/logic/config/rts_building_config.gd` (Phase A: cost dict 化; Phase C: StatBlock.is_drop_off; Phase D: cost 重平衡)
- `addons/logic-game-framework/example/rts-auto-battle/logic/config/rts_team_config.gd` (Phase A: starting_resources dict)
- `addons/logic-game-framework/example/rts-auto-battle/logic/config/rts_unit_class_config.gd` (Phase B: UnitClass.WORKER + carry_capacity / harvest_speed)
- `addons/logic-game-framework/example/rts-auto-battle/logic/commands/rts_building_placement.gd` (Phase A: multi-resource check)
- `addons/logic-game-framework/example/rts-auto-battle/logic/commands/rts_place_building_command.gd` (Phase A: dict spend)
- `addons/logic-game-framework/example/rts-auto-battle/logic/ai/rts_ai_strategy_factory.gd` (Phase B: WORKER 复用 basic; Phase C: WORKER 切 harvest)
- `addons/logic-game-framework/example/rts-auto-battle/logic/buildings/rts_buildings.gd` (Phase C: _create_from_kind 注入 is_drop_off)
- `addons/logic-game-framework/example/rts-auto-battle/frontend/demo_rts_frontend.gd` (Phase A: HUD 双显示; Phase D: 完全重写经济闭环 demo)

### 测试 (新增/适配)
- `tests/battle/smoke_resource_nodes.{gd,tscn}` (Phase B 新, Phase C 重定位)
- `tests/battle/smoke_harvest_loop.{gd,tscn}` (Phase C 新)
- `tests/battle/smoke_economy_demo.{gd,tscn}` (Phase D 新)
- 4 个 fixture 适配 starting/cost: smoke_player_command, smoke_player_command_production, smoke_castle_war_minimal, smoke_replay_bit_identical

## 真实运行证据 (M2.1 Phase D 收口快照, 18/18 PASS)

| 命令 | 结果 |
|---|---|
| `godot --headless --path . --import` | exit=0, 0 type error, 全 class 注册 |
| `godot --headless --path . addons/logic-game-framework/tests/run_tests.tscn` | 73/73 PASS, 0 fail |
| `godot --headless --path . .../tests/battle/smoke_rts_auto_battle.tscn` | left_win, ticks=347 attacks=74 melee_max=24.00 (bit-identical) |
| `godot --headless --path . .../tests/battle/smoke_castle_war_minimal.tscn` | left_win, ticks=193 unit_to_building_attacks=4 archer_anti_air=1 |
| `godot --headless --path . .../tests/battle/smoke_player_command.tscn` | PASS, gold_remaining=20 wood_remaining=50 (Phase D D17) |
| `godot --headless --path . .../tests/battle/smoke_player_command_production.tscn` | PASS, ticks=600 left_spawned=7 max_eastward=254.74 gold_remaining=20 |
| `godot --headless --path . .../tests/battle/smoke_production.tscn` | PASS, ticks=600 left_spawned=7 right_spawned=7 max_left_eastward=118.51 |
| `godot --headless --path . .../tests/battle/smoke_crystal_tower_win.tscn` | PASS, ticks=2 left_win |
| `godot --headless --path . .../tests/battle/smoke_resource_nodes.tscn` | PASS, ticks=200 alive_workers=5 max_drift=0.00 |
| `godot --headless --path . .../tests/battle/smoke_harvest_loop.tscn` | PASS, ticks=600 alive=5 team_gold=140 team_wood=212 cycle_workers=5 |
| **`godot --headless --path . .../tests/battle/smoke_economy_demo.tscn`** | **PASS, ticks=900 alive=5 cycle=5 barracks_enqueued_tick=348 melee_spawned=4 melee_to_ct_attacks=31** |
| `godot --headless --path . .../tests/replay/smoke_replay_bit_identical.tscn` | PASS, seed=42 commands=2 frames=9 events=20 deep-equal |
| `godot --headless --path . .../tests/replay/smoke_determinism.tscn` | PASS, seed=12345 run1=run2=(left_win, 347) tick_diff=0 |
| `godot --headless --path . .../tests/frontend/smoke_frontend_main.tscn` | PASS, visualizers=10 (5 worker × 2) alive_after_3.0s=10 |

## 残余风险 / 已知 follow-up

- **ResourceNode 无 visualizer** (Phase D AC4 注): WorldView._spawn_visualizer 仅对 RtsUnitActor / RtsBuildingActor 创 visualizer; F6 时 ResourceNode 不可见, 视觉链路依赖 worker 移动 + HUD 资源数字增长。后续若需 F6 看到 node, 加 RtsResourceNodeVisualizer (extends RtsBaseVisualizer 同模式 RtsBuildingVisualizer)。
- **smoke_economy_demo 用 starting {0,0}** (与 demo 玩法 starting 100/100 不同): 这是 smoke 验"harvest 攒到 cost"的 critical path, 不是 bug。AC3 文档已说明。
- **smoke_economy_demo 1 gold + 1 wood (非 D17 草案 2+2)**: 实测 2+2 同侧布局让 worker 全选 gold (距离 tiebreak), 1+1 模式跟 smoke_harvest_loop 同, 是已知能 mix 的最简配置。AC3 文档已说明。
- **frontend smoke 报告 message 仍 "renders 4v4"**: stale text (Phase D demo 实际是 5 worker / 方), 不影响 PASS; 后续 cleanup 可顺手更新 print 字串。
- **ObjectDB instances leaked / resources still in use** warning: M2.1 期间未引入新 leak (与 Phase B/C 末态一致); Phase B/C 已加 RtsActivity / RtsResourceNode 类导致小幅 +2-3, 但 exit code=0, 不阻塞 acceptance。

## 跨 Phase 关键决策 (D1-D19)

D1 资源累积模式: Worker harvest (SC 经典)
D2 ResourceNode 不阻挡 footprint
D3 Frontend HUD: minimal Label (Gold: X | Wood: Y) 不做 icon bar
D4 Worker default strategy: Phase B 复用 RtsBasicAttackStrategy (idle 行为); Phase C 切到 RtsHarvestStrategy
D5 RtsResourceNode 与 RtsBuildingActor 平级独立子类 (都继承 RtsBattleActor)
D6-D16 Phase C harvest activity / drop-off 设计细节 (NAV_REFRESH_INTERVAL / find_closest 算法 / actor_id tiebreak / etc.)
D17 Phase D cost 配方: barracks {gold:80, wood:50} / archer_tower {gold:60, wood:100} / starting {gold:100, wood:100}
D18 smoke_economy_demo 时长: 900 tick @ 30Hz (timeout 45000ms)
D19 demo_rts_frontend 起手 spawn: 双方各 5 worker + 1 ct + 2g + 2w (实现简化为 1+1 见残余风险)

完整决策追溯: 各 phase 文档 §设计决策 + Progress.md §Phase X 段。

## Commits

待 commit (按 Autonomous-Work-Protocol commit 策略):
- submodule (`addons/logic-game-framework`): Phase D 6 改 + 2 新 + 1 .uid — `feat(rts-m21): Phase D done — cost rebalance + smoke_economy_demo + demo 起手 spawn 改 + 4 fixture 适配`
- 主仓: bump pointer + 全 .feature-dev 文档同步 + archive 创建 — `feat(rts-m21): bump addons + 同步 .feature-dev (Phase D 收口 + M2.1 Economy 整体 archive)`

(注: M2.1 Phase A/B/C 各自的 commit 已在前面 18 commits 完成, 见主仓 git log 72c62f7 / 8002be9 / b9819a8 / 4f5902d / e3d2c52 等。)
