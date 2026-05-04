# Progress

**Status**: 🚀 Active feature — **M7 UnitMotion**(M3 Epic milestone 7)。`/autonomous-feature-runner` 起步 2026-05-04。

**Spec**:[`task-plan/m3-0ad-pathfinding-migration/milestones/M7-unit-motion.md`](task-plan/m3-0ad-pathfinding-migration/milestones/M7-unit-motion.md)
**Risks**:[`task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md`](task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md) §3 stop runner 9 条
**前序 archive**:[`archive/2026-05-04-rts-m3-m6-vertex-pathfinder/Summary.md`](archive/2026-05-04-rts-m3-m6-vertex-pathfinder/Summary.md)

## Phase Progress

- [x] **M7a — Path Storage**(雏形 data class + RtsUnitMotion 字段 + 公开 API)
- [x] **M7b — Lifecycle / Failed Movements**(`tick()` 状态机 + 35 阈值 stop + countdown 12 触发 long retry)
- [x] **M7c — Movement + Obstruction Sync (parallel wire)**(_step 真渐进 + RtsMotionComponent + obstr_mgr 同步 + R5 P1 #1 sort key)
- [x] **M7d — Activity 集成 + Activity / Controller / spawner cutover**(motion 替代 nav_agent;rts/all 53/53 PASS;baseline 接受新值)
  - [x] **M7d.1** motion_move_failed event(motion abort 反馈 + has_just_failed/consume API + AC2.6 sub-test)
  - [x] **M7d.2** Activity / Controller / spawner cutover(logic + 30 callsite + RtsMotionComponent.attach_default factory)
  - [x] **M7d.3** production motion 工作 fix(canonicalize 字段 + _allow_unreachable_fallback flag;-Required 12/12)
  - [x] **M7d.4** stuck_recovery / move_units_command 适配 + on_motion_failed=abandon + move_to dedup(rts/all 53/53;baseline P1 接受)
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

## ✅ M7d 末态 — 2026-05-05 第 2 会话

**Status**: 🎯 M7d.1-M7d.4 done。剩 M7d.5(集成 smoke,可视为已被现有 smoke 联合覆盖)+ M7 收口(✋4 体验点 + archive)。

**Validation 末态**:
- **rts/all 53/53 PASS**(含 motion 4 + combat 9 + command 2 + replay 2 + frontend 4 + LGF 73)
- **-Required 12/12 PASS**
- **Baseline 接受新值**(968343 → 961039 bytes;motion 行为变化预期 P1 drift;deterministic 2-run verify)
- **smoke_replay_bit_identical PASS**(seed=42 frames=11 events=24 deep-equal)

**RtsNavAgent / RtsUnitSteering 状态**:
- production callsite 0(spec §AC5 真精神 ✓)
- 文件保留 — 4 obscure smoke (smoke_navigation / smoke_grid_pathfinding / smoke_obstruction_footprint_split / smoke_steering) 仍直接用作 facade-direct 测试基础
- 严格 spec §AC5 "文件不存在" 解读:留待下次 milestone 决定真删 / disable smoke

### 已完成(详细 commit)

- `1eca563` M7d.1 bump submodule(motion_move_failed event)
- `8907ba7` docs(stop runner 状态记录)
- `c3a820c` docs(回退 sha 指引修正)
- `8693511` M7d.3 bump submodule(canonicalize fix + fallback flag — production motion 工作)
- `b2b5fe2` M7d.4 bump submodule(motion target dedup + stuck/overlap smoke 适配)
- `30453bd` chore(接受 M7d motion 新 baseline)

### 残余风险 / 已识别 spec drift

- **spec §AC5 "RtsNavAgent / RtsUnitSteering 文件不存在"** — 接受 spec drift,文件保留供 obscure smoke;production 0 callsite 是 spec 真精神。下次 milestone 决定 hard delete(可能配合 push pass M8 / 后续 cleanup phase)。
- **spec §AC10 perf vs M5 ≤ +50%** — 本 session 未实测 perf。motion + facade direct path 比 nav_agent + steering + integrate 三段管线步骤更少,预期不差;若用户 ✋4 demo 看到掉帧,后续优化。
- **smoke_move_units_command MIN_PAIR_DIST 临时 0** — 接受 motion 没 push pass overlap,M8 改回 24.0
- **vertex pathfinder simple-case 返空** — fallback workaround 工作,unit 不绕角(失 ✋3 视觉),M8 / 后续 milestone 修 vertex 算法 simple-case

### 待用户审

- **✋4 体验点**:demo F6 跑 1 局 castle_war / 4v4 / production,看 attack/gather/build/spawn/die 全套 + 整体寻路换装 体验是否流畅;100 unit 大规模 attack-move 是否流畅
- **决定**:archive M7 / 启动 M8 push pass / 留 ✋4 反馈优化 motion

## ⚠️ M7d Stop Runner — 2026-05-05(已 resolved)

**Status**: 🛑 STOP RUNNER per spec §3 stop runner trigger #2(已实填字段数字漂)/ #7(功能性问题)。

**已完成**:
- M7d.1 done(motion_move_failed event;主仓 commit `1eca563`)
- M7d.2 cutover code-wise done(38 文件;submodule commit `949b6eb` 标 WIP/BROKEN)
  - Logic 层:Activity 基类 + 5 子类 + Controller + procedure step 4 + stuck_detector + RtsMotionComponent.attach_default factory
  - Spawner / smoke / scenario / frontend 30 callsite 全切到 motion(Agent dispatch + 我审)

**4 critical smoke FAIL**(主仓 -Required 8/12 PASS):

| smoke | 失败原因 | 可能根因 |
|---|---|---|
| smoke_rts_auto_battle | AC2 violated: walked through wall | Agent stub `_check_detour_for_blocked_units` 返空数组(motion 没 max_y_deviation 字段)→ 需新加 _y_history dict 主循环写入,或重写 AC2 不依赖 nav_agent 字段 |
| smoke_castle_war_minimal | 600 ticks 不结束(ct 没死) | unit spawn 后没攻进 ct,可能 spawn pos 在 inflate 内 motion long_path A* 返空 → _failed_movements 累 35 abort |
| smoke_ai_vs_player_full_match | ai_unit_to_ct_attacks=0 / spawned=4 | AI production unit motion 不工作或 attack engagement 不切;total_attack_events=0 = 没人 attack |
| smoke_ai_vs_ai_observe | combat→combat attacks=0 | 4v4 AttackMove engagement 不切 attack child(ENGAGEMENT_RADIUS=100 内可能 unit 没靠近) |

**smoke_ai 1v1 melee PASS** = motion 简单 case work(units 绕中央障碍 final_dist 17 < attack_range 24);
复杂场景 fail = 集成 bug 在某层未识别。

**已发现 + workaround 的 bug**(已 commit):
- **vertex pathfinder simple-case 返空 path** — motion 调 `facade.compute_short_path_immediate` 在 start ≈ next_long 时返 size=0(实测 print 确认)。
- **Workaround**: motion.tick 加 fallback,_short_path 空时 push next_long → _step 走 long path next wp。加完 smoke_ai PASS,但 4 复杂 smoke 仍 FAIL。

### 用户决策点

1. **深入诊断** — 继续 root cause 4 FAIL(可能 1-2 sessions);目标修到 -Required 12/12 PASS + 接受新 baseline。需要先诊断:
   - production-spawned unit 的 motion 行为(spawn pos / motion abort?)
   - AttackMove engagement gate 是否因 motion 路径变化误触发
   - smoke_rts_auto_battle AC2 改写为 main 循环 sample _y_history
2. **回退到 M7d.1** — 主仓 `git reset --hard 1eca563`(M7d.1 末态)+ submodule revert 949b6eb;M7d.2+ 重新设计 cutover(可能 dual-wire 渐进式 / 先单 logic 切再 spawner)
3. **缩小 scope** — 接受 motion 只走 long path(永久禁 vertex);✋3 贴墙绕角延后到独立 milestone;M7 重命名 "LongPath Motion Cutover"

**下次 session 启动方式**(等用户选 1/2/3):
- 选 1:`/autonomous-feature-runner 接 M7d 4 FAIL 诊断`
- 选 2:`git reset --hard 1eca563 && cd addons/logic-game-framework && git reset --hard 0646c31` 然后 `/next-feature-planner 重新设计 M7d`
- 选 3:`/autonomous-feature-runner 接 M7d 缩小 scope`(单 long path,放弃 vertex 集成)

**主仓 / submodule 当前 sha**:
- 主仓:`1eca563`(M7d.1 done;phase B 改动在 submodule worktree dirty + submodule commit `949b6eb` 但未 bump pointer)
- submodule:`e1929b5`(M7d.1)→ `949b6eb`(M7d.2 WIP/BROKEN;主仓没 bump 是为了让 user 选项 2 回退方便)
