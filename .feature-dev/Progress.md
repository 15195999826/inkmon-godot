# Progress

**Status**: 🚀 Active feature — **M7 UnitMotion**(M3 Epic milestone 7)。`/autonomous-feature-runner` 起步 2026-05-04。

**Spec**:[`task-plan/m3-0ad-pathfinding-migration/milestones/M7-unit-motion.md`](task-plan/m3-0ad-pathfinding-migration/milestones/M7-unit-motion.md)
**Risks**:[`task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md`](task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md) §3 stop runner 9 条
**前序 archive**:[`archive/2026-05-04-rts-m3-m6-vertex-pathfinder/Summary.md`](archive/2026-05-04-rts-m3-m6-vertex-pathfinder/Summary.md)

## Phase Progress

- [x] **M7a — Path Storage**(雏形 data class + RtsUnitMotion 字段 + 公开 API)
- [x] **M7b — Lifecycle / Failed Movements**(`tick()` 状态机 + 35 阈值 stop + countdown 12 触发 long retry)
- [x] **M7c — Movement + Obstruction Sync (parallel wire)**(_step 真渐进 + RtsMotionComponent + obstr_mgr 同步 + R5 P1 #1 sort key)
- [ ] M7d — Activity 集成 + 删除 RtsNavAgent / RtsUnitSteering(RtsActivity 全迁 motion API + emit MoveFailed 事件)
  - [x] **M7d.1 — motion_move_failed event** (motion abort 反馈 + has_just_failed/consume API + RtsBattleEvents factory + RtsMotionComponent emit;AC2.6 sub-test 加入 smoke_motion_failed_movements)
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

**M7a smoke**:`PASS - motion_path_storage — AC1.1-AC1.5 all OK`

## M7b Evidence

**修改**(submodule):
- `logic/movement/rts_unit_motion.gd`(+200 行):tick / _path_update_needed /
  _request_long_path / _request_short_path / _request_short_path_to /
  _do_short_path / _make_path_goal_from_request / _resolve_pass_mask /
  _alloc_ticket(static counter)/ _step(M7b stub)+ _position_2d mirror + set/get
- `tests/test_groups.json` motion group 加 failed_movements smoke

**新增**:`tests/battle/smoke_motion_failed_movements.{tscn,gd}`(5 sub-test 覆盖 AC2.1-2.5)

**M7b smoke**:`PASS - motion_failed_movements — AC2.1-2.5 all OK`

## M7c Evidence

**修改**(submodule):
- `logic/rts_battle_actor.gd`(+spawn_seq + motion_component 字段)
- `logic/movement/rts_unit_motion.gd`(_step 真渐进 + ARRIVAL_THRESHOLD=4 常量)
- `core/rts_auto_battle_procedure.gd`(+step 4g 加 motion-bearing actor sort + tick + _compare_motion_actor static helper)
- `tests/battle/smoke_motion_failed_movements.gd`(修 countdown test 让 _walk_speed 大 trigger pop)
- `tests/test_groups.json`(motion group 加 2 新 smoke)

**新增**:
- `logic/movement/rts_motion_component.gd`(component 桥接 actor ↔ motion ↔ obstr_mgr)
- `tests/battle/smoke_motion_obstruction_sync.{tscn,gd}`(AC3.1-3.4 actor / obstr_shape 同步 + clearance)
- `tests/battle/smoke_motion_tick_order_with_10plus_units.{tscn,gd}`(AC9.1-9.4 R5 P1 #1 数值序)

**M7c smoke**:
- `PASS - motion_obstruction_sync — AC3.1-3.4 all OK`
- `PASS - motion_tick_order_with_10plus_units — AC9.1-9.4 (R5 P1 #1) all OK`

**Scope 拆分决策**(用户授权):**M7c.4 删除 RtsNavAgent / RtsUnitSteering 推到 M7d**(activity 切 motion API 之前不能删)。M7c 末态:NavAgent / Steering 仍在 production 路径,motion-bearing actor 集合实测空 → baseline / replay 0 漂(实测 -Required 12/12)。

## Validation 累计(M7a + M7b + M7c)

**Stop runner 核心 9 条**(每 sub-phase 末跑):
```
PASS 12 / FAIL 0 / TIMEOUT 0  (total 12)
- LGF 73/73 / replay seed=42 frames=11 events=24 deep-equal
- baseline CSV byte-identical 968343 bytes
- 主要 RTS smoke(rts_auto_battle / castle_war / ai_vs_player / pathfinding_*)
- frontend smoke (hex + rts)
```

**Stop runner 9 条状态**:全 clear。M7b 仍不接 production,production callsite
(activity / nav_agent)还走旧 RtsNavAgent → baseline / replay 不应漂(实测 0 漂)。

## 残余风险 / 下一步关注

- M7d:RtsActivity 子类(MoveTo / Attack / Gather / Build / ReturnAndDrop / AttackMove / Idle)逐个切 motion API,`_create_unit` spawner 设 actor.motion_component;现有 RtsNavAgent 调用 sites ~49 个文件(5 logic / 16 smoke / frontend)需逐一替换或并行 dual-wire
- M7d 末删除 RtsNavAgent + RtsUnitSteering(destructive)
- M7d 接 production 后 baseline CSV 漂(short_path 字段从占位 -1 变实填 + 路径形状变化 — P1 接受新 baseline)
- M7d 触发 ✋3(M6 deferred:VertexPathfinder 进 production tick + 贴墙绕角)+ ✋4(完整 demo 1 局 流畅)
- Perf 实测(100 unit × 30 Hz)— spec AC10 允许 ≤ +50% vs M5;tick_p99 / tick_max 监控
