## Progress — RTS Auto-Battle M2.1 Economy

**Status**: ✅ **Phase A + B + C + D 全部收口** (2026-05-02); M2.1 Economy 整体完成, 待 archive
- Phase A: ✅ 完成 (7/7 AC) — Multi-Resource Foundation
- Phase B: ✅ 完成 (6/6 AC) — Resource Nodes + Worker Class
- Phase C: ✅ 完成 (7/7 AC) — Harvest Activity + Drop-off Loop
- Phase D: ✅ 完成 (5/5 AC) — Cost Rebalance + smoke_economy_demo (经济闭环对外可观)

最近更新: 2026-05-02 (Phase D 收口: 5/5 AC PASS + 18/18 validation 全套 PASS + simplify pass clean; 准备 M2.1 整体收口 archive)

---

## Phase A 验收准则 checklist (✅ 全过)

详见 [`Next-Steps.md`](Next-Steps.md) §Phase A 验收准则 + [`task-plan/m2-1-economy/phase-a-multi-resource.md`](task-plan/m2-1-economy/phase-a-multi-resource.md)。

- [x] **AC1** RtsBuildingConfig.cost 迁 Dictionary[String, int] (gold + wood 双 key)
  - 文件: `addons/logic-game-framework/example/rts-auto-battle/logic/config/rts_building_config.gd`
  - 改动: `cost: int = 0` → `cost: Dictionary[String, int] = {}`; barracks `{"gold": 100}`, archer_tower `{"gold": 50}`, crystal_tower `{}` (不可建造来源); raw const → typed copy via `_copy_resource_dict` helper
- [x] **AC2** RtsTeamConfig.starting_resources 迁 dict
  - 文件: `addons/logic-game-framework/example/rts-auto-battle/logic/config/rts_team_config.gd`
  - 改动: `starting_resources: int = 0` → `Dictionary[String, int] = {}`; `create(...)` 第 3 参数同步; `unconfigured(team_id)` 默认 `{}` (空 dict 等价旧 0)
- [x] **AC3** RtsAutoBattleProcedure._team_resources runtime + signature 改 dict
  - 文件: `addons/logic-game-framework/example/rts-auto-battle/core/rts_auto_battle_procedure.gd`
  - 改动: `_team_resources: Dictionary[int, Dictionary]`; `spend_team_resources(team_id, cost: Dictionary)` 逐 key 减; `get_team_resources(team_id) -> Dictionary` 返回深拷贝防外部污染; `_install_team_configs` 拷贝 `cfg.starting_resources` 进 bucket
- [x] **AC4** RtsBuildingPlacement.validate 走 multi-resource check
  - 文件: `addons/logic-game-framework/example/rts-auto-battle/logic/commands/rts_building_placement.gd` + `rts_place_building_command.gd`
  - 改动: `team_remaining: Dictionary` 入参; 逐 `kind in stats.cost` check, 任一不足返回 `reason="not_enough_<kind>"` (例 `not_enough_gold` / `not_enough_wood`); `cost: stats.cost` 整 dict 返回; `place_building_command.apply` 走 dict spend
  - Evidence: `grep not_enough_resources` 0 命中 (字面量); 注释里仅 1 处说明"M2.1 Phase A 取代旧 not_enough_resources"
- [x] **AC5** 既有 6 smoke 全部 PASS (硬迁 fixture, 0 行为差)
  - `tests/battle/smoke_player_command.tscn` → PASS, `gold_remaining=100 wood_remaining=0 log_entries=3` (`/tmp/m21_a_pc.txt`)
  - `tests/battle/smoke_player_command_production.tscn` → PASS, `ticks=600 left_spawned=7 max_eastward=254.74 gold_remaining=100` (`/tmp/m21_a_pcp.txt`)
  - `tests/battle/smoke_castle_war_minimal.tscn` → PASS, `ticks=193 result=left_win unit_to_building_attacks=4 archer_anti_air=1` (`/tmp/m21_a_cw.txt`) — 与 RTS M1 末态一致
  - `tests/battle/smoke_production.tscn` → PASS, `ticks=600 left_spawned=7 right_spawned=7 max_left_eastward=118.51` (`/tmp/m21_a_prod.txt`)
  - `tests/battle/smoke_crystal_tower_win.tscn` → PASS, `ticks=2 result=left_win` (`/tmp/m21_a_ct.txt`)
  - `tests/battle/smoke_rts_auto_battle.tscn` → PASS, `ticks=347 attacks=74 (melee=32 ranged=42) deaths=6 melee_max_dist=24.00 ranged_max_dist=125.75 detoured=4` (`/tmp/m21_a_main.txt`) — bit-identical 与 RTS M1 末态
- [x] **AC6** LGF 73/73 + bit-identical replay 不退化
  - `addons/logic-game-framework/tests/run_tests.tscn` → 73/73 PASS (`/tmp/m21_a_lgf_unit.txt`)
  - `tests/replay/smoke_replay_bit_identical.tscn` → PASS, `seed=42 commands=2 frames=9 events=20` deep-equal (`/tmp/m21_a_replay.txt`)
  - `tests/replay/smoke_determinism.tscn` → PASS, `seed=12345 run1=(left_win, 347), run2=(left_win, 347), tick_diff=0` (`/tmp/m21_a_det.txt`)
  - `tests/frontend/smoke_frontend_main.tscn` → PASS, `visualizers=10 alive_after_3.0s=10` (`/tmp/m21_a_fe.txt`)
- [x] **AC7** Demo HUD Label 拆 Gold/Wood 双显示
  - 文件: `addons/logic-game-framework/example/rts-auto-battle/frontend/demo_rts_frontend.gd` HUD Label 升级为 "Gold: %d | Wood: %d  |  Click left mouse..."; 取数 `procedure.get_team_resources(0).get("gold"/"wood")`
  - `frontend/demo_rts_pathfinding.gd` 不显示 resources, 不需改 (HUD 显示 selected/last cmd/tick)
  - F6 视觉验证留给用户 (Phase A acceptance: headless smoke 不卡 demo 改动)

## Phase A 子任务进度 (✅ 全过)

- [x] **A.1 — RtsBuildingConfig.cost 迁 dict** (commit-pending — 与 Phase A 收口一起 submodule commit)
- [x] **A.2 — RtsTeamConfig.starting_resources 迁 dict**
- [x] **A.3 — RtsAutoBattleProcedure._team_resources runtime 改 dict** (深拷防 cfg.starting_resources 污染)
- [x] **A.4 — RtsBuildingPlacement.validate 走 multi-resource check** (`not_enough_<kind>` 字面量替代旧 `not_enough_resources`)
- [x] **A.5 — 既有 smoke fixture 适配** + 顺手适配 `smoke_replay_bit_identical.gd` (typed param 编译要求)
- [x] **A.6 — Demo HUD Label 升级** + 顺手更新 `logic/commands/README.md` 文档示例

## Phase A 残余风险 (回顾, 全部 mitigated)

- ✅ **fixture 大改面 (AC5)**: 6 smoke + `smoke_replay_bit_identical` (typed param 强制 compile time error 帮助发现) 全部 PASS, 数字与 RTS M1 末态完全一致
- ✅ **bit-identical replay 风险 (AC6)**: dict iteration order 保 insertion order; spend/get 按 cost 字典固定顺序遍历, replay smoke deep-equal frames=9/events=20, det tick_diff=0 — 0 漂移
- ✅ **HUD demo 改动 (AC7)**: 代码层改完 (`demo_rts_frontend.gd`); F6 视觉验证留可选 (smoke 不阻塞)

---

## Phase B — Resource Nodes + Worker Class (✅ 收口)

详见 [`task-plan/m2-1-economy/phase-b-resource-nodes.md`](task-plan/m2-1-economy/phase-b-resource-nodes.md) (Phase A 收口时新写; Phase B 收口时 AC checkbox 打勾 + 文档与代码对齐)。

### Phase B 验收准则 checklist (✅ 全过)

- [x] **AC1** 新 `RtsResourceNodeConfig` (FieldKind enum + StatBlock + get_stats + field_kind_to_resource_key)
  - 文件: `addons/logic-game-framework/example/rts-auto-battle/logic/config/rts_resource_node_config.gd` (新)
  - 字段: GOLD=0 / WOOD=1; `max_amount=1500`; `harvest_per_tick=0`; `footprint_size=(1,1)`; `actor_tags=["resource_node","gold"]` 或 `["resource_node","wood"]` (双 tag pattern 与 melee/ranged unit_tags 一致)
- [x] **AC2** 新 `RtsResourceNode` actor (extends RtsBattleActor)
  - 文件: `addons/logic-game-framework/example/rts-auto-battle/logic/rts_resource_node.gd` (新)
  - 字段: field_kind / max_amount / amount / field_kind_key (Phase C drop-off cache); override is_dead 返 `_is_dead or is_depleted()`; check_death/can_attack 永远 false
- [x] **AC3** 新 `RtsResourceNodes` 工厂 (`create_gold_node` / `create_wood_node`)
  - 文件: `addons/logic-game-framework/example/rts-auto-battle/logic/buildings/rts_resource_nodes.gd` (新)
- [x] **AC4** `RtsUnitClassConfig.UnitClass.WORKER` + 新字段 carry_capacity / harvest_speed
  - 文件: `addons/logic-game-framework/example/rts-auto-battle/logic/config/rts_unit_class_config.gd` (改)
  - WORKER 数值: max_hp=50, move_speed=80, atk=0, attack_speed=0, attack_range=0, collision_radius=12, movement_layer=GROUND, target_layer_mask=MASK_NONE, unit_tags=["worker"], carry_capacity=10, harvest_speed=5.0
- [x] **AC5** RtsAIStrategyFactory worker 路径 (复用 `_basic_attack`)
  - 文件: `addons/logic-game-framework/example/rts-auto-battle/logic/ai/rts_ai_strategy_factory.gd` (改)
  - WORKER 复用 _basic_attack — worker mask=NONE → AutoTargetSystem 永不写 cached_target → decide 返 IdleActivity 自然 idle (设计决策 D4)
- [x] **AC6** 新 `smoke_resource_nodes.tscn` PASS + 既有 smoke 不退化
  - 文件: `addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_resource_nodes.{gd,tscn}` (新)
  - 起手: 5 worker (左 team 0) + 1 gold node + 1 wood node (中立 team_id=-1) + 右 1 ct (hp=2000 永远不死)
  - PASS: ticks=200 alive_workers=5 gold_amount=1500 wood_amount=1500 max_drift=0.00 (`/tmp/m21_b_rn.txt`)
  - 验证 worker `_cached_target_id` 始终空 (mask=NONE → AutoTargetSystem skip mover) ✓

### Phase B Validation 全套 (11/11 PASS, 0 漂移)

| smoke / 测试 | 结果 | 数字 vs Phase A 末态 | log |
|---|---|---|---|
| import 类型检查 | 0 错误, 新 class 注册 | 新加 RtsResourceNodes/Config/Node 出现 | `/tmp/m21_b_import.txt` |
| LGF unit tests `run_tests.tscn` | **73/73 PASS** | 与 Phase A 一致 | `/tmp/m21_b_lgf_unit.txt` |
| `smoke_resource_nodes.tscn` (新) | PASS | ticks=200 alive=5 gold=1500 wood=1500 drift=0 | `/tmp/m21_b_rn.txt` |
| `smoke_player_command.tscn` | PASS | ticks=30 log=3 gold=100 wood=0 | `/tmp/m21_b_pc.txt` |
| `smoke_castle_war_minimal.tscn` | PASS | ticks=193 left_win unit_to_building=4 archer_anti_air=1 | `/tmp/m21_b_cw.txt` |
| `smoke_rts_auto_battle.tscn` | PASS | ticks=347 attacks=74(m32/r42) melee_max=24.00 (bit-id) | `/tmp/m21_b_main.txt` |
| `smoke_player_command_production.tscn` | PASS | ticks=600 left_spawned=7 max_eastward=254.74 gold=100 | `/tmp/m21_b_pcp.txt` |
| `smoke_production.tscn` | PASS | ticks=600 left=7 right=7 max_left_eastward=118.51 | `/tmp/m21_b_prod.txt` |
| `smoke_crystal_tower_win.tscn` | PASS | ticks=2 left_win | `/tmp/m21_b_ct.txt` |
| `smoke_replay_bit_identical.tscn` | PASS | seed=42 commands=2 frames=9 events=20 deep-equal | `/tmp/m21_b_replay.txt` |
| `smoke_determinism.tscn` | PASS | seed=12345 run1=run2=(left_win,347) tick_diff=0 | `/tmp/m21_b_det.txt` |
| `smoke_frontend_main.tscn` | PASS | visualizers=10 alive_after_3s=10 | `/tmp/m21_b_fe.txt` |

**结论**: Phase B 加新 actor 类型 + 新 unit_class 0 行为漂移 — 既有 6 smoke + 2 replay smoke + frontend smoke 数字与 Phase A 末态完全一致 (bit-identical replay frames=9/events=20 deep-equal, det tick_diff=0)。

## Phase B 子任务进度 (✅ 全过)

- [x] **B.1 — RtsResourceNodeConfig** (新文件)
- [x] **B.2 — RtsResourceNode actor** (新文件)
- [x] **B.3 — RtsResourceNodes 工厂** (新文件)
- [x] **B.4 — UnitClass.WORKER + carry_capacity / harvest_speed** (改 rts_unit_class_config.gd)
- [x] **B.5 — RtsAIStrategyFactory worker 路径** (改 rts_ai_strategy_factory.gd)
- [x] **B.6 — smoke_resource_nodes.{gd,tscn}** (新文件) + 11/11 validation 全套 PASS

## Phase B 残余风险 (回顾, 全部 mitigated)

- ✅ **新 UnitClass.WORKER 破既有 4v4 smoke**: enum 末尾加 (=3, 不挤掉 0/1/2); StatBlock 新字段 carry_capacity / harvest_speed 默认 0 / 0.0 — 既有兵种 raw 不含, 走 raw.get(key, default) 返默认值; 既有 4v4 main smoke 数字 ticks=347 attacks=74 完全一致。
- ✅ **bit-identical replay 风险**: replay smoke 数字与 Phase A 末态完全一致 (frames=9 events=20 deep-equal); RtsResourceNode 不入 left_team/right_team, 不影响 procedure 主循环 actor 顺序; UnitClass enum 加新值不影响序列化 (smoke 不 spawn worker, replay 走 4v4 melee/ranged path)
- ✅ **Worker idle 行为漂移**: smoke 验证 max_drift=0.00 (worker 完全不动); D4 决策正确 — RtsBasicAttackStrategy 在 cached_target_id 空时直接返 IdleActivity, 无副作用
- 🔒 **未触发的 Phase C 风险**: ResourceNode 被 AutoTargetSystem 误选为 attack target — Phase B smoke 双方都没 attacker (worker mask=NONE, ct mask=NONE), AutoTargetSystem mover 阶段全 skip; Phase C 启动后若发现 ranged attacker 选 ResourceNode 当 target, 在 AutoTargetSystem 加 `is RtsResourceNode skip` 处理。

---

---

## Phase C — Harvest Activity + Drop-off Loop (✅ 收口)

详见 [`task-plan/m2-1-economy/phase-c-harvest-activity.md`](task-plan/m2-1-economy/phase-c-harvest-activity.md) (AC 全部 [x] 收口 + Simplify Pass 段)。

### Phase C 验收准则 checklist (✅ 全过)

- [x] **AC1** `RtsAutoBattleProcedure.add_team_resources(team_id, delta: Dictionary)` 对称 spend
  - 文件: `addons/logic-game-framework/example/rts-auto-battle/core/rts_auto_battle_procedure.gd`
  - Evidence: 单 method, 逐 key 加; key 不在 bucket → bucket[key] = delta; value=0 跳过
- [x] **AC2** 新 `RtsHarvestActivity` (extends RtsActivity)
  - 文件: `addons/logic-game-framework/example/rts-auto-battle/logic/activity/harvest_activity.gd` (新)
  - Evidence: 单 Activity 自管 nav (类似 AttackActivity); on_first_run cache `_carry_capacity` / `_harvest_speed` (simplify); tick in-range 累 progress + transfer; 满 capacity 切 ReturnAndDrop
- [x] **AC3** 新 `RtsReturnAndDropActivity` (extends RtsActivity)
  - 文件: `addons/logic-game-framework/example/rts-auto-battle/logic/activity/return_and_drop_activity.gd` (新)
  - Evidence: drop_off_id 空时 _find_closest_drop_off (己方 + is_drop_off + 距离最近 + actor_id 字典序 tiebreak); 抵达调 world.procedure.add_team_resources + carrying.clear; drop-off 中途死亡重找
- [x] **AC4** 新 `RtsHarvestStrategy` (extends RtsAIStrategy)
  - 文件: `addons/logic-game-framework/example/rts-auto-battle/logic/ai/rts_harvest_strategy.gd` (新)
  - Evidence: actor.get_carry_total() ≥ 1 → ReturnAndDrop; 否则找最近未耗尽 ResourceNode → HarvestActivity; 找不到 → IdleActivity
- [x] **AC5** `RtsAIStrategyFactory.get_strategy(WORKER)` 切到 `_harvest_strategy`
  - 文件: `addons/logic-game-framework/example/rts-auto-battle/logic/ai/rts_ai_strategy_factory.gd`
  - Evidence: `static var _harvest_strategy: RtsAIStrategy = RtsHarvestStrategy.new()`; match WORKER → _harvest_strategy; melee/ranged 仍 _basic_attack
- [x] **AC6** 新 `smoke_harvest_loop.{gd,tscn}` PASS
  - 文件: `addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_harvest_loop.{gd,tscn}` (新)
  - Evidence: ticks=600 alive_workers=5 team_gold=140 team_wood=212 gold_node=1360/1500 wood_node=1288/1500 cycle_workers=5 (`/tmp/m21_simplify_hl.txt`)
- [x] **AC7** Validation 全套不退化 (13 项 — 12 RTS smoke + LGF 73/73 + smoke_harvest_loop)
  - LGF 73/73 PASS (`/tmp/m21_simplify_lgf.txt`)
  - smoke_rts_auto_battle 4v4 main: ticks=347 attacks=74 (melee=32 ranged=42) deaths=6 melee_max_dist=24.00 ranged_max_dist=125.75 detoured=4 (与 Phase B 末态 0 漂移; `/tmp/m21_simplify_main.txt`)
  - smoke_castle_war_minimal: ticks=193 result=left_win unit_to_building_attacks=4 archer_anti_air=1 spawn_count=2 (与 Phase B 末态 0 漂移; `/tmp/m21_simplify_cw.txt`)
  - smoke_player_command: ticks=30 log_entries=3 gold_remaining=100 wood_remaining=0 (`/tmp/m21_simplify_pc.txt`)
  - smoke_player_command_production: ticks=600 left_spawned=7 max_eastward=254.74 gold_remaining=100 (`/tmp/m21_simplify_pcp.txt`)
  - smoke_production: ticks=600 left_spawned=7 right_spawned=7 max_left_eastward=118.51 (`/tmp/m21_simplify_prod.txt`)
  - smoke_crystal_tower_win: ticks=2 left_win (`/tmp/m21_simplify_ct.txt`)
  - smoke_resource_nodes (Phase C 重定位 — HarvestStrategy fallback to IdleActivity 找不到 node): ticks=200 alive_workers=5 max_drift=0.00 (`/tmp/m21_simplify_rn.txt`)
  - smoke_replay_bit_identical: seed=42 commands=2 frames=9 events=20 deep-equal (与 Phase B 末态 0 漂移; `/tmp/m21_simplify_replay.txt`)
  - smoke_determinism: seed=12345 run1=run2=(left_win, 347) tick_diff=0 (与 Phase B 末态 0 漂移; `/tmp/m21_simplify_det.txt`)
  - smoke_frontend_main: visualizers=10 alive_after_3.0s=10 (`/tmp/m21_simplify_fe.txt`)

### Phase C 子任务进度 (✅ 全过)

- [x] **C.1 — World ↔ Procedure 通信打通**
  - World 加 `procedure: RtsAutoBattleProcedure` 字段 + `bind_procedure(p)` 方法 (rts_world_gameplay_instance.gd)
  - Procedure._init 末尾调 `world.bind_procedure(self)` (rts_auto_battle_procedure.gd)
  - Procedure 加 `add_team_resources(team_id, delta: Dictionary)` (对称 spend; rts_auto_battle_procedure.gd)
- [x] **C.2 — `RtsUnitActor.carrying` 字段** + simplify pass `get_carry_total()` helper
- [x] **C.3 — `RtsBuildingActor.is_drop_off` 字段 + ct 起手设 true**
  - simplify pass: 进 `RtsBuildingConfig.StatBlock.is_drop_off`, 工厂 `_create_from_kind` 统一注入
- [x] **C.4 — `RtsHarvestActivity` 新文件** (单 Activity 自管 nav, 类似 RtsAttackActivity 模式)
- [x] **C.5 — `RtsReturnAndDropActivity` 新文件** (on_first_run 找己方最近 is_drop_off; 抵达调 add_team_resources)
- [x] **C.6 — `RtsHarvestStrategy` 新文件 + factory 切换** (worker → harvest_strategy, melee/ranged 不动)
- [x] **C.7 — `smoke_harvest_loop.{gd,tscn}` 新文件 + Phase B smoke_resource_nodes 重定位** (方案 A — 不放 node 验 fallback to idle)

### Phase C Simplify Pass (SKILL.md §7a-7c)

7 AC 全过后 simplify + AC-doc consistency review:

1. **Nav refresh helper 抽取**: NAV_REFRESH_INTERVAL / `_time_since_nav_refresh` / `_last_set_target` / `_should_refresh_nav` / `_refresh_nav_target` 上推到 `RtsActivity` 基类; attack/harvest/return 三 Activity 共用 — 减 ~30 行重复 (4v4 main bit-identical 0 漂移; replay frames=9 events=20 deep-equal)
2. **`RtsUnitActor.get_carry_total()` helper**: harvest_strategy + harvest_activity 两处 `_carry_total(unit)` 抽到 actor; 单点真相 (carrying 是 actor 字段)
3. **`is_drop_off` into `RtsBuildingConfig.StatBlock`**: 与 `is_crystal_tower` 同模式 — 工厂统一注入; create_crystal_tower 不再特例
4. **HarvestActivity stats cache**: `_carry_capacity` / `_harvest_speed` 在 `on_first_run` 缓存 — tick 不再每帧 `RtsUnitClassConfig.get_stats(unit_class)` (5 worker × 30Hz = 150 alloc/sec → 0)
5. **Dead `_intent_arriving = true` write 删除**: ReturnAndDrop 抵达瞬间设 `_intent_arriving=true` 紧接 return false → DONE → controller is_done 返 "idle", 永远不可观察

13 项 validation 全套 simplify 后再跑 0 漂移 (上面 AC7 evidence 路径 `/tmp/m21_simplify_*.txt` 即 simplify 后 evidence)。AC-doc consistency review: 7/7 AC 文档与代码 file:line 对齐 — 见 phase-c-harvest-activity.md §Acceptance 各 AC "实现" 路径。

### Phase C 风险表回顾 (全部 mitigated)

- ✅ **Phase B `smoke_resource_nodes` 被 break** (C.6 切 factory 后 worker 不再 idle): 方案 A 落地 — smoke setup 改不放 ResourceNode, 验 HarvestStrategy fallback to IdleActivity 链路 (max_drift=0.00)。
- ✅ **Activity ↔ procedure 通信循环 (World ↔ Procedure 互 hold ref)**: bind_procedure 后 ObjectDB leak warning 与 Phase B 末态一致 (35→37 个 resources still in use, +2 因新 Activity 类 GC 时机), 不影响退出码 0。
- ✅ **Bit-identical replay 漂移** (新 strategy + Activity): replay smoke 数字 frames=9 events=20 deep-equal, det tick_diff=0 — 0 漂移。
- ✅ **Drop-off 找不到 ct (ct 死亡)**: smoke_harvest_loop 起手双方 ct hp=2000 不死规避; Phase D smoke_economy_demo 加 fallback 测。
- ✅ **Multiple worker 同 node 抢 amount → 决定性破**: controller.tick 顺序决定性, 同 tick 内多 worker mutate `node.amount -= actual` 时 actual=min(transferable, node.amount, capacity_remaining) 自然处理。
- ✅ **HarvestActivity tick 内 nav 接敌频繁 set_target 抖动**: 与 AttackActivity 同模式 NAV_REFRESH_INTERVAL=0.2s + 距离 > 2px 强制刷新 (simplify 后基类 helper); smoke 跑通无抖动。
- ✅ **ResourceNode 同时被多 worker harvest, amount 减到负**: actual = min(transferable, node.amount, capacity_remaining) 限上界, 后到 worker actual=0 → tick 末 strategy.decide 切其它 node。

---

## Phase D — Cost Rebalance + smoke_economy_demo (✅ 收口)

详见 [`task-plan/m2-1-economy/phase-d-cost-rebalance.md`](task-plan/m2-1-economy/phase-d-cost-rebalance.md) (AC 全部 [x] + Simplify Pass 段 + Validation 全套 18/18 表)。

### Phase D 验收准则 checklist (✅ 全过)

- [x] **AC1** Building cost 重平衡 — multi-resource trade-off
  - 文件: `rts_building_config.gd:104` (_BARRACKS_STATS cost {gold:80, wood:50}), `:130` (_ARCHER_TOWER_STATS cost {gold:60, wood:100}), `:85` (_CRYSTAL_TOWER_STATS cost {})
- [x] **AC2** starting_resources 调到 D17 finalized {gold:100, wood:100}
  - 实现 (按 "或 smoke setup" 分支): rts_team_config.gd 默认 `{}` 不动; 4 个 smoke fixture (player_command / player_command_production / castle_war_minimal) + demo_rts_frontend.gd 直接传 `{"gold": 100, "wood": 100}`
- [x] **AC3** 新 `smoke_economy_demo.{gd,tscn}` PASS (full cycle 经济闭环)
  - 实测: ticks=900 alive_workers=5 cycle_workers=5 barracks_enqueued_tick=348 melee_spawned=4 melee_to_ct_attacks=31 final_gold=138 final_wood=196
  - smoke 用 starting {0,0} 强制 worker harvest 才能放 barracks (与 demo 玩法 starting 100/100 不同 — smoke 验"harvest 攒到 cost"的 critical path); setup 用 1 gold + 1 wood node (smoke_harvest_loop 同; 实测 2+2 同侧布局让 worker 全选 gold)
- [x] **AC4** demo_rts_frontend 起手 spawn 改 (D19: 5 worker + 1 ct + 4 中立 node / 方; 删 archer/4 ground/scout)
  - frontend smoke 验 visualizers=10 alive_after_3.0s=10 不崩 ✓
  - HUD 文字更新 cost (gold 80 + wood 50)
  - 注: ResourceNode 当前无 RtsResourceNodeVisualizer; F6 时 node 不可见, 视觉链路依赖 worker 移动 + HUD 资源数字增长 (后续若需可视加)
- [x] **AC5** Validation 全套不退化 (18/18 PASS)
  - 数字漂移 (改 fixture 顺手): smoke_player_command (gold/wood remaining 100/0 → 20/50), smoke_player_command_production (gold remaining 100 → 20)
  - 0 漂移: smoke_rts_auto_battle 4v4 (ticks=347 attacks=74 melee_max_dist=24.00 bit-identical), smoke_castle_war_minimal (ticks=193 left_win unit_to_building=4 archer_anti_air=1), smoke_replay_bit_identical (frames=9 events=20 deep-equal), smoke_determinism (tick_diff=0), smoke_harvest_loop (gold=140 wood=212 cycle=5)

### Phase D 子任务进度 (✅ 全过)

- [x] **D.1 — Cost 数值改 + smoke fixture 适配** (rts_building_config.gd 2 dict literal 改 + 4 smoke fixture 适配)
- [x] **D.2 — `smoke_economy_demo.{gd,tscn}` 新文件** (full cycle, 900 tick @ 30Hz; 5 验证条 PASS)
- [x] **D.3 — `demo_rts_frontend.gd` 起手 spawn 改** (5 worker + 1 ct + 4 中立 node / 方; frontend smoke 不退化)
- [x] **D.4 — Validation 全套** (18/18 PASS) + 文档同步 + Simplify Pass clean

### Phase D Simplify Pass (SKILL.md §7a-7c)

5 AC 全过后 simplify + AC-doc consistency review:

1. **smoke_economy_demo `_max_total_gold` / `_max_total_wood` tracking 删除** — `_barracks_enqueued = true` 已隐含 "resources 曾达到 cost" (enqueue 条件即 ≥80g+50w); 删 2 var + 5 行 main loop tracking + 6 行验证段; 验证条从 6 简化到 5; report 行去掉 max_gold/max_wood
2. **AC-doc consistency review**: AC1-AC2 实现 file:line 与文档对齐; AC3 setup 文档原写"2 gold + 2 wood node"已更新为"1+1 模式"; AC3 starting 文档原写"100/100"已更新为"smoke 0/0 强制 harvest"; AC4 加注"ResourceNode 无 visualizer"

re-validation 5 sanity smoke (smoke_economy_demo + LGF 73/73 + 4v4 main + replay + harvest_loop) simplify 后全 PASS 0 漂移 (`/tmp/m21_simp_*.txt`)。
