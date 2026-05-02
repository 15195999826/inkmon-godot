## Progress — RTS Auto-Battle M2.2 AI 对手 (Computer Player)

**Status**: ✅ **6/6 AC PASS + 14/14 validation 全过 + simplify pass clean + AC-doc consistency aligned**(2026-05-02; 待 archive)

- 上一个 sub-feature: M2.1 Economy ✅ done + archive 完成 (2026-05-02; archive `archive/2026-05-02-rts-m2-1-economy/`)
- 本 sub-feature 模式: **1 phase 单线推进**(scope minimal); 子任务 E.1 → E.2 → E.3 → E.4
- 详细 plan: [`task-plan/m2-2-ai-opponent/README.md`](task-plan/m2-2-ai-opponent/README.md) (含 E1-E10 决策表 + 6 AC + 子任务拆分)

---

## 验收准则 checklist (6 AC, 待 /autonomous-feature-runner 推进)

### AC1 — RtsComputerPlayer module 存在 + procedure 注册并 tick 驱动 ✅ (E.1 done)

- [x] **新文件** `addons/logic-game-framework/example/rts-auto-battle/logic/ai/rts_computer_player.gd`
  - `class_name RtsComputerPlayer extends RefCounted`
  - 字段: `team_id: int = -1`, `_attack_dispatched: bool = false`
  - 常量: `DECISION_INTERVAL_TICKS: int = 30` (E3)
  - 接口: `func think(world: RtsWorldGameplayInstance, current_tick: int) -> void`(决策 tick % 30 == 0 才动作)
  - 占位: `_try_build_barracks` / `_try_attack` (E.2 / E.3 实现)
- [x] **改** `addons/logic-game-framework/example/rts-auto-battle/core/rts_auto_battle_procedure.gd`
  - `_computer_players: Array[RtsComputerPlayer] = []`
  - `func attach_computer_player(p_team_id: int) -> void` (含 team_id 校验 0/1)
  - tick 流程 step 6.5 (record_current_frame_events 后, 胜负判定前): `for cp in _computer_players: cp.think(world, _current_tick)`
- [x] Evidence (E10 — procedure 默认不 attach AI, 既有路径 0 漂移):
  - `/tmp/m22_e1_lgf.txt` — LGF 73/73 PASS (总计: 73 通过: 73 失败: 0)
  - `/tmp/m22_e1_main.txt` — `SMOKE_TEST_RESULT: PASS - left_win` ticks=347 attacks=74 melee=32 ranged=42 melee_max_dist=24.00 ranged_max_dist=125.75 (与 M2.1 末态 bit-identical)
  - `/tmp/m22_e1_replay.txt` — `SMOKE_TEST_RESULT: PASS` seed=42 commands=2 frames=9 events=20 (deep-equal)

### AC2 — Build 决策 (place barracks @ ct 偏移点) ✅ (E.2 done — 代码层; runtime 验证落 AC4)

- [x] **`_try_build_barracks` 实现** in `rts_computer_player.gd`
  - decision tick (think 入口已守 % 30 == 0)
  - `_count_team_barracks(world)` 实时查 alive RtsBuildingActor 过滤 team_id + building_kind == BARRACKS, ≥ BARRACKS_CAP (=1) 直接 return (E5 — 不缓存)
  - `_team_can_afford(procedure, cost)` 逐 key 对比 procedure.get_team_resources(team_id) 与 RtsBuildingConfig.get_stats(BARRACKS).cost = {gold: 80, wood: 50}; 任一不足 return
- [x] **位置算法**: BARRACKS_OFFSET_X = 96.0; 左 team offset = Vector2(+96, 0); 右 team = Vector2(-96, 0); 基准 = `_find_team_ct_position_for(world, procedure, team_id)` (走 team_config.crystal_tower_id → world.get_actor → position_2d; 任一缺失 return Vector2.INF → 不放)
- [x] **失败处理**: 不在 _try_build_barracks 内做 placement 校验; PlaceBuildingCommand.apply 内部 RtsBuildingPlacement.validate 失败 → 命令进 _failed_commands_log; AI 下个 30 tick 重新调用 → 天然 retry (stateless)
- [x] **enqueue 接口**: `procedure.enqueue_player_command(RtsPlaceBuildingCommand.new(current_tick, team_id, KIND_BARRACKS, place_pos))` — 与玩家命令同链路
- [x] Evidence (E10 — 既有 smoke 不 attach AI, 0 漂移; AI 实跑验证落 AC4):
  - `/tmp/m22_e2_lgf.txt` — LGF 73/73 PASS
  - `/tmp/m22_e2_main.txt` — `SMOKE_TEST_RESULT: PASS - left_win` ticks=347 attacks=74 melee=32 ranged=42 melee_max=24.00 (bit-identical M2.1 末态)
  - `/tmp/m22_e2_replay.txt` — `SMOKE_TEST_RESULT: PASS` seed=42 commands=2 frames=9 events=20 deep-equal

### AC3 — Attack 决策 (出 ≥3 non-worker unit 后 attack-move 一次) ✅ (E.3 done — 代码层; runtime 验证落 AC4)

- [x] **`_try_attack` 实现** in `rts_computer_player.gd`
  - decision tick (think 入口已守 % 30 == 0)
  - `_attack_dispatched == false` 守卫 (E6 — only-once)
  - `_collect_team_non_worker_unit_ids(world)` 走 world.get_alive_units 过滤 team_id + unit_class != WORKER; 数量 < ATTACK_DISPATCH_THRESHOLD (=3) return
- [x] **目标 = 敌方 ct.position**: `_find_team_ct_position_for(world, procedure, 1 - team_id)` (Build 决策查己方 / Attack 决策查敌方均走此 helper 单入口)
- [x] **enqueue MoveUnitsCommand**(unit_ids = all alive non-worker; target_pos = enemy_ct_pos): RtsMoveUnitsCommand sig (current_tick, team_id, unit_ids, target_pos) — spacing 走 default 30; 没有 attack_move 字段, 走纯 RtsMoveToActivity, unit 抵达后 controller._player_command_active 自动清, RtsBasicAttackStrategy 接管 → AutoTargetSystem 写 cached_target_id → unit attack ct
- [x] **Only-once**: `_attack_dispatched = true` 派出后 (M2.2 不做反复跟随)
- [x] Evidence (E10 — 既有 smoke 不 attach AI, 0 漂移; AI 实跑验证落 AC4):
  - `/tmp/m22_e3_lgf.txt` — LGF 73/73 PASS
  - `/tmp/m22_e3_main.txt` — `SMOKE_TEST_RESULT: PASS - left_win` ticks=347 attacks=74 melee=32 ranged=42 melee_max=24.00 (bit-identical M2.1 末态)
  - `/tmp/m22_e3_replay.txt` — `SMOKE_TEST_RESULT: PASS` seed=42 commands=2 frames=9 events=20 deep-equal

### AC4 — `smoke_ai_vs_player_full_match.{gd,tscn}` PASS (中等强度) ✅ (E.4 done)

- [x] **新文件** `addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_ai_vs_player_full_match.{gd,tscn}`
  - setup: 双方 5 worker + 1 ct + 1 gold + 1 wood node; starting {gold:100, wood:100} 双方
  - 左 team(team_id=0) attach AI; 右 team(team_id=1) NO attach (站桩)
  - 跑 600 tick @ 30Hz (TICK_INTERVAL_MS = 33.33; RNG_SEED = 31415)
- [x] 输出格式: `SMOKE_TEST_RESULT: PASS - ai_barracks=N1 ai_units_spawned=N2 ai_unit_to_ct_attacks=N3`(N3 = 敌方 ct 收到的攻击次数)
- [x] 断言全过: ai_barracks ≥ 1 ✅, ai_units_spawned ≥ 3 ✅, ai_unit_to_ct_attacks ≥ 1 ✅
- [x] Evidence: `/tmp/m22_e4_ai_match.txt` — `SMOKE_TEST_RESULT: PASS - ai_barracks=1 ai_units_spawned=4 ai_unit_to_ct_attacks=9` (total_attack_events=15)

### AC5 — demo_rts_frontend 双方都启 AI + F6 视觉验证 ✅ (E.4 done — headless 验证)

- [x] **改** `addons/logic-game-framework/example/rts-auto-battle/frontend/demo_rts_frontend.gd`
  - procedure setup 后 (line ~171-176) `procedure.attach_computer_player(0)` + `procedure.attach_computer_player(1)` (E9)
  - 起手 spawn 维持 M2.1 末态 (5 worker + 1 ct + 4 中立 node / 方); HUD 不动
  - 头注释更新到 M2.2 — 经济闭环 + AI vs AI demo, 玩家鼠标 click 仍可 enqueue (M2.2 不做 override 模式)
- [x] frontend smoke 不崩: `tests/frontend/smoke_frontend_main.tscn` (visualizers=10 alive_after_3.0s=10)
  - Evidence: `/tmp/m22_e4_fe.txt` — `SMOKE_TEST_RESULT: PASS - frontend stub renders 4v4 via director without script error`
- [ ] F6 用户视觉验证(留给用户; 不阻塞 headless): 双方 AI 起跑后, 各自采集 → 放 barracks → 出 unit → 攻 ct

### AC6 — Validation 全套 0 行为漂移 (13 项 + 1 新 = 14 项) ✅ (E.4 done — 全过, 数字 bit-identical M2.1 末态)

| smoke / 测试 | 预期 | 实测 (post-simplify 重跑) | Evidence |
|---|---|---|---|
| `addons/logic-game-framework/tests/run_tests.tscn` | 73/73 PASS | 73/73 PASS ✅ | `/tmp/m22_e4_lgf.txt` |
| `tests/battle/smoke_rts_auto_battle.tscn` | bit-identical: ticks=347 attacks=74 melee=32 ranged=42 melee_max=24.00 | ticks=347 attacks=74 melee=32 ranged=42 melee_max_dist=24.00 ranged_max_dist=125.75 detoured=4 ✅ | `/tmp/m22_e4_main.txt` |
| `tests/battle/smoke_castle_war_minimal.tscn` | ticks=193 left_win unit_to_building=4 archer_anti_air=1 | ticks=193 left_win unit_to_building=4 archer_anti_air=1 spawn_count=2 ✅ | `/tmp/m22_e4_cw.txt` |
| `tests/battle/smoke_player_command.tscn` | gold_remaining=20 wood_remaining=50 log=3 | log=3 gold=20 wood=50 ✅ | `/tmp/m22_e4_pc.txt` |
| `tests/battle/smoke_player_command_production.tscn` | ticks=600 left_spawned=7 max_eastward=254.74 gold_remaining=20 | ticks=600 left_spawned=7 max_eastward=254.74 gold=20 ✅ | `/tmp/m22_e4_pcp.txt` |
| `tests/battle/smoke_production.tscn` | ticks=600 left=7 right=7 max_left_eastward=118.51 | ticks=600 left_spawned=7 right_spawned=7 max_left_eastward=118.51 ✅ | `/tmp/m22_e4_prod.txt` |
| `tests/battle/smoke_crystal_tower_win.tscn` | ticks=2 left_win | ticks=2 left_win ✅ | `/tmp/m22_e4_ct.txt` |
| `tests/battle/smoke_resource_nodes.tscn` | ticks=200 alive=5 max_drift=0 | ticks=200 alive_workers=5 max_drift=0.00 ✅ | `/tmp/m22_e4_rn.txt` |
| `tests/battle/smoke_harvest_loop.tscn` | ticks=600 alive=5 team_gold=140 team_wood=212 cycle=5 | ticks=600 alive=5 team_gold=140 team_wood=212 cycle_workers=5 ✅ | `/tmp/m22_e4_hl.txt` |
| `tests/battle/smoke_economy_demo.tscn` | ticks=900 melee_to_ct=31 | ticks=900 melee_spawned=4 melee_to_ct=31 final_gold=138 final_wood=196 ✅ | `/tmp/m22_e4_econ.txt` |
| `tests/replay/smoke_replay_bit_identical.tscn` | seed=42 frames=9 events=20 deep-equal | seed=42 commands=2 frames=9 events=20 ✅ | `/tmp/m22_e4_replay.txt` |
| `tests/replay/smoke_determinism.tscn` | tick_diff=0 | seed=12345 run1=(left_win, 347) run2=(left_win, 347) tick_diff=0 ✅ | `/tmp/m22_e4_det.txt` |
| `tests/frontend/smoke_frontend_main.tscn` | visualizers=10 alive_after_3.0s=10 | visualizers=10 alive_after_3.0s=10 ✅ | `/tmp/m22_e4_fe.txt` |
| **`tests/battle/smoke_ai_vs_player_full_match.tscn` (新)** | PASS, ai_barracks ≥1, ai_units_spawned ≥3, ai_unit_to_ct_attacks ≥1 | ai_barracks=1 ai_units_spawned=4 ai_unit_to_ct_attacks=9 total_attack_events=15 ✅ | `/tmp/m22_e4_ai_match.txt` |

**关键不漂移点**:
- E10 决策 — procedure 默认不 attach AI; 既有 12 项 smoke 全部走"右侧不发 command 就死站"路径不变
- bit-identical replay (seed=42, 既有 smoke 不 attach AI): 数字与 M2.1 末态完全一致

---

## 子任务进度 (E.1-E.4, 单 phase)

- [x] **E.1 — RtsComputerPlayer module + procedure 注册 + tick 末调 .think()** ✅ (LGF 73/73 + 4v4 main + replay 三 sanity 全过, 0 漂移)
- [x] **E.2 — Build 决策(barracks 1 cap, ct 偏移点)** ✅ (代码层; sanity 三件套 0 漂移; AI 实跑验证落 AC4)
- [x] **E.3 — Attack 决策(≥3 unit 后 attack-move 一次)** ✅ (代码层; sanity 三件套 0 漂移; AI 实跑验证落 AC4)
- [x] **E.4 — smoke_ai_vs_player_full_match + demo_rts_frontend 启用双 AI + Validation 全套 + Simplify pass + commit + archive** ✅ (新 smoke PASS ai_barracks=1 ai_units_spawned=4 ai_unit_to_ct_attacks=9; 14/14 validation 全套 0 漂移; simplify 删 _find_team_ct_position wrapper + 精简注释 后重跑 14/14 仍 bit-identical M2.1 末态; AC-doc consistency aligned)

---

## 残余风险 (验收时 mitigated)

- ✅ **bit-identical replay 漂移风险**(新 module 入 procedure tick): E10 决策落地 — procedure 默认不 attach AI, 既有 smoke 12 项不进 think() 路径; smoke_replay_bit_identical 数字 frames=9 events=20 deep-equal M2.1 末态。
- ✅ **AI 决策非决定性**(if AI 内部 cache 状态破 replay): E5/E6 决策落地 — barracks 数 _count_team_barracks 每决策 tick 重新计数 (不缓存); _attack_dispatched 是 procedure-attached object 字段, 决定性来源 = 同 game state → 同决策; smoke_ai_vs_player_full_match 600 tick 单跑稳定 PASS。
- ✅ **placement 在 ct 偏移点失败**(E4 决策 — 跳过本轮): smoke 起手 starting 100/100 ≥ cost 80/50, 第一个 decision tick (=30) 立即放下 (实测 ai_barracks=1 peak); 天然 retry 路径无需 hit。
- ✅ **AI 出 unit 后跑反方向**(unit 不主动找路): unit MoveUnitsCommand 走纯 RtsMoveToActivity, 抵达后 controller._player_command_active 自然清, RtsBasicAttackStrategy + AutoTargetSystem 接管, 写 cached_target_id → unit 在 ct 范围内即 attack ct; 实测 ai_unit_to_ct_attacks=9 (≥1 阈值 9 倍) 充分验证可达。

---

## 决策来源

- 2026-05-02 用户答复 4 轮 AskUserQuestion(/next-feature-planner): 接口=PlayerCommandQueue / scope=minimal / module=team-level procedure tick / build 粒度=30 tick + ct 偏移 / smoke=中等 / phase=1 phase / demo=双方都 AI
- 决策表 E1-E10 锁定: `task-plan/m2-2-ai-opponent/README.md` §设计决策表
- M2.1 末态 baseline: `archive/2026-05-02-rts-m2-1-economy/Summary.md`
- M2 整体路线图: `task-plan/m2-roadmap.md`
