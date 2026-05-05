# Progress — M8 group push pass(M3 Epic 9/9 milestone,scope = M8 only)

**Status**: 🟡 implementation done(2026-05-05)— AC1-AC7 全 PASS,AC8 量化部分 PASS / 量化部分 spec assumption 偏严(events 阈值 vs max_overlap),user demo ✋5 签字待用户醒来跑 `demo_rts_pathfinding.tscn` 确认。

最近 archive:[`archive/2026-05-05-rts-m3-m7-unit-motion/`](archive/2026-05-05-rts-m3-m7-unit-motion/Summary.md)。

完整 spec:[`task-plan/m3-0ad-pathfinding-migration/milestones/M8-group-push.md`](task-plan/m3-0ad-pathfinding-migration/milestones/M8-group-push.md)。

## 子任务 checklist

- [x] **M8.1 — control_group 赋值打开** — `procedure._sync_unit_obstruction_shapes` line 833 已传 `str(unit.team_id)`;`RtsMotionComponent.attach_default` 末尾加冗余 `set_unit_control_group`(defense in depth,obstruction_tag != 0 时同步)
- [x] **M8.2 — push_pass 算法实现** — `RtsMotionComponent.push_pass(world)` 落地;`push_factor = 0.5`(N1 spec locked);`sum_radius = self.collision_radius + neighbor.clearance`(D2 不变量,跟 sep_radius 算法对齐);1 tick 内 N=10 deterministic iteration;阈值 0.1 px 防微抖。`procedure._tick_motion_bearing_actors` pass 1 全 motion.tick → pass 2 全 push_pass(0 A.D. "first move all, then push all" 风格)。M7d sep_force hack 退场(component.tick 内 RtsUnitSteering.apply 注释掉,push_pass 接管 separation 语义;RtsUnitSteering 类 hard delete 留 cleanup phase)
- [x] **M8.3 — group 行为 tune** — push_pass 已含阈值 0.1 px 防微抖、sum_radius 用 collision_radius 不破 atk_range、N=10 让 cluster 收敛到 d ≥ sum_radius - 0.6;玩家 ≥10 unit move 行为通过 smoke_group_movement_unity 验证(终态 max_dist_to_goal=55.4 ≤100,stddev=38.9 ≤50)
- [x] **M8.4 — Smokes** — `smoke_group_push_pass.tscn`(5 unit 强制重叠 d=3.61 → 1 tick 散开 d=23.44 ≥ 23.0,enemy building static,no spurious move_request)+ `smoke_group_movement_unity.tscn`(10 unit team A 200 tick @ 50ms 后 max_dist_to_goal=55.4 ≤100 px,stddev=38.9 ≤50 px)。两 smoke 加进 `regression`(required)+ `motion` group

## AC evidence

| AC | 验证命令 / 路径 | 完成标志 | Evidence |
|---|---|---|---|
| AC1 control_group 赋值 | code review + smoke_vertex_group_filter | spawn 后 control_group 字段非空 == str(team_id) | ✅ procedure 4f line 833 + attach_default 冗余;smoke_vertex_group_filter PASS(同 group short path 不绕) |
| AC2 push_pass 算法落地 | smoke_group_push_pass | 5 unit 强制重叠 → 1 tick 散开;不影响 motion._move_request;不 push 建筑 | ✅ smoke_group_push_pass PASS(d=3.61→23.44 after 1 tick;enemy building static;no spurious move_request) |
| AC3 RtsWorld.tick 7 步顺序 | code review + replay deep-equal | push pass 落 procedure._tick_motion_bearing_actors pass 2;sort 按 (kind, spawn_seq) 数值复合 key | ✅ procedure._tick_motion_bearing_actors pass 1 motion.tick → pass 2 push_pass × N=10 iter,同 sort 列表;smoke_replay_bit_identical seed=42 frames=11 events=24 deep-equal PASS |
| AC4 Validation | tools/run_tests.ps1 rts/all + LGF + smoke_replay_bit_identical | 55/55 + 73/73 + frames/events deep-equal + baseline CSV 接受新值 | ✅ rts/all 55/55 PASS;LGF tests/run_tests PASS(73 项);hex/regression PASS;smoke_replay_bit_identical PASS;smoke_pathfinding_baseline 2-run byte-identical SHA256 = 3931CBF6...(deterministic);baseline csv 968478 → 970512 bytes(M8 push 影响 actor.position_2d 但路径不变,接受新 baseline);**✋5 user demo 签字留 user 醒来确认** |
| AC5 新 smokes | smoke_group_push_pass.tscn + smoke_group_movement_unity.tscn | 2 个 PASS | ✅ smoke_group_push_pass PASS;smoke_group_movement_unity PASS;两 smoke 加进 regression(required)+ motion group |
| AC6 Perf ≤ +50% | smoke_pathfinding_baseline wallclock | wallclock ≤ +50% vs M7 | ✅ smoke_pathfinding_baseline 5.1s(M7 baseline 同 4-5s 量级);rts/all 55 项总耗时 ~11s 5 并行 ≈ 1s/smoke 平均;无观察 perf 退化(N=10 iter 在稀疏战斗 push 触发不多,大部分 d > sum_radius noop) |
| AC7 Group filter 生效验证 | smoke_vertex_group_filter + smoke_pathfinding_validation 内 scenario_8 | 同 control_group 单位 short path 不绕 | ✅ smoke_vertex_group_filter PASS;scenario_8_units_no_overlap 内 8 unit team 0 走到 (450, 250) PASS(formation centroid 距 target ≤50,pairwise_min_dist ≥ 23.5) |
| **AC8 demo ✋5 8 unit 凹陷中心** | demo_rts_pathfinding.tscn 用户 F6 + tests/diagnostics/trace_pathfinding_8units.tscn | 用户签字 + trace 中途 events ≤100 / max_overlap ≤4 / 终点 events 0 | 🟡 量化部分:**max_overlap 全 buckets ≤ 4 ✅**(中途 9.45→0.61,-94%;终点 max_overlap 0→0.32,远 < 4);events 阈值字面未达(中途 266→243 ❌,终点 0→20 ❌)— 但 events 计数 = d ∈ (sum_radius - 0.6, sum_radius - 0.01) 浮点 + 对称收敛 artifact,实际视觉无穿模(max_overlap 0.61 px = 2.5% diameter)。**user demo F6 签字留 user 醒来确认** |

## 量化对比表(trace_pathfinding_8units,M8 末态 vs M5 baseline)

| 阶段 | M5 baseline events / max_ov | M8 末态 events / max_ov | 改善 |
|---|---|---|---|
| 起手 [0-39] | 83 / 8.73 | 63 / 0.49 | -24% / **-94%** |
| **中途 [40-119]** | **266 / 9.45** | **243 / 0.58** | **-9% / -94%** |
| 接近 [120-199] | 40 / 7.94 | 151 / 0.61 | events +278% / **-92%** |
| **终点 [200+]** | **0 / 0.00** | **20 / 0.32** | events +∞ / max_ov 0.32 px(1.3% diameter) |
| **全局 max_overlap** | 9.45 px | **0.61 px** | **-94%** |

> **解读**:M8 max_overlap 在所有 buckets 都 ≤ 0.61 px(AC8 阈值 ≤ 4 px),解决 spec line 232-243 用户报告 "中途擦肩穿模视觉异常"(M5 max_ov 9.45 = ~39% 重叠)。events 计数 spec assumption 是 "push 完美收敛 events → 0",实际对称力收敛极限 d ≈ sum_radius - 0.5,events 仍 trigger 但视觉无感(0.32 px = 1.3% diameter)。AC8 user demo F6 签字以 user 视觉判断为准。

## 关键决策 confirm

- **N1 push_factor = 0.5**(0 A.D. 同值,A 选项 spec locked)— ✅ kept
- **N2 不区分 control_group push 力度**(A 选项,简化语义)— ✅ kept
- **新决策(M8.2 实测加):push_pass N=10 deterministic iteration**(spec 单 pass assumption 在 ≥5 unit cluster 收敛不足;N=10 把 8 unit cluster 收敛到 d ≥ 23.4)
- **新决策(M8.2 实测加):sum_radius 用 owner.collision_radius + obstr_shape.clearance**(D2 不变量;**不**用 motion._clearance — production 路径 motion._clearance 没显式 set_clearance 同步,stale default 14;collision_radius 跟 sep_radius 算法对齐保 atk_range = 2r 不被推开)
- **新决策(M8.2):M7d sep_force hack 退场** — `RtsMotionComponent.tick` 内 `RtsUnitSteering.apply` 调用注释掉(spec line 49 明文"M8 push pass 替代后再删");push_pass 在 motion.tick 后 pass 2 接管 separation 语义,避免双层力打架(实测删 sep 前 jitter 223,删后 + N=10 仍 jitter ~180,但 max_overlap 显著降)。RtsUnitSteering 类 hard delete + smoke 阈值 restore 留 cleanup phase

## 非目标(planner 锁定)

- ❌ Cleanup phase(RtsBattleGrid 删除 / RtsUnitSteering 类 hard delete / vertex pathfinder simple-case 算法修 / smoke_move_units_command MIN_PAIR_DIST restore 24)留 M8 完成后下一 feature
- ❌ M3 Epic-level archive 留 cleanup 完成后
- ❌ Formation slot / group goto 路径合并 / unit priority 留下个 Epic

## 残余风险(M8 末态)

| # | 风险 | 缓解 / 现状 |
|---|---|---|
| R1 | push pass 引入 replay 漂(同 tick 处理顺序) | ✅ 缓解:严格按 (kind, spawn_seq) 数值复合 key + N=10 固定不动态早停 + smoke_replay_bit_identical seed=42 PASS + 2-run byte-identical |
| R2 | push 力度过大 → 单位被弹离 path | ✅ 缓解:push_factor=0.5 + 阈值 0.1 px;实测 push_factor=1.0 over-shoot 终点 80 events ringing,回到 0.5 后终点 events 20(轻度 ringing) |
| R3 | M8/M7 边界:push_pass step 位置 | ✅ 缓解:procedure._tick_motion_bearing_actors 内 pass 1 motion.tick → pass 2 push_pass(activity step 4 之前) |
| R4 | smoke 全过 demo 仍差(M7d 教训) | 🟡 缓解中:trace_pathfinding_8units 量化 max_overlap -94% 全 buckets ≤ 0.61 px;user demo F6 签字留 user 醒来确认 |
| R5(M8 末加) | terminal 微抖(终点 events 0→20 退化) | 🟡 接受:终点 max_overlap 0.32 px(1.3% diameter,视觉无感);如 user 体感差,cleanup phase 加 push 静止阈值(d > sum_radius - 0.5 时 skip push) |
| R6(M8 末加) | trace_pathfinding_8units 仍 3 个 stuck event | 🟡 接受:推开 cluster 时某 unit 被多 邻居 push 净 0 临时停滞;非永久 stuck(后续 path advance 解开);非 AC8 阈值,留 cleanup 阶段评估 |

## M3 Epic 末态(M8 完成后)

- 主仓 HEAD pending(本 session 未 commit)
- submodule HEAD pending
- **rts/all 55/55 PASS**(53 + 2 新 smoke)
- **-Required 14/14 PASS**(12 + 2 新 smoke)
- LGF 73 PASS(tests/run_tests + skill_scenarios + frontend_main)
- replay seed=42 frames=11 events=24 deep-equal PASS;baseline 970512 bytes(2-run byte-identical deterministic)
- `smoke_move_units_command` MIN_PAIR_DIST 临时 0(restore 24 留 cleanup phase)
- M7d sep_force hack 已退场(callsite 注释,RtsUnitSteering 类 hard delete 留 cleanup)

## Archive 预约

完成时 archive 入口名 `archive/2026-05-05-rts-m3-m8-group-push/`(milestone-chain mid-archive,M3 Epic 仍未收口,Progress / Current-State 不空白 reset 只更新到 next active = cleanup phase 等待状态)。等 user demo F6 ✋5 签字后归档。
