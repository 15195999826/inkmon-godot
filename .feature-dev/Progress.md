## Progress — RTS Auto-Battle M2.2 AI 对手 (Computer Player)

**Status**: 🚧 **E.1 done, E.2 进行中**(2026-05-02)

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

### AC2 — Build 决策 (place barracks @ ct 偏移点)

- [ ] **`_try_build_barracks` 实现** in `rts_computer_player.gd`
  - decision tick (current_tick % 30 == 0)
  - procedure team_id 当前 barracks 数 == 0 (查 procedure / world API; 不缓存)
  - procedure.get_team_resources(team_id) ≥ {gold: 80, wood: 50}
- [ ] **位置算法**:左 team offset = Vector2(96, 0); 右 team Vector2(-96, 0); 基准 = 己方 ct.position
- [ ] **失败处理**:placement 校验失败(被占 / out of build_zone)就跳过本轮(下个 1s 重试)
- [ ] **enqueue 接口**:走 `world.procedure.player_command_queue` 现有 push 接口(与玩家命令同链路)
- [ ] Evidence: AC4 smoke 体现(ai_barracks ≥1)

### AC3 — Attack 决策 (出 ≥3 non-worker unit 后 attack-move 一次)

- [ ] **`_try_attack` 实现** in `rts_computer_player.gd`
  - decision tick
  - `_attack_dispatched == false`
  - team alive non-worker unit count ≥ 3(查 procedure 兵种统计)
- [ ] **目标 = 敌方 ct.position**(team_config.crystal_tower_id 查找)
- [ ] **enqueue MoveUnitsCommand**(unit_ids = team 所有 alive non-worker; attack_move=true)
- [ ] **Only-once**:派出后 `_attack_dispatched = true`(M2.2 不做反复跟随)
- [ ] Evidence: AC4 smoke 体现(ai_unit_to_ct_attacks ≥1)

### AC4 — `smoke_ai_vs_player_full_match.{gd,tscn}` PASS (中等强度)

- [ ] **新文件** `addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_ai_vs_player_full_match.{gd,tscn}`
  - setup: 双方 5 worker + 1 ct + 1 gold + 1 wood node; starting {gold:100, wood:100}
  - 左 team(team_id=0) attach AI; 右 team(team_id=1) NO attach
  - 跑 600 tick (20s @ 30Hz)
- [ ] 输出格式: `SMOKE_TEST_RESULT: PASS - ai_barracks=N1 ai_units_spawned=N2 ai_unit_to_ct_attacks=N3`(N3 = 敌方 ct 收到的攻击次数)
- [ ] 断言全过: ai_barracks ≥ 1, ai_units_spawned ≥ 3, ai_unit_to_ct_attacks ≥ 1
- [ ] Evidence: `/tmp/m22_e4_ai_match.txt`

### AC5 — demo_rts_frontend 双方都启 AI + F6 视觉验证

- [ ] **改** `addons/logic-game-framework/example/rts-auto-battle/frontend/demo_rts_frontend.gd`
  - procedure setup 后 `procedure.attach_computer_player(0)` + `procedure.attach_computer_player(1)`
  - 起手 spawn 维持 M2.1 末态(5 worker + 1 ct + 4 中立 node / 方); HUD 不动
- [ ] frontend smoke 不崩: `tests/frontend/smoke_frontend_main.tscn` (visualizers=10 alive_after_3.0s=10)
  - Evidence: `/tmp/m22_e4_fe.txt`
- [ ] F6 用户视觉验证(留给用户; 不阻塞 headless): 双方 AI 起跑后, 各自采集 → 放 barracks → 出 unit → 攻 ct

### AC6 — Validation 全套 0 行为漂移 (13 项)

| smoke / 测试 | 预期 | Evidence 路径(预期) |
|---|---|---|
| `addons/logic-game-framework/tests/run_tests.tscn` | 73/73 PASS | `/tmp/m22_e4_lgf.txt` |
| `tests/battle/smoke_rts_auto_battle.tscn` | bit-identical: ticks=347 attacks=74 melee=32 ranged=42 melee_max=24.00 | `/tmp/m22_e4_main.txt` |
| `tests/battle/smoke_castle_war_minimal.tscn` | ticks=193 left_win unit_to_building=4 archer_anti_air=1 | `/tmp/m22_e4_cw.txt` |
| `tests/battle/smoke_player_command.tscn` | gold_remaining=20 wood_remaining=50 log=3 | `/tmp/m22_e4_pc.txt` |
| `tests/battle/smoke_player_command_production.tscn` | ticks=600 left_spawned=7 max_eastward=254.74 gold_remaining=20 | `/tmp/m22_e4_pcp.txt` |
| `tests/battle/smoke_production.tscn` | ticks=600 left=7 right=7 max_left_eastward=118.51 | `/tmp/m22_e4_prod.txt` |
| `tests/battle/smoke_crystal_tower_win.tscn` | ticks=2 left_win | `/tmp/m22_e4_ct.txt` |
| `tests/battle/smoke_resource_nodes.tscn` | ticks=200 alive=5 max_drift=0 | `/tmp/m22_e4_rn.txt` |
| `tests/battle/smoke_harvest_loop.tscn` | ticks=600 alive=5 team_gold=140 team_wood=212 cycle=5 | `/tmp/m22_e4_hl.txt` |
| `tests/battle/smoke_economy_demo.tscn` | ticks=900 melee_to_ct=31 | `/tmp/m22_e4_econ.txt` |
| `tests/replay/smoke_replay_bit_identical.tscn` | seed=42 frames=9 events=20 deep-equal | `/tmp/m22_e4_replay.txt` |
| `tests/replay/smoke_determinism.tscn` | tick_diff=0 | `/tmp/m22_e4_det.txt` |
| `tests/frontend/smoke_frontend_main.tscn` | visualizers=10 alive_after_3.0s=10 | `/tmp/m22_e4_fe.txt` |
| **`tests/battle/smoke_ai_vs_player_full_match.tscn` (新)** | PASS, ai_barracks ≥1, ai_units_spawned ≥3, ai_unit_to_ct_attacks ≥1 | `/tmp/m22_e4_ai_match.txt` |

**关键不漂移点**:
- E10 决策 — procedure 默认不 attach AI; 既有 12 项 smoke 全部走"右侧不发 command 就死站"路径不变
- bit-identical replay (seed=42, 既有 smoke 不 attach AI): 数字与 M2.1 末态完全一致

---

## 子任务进度 (E.1-E.4, 单 phase)

- [x] **E.1 — RtsComputerPlayer module + procedure 注册 + tick 末调 .think()** ✅ (LGF 73/73 + 4v4 main + replay 三 sanity 全过, 0 漂移)
- [ ] **E.2 — Build 决策(barracks 1 cap, ct 偏移点)** 🚧 进行中
- [ ] **E.3 — Attack 决策(≥3 unit 后 attack-move 一次)**
- [ ] **E.4 — smoke_ai_vs_player_full_match + demo_rts_frontend 启用双 AI + Validation 全套 + Simplify pass + commit + archive**

---

## 残余风险 (planning 阶段; 实现时 mitigate)

- 🔒 **bit-identical replay 漂移风险**(新 module 入 procedure tick): E10 决策 — procedure 默认不 attach AI, 既有 smoke 12 项不进 .think() 路径; replay smoke 数字 frames=9 events=20 应 deep-equal。验证落在 AC6 期间。
- 🔒 **AI 决策非决定性**(if AI 内部 cache 状态破 replay): E5/E6 决策 — barracks 数查 procedure(每决策 tick 重新计数), 不缓存; `_attack_dispatched` 是 procedure-attached object 的字段, 决定性来源 = 同 game state → 同决策。验证落在 AC4 + AC6 replay。
- 🔒 **placement 在 ct 偏移点失败**(E4 决策 — 跳过本轮): smoke 起手起跑后 1s 内一定够 cost(starting 100/100 ≥ cost 80/50), 第一个 decision tick 立即放下; 若 ct 邻接被占的稀有 case 走 "下个 1s 重试" 路径自然 mitigated。
- 🔒 **AI 出 unit 后跑反方向**(unit 不主动找路): unit attack-move 走 RtsAttackMoveActivity (M1 落地), 寻路+ AutoTargetSystem 主动选 target; M2.2 不要求"AI 反复 follow up", 一次性派遣后行为由 unit 自身负责。AC4 smoke 跑 600 tick 实测 attack ct 次数 ≥ 1 验证可达。

---

## 决策来源

- 2026-05-02 用户答复 4 轮 AskUserQuestion(/next-feature-planner): 接口=PlayerCommandQueue / scope=minimal / module=team-level procedure tick / build 粒度=30 tick + ct 偏移 / smoke=中等 / phase=1 phase / demo=双方都 AI
- 决策表 E1-E10 锁定: `task-plan/m2-2-ai-opponent/README.md` §设计决策表
- M2.1 末态 baseline: `archive/2026-05-02-rts-m2-1-economy/Summary.md`
- M2 整体路线图: `task-plan/m2-roadmap.md`
