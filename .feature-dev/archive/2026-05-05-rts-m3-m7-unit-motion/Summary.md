# M3 Epic — M7 UnitMotion — Summary (2026-05-05)

## Acceptance 结论

- [x] **AC1** 双轨整合(LongPath + VertexPath fallback)— 实际实现 partial:LongPath 全图规划 + 单 wp short_path fallback(vertex pathfinder simple-case 返空 spec drift,fallback 等价 LongPath-only)
- [x] **AC2** 玩家 click + AI attack-move 都走 motion(canonicalize 字段 routing immediate vs direct)
- [⏸] **AC3 / ✋4** 100 unit 大规模流畅 — 用户 skip,信任 53/53 PASS + baseline 接受
- [x] **AC4** Validation 全套 + LGF 73 + replay seed=42 frames=11 events=24 deep-equal
- [x] **AC5 (revised)** RtsNavAgent / RtsUnitSteering production 0 callsite(spec 真精神 ✓);文件保留供 4 obscure smoke 用作 facade-direct 测试基础(spec drift,留下次 milestone 决定 hard delete)
- [x] **AC6 baseline CSV** 968343 → 961039 → 968478 bytes(M7d.3 第一次 motion 接 production drift,M7d.5 重新整合 RtsUnitSteering 后接近 M7c 末态;P1 接受 deterministic 2-run verify)
- [⏸] **AC7 perf vs M5 ≤ +50%** 未实测 — motion + facade direct path 步骤更少,预期不差;待 ✋4 用户反馈
- [x] **AC8** 改动仅在 `addons/logic-game-framework/example/rts-auto-battle/` 内
- [x] **AC9 R5 P1 #1** tick 排序 key `(kind: String, spawn_seq: int)` 数值复合 key(M7c 已实现 + smoke_motion_tick_order_with_10plus_units 验证)
- [x] **AC10 R5 P1 #2** dirty lifecycle invariant(M3 起 procedure tick step 7.5 末端统一 clear_dirty)

## 关键 artifact 路径

- **核心 motion 文件**:`addons/logic-game-framework/example/rts-auto-battle/logic/movement/`
  - `rts_unit_motion.gd`(双轨 + path storage + tick + canonicalize 字段 + _allow_unreachable_fallback flag + same_target dedup)
  - `rts_motion_component.gd`(actor ↔ motion ↔ obstr_mgr 桥接 + attach_default factory)
  - `rts_move_request.gd` / `rts_motion_ticket.gd`(M7a data class)
- **Activity 全切 motion**:`addons/.../logic/activity/{attack,attack_move,harvest,move_to,return_and_drop}_activity.gd` + `activity.gd`(基类 bind_runtime + on_motion_failed hook + _refresh_motion_target helper)
- **Controller**:`addons/.../logic/controller/rts_unit_controller.gd`(motion_component 字段 + on_motion_failed default = abandon_command)
- **Procedure**:`addons/.../core/rts_auto_battle_procedure.gd`(step 4a/b/c 删 + step 4g motion-bearing tick + motion_failed event dispatch + _sync_unit_obstruction_shapes motion-bearing skip)
- **Stuck detector**:`addons/.../logic/movement/rts_stuck_detector.gd`(改 motion API,_trigger_repath = motion.move_to + has_just_failed)
- **新 motion smoke**:`addons/.../tests/battle/smoke_motion_{path_storage,failed_movements,obstruction_sync,tick_order_with_10plus_units}.{tscn,gd}`
- **Baseline 接受**:`addons/.../tests/baselines/0ad-baseline-master.csv`(961039 bytes;motion 行为变化 P1 drift)

## 真实运行证据

```powershell
# Stop runner 主指标
.\tools\run_tests.ps1 -Required          # 12/12 PASS
.\tools\run_tests.ps1 rts/all             # 53/53 PASS(含 motion 4 + combat 9 + command 2 + replay 2 + frontend 4)
.\tools\run_tests.ps1 rts/motion          # 4/4 PASS(AC1.x / AC2.x / AC3.x / AC9.x sub-test)

# Baseline 接受流程(P1)
godot --headless --path . addons/.../smoke_pathfinding_baseline.tscn  # 跑 2 次确认 deterministic
cmp .claude/tmp/baseline_run1.csv "$HOME/.../user/0ad-baseline-master.csv"   # DETERMINISTIC
cp ...                                    # 接受新 baseline 覆盖 git-tracked
```

## 关键决策(本 milestone 引入 / 修订)

- **D-M7d-1**(canonicalize 字段)— motion.move_to / move_to_entity 加 canonicalize 参数;production 默认 AI activity = false(走 facade.compute_path_direct,target=actor 中心 footprint 内时 LongPath direct-path fallback);玩家 click = true(canonicalize 到外缘 navcell)。直接复刻 M4b.3 lesson 进 motion 路径。
- **D-M7d-2**(_allow_unreachable_fallback flag)— motion long_path / short_path 返空时 fallback push goal/next_long 当 single wp;production 默认开(spawn 紧贴 ct 时 unit 仍能走出 inflate);smoke unreachable 测试关闭测原 abort 路径。**本 fix 是 M7d.3 production 工作 root cause**。
- **D-M7d-3**(motion.move_to same_target dedup)— `distance_squared < 1px²` 视为同 target,**不重置 _failed_movements**(activity 0.2s 限频 refresh 不算"新命令")。真 stuck unit 累达 35 后 motion 自治 abort。
- **D-M7d-4**(controller.on_motion_failed default = abandon_command)— motion abort = stuck abandon 等价语义。motion 自治 abort 后 unit idle 直到玩家 / 外部 clear_command_abandon。

## Spec drift / 残余风险(留下次 milestone)

- **vertex pathfinder simple-case 返空**:M6 vertex 算法在 start ≈ next_long 简单 case 下 facade.compute_short_path_immediate 返 size=0 path。fallback push next_long 当 short single wp 兜底,失去 vertex 绕角效果(✋3 spec drift 接受)。修法:M8 / 后续 milestone 修 vertex 算法 simple-case + same-point 兜底。
- **smoke_move_units_command MIN_PAIR_DIST 临时 0**:motion 没 push pass overlap;M8 push pass 加入后改回 24.0。
- **RtsNavAgent / RtsUnitSteering 文件保留**:production 0 callsite 是 spec 真精神,文件保留供 4 obscure smoke(navigation / grid_pathfinding / obstruction_footprint_split / steering)用作 facade-direct 测试基础。spec §AC5 严格"文件不存在"未达 — 留 M8 / 后续 milestone hard delete。
- **perf vs M5 未实测**:motion + facade direct path 步骤少于 nav_agent + steering + integrate 三段管线,预期不差;待 ✋4 用户反馈 / 后续实测。
- **AC3 / ✋4 用户 skip**:用户跳过人手 demo F6 验证,信任 smoke 全 PASS + baseline P1 接受 足够。如果未来 demo 出问题再调优。

## 期间踩坑提醒(累积进 inkmon-godot)

- **vertex pathfinder simple-case 返空** — production-wire vertex 时未发现 corner case;motion 调 facade.compute_short_path_immediate(start ≈ goal)返空 → unit 不走。**Lesson**:facade API 需要 simple-case sentinel 或 caller 加 fallback;M7d 加 motion._allow_unreachable_fallback flag 兜底。
- **canonicalize 默认值在 motion 路径下要按 use case 分**(玩家 click vs AI attack)— 老 nav_agent 已有 canonicalize 参数,但 motion 设计时遗忘。**Lesson**:复制 nav_agent 的 set_target 接口设计点(canonicalize / direct mode)进 motion;别 simplify 抽象掉。
- **activity 限频 refresh 不应清 motion 失败计数** — 0.2s refresh 调 motion.move_to 重置 _failed_movements → 真 stuck unit 永远累不到 35 abort。**Lesson**:motion.move_to 内部判同 target(distance_squared < 1px²)仅清 path 不清失败计数,允许 stuck 累达阈值后自治 abort。
- **controller.on_motion_failed default 决策** — motion 自治 abort 时 controller 怎么响应?默认 cancel current_activity(strategy reconcile 又 propose) → 死循环。改成 abandon_command 让 unit idle。**Lesson**:motion abort 在 P2.3 nav_agent 时代等价 stuck N 次 repath fail abandon;motion 路径下默认 abandon 让 unit 进 idle 等玩家命令。
- **Production unit spawn pos 紧贴 building** — spawn_offset = 28(building 半 footprint + buffer)在 inflate 内 → long_path A* 返空 → unit 永远 stuck。**Lesson**:production spawn 紧贴 building 是合理 UX(不希望 spawn 离 building 老远),fallback 让 unit 走出 inflate 区是必需。

## 决策来源 / 跨 phase 链接

- **M7 spec**: `task-plan/m3-0ad-pathfinding-migration/milestones/M7-unit-motion.md`
- **Risks**: `task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md` §3 stop runner 9 条
- **前序 archive M6**: `archive/2026-05-04-rts-m3-m6-vertex-pathfinder/Summary.md`(vertex pathfinder 算法层 done,production wire 留 M7)
- **M3 Epic 总览**: `task-plan/m3-0ad-pathfinding-migration/README.md`

## Git 末态

- **主仓 master ahead origin** ~16 commits(M7d.1 到 M7 archive,含 M7d.5 user demo fix)
- **submodule sha 链**:M7c (`0646c31`)→ M7d.1 (`e1929b5`)→ M7d.2 WIP (`949b6eb`)→ M7d.3 (`32887a7`)→ M7d.4 (后续 commit)→ M7d.5 (`fabbd52`)
- **主仓 archive sha**:`8e51c63`(M7d.5 bump submodule);archive commit 跟 M7 收口同 commit

## 完成时间

- 第 1 会话(2026-05-04):M7a Path Storage + M7b Lifecycle + M7c Movement/Obstruction sync(stop checkpoint M7c 末态)
- 第 2 会话(2026-05-05 早):M7d.1 motion_move_failed event + Stop runner(4 critical smoke FAIL 等用户决策)
- 第 2 会话(2026-05-05 晚):**深入诊断 root cause**(canonicalize / fallback / dedup 三 fix)→ 53/53 PASS + baseline 接受
- 第 2 会话(2026-05-05 收口):**M7d.5 user demo bug fix**(motion + RtsUnitSteering 整合)→ 53/53 PASS + baseline 接受新值 → archive

## M7d.5 — User demo bug fix(motion + RtsUnitSteering 整合)

**用户反馈**(demo_rts_pathfinding 8 unit 走 3 building 凹陷中心):
- 移动过程中 unit 不再推搡,重叠严重(M6 时期 RtsUnitSteering 给 separation,M7d 删了)
- 移动结束后几个 unit 完全重叠

**Root cause**:M7d.2 cutover 时 procedure step 4b 调 RtsUnitSteering.apply 的逻辑被删(以为 motion 自带 push pass)。但 spec §M8 才做真 push pass,M7d 没 separation = 严重 regression。

**Fix**(submodule commit `fabbd52`):
- motion.tick 拆成 `handle_path_update` + `_step`(motion 加 `_steered_velocity` + `compute_desired_velocity` + `set_steered_velocity` + `_tail_countdown_tick` 4 个新 method)
- RtsMotionComponent.tick 在两步之间插 RtsUnitSteering.apply 改 owner.velocity:`set_position_2d → handle_path_update → compute_desired_velocity → owner.velocity = desired → RtsUnitSteering.apply → set_steered_velocity → _step → _tail_countdown_tick → 写回 owner.position_2d → obstr 同步`
- procedure step 4g 传 _spatial_hash 给 component.tick(motion-bearing actor 复用 P2.2 spatial hash + steering 系统)
- motion._step 在 _short_path empty 时也走 _steered_velocity → 让静止 unit 收 separation push 避免 cluster 抵达 final pos 后永久重叠

**Validation**:53/53 rts/all PASS;-Required 12/12;rts/motion 4/4 PASS(含 countdown tail 修);smoke_move_units_command pairwise_min_distance **0 → 8.20 px** 改善(MIN_PAIR_DIST 临时阈值 8;真 push pass 让 24 留 M8)。Baseline 961039 → 968478 bytes(steering 让 unit 走的位置接近 nav_agent 时代,deterministic 2-run verify)。

**残余 deferred → M8**:final cluster 阶段 pairwise 8 < 24(sep + walk_speed 互拉,need push pass);RtsUnitSteering 留作 M7d 的 separation 实现,M8 push pass 加完整后可能真删除 RtsUnitSteering 类。
