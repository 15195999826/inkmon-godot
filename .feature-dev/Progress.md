## Progress — RTS Auto-Battle M2.1 Economy

**Status**: ✅ **Phase A 收口** (2026-05-02) — Multi-Resource Foundation; **Phase B 启动中** — Resource Nodes + Worker Class
- Phase A: ✅ 完成 (7/7 AC) — 详见下方 evidence
- Phase B: 🚧 进行中 — 见 `task-plan/m2-1-economy/phase-b-resource-nodes.md`
- Phase C-D: 🔒 等待 Phase B 收口

最近更新: 2026-05-02 (M2.1 Phase A 全 7 AC 收口, 切到 Phase B 启动)

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

## Phase B — Resource Nodes + Worker Class (🚧 进行中)

详见 [`task-plan/m2-1-economy/phase-b-resource-nodes.md`](task-plan/m2-1-economy/phase-b-resource-nodes.md) (Phase A 收口时新写)。

**Scope 概要** (Phase A 末态时启动): 新 `RtsResourceNode` actor + `UnitClass.WORKER` + idle 行为 + smoke_resource_nodes; 不接 harvest 行为 (那是 Phase C)。

待启动: 见 Phase B 文档 §Acceptance + §子任务清单。

## Phase C-D 待启 (Phase B 收口后)

详见 [`task-plan/m2-1-economy/README.md`](task-plan/m2-1-economy/README.md)。

- **Phase C** — Harvest Activity + Drop-off Loop (HarvestActivity + ReturnAndDropActivity + crystal_tower 兼 drop-off + HarvestStrategy; smoke_harvest_loop)
- **Phase D** — Cost Rebalance + smoke_economy_demo (multi-resource cost 配方调整 + 经济闭环 full cycle smoke + 编辑器 F6 视觉验证)
