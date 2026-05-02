## Progress — RTS Auto-Battle M2.1 Economy

**Status**: ✅ **Phase A + B 收口** (2026-05-02); 🚧 **Phase C 启动 active** (2026-05-02)
- Phase A: ✅ 完成 (7/7 AC) — Multi-Resource Foundation
- Phase B: ✅ 完成 (6/6 AC) — Resource Nodes + Worker Class
- Phase C: 🚧 active (0/7 AC) — Harvest Activity + Drop-off Loop
- Phase D: 🔒 待 Phase C 收口后启动

最近更新: 2026-05-02 (Phase C 启动: 用户确认 D6/D7/D8 决策, phase-c-harvest-activity.md plan 落地, 等待 /autonomous-feature-runner 进 Step 1 — C.1)

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

## Phase C — Harvest Activity + Drop-off Loop (🚧 active)

详见 [`task-plan/m2-1-economy/phase-c-harvest-activity.md`](task-plan/m2-1-economy/phase-c-harvest-activity.md)。

### Phase C 验收准则 checklist (0/7)

- [ ] **AC1** `RtsAutoBattleProcedure.add_team_resources(team_id, delta: Dictionary)` 对称 spend
  - 文件: `addons/logic-game-framework/example/rts-auto-battle/core/rts_auto_battle_procedure.gd` (改)
  - Evidence: 待实现
- [ ] **AC2** 新 `RtsHarvestActivity` (extends RtsActivity)
  - 文件: `addons/logic-game-framework/example/rts-auto-battle/logic/activity/harvest_activity.gd` (新)
  - Evidence: 待实现 (字段 target_node_id / harvest_progress / _nav_agent; 钩子 on_first_run / tick / on_last_run / is_equivalent_to / get_intent_label)
- [ ] **AC3** 新 `RtsReturnAndDropActivity` (extends RtsActivity)
  - 文件: `addons/logic-game-framework/example/rts-auto-battle/logic/activity/return_and_drop_activity.gd` (新)
  - Evidence: 待实现 (字段 drop_off_id / _nav_agent; on_first_run 找 is_drop_off 建筑; tick 抵达调 procedure.add_team_resources)
- [ ] **AC4** 新 `RtsHarvestStrategy` (extends RtsAIStrategy)
  - 文件: `addons/logic-game-framework/example/rts-auto-battle/logic/ai/rts_harvest_strategy.gd` (新)
  - Evidence: 待实现 (carrying 非空 → ReturnAndDrop; 否则找最近 ResourceNode → Harvest; 找不到 → Idle)
- [ ] **AC5** `RtsAIStrategyFactory.get_strategy(WORKER)` 切到 `_harvest_strategy`
  - 文件: `addons/logic-game-framework/example/rts-auto-battle/logic/ai/rts_ai_strategy_factory.gd` (改)
  - Evidence: 待实现 (新 `static var _harvest_strategy`; WORKER 分支返 `_harvest_strategy`)
- [ ] **AC6** 新 `smoke_harvest_loop.{gd,tscn}` PASS
  - 文件: `addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_harvest_loop.{gd,tscn}` (新)
  - Evidence: 待跑 (`/tmp/m21_c_hl.txt`; 期望 ticks=600 alive_workers=5 gold_amount<1500 wood_amount<1500 team_gold≥100 team_wood≥100 cycle_completed≥1)
- [ ] **AC7** Validation 全套不退化 (LGF 73/73 + 既有 6 RTS smoke + 2 replay smoke + frontend smoke 0 漂移; smoke_resource_nodes 见风险表)
  - Evidence: 待跑 (`/tmp/m21_c_lgf_unit.txt` / `/tmp/m21_c_main.txt` / `/tmp/m21_c_replay.txt` / `/tmp/m21_c_det.txt` / `/tmp/m21_c_fe.txt` / `/tmp/m21_c_pc.txt` / `/tmp/m21_c_pcp.txt` / `/tmp/m21_c_cw.txt` / `/tmp/m21_c_prod.txt` / `/tmp/m21_c_ct.txt` / `/tmp/m21_c_rn.txt`)

### Phase C 子任务进度 (0/7)

- [ ] **C.1 — World ↔ Procedure 通信打通**
  - World 加 `procedure: RtsAutoBattleProcedure` 字段 + `bind_procedure(p)` 方法
  - Procedure._init 末尾调 `world.bind_procedure(self)`
  - Procedure 加 `add_team_resources(team_id, delta: Dictionary)` (对称 spend)
- [ ] **C.2 — `RtsUnitActor.carrying` 字段**
  - 加 `carrying: Dictionary[String, int] = {}`; 既有兵种不读不写, 默认 {}
- [ ] **C.3 — `RtsBuildingActor.is_drop_off` 字段 + ct 起手设 true**
  - RtsBuildingActor 加 `is_drop_off: bool = false`
  - RtsBuildings.create_crystal_tower 末尾设 `b.is_drop_off = true`
- [ ] **C.4 — `RtsHarvestActivity` 新文件** (单一 Activity 自管 nav, 类似 RtsAttackActivity 模式)
- [ ] **C.5 — `RtsReturnAndDropActivity` 新文件** (on_first_run 找己方最近 is_drop_off; 抵达调 add_team_resources)
- [ ] **C.6 — `RtsHarvestStrategy` 新文件 + factory 切换** (worker → harvest_strategy, melee/ranged 不动)
- [ ] **C.7 — `smoke_harvest_loop.{gd,tscn}` 新文件**
  - 起手: 5 worker (左 team 0) + 1 gold node + 1 wood node (中立) + 双方 ct 不死
  - 跑 600 tick, 验 gold/wood 双增长 ≥ 100 + 至少 1 worker 完整 cycle

### Phase C 设计决策 (用户 2026-05-02 确认 + phase-c-harvest-activity.md §设计决策详)

- **D6**: Drop-off = 复用 `crystal_tower` (用户已确认)
- **D7**: Worker AI = 找最近未耗尽 ResourceNode (用户已确认; round-robin tiebreak by actor_id 字典序)
- **D8**: Worker 出生 = hardcode smoke/demo (用户已确认; 不加 SpawnWorkerCommand)
- **D9**: Activity ↔ procedure 通信 = `RtsWorldGameplayInstance.bind_procedure` + `world.procedure.add_team_resources(...)` (Activity sig 不动)
- **D10**: HarvestActivity = 单一 Activity 自管 nav (类似 RtsAttackActivity, 不嵌套 child MoveTo)
- **D11**: 多 worker 同 node 无锁 (controller.tick 顺序决定性, 后到 worker actual=0)
- **D12**: HARVEST_RADIUS = 32 px; DROP_OFF_RADIUS = 32 px
- **D13**: smoke 跑 600 tick @ 33.33ms ≈ 20s; 阈值 gold + wood 双 ≥ 100 (5 worker × 4 cycle × 10 cap = 200, 阈值留余)
- **D14**: Stance 不影响 worker (mask=NONE 不参战)
- **D15**: `RtsUnitActor.carrying: Dictionary[String, int] = {}` 字段
- **D16**: harvest_progress per-tick 累积 + floor(progress) 单位时刻 mutate node.amount + worker.carrying

### Phase C 风险占位 (详见 phase-c-harvest-activity.md §风险表)

- 🔒 Phase B `smoke_resource_nodes` 被 break (worker 不再 idle 因 harvest_strategy 切换) — 实现 C.6 后跑此 smoke 决定方案 A (改 smoke 起手不放 node) vs 方案 B (删此 smoke, smoke_harvest_loop 已覆盖)
- 🔒 Activity ↔ procedure 通信循环 (World ↔ Procedure 互 hold ref) — bind_procedure 后 ObjectDB leak 无变化即可
- 🔒 Bit-identical replay 漂移 — factory `_harvest_strategy` 静态 init 不调 RtsRng, HarvestStrategy 找最近用 actor_id tiebreak (确定性), replay 应 0 漂移
- 🔒 Drop-off 找不到 ct (ct 死亡) → carrying-locked-no-drop 死循环 — smoke 起手 ct 不死规避; Phase D smoke_economy_demo 加 fallback 测

---

## Phase D 待启 (Phase C 收口后)

详见 [`task-plan/m2-1-economy/README.md`](task-plan/m2-1-economy/README.md) §Phase D。

- **Phase D** — Cost Rebalance + smoke_economy_demo (multi-resource cost 配方调整 + 经济闭环 full cycle smoke + 编辑器 F6 视觉验证 + demo_rts_frontend worker spawn)
