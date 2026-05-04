# Progress

**Status**: 🚀 Active feature — **M7 UnitMotion**(M3 Epic milestone 7)。`/autonomous-feature-runner` 起步 2026-05-04。

**Spec**:[`task-plan/m3-0ad-pathfinding-migration/milestones/M7-unit-motion.md`](task-plan/m3-0ad-pathfinding-migration/milestones/M7-unit-motion.md)
**Risks**:[`task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md`](task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md) §3 stop runner 9 条
**前序 archive**:[`archive/2026-05-04-rts-m3-m6-vertex-pathfinder/Summary.md`](archive/2026-05-04-rts-m3-m6-vertex-pathfinder/Summary.md)

## Phase Progress

- [x] **M7a — Path Storage**(雏形 data class + RtsUnitMotion 字段 + 公开 API)
- [ ] M7b — Lifecycle / Failed Movements(`tick()` 状态机 + `_failed_movements` 累计 + countdown 触发 long retry)
- [ ] M7c — Movement + Obstruction Sync(`_step()` per tick + move_shape + set_unit_moving_flag + RtsWorld.tick 6 步顺序 + 删除 RtsNavAgent / RtsUnitSteering)
- [ ] M7d — Activity 集成(RtsActivity 全迁 motion API + emit MoveFailed 事件)
- [ ] M7 收口(Validation 全套 + ✋4 体验点 + archive + clean-slate sweep)

## M7a Evidence

**新增文件**(submodule `addons/logic-game-framework/example/rts-auto-battle/`):
- `logic/movement/rts_move_request.gd`(NONE / POINT / ENTITY / OFFSET 4 type + 工厂)
- `logic/movement/rts_motion_ticket.gd`(SHORT_PATH / LONG_PATH 2 type + is_active / clear)
- `logic/movement/rts_unit_motion.gd`(雏形 ~180 行;字段 + move_to / move_to_entity / move_with_offset / stop / has_target / get/set_clearance;tick / step 留 M7b/c)
- `tests/battle/smoke_motion_path_storage.{tscn,gd}`(9 sub-test 覆盖 AC1.1-AC1.5)
- `tests/test_groups.json` 加 `motion` group

**Tooling fix**(主仓):
- `tools/run_tests.ps1` Start-Process .bat 在 PS 7+ Windows 拿不到 `Process.ExitCode` race 修复 — .bat 末尾 `(echo __GODOT_EXIT_CODE=%ERRORLEVEL%)>> log` 写到 log,launcher 解析

**M7a smoke**:
```
PASS - motion_path_storage — AC1.1-AC1.5 all OK
```

**Validation -Required**(stop runner 核心 9 条):
```
PASS 12 / FAIL 0 / TIMEOUT 0  (total 12)
- battle/smoke_castle_war_minimal       PASS
- battle/smoke_rts_auto_battle          PASS
- tests/run_tests                       PASS  (LGF 73/73)
- battle/smoke_skill_scenarios          PASS
- frontend/smoke_frontend_main          PASS  (×2 hex+rts)
- battle/smoke_ai_vs_player_full_match  PASS
- battle/smoke_long_pathfinder_determinism PASS
- battle/smoke_ai_vs_ai_observe         PASS
- battle/smoke_pathfinding_baseline     PASS  (CSV byte-identical 968343 bytes)
- battle/smoke_hierarchical_unreachable PASS
- replay/smoke_replay_bit_identical     PASS  (seed=42 frames=11 events=24 deep-equal)
```

**Stop runner 9 条状态**:全 clear(M7a 是纯 data class 雏形,不接 production,baseline / replay 不应漂 — 实测 0 漂)

## 残余风险 / 下一步关注

- M7b 接 `tick()` 状态机,引入 `_failed_movements` 累计 + countdown — 仍不接 production,baseline 不漂
- M7c 引入 `(kind, spawn_seq)` actor sort key(R5 P1 #1)+ `RtsWorld.tick` 6 步顺序调整 — **R5 P1 #1 stop runner 触发条件高风险**,需要 `smoke_motion_tick_order_with_10plus_units` 验 ≥ 10 unit 数值序而非字典序
- M7c 末删除 RtsNavAgent / RtsUnitSteering destructive,activity 全切走前不能删
- M7d Activity 全迁 + baseline CSV `short_path_*` 字段从占位变实填(P1 接受新 baseline;真正"漂"在 M7d production wire 后)
