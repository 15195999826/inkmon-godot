# Next Steps — 2026-05-02 (RTS M2.2 — AI 对手 / Computer Player; 启动)

## 当前目标

**RTS Auto-Battle M2.2 — AI 对手 (Computer Player) — Minimal AI**

让 RTS 例子第一次拥有自主 AI:把"右侧不发 player_command 就死站"演进为"双方各跑一个 RtsComputerPlayer, 自动 worker 采集 → 放 barracks → 出兵 attack-move 攻敌方 ct"。Minimal scope:1 档难度 + 单跳 build order(只放 barracks); worker harvest 沿用 M2.1 的 RtsHarvestStrategy。

**实现入口 / 文档**:
- 完整 plan: [`task-plan/m2-2-ai-opponent/README.md`](task-plan/m2-2-ai-opponent/README.md)
- 决策表 E1-E10: 同上文档 §设计决策表
- 6 AC 验收准则: 同上文档 §Acceptance Criteria

**1 phase 单线推进 (E.1 → E.4)**:
- E.1 — RtsComputerPlayer module + procedure 注册 + tick 末调 .think()
- E.2 — Build 决策 (barracks 1 cap, ct 偏移点)
- E.3 — Attack 决策 (≥3 unit 后 attack-move 一次)
- E.4 — smoke_ai_vs_player_full_match + demo_rts_frontend 双 AI + Validation 全套

## 验收准则 (6 AC, 详细见 [`task-plan/m2-2-ai-opponent/README.md`](task-plan/m2-2-ai-opponent/README.md))

- **AC1** RtsComputerPlayer module 存在 + procedure 注册并 tick 驱动
  - 文件: `addons/logic-game-framework/example/rts-auto-battle/logic/ai/rts_computer_player.gd` (新)
  - procedure 加 `_computer_players: Array[RtsComputerPlayer]` + `attach_computer_player(team_id)` + tick 末调 `cp.think(world, current_tick)`
- **AC2** Build 决策 (place barracks @ ct 偏移点)
  - 每 30 tick 检查; ≥80g+50w 且 已建 barracks=0 → enqueue PlaceBuildingCommand
  - 左 team 偏移 Vector2(96, 0), 右 team Vector2(-96, 0)
  - placement 校验失败就跳过本轮(下个 1s 重试)
- **AC3** Attack 决策 (出 ≥3 non-worker unit 后 attack-move 一次)
  - decision tick + `_attack_dispatched=false` + alive non-worker ≥ 3 → enqueue MoveUnitsCommand 攻敌方 ct (`_attack_dispatched=true`)
- **AC4** `smoke_ai_vs_player_full_match.{gd,tscn}` PASS (中等强度)
  - 双方 5 worker + 1 ct + 1 gold + 1 wood node, starting {gold:100, wood:100}
  - 左 team attach AI, 右 team 哑巴(站桩)
  - 600 tick @ 30Hz; 验证 ai_barracks ≥1 + ai_units_spawned ≥3 + ai_unit_to_ct_attacks ≥1
- **AC5** demo_rts_frontend 双方都启 AI + F6 视觉验证
  - procedure setup 后 `attach_computer_player(0)` + `attach_computer_player(1)`
  - 起手 spawn 维持 M2.1 末态(5 worker + 1 ct + 4 中立 node / 方)
  - frontend smoke 不崩 (visualizers=10 alive_after_3.0s=10)
  - F6 视觉验证留给用户(双方 AI 起跑后, 各自采集 → 放 barracks → 出 unit → 攻 ct)
- **AC6** Validation 全套 0 行为漂移 (12 既有 smoke + 1 新 smoke = 13 项)
  - LGF 73/73 + smoke_rts_auto_battle 4v4 (ticks=347 attacks=74 melee=32 ranged=42 melee_max=24.00 bit-identical) + smoke_castle_war_minimal (ticks=193 left_win unit_to_building=4 archer_anti_air=1) + smoke_replay_bit_identical (frames=9 events=20 deep-equal) + 既有 smoke 数字与 M2.1 末态完全一致
  - 关键不漂移点: E10 决策 — procedure 默认不 attach AI; 既有 smoke 走"右侧不发 command 就死站"路径不变

## 收口动作 (6 AC PASS 后)

1. 创建 `archive/<YYYY-MM-DD>-rts-m2-2-ai-opponent/`(Summary.md / Current-State.md / Next-Steps.md / Progress.md / task-plan/)
2. 主 `Next-Steps.md` 切回"等待用户确认下一个 feature"
3. `task-plan/m2-roadmap.md` M2.2 status 标 ✅ done
4. 主 `Current-State.md` 更新为 M2.2 末态 baseline

## 下一步

**E.2 — Build 决策(barracks 1 cap, ct 偏移点)**

E.1 已收口 ✅(2026-05-02; sanity smoke 全过, 既有 12 项路径 0 漂移)

具体动作:
1. 在 `addons/logic-game-framework/example/rts-auto-battle/logic/ai/rts_computer_player.gd` 内实现 `_try_build_barracks(world, current_tick)`:
   - 查 procedure.get_team_resources(team_id) — 必须 ≥ {gold: 80, wood: 50}
   - 查己方 team 当前 barracks 数 — 走 world.get_alive_actors() 过滤 RtsBuildingActor + team_id == self.team_id + building_kind == BARRACKS; ≥ 1 直接 return
   - 找己方 ct (team_config.crystal_tower_id 拿 actor.position_2d); 没 ct → return
   - 计算 offset (左 +96, 右 -96) → enqueue PlaceBuildingCommand (tick_stamp = current_tick) 走 world.procedure.enqueue_player_command
   - placement 校验失败 (out of build_zone / cells_occupied) 走 PlaceBuildingCommand.apply 内部失败链路, 失败 → 下个 1s 决策再试 (天然 retry)
2. headless smoke sanity:
   - LGF 73/73 不退化(`/tmp/m22_e2_lgf.txt`)
   - smoke_rts_auto_battle 4v4 数字 bit-identical(`/tmp/m22_e2_main.txt`)
   - smoke_replay_bit_identical 数字 deep-equal(`/tmp/m22_e2_replay.txt`)
3. 都过后 commit (submodule 内 commit + 主仓 bump pointer)

## 非下一步

- ❌ 现在不写 Build 决策具体逻辑(在 E.2)
- ❌ 现在不写 Attack 决策具体逻辑(在 E.3)
- ❌ 现在不动 demo_rts_frontend(在 E.4)
- ❌ 现在不动 LGF submodule core / stdlib
- ❌ 现在不引入难度档位 / archer_tower 选择 / 兵种偏好(超出 M2.2 scope, 留给后续 sub-feature)
- ❌ 现在不动 worker harvest 路径(沿用 M2.1 的 RtsHarvestStrategy)
- ❌ 现在不动 project.godot autoload(M2.2 全程不预期)
