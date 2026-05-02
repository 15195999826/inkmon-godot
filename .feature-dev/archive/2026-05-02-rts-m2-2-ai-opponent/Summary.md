# RTS Auto-Battle M2.2 — AI 对手 (Computer Player) — Summary (2026-05-02)

## Sub-feature 概要

让 RTS 例子第一次拥有自主行动的 AI:把"右侧不发 player_command 就死站"演进为"双方各跑一个 RtsComputerPlayer, 自动 worker 采集 → 放 barracks → 出兵 attack-move 攻敌方 ct"。

**Minimal AI scope** (M2.2 第一轮; 后续轮可加难度 / 兵种偏好 / 防御阵型):
- 1 档难度,无难度档位选项
- 单跳 build order:只放 barracks (1 个 cap; 不管 archer_tower / 防空 / 兵种偏好)
- AI 出 unit 走默认 melee (barracks 默认 spawn melee)
- worker harvest 沿用 M2.1 的 RtsHarvestStrategy(AI 不 override worker)
- 不引入侦探 / 防御阵型

**模式**: 1 phase 单线推进, 子任务 E.1 → E.2 → E.3 → E.4。

## Acceptance 结论 (6/6 PASS)

- [x] **AC1 — RtsComputerPlayer module 存在 + procedure 注册并 tick 驱动**
  - 新文件 `addons/logic-game-framework/example/rts-auto-battle/logic/ai/rts_computer_player.gd` (class RtsComputerPlayer extends RefCounted, team_id + _attack_dispatched 字段, think(world, current_tick) 决策入口, DECISION_INTERVAL_TICKS=30 / BARRACKS_OFFSET_X=96.0 / BARRACKS_CAP=1 / ATTACK_DISPATCH_THRESHOLD=3 常量)
  - procedure 集成: `_computer_players: Array[RtsComputerPlayer]` + `attach_computer_player(p_team_id)` + tick_once step 6.5 (record_current_frame_events 后, 胜负判定前) 循环调 `cp.think(world, _current_tick)`

- [x] **AC2 — Build 决策 (place barracks @ ct 偏移点)** (E.2 落地)
  - `_try_build_barracks`: barracks 数 ≥ BARRACKS_CAP (=1) 不放; 资源 < {gold:80, wood:50} 不放; ct 不存在不放; 否则 enqueue PlaceBuildingCommand 在 ct + Vector2(±96, 0) (左 +96 east / 右 -96 west)
  - placement 校验失败 (out of build_zone / cells_occupied) 走 PlaceBuildingCommand.apply 内部失败链路, AI 下个 30 tick 重新调用 → stateless 天然 retry
  - enqueue 接口: `procedure.enqueue_player_command(RtsPlaceBuildingCommand.new(current_tick, team_id, KIND_BARRACKS, place_pos))`, 与玩家命令同链路保 bit-identical replay

- [x] **AC3 — Attack 决策 (出 ≥3 non-worker unit 后 attack-move 一次)** (E.3 落地)
  - `_try_attack`: `_attack_dispatched == true` 守卫 (E6 only-once); alive non-worker unit < ATTACK_DISPATCH_THRESHOLD (=3) 不放; 敌方 ct 不存在不放
  - 否则 enqueue MoveUnitsCommand(unit_ids = all alive non-worker, target_pos = enemy_ct.position, spacing default 30); 设 `_attack_dispatched = true`
  - 不传 attack_move=true (RtsMoveUnitsCommand 没此字段); 走纯 RtsMoveToActivity, unit 抵达后 controller._player_command_active 自然清, RtsBasicAttackStrategy + AutoTargetSystem 接管 → unit 在 ct 范围内 attack ct

- [x] **AC4 — smoke_ai_vs_player_full_match.{gd,tscn} PASS (中等强度)** (E.4 落地)
  - 新文件 `addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_ai_vs_player_full_match.{gd,tscn}`
  - setup: 双方 5 worker + 1 ct + 1 gold + 1 wood node; starting {gold:100, wood:100}; 左 team attach AI, 右 team NO attach (站桩)
  - 跑 600 tick @ 30Hz (TICK_INTERVAL_MS=33.33; RNG_SEED=31415)
  - 实测 PASS: ai_barracks=1 ai_units_spawned=4 ai_unit_to_ct_attacks=9 (≥ {1,3,1} 阈值全过, total_attack_events=15)

- [x] **AC5 — demo_rts_frontend 双方都启 AI + F6 视觉验证** (E.4 落地; F6 视觉留给用户)
  - 改 `frontend/demo_rts_frontend.gd`: procedure setup 后 attach_computer_player(0) + (1) (E9 — AI vs AI); 起手 spawn 维持 M2.1 末态 (5 worker + 1 ct + 4 中立 node / 方); HUD 不动
  - frontend smoke `tests/frontend/smoke_frontend_main.tscn` 不崩: visualizers=10 alive_after_3.0s=10 (M2.1 末态 0 漂移)

- [x] **AC6 — Validation 全套 0 行为漂移 (13 既有 + 1 新 = 14 项)** (E.4 + simplify 后重跑全过)
  - LGF 73/73 + smoke_rts_auto_battle (ticks=347 attacks=74 melee=32 ranged=42 melee_max=24.00 bit-identical) + smoke_castle_war_minimal (ticks=193 left_win unit_to_building=4 archer_anti_air=1) + smoke_player_command (gold=20 wood=50 log=3) + smoke_player_command_production (ticks=600 left_spawned=7 max_eastward=254.74 gold=20) + smoke_production (ticks=600 left=7 right=7 max_left_eastward=118.51) + smoke_crystal_tower_win (ticks=2 left_win) + smoke_resource_nodes (ticks=200 alive=5 max_drift=0) + smoke_harvest_loop (ticks=600 alive=5 team_gold=140 team_wood=212 cycle=5) + smoke_economy_demo (ticks=900 melee_to_ct=31) + smoke_replay_bit_identical (seed=42 frames=9 events=20 deep-equal) + smoke_determinism (tick_diff=0) + smoke_frontend_main (visualizers=10 alive_after_3.0s=10) — 全部数字 bit-identical M2.1 末态

  - 关键不漂移点: E10 决策 — procedure 默认不 attach AI; 既有 12 项 smoke 全部走"右侧不发 command 就死站"路径, 数字与 M2.1 末态完全一致

## E1-E10 设计决策表 (sub-feature 启动锁定, 收口落地)

| 决策 ID | 内容 | 取值 |
|---|---|---|
| E1 | AI 模块层级 + 驱动方 | `logic/ai/rts_computer_player.gd` team-level + procedure tick 驱动 |
| E2 | AI 出兵 / 放建筑 接口 | RtsPlayerCommandQueue (与玩家同接口, 保 bit-identical replay) |
| E3 | 决策粒度 | 每 30 tick (1s @ 30Hz) |
| E4 | barracks 建造位置 | ct 偏移点固定 (左 team east+96, 右 team west-96); placement 失败跳过本轮 |
| E5 | barracks 建造 cap | 1 个/team; 实时计数 (不缓存) |
| E6 | attack-move 触发条件 | alive non-worker unit ≥ 3 + `_attack_dispatched=false` (per-team only-once) |
| E7 | attack-move 目标 | 敌方 team_config.crystal_tower_id 对应 actor.position |
| E8 | smoke 验收强度 | 中等 (≥1 barracks + ≥3 unit + ≥1 attack ct) |
| E9 | demo F6 启用方式 | 双方都启 AI (AI vs AI) |
| E10 | procedure 内 AI attach 时机 | 显式 `procedure.attach_computer_player(team_id)`; 默认不创建 (保旧 12 项 smoke 不漂移) |

## 关键 artifact 路径

**新增 (M2.2 落地)**:
- `addons/logic-game-framework/example/rts-auto-battle/logic/ai/rts_computer_player.gd` — RtsComputerPlayer 主类 (158 行 post-simplify)
- `addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_ai_vs_player_full_match.{gd,tscn}` — AC4 主 acceptance smoke

**改动 (M2.2)**:
- `addons/logic-game-framework/example/rts-auto-battle/core/rts_auto_battle_procedure.gd` — 加 `_computer_players` + `attach_computer_player(p_team_id)` + tick_once step 6.5 think 调用
- `addons/logic-game-framework/example/rts-auto-battle/frontend/demo_rts_frontend.gd` — procedure setup 后 attach_computer_player(0/1) + 头注释升级

**未动 (M2.2 沿用 M2.1 末态)**:
- 所有 logic/commands/* (PlayerCommandQueue / PlaceBuildingCommand / MoveUnitsCommand)
- 所有 logic/activity/* (Idle / MoveTo / Attack / AttackMove / Harvest / ReturnAndDrop)
- 所有 logic/ai/{strategy / target_system / factory} (RtsComputerPlayer 与 RtsAIStrategy 平级独立)
- 所有 既有 12 项 smoke / replay tests (E10 — 不 attach AI 走旧路径)

## 真实运行证据 (commands + 关键数字)

```
# Validation 全套 14 项 (post-simplify pass 重跑, EXIT=0 全过)
godot --headless --path . --import                                                           # ok
godot --headless --path . addons/logic-game-framework/tests/run_tests.tscn                   # 73/73 PASS
godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_rts_auto_battle.tscn         # ticks=347 attacks=74 melee=32 ranged=42 melee_max=24.00 (bit-identical)
godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_castle_war_minimal.tscn      # ticks=193 left_win unit_to_building=4 archer_anti_air=1
godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_player_command.tscn          # gold=20 wood=50 log=3
godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_player_command_production.tscn  # ticks=600 left_spawned=7 max_eastward=254.74 gold=20
godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_production.tscn              # ticks=600 left=7 right=7 max_left_eastward=118.51
godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_crystal_tower_win.tscn       # ticks=2 left_win
godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_resource_nodes.tscn          # ticks=200 alive=5 max_drift=0
godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_harvest_loop.tscn            # ticks=600 alive=5 team_gold=140 team_wood=212 cycle=5
godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_economy_demo.tscn            # ticks=900 melee_spawned=4 melee_to_ct=31 final_gold=138 final_wood=196
godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/replay/smoke_replay_bit_identical.tscn    # seed=42 commands=2 frames=9 events=20 (deep-equal)
godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/replay/smoke_determinism.tscn             # seed=12345 tick_diff=0
godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/frontend/smoke_frontend_main.tscn         # visualizers=10 alive_after_3.0s=10
godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_ai_vs_player_full_match.tscn # ai_barracks=1 ai_units_spawned=4 ai_unit_to_ct_attacks=9 (NEW; AC4 主 gate)
```

Evidence 路径汇总 (E.4 重跑后):
- `/tmp/m22_e4_lgf.txt` (LGF 73/73 PASS)
- `/tmp/m22_e4_main.txt` (4v4 main bit-identical)
- `/tmp/m22_e4_cw.txt` `/tmp/m22_e4_pc.txt` `/tmp/m22_e4_pcp.txt` `/tmp/m22_e4_prod.txt` `/tmp/m22_e4_ct.txt` (既有 smoke)
- `/tmp/m22_e4_rn.txt` `/tmp/m22_e4_hl.txt` `/tmp/m22_e4_econ.txt` (M2.1 economy smoke)
- `/tmp/m22_e4_replay.txt` `/tmp/m22_e4_det.txt` (replay)
- `/tmp/m22_e4_fe.txt` (frontend; demo 改后不崩)
- `/tmp/m22_e4_ai_match.txt` (AC4 主 gate; AI 自跑 PASS)

## Phase-close gate (§7a-7c) 通过

- **§7a Simplify pass** — 对 changed files (rts_computer_player.gd / rts_auto_battle_procedure.gd / smoke_ai_vs_player_full_match.{gd,tscn} / demo_rts_frontend.gd) 跑 simplify skill, 3 个 review agent 并行
- **§7b 重跑 14/14 validation** — simplify 删 `_find_team_ct_position` wrapper + 精简注释 (无逻辑改动) 后重跑全套, 数字 bit-identical simplify 前 (与 M2.1 末态完全一致)
- **§7c AC-doc consistency** — Progress.md AC2/AC3 doc 已更新反映 simplify 后的代码现状 (移除 _find_team_ct_position 引用, 改为单入口 _find_team_ct_position_for); Evidence 路径全部更新到 /tmp/m22_e4_*.txt

## 残余风险 / 已知 follow-up

- 🟢 **bit-identical replay 漂移**: ✅ mitigated. E10 决策落地保旧 smoke 0 漂移; smoke_replay_bit_identical 数字 deep-equal M2.1 末态。
- 🟢 **AI 决策非决定性**: ✅ mitigated. barracks 数每决策 tick 现查不缓存; _attack_dispatched 是 procedure-attached object; smoke_ai_vs_player_full_match 单跑稳定 PASS。
- 🟢 **placement 在 ct 偏移点失败**: ✅ mitigated. starting 100/100 ≥ cost 80/50, smoke 实测第一个决策 tick (=30) 立即放下 ai_barracks=1; 天然 retry 路径无需 hit。
- 🟢 **AI 出 unit 后跑反方向**: ✅ mitigated. smoke 实测 ai_unit_to_ct_attacks=9 (≥ 1 阈值 9 倍), unit 走纯 MoveTo 抵达后 strategy 接管 attack 链路稳定可达。
- 🟡 **F6 视觉验证留给用户**: AC5 留给用户在编辑器 F6 跑 demo_rts_frontend.tscn 实地观察 "采集 → 放 barracks → 出 unit → 攻 ct" 完整链路。Headless smoke 不阻塞此项。
- 🟡 **Smoke boilerplate 重复 (smoke_ai_vs_player_full_match 与 smoke_economy_demo)**: simplify pass 时识别但跳过 — 仅 2 个 smoke 重复, helper 提取 cost > benefit; 后续若 smoke 数继续增长再做 base class 抽取。
- 🟢 **Future scope 留给后续 sub-feature**: 难度档位 / archer_tower 选择 / 兵种偏好 / 侦探 / 防御阵型 都不在 M2.2 minimal scope 内, 留给后续 sub-feature (M2.2 增量 / M2.3 / M3)。

## Commits (主仓 + submodule)

**Submodule (addons/logic-game-framework/) — M2.2 4 commit**:
- `93258d9` feat(rts-m22): E.1 — RtsComputerPlayer module + procedure tick 驱动 (skeleton)
- `512595f` feat(rts-m22): E.2 — Build 决策 (barracks 1 cap, ct 偏移点)
- `23b819b` feat(rts-m22): E.3 — Attack 决策 (≥3 non-worker unit 后 attack-move 一次, only-once)
- `4d3d85f` feat(rts-m22): E.4 — smoke_ai_vs_player_full_match + demo 双 AI + simplify pass (M2.2 收口)

**主仓 — M2.2 5 commit (含 archive 收口 commit)**:
- `d80461d` feat(rts-m22): bump addons + 同步 .feature-dev (E.1 — RtsComputerPlayer skeleton)
- `1d396d0` docs(rts-m22): baseline 文档 — M2.2 启动 (E1-E10 决策表 + 6 AC)
- `8f480ca` feat(rts-m22): bump addons + 同步 .feature-dev (E.2 — Build 决策)
- `f73bdfc` feat(rts-m22): bump addons + 同步 .feature-dev (E.3 — Attack 决策)
- (待 push) feat(rts-m22): bump addons + 同步 .feature-dev + archive (E.4 收口 + M2.2 整体 done)

## 决策来源

- 2026-05-02 用户授权 M2.2 启动 + 决策 E1-E10 (4 轮 AskUserQuestion via /next-feature-planner)
- M2 整体路线图: `task-plan/m2-roadmap.md`
- M2.1 末态 baseline: archive `archive/2026-05-02-rts-m2-1-economy/Summary.md`
- RTS M1 完整决策: archive `archive/2026-05-02-rts-m1-refactor/task-plan/architecture-baseline.md`
