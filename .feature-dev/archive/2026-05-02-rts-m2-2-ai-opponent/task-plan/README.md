# M2.2 — AI 对手 (Computer Player)

> 父路线图: [`../m2-roadmap.md`](../m2-roadmap.md) §M2.2
>
> 上一个 sub-feature: M2.1 Economy ✅ done (2026-05-02; archive `archive/2026-05-02-rts-m2-1-economy/`)

---

## Sub-feature 目标

让 RTS 例子第一次拥有自主行动的 AI 对手:把 RTS M2.1 末态"右侧不发 player_command 就死站"演进为"双方各跑一个 RtsComputerPlayer, AI 自动放 barracks + 出兵后 attack-move 攻敌方 ct"。

最小可观察单元 (Minimal AI scope):
- 1 档难度,无难度档位选项
- 单跳 build order:只放 barracks(不管 archer_tower / 防空 / 兵种偏好)
- AI 出 unit 走默认 melee(barracks 默认 spawn melee)
- worker harvest 沿用既有 RtsHarvestStrategy(M2.1 落地的, AI 不 override worker)
- 不引入新难度参数 / 不引入侦探 / 不引入防御阵型

M2.2 完成后, F6 demo 双方均 AI 自动跑, 用户旁观即能看见"采集 → 放 barracks → 出兵 → 攻 ct"完整链路。

---

## 设计决策表 (E1-E10, sub-feature 启动时锁定)

| 决策 ID | 内容 | 取值 |
|---|---|---|
| **E1** | AI 模块层级 + 驱动方 | `logic/ai/rts_computer_player.gd` team-level + procedure tick 驱动(每 tick 调 `.think()`) |
| **E2** | AI 出兵 / 放建筑 接口 | 走 RtsPlayerCommandQueue, 与玩家同接口(保 bit-identical replay) |
| **E3** | AI 决策粒度 (decision interval) | 每 30 tick (1s @ 30Hz) 触发一次决策; 非决策 tick `.think()` 直接返 |
| **E4** | barracks 建造位置算法 | ct 偏移点固定:左 team `ct.position + Vector2(96, 0)` (east-of-ct 3 格); 右 team `ct.position + Vector2(-96, 0)` (west-of-ct 3 格); placement 校验失败(被占)就跳过本轮决策, 下个 1s 重试 |
| **E5** | barracks 建造 cap | 1 个/team(已建 ≥1 就不再放); 通过查 procedure 当前 barracks 数判断, AI 不缓存自身状态(replay 决定性来源 = 同 game state → 同决策) |
| **E6** | attack-move 触发条件 | team alive unit count ≥ 3 (不含 worker), 且本 team 尚未发过 MoveUnitsCommand (per-team boolean `_attack_dispatched: bool` cache 在 ComputerPlayer 实例; 决定性 OK — ComputerPlayer 也是 procedure-attached object) |
| **E7** | attack-move 目标 | 敌方 team_config.crystal_tower_id 对应的 actor.position |
| **E8** | smoke 验收强度 | 中等:600 tick @ 30Hz; AI 放 ≥1 barracks + 出 ≥3 unit + unit attack ct ≥1 次 (3 个全过算 PASS); 不要求决出胜负 |
| **E9** | demo F6 启用方式 | 双方都启 AI(AI vs AI); demo_rts_frontend 起手 attach 两个 ComputerPlayer; 玩家鼠标 click 仍可 enqueue 但不强制(M2.2 不做 override 模式) |
| **E10** | AI 在 procedure 内的 attach 时机 | smoke / demo 创建 procedure 后**显式** `procedure.attach_computer_player(team_id)`; 不在 procedure._init 默认创建(保留旧 smoke "右侧不发 command 就死站"行为不变) |

---

## Acceptance Criteria (AC1-AC6)

### AC1 — RtsComputerPlayer module 存在 + procedure 注册并 tick 驱动

**实现**: `addons/logic-game-framework/example/rts-auto-battle/logic/ai/rts_computer_player.gd` (新文件)
- `class_name RtsComputerPlayer extends RefCounted`
- 字段: `team_id: int`, `_attack_dispatched: bool = false` (E6 cache)
- 接口: `func think(world: RtsWorldGameplayInstance, current_tick: int) -> void`
  - 非决策 tick (current_tick % 30 != 0) 直接返
  - 决策 tick:`_try_build_barracks(world, current_tick)` → `_try_attack(world, current_tick)`
- 不持有 procedure ref(避免循环); world 已经有 `procedure: RtsAutoBattleProcedure` 字段(Phase C 加的)

**procedure 集成**: `addons/logic-game-framework/example/rts-auto-battle/core/rts_auto_battle_procedure.gd`
- 字段: `_computer_players: Array[RtsComputerPlayer] = []`
- 接口: `func attach_computer_player(team_id: int) -> void`(创建并 push 一个 ComputerPlayer)
- tick 流程末尾(在 player_command_queue drain 前): for cp in _computer_players: cp.think(world, current_tick)

### AC2 — Build 决策 (place barracks @ ct 偏移点)

**条件**:
- decision tick (current_tick % 30 == 0)
- procedure 当前 team `barracks` 数 == 0(查 procedure / world 既有 list-buildings 接口)
- procedure.get_team_resources(team_id) ≥ {gold: 80, wood: 50}

**动作**: 构造 RtsPlaceBuildingCommand(team_id, kind=BARRACKS, position=`<ct.position + offset>`) 入 player_command_queue。
- 左 team (team_id=0): offset = Vector2(96, 0)
- 右 team (team_id=1): offset = Vector2(-96, 0)
- placement 校验失败(被占 / out of build_zone)就跳过本轮(下个 1s 重试)

### AC3 — Attack 决策 (出 ≥3 unit 后 attack-move 攻敌方 ct)

**条件**:
- decision tick
- `_attack_dispatched == false`
- team alive non-worker unit count ≥ 3

**动作**: 收集 team 所有 alive non-worker unit_id, 构造 RtsMoveUnitsCommand(team_id, unit_ids, target=`<enemy_ct.position>`, attack_move=true) 入 queue; 设 `_attack_dispatched = true`(only-once)。

注: M2.2 不做"反复 attack-move 跟随"; 一次性派出后 unit 走自身 AutoTargetSystem(M1 落地)。

### AC4 — smoke_ai_vs_player_full_match.{gd,tscn} PASS (中等强度)

**文件**: `addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_ai_vs_player_full_match.{gd,tscn}` (新)

**setup**:
- 起手: 双方 5 worker + 1 ct + 1 gold + 1 wood node
- starting_resources: `{"gold": 100, "wood": 100}`(同 demo)
- 左 team(team_id=0): attach RtsComputerPlayer
- 右 team(team_id=1): NO attach(右侧默认哑巴, 站桩)
- 跑 600 tick (20s @ 30Hz)

**断言** (3 个全过算 PASS):
- AI 放 barracks 数 ≥ 1
- AI team alive non-worker unit 累计 spawn 数 ≥ 3
- AI 旗下 unit attack 敌方 ct 攻击次数 ≥ 1

输出格式: `SMOKE_TEST_RESULT: PASS - ai_barracks=N1 ai_units_spawned=N2 ai_unit_to_ct_attacks=N3`(N3 是敌方 ct 收到的攻击次数)

### AC5 — demo_rts_frontend.gd 双方都启 AI + F6 视觉验证

**改动**: `addons/logic-game-framework/example/rts-auto-battle/frontend/demo_rts_frontend.gd`
- procedure setup 后 attach 双方 ComputerPlayer:
  ```gdscript
  procedure.attach_computer_player(0)
  procedure.attach_computer_player(1)
  ```
- 起手 spawn 维持 M2.1 末态(5 worker + 1 ct + 4 中立 node / 方); 不动 HUD
- F6 用户视觉验证: 双方 AI 起跑后, 各自有 worker 采集 → 资源到 cost → 放 barracks → 出 unit → unit 进攻 ct
- frontend smoke `smoke_frontend_main.tscn` 不崩(visualizers=10 alive_after_3.0s=10)

### AC6 — Validation 全套 0 行为漂移 (除 AC2-AC5 引入的新数字)

| smoke / 测试 | 预期 |
|---|---|
| `addons/logic-game-framework/tests/run_tests.tscn` | 73/73 PASS (LGF 单元) |
| `tests/battle/smoke_rts_auto_battle.tscn` | bit-identical 与 M2.1 末态: ticks=347 attacks=74 melee=32 ranged=42 melee_max_dist=24.00 |
| `tests/battle/smoke_castle_war_minimal.tscn` | ticks=193 left_win unit_to_building=4 archer_anti_air=1 (与 M2.1 末态 0 漂移) |
| `tests/battle/smoke_player_command*.tscn` | M2.1 末态(右侧站桩 / 玩家放兵营 数字不变) |
| `tests/battle/smoke_production.tscn` | ticks=600 left=7 right=7 max_left_eastward=118.51 |
| `tests/battle/smoke_crystal_tower_win.tscn` | ticks=2 left_win |
| `tests/battle/smoke_resource_nodes.tscn` | ticks=200 alive=5 max_drift=0.00 |
| `tests/battle/smoke_harvest_loop.tscn` | ticks=600 alive=5 team_gold=140 team_wood=212 cycle=5 (M2.1 末态) |
| `tests/battle/smoke_economy_demo.tscn` | ticks=900 melee_to_ct=31 (M2.1 末态) |
| `tests/replay/smoke_replay_bit_identical.tscn` | seed=42 frames=9 events=20 deep-equal |
| `tests/replay/smoke_determinism.tscn` | tick_diff=0 |
| `tests/frontend/smoke_frontend_main.tscn` | visualizers=10 alive_after_3.0s=10 |
| **`tests/battle/smoke_ai_vs_player_full_match.tscn` (新)** | PASS, ai_barracks ≥1, ai_units_spawned ≥3, ai_unit_to_ct_attacks ≥1 |

**关键不漂移点**:
- E10 决策 — procedure 默认不 attach AI, 既有 12 项 smoke 全部走"右侧不发 command 就死站"路径; 数字 0 漂移
- bit-identical replay: seed=42 既有 smoke 不 attach AI, 数字与 M2.1 末态完全一致

---

## 子任务拆分 (E.1-E.4, 1 phase 单线推进)

| 子任务 | 内容 |
|---|---|
| **E.1** | `rts_computer_player.gd` module + procedure attach_computer_player + tick 末调 .think() |
| **E.2** | Build 决策(barracks 1 cap, ct 偏移点); 在 E.1 跑过基础后做 |
| **E.3** | Attack 决策(≥3 unit 后 attack-move 一次); 在 E.2 跑过基础后做 |
| **E.4** | `smoke_ai_vs_player_full_match.{gd,tscn}` 新 + `demo_rts_frontend` 启用双 AI + Validation 全套 |

---

## 收口条件 (Sub-feature 完成 = M2.2 整体 done)

- 所有 6 AC PASS(headless)+ 用户 F6 视觉认可双方 AI 自跑链路
- 创建 `archive/<YYYY-MM-DD>-rts-m2-2-ai-opponent/`(Summary.md / Current-State.md / Next-Steps.md / Progress.md / task-plan/)
- 主 `Next-Steps.md` 切回"等待用户确认下一个 feature"
- `m2-roadmap.md` M2.2 status 标 ✅ done
- 主 `Current-State.md` 更新为 M2.2 末态 baseline (RtsComputerPlayer + AI 自动放 barracks + 出兵 attack-move 链路 已落地)

---

## 关键约束 (跨 sub-feature 不变)

来自 `Autonomous-Work-Protocol.md`:

1. **不修改 LGF submodule core / stdlib**(所有新代码进 `addons/logic-game-framework/example/rts-auto-battle/`)
2. **三层架构**:`core ← logic ← frontend`,frontend 不能被 core/logic 引用
3. **测试入口规范**:`.tscn` 入口 + `> /tmp/*.txt 2>&1` redirect, 不用 `--script` 不用 pipe
4. **修改 `project.godot` autoload 需用户确认** (M2.2 不预期加新 autoload)
5. **submodule (addons/logic-game-framework/) 改动单独 commit 在 submodule 内**, 主仓 commit 同时 bump submodule pointer

---

## 决策来源

- 2026-05-02 用户授权 M2.2 启动 + 决策 E1-E10(本文档 §设计决策表)
- M2.1 末态 baseline: archive `archive/2026-05-02-rts-m2-1-economy/Summary.md`
- M2 整体路线图: `../m2-roadmap.md`
