# Next Steps — 2026-05-04 (M6a + M6b done;M6c 待启动)

## 当前目标

🚧 **M6 milestone 进行中** — M6a + M6b **done 2026-05-04**(submodule commits `d4eda45` + `c458bee`),下一步推 **M6c** dynamic units + group filter + facade wire + prototype 退役 + ✋3 体验点。M6c 是 M6 milestone 末端,完成后 archive + 等 ✋3 用户审 → M7。

> **M3 Epic 进度**: M0+M1+M2+M3+M4+M5 archived + M6a + M6b done(sub-phase),6.66/9 milestone。剩余 M6c → M7 (UnitMotion) / M8 (Group Push) + EPIC 末 cleanup phase。
> Epic 总览 [`task-plan/m3-0ad-pathfinding-migration/README.md`](task-plan/m3-0ad-pathfinding-migration/README.md)。

**M6b 末态(M6c 出发点)**:
- vertex pathfinder 算法层 7 details 全到位(M6c 加 #7 #8 dynamic units / group filter):
  - #1 search bounds toward goal shift / #2 range boundary / #3 virtual goal CIRCLE/SQUARE/INVERTED 几何 / #4 terrain edges / #5 lazy visibility / #6 best-so-far fallback / #9 tie-break deterministic
- segment-vs-OBB 精确化:Liang-Barsky 精确测相交 + 不相交时 endpoint/corner-to-segment 取 min;精度 ≤ 1 IEEE ulp(替代 t-stepping 100 sample);保留 enclose-radius 早出 + axis-aligned fast-path
- M6b smoke_vertex_virtual_goal 7 sub-test PASS;M6a smoke_vertex_static_obb 8 sub-test 仍 PASS(best-so-far + Liang-Barsky 不破坏 M6a 行为)
- M6a/b 仍不接 facade / production:0 baseline 漂移 + tick_p99 / tick_max 不变;M6c.4 facade.compute_short_path_immediate wire 后预期 baseline 漂(short_path_size / short_path_wp_json 字段从占位变实填)
- Validation:-Required 12/12 + rts/pathfinding 14/14 PASS;LGF 73 + replay seed=42 deep-equal + baseline CSV byte-identical;9 条 stop runner 全 clear

## 下一步

**M6c — Dynamic Units + Group Filter + Facade Wire + Prototype 退役**(完整 spec [`M6-vertex-pathfinder.md §M6c`](task-plan/m3-0ad-pathfinding-migration/milestones/M6-vertex-pathfinder.md#m6c--dynamic-units--group-filter--prototype-退役-15-周))。

M6c sub-phase 子任务(spec §M6c.1-6):
1. **Moving unit square proxy(detail #7)** — 圆形 obstruction 在 visibility graph 中近似 AABB 4 角作 vertex(0 A.D. 简化,避免几何 bug);visibility 测试时 unit 仍当圆处理(`_segment_to_point_dist` 模式)
2. **Group filter(detail #8)** — 同 control_group obstruction 跳过(队伍内不互相挡);RtsShortPathRequest.control_group 字段已落地(M6a),M6c 启用 filter 逻辑
3. **avoid_moving_units 开关** — false 时 MOVING flag 单位不算障碍(让"挤过"队伍)
4. **facade.compute_short_path_immediate wire** — RtsPathfinderFacade 加 API,production 可调;此时**baseline 预期漂**(short path 字段从占位变实填)
5. **smoke_vertex_corner_walking + smoke_vertex_group_filter** — 验证贴墙绕角自然 + 同 group 不互相挡
6. **Prototype 退役 R6** — 删 `tests/prototype/proto_vertex_obb.{gd,tscn,gd.uid}` + 跑 grep 确认 RtsVertexPathfinder 内无 prototype-only 简化分支

M6c 收口后 → ✋3 体验点 demo F6 验证 + 等用户审 → milestone-chain 触发 → archive M6 → 启动 M7 UnitMotion。

## 验收准则

M6 完整 AC 见 [`M6-vertex-pathfinder.md §3`](task-plan/m3-0ad-pathfinding-migration/milestones/M6-vertex-pathfinder.md#3-验收准则-m6-总);M6c sub-phase 关键过线:

### M6c 关键过线条件

- ✅ **AC1.7** moving unit square proxy:visibility graph 加 unit AABB 4 corner vertex,visibility check segment-to-point 圆模式
- ✅ **AC1.8** group filter:`req.control_group == ""` 跳过 filter;非空时同 group obstruction 不算障碍
- ✅ **AC10** ✋3 体验点 demo F6 验证(用户最终判)
- ✅ **AC11(完整)** baseline CSV short_path_size / short_path_wp_json 字段从占位变实填(M6c facade wire 预期 P1 baseline 漂);其他字段 byte-identical
- ✅ **AC11(perf)** tick_p99 / tick_max ≤ +50% vs M5(facade wire 后实测;Liang-Barsky 精确版 + enclose-radius 早出应足够)
- ✅ **AC12** Determinism:dynamic units AABB corner 顺序按 (obstr.tag, corner_index) 字典序,group filter 不破坏顺序
- ✅ Prototype scene 完整删除 + 确认无 prototype-only 简化代码残留(R6)
- ✅ 改动仅在 `addons/logic-game-framework/example/rts-auto-battle/` 内,不动 LGF core/ stdlib/

### Stop Runner 触发条件

⚠️ M6c 引入 facade wire 后**预期** baseline 漂(short path 字段从占位变实填,§3 第 6 条 P2 接受);其他字段 byte-identical,replay seed=42 deep-equal 必须仍 PASS。详见 [`risks-and-rollback.md §3`](task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md)。

## 验收准则

M6 完整 AC 见 [`M6-vertex-pathfinder.md §3`](task-plan/m3-0ad-pathfinding-migration/milestones/M6-vertex-pathfinder.md#3-验收准则-m6-总);M6b sub-phase 关键过线:

### M6b 关键过线条件

- ✅ **AC1.3** virtual goal CIRCLE/SQUARE 几何边界点解析正确
- ✅ **AC1.4** terrain edges 在 search box 内扫到 passable / impassable 邻居对中点
- ✅ **AC1.6** best-so-far:A* open 耗尽未达 goal_idx 时返回离 goal 最近 expanded vertex 的 reconstruct
- ✅ **AC12** Determinism §12.3:terrain vertex 加入顺序按 (i, j) 字典序;best-so-far candidate update 严格按 expansion 顺序
- ✅ Validation:LGF 73 + replay seed=42 deep-equal + 14 项 smoke byte-identical(M6b 算法层独立,不接 production → 0 baseline 漂移)
- ✅ 改动仅在 `addons/logic-game-framework/example/rts-auto-battle/` 内,不动 LGF core/ stdlib/

### Stop Runner 触发条件

⚠️ **M6b runner 启动前必读** [`risks-and-rollback.md §3`](task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md) **§3 stop runner 9 条触发条件**(M6a 启动前已读完,9 条全 clear)。

M6b 期间新增需关注:
- terrain edges grid 扫描 perf(96² grid 内大半 cell pair 比较)— 必须只扫 search bounds 内 cells,不全图
- best-so-far reconstruct 链路:`came_from[best_idx]` 必须仍在 came_from 链上(不能往 closed 外指)

## 非下一步

- ❌ 不启动 M7/M8(M6 整 milestone 末等用户授权再起 M7)
- ❌ 不实现 UnitMotion / Push pass(分别在 M7 / M8)
- ❌ 不修改 LGF submodule core/ 或 stdlib/(项目硬约束)
- ❌ 不主动跑 `/ultrareview` 或 push commit(commit 是本地节点,push 等用户)

## 等待动作

`/autonomous-feature-runner` 接 **M6c** 起步(sub-phase 间自治推进,不再等用户授权 — milestone-chain 仅在 M6 整 milestone 末触发)。runner 进入后应:

1. 读 [`task-plan/m3-0ad-pathfinding-migration/milestones/M6-vertex-pathfinder.md §M6c`](task-plan/m3-0ad-pathfinding-migration/milestones/M6-vertex-pathfinder.md#m6c--dynamic-units--group-filter--prototype-退役-15-周)
2. M6b 末态 baseline:见 Progress.md §0 / §5(submodule HEAD `c458bee`)
3. 按 M6c.1 → M6c.6 顺序推进;facade wire(M6c.4)前先把 dynamic units / group filter / smoke 准备好,wire 一刀 baseline 预期漂(P1 接受)
4. M6c 末跑 phase-close gate 7a-7c(simplify + re-validate + AC-doc consistency)
5. M6 整 milestone done → archive 整套 → 等 ✋3 用户审 demo F6(milestone-chain 触发点) → M7

## 期间踩坑提醒(累积)

- **M0-M4 累积坑** 见 [`archive/2026-05-04-rts-m3-m4-hierarchical/Next-Steps.md`](archive/2026-05-04-rts-m3-m4-hierarchical/Next-Steps.md) "期间踩坑提醒"
- **M5 累积坑** 见前一版 Next-Steps `archive/2026-05-04-rts-m3-m5-long-pathfinder/`
- **M6a 新增坑**:
  - **GDScript class_name cache race(再次踩)** — 加新 class(RtsLineOfSight / RtsShortPathRequest / RtsVertexPathfinder / RtsPathfinderHeap)首次 smoke 报"Identifier not declared"。**Lesson 同 M5**:加新 class_name 后必须先跑 `godot --headless --path . --import` 让 cache stabilize 才跑 smoke
  - **Bash `cd submodule_root` 漂 cwd** — `cd addons/logic-game-framework && git status` 后再调 godot,主仓 project.godot 找不到 → headless 卡死。**Lesson**:godot 调用永远用绝对路径 `--path D:/...inkmon-godot`,不依赖 shell pwd
  - **浮点 distance round-off 让 visibility A* path 不"最短"** — start, bounds_TL, goal 三点共线时(几何 corner case),A* 选 via-bounds_TL(累加浮点 sum 反比 direct distance 小 1 ulp),path size=2 而非 size=1。**Lesson**:visibility graph A* 的"路径形状"对几何 corner case 敏感,但语义等价(unit 走的轨迹相同),不是 bug — smoke 不应 hard-assert "size=1"
- **M6b 新增坑**:
  - **Liang-Barsky 浮点除零 epsilon** — segment 几乎平行 X 或 Y 轴时 `dx` / `dy` 极小但非 0,`1.0 / dx` 爆无穷大 → t1/t2 误判 → segment-AABB 相交错判。**Lesson**:浮点 sentinel 用 `absf(dx) > 1e-9` 而非 `dx != 0.0`;阈值跟 buffer (~12 px) 数量级比绝对小,不影响精度
  - **best-so-far 严格 < 比较保 deterministic** — `if nb_h < best_dist:` 而非 `<=`,等距时按 expansion 顺序保 deterministic;否则同距离 tie-break 走 nb_idx 字面值,跨 run 不稳定
  - **best-so-far start_idx 兜底返空** — A* open 耗尽时 best_idx 仍 = start_idx 意味"start 没邻居可见"(完全 enclosed),返非空 path = [start] 会让 caller 把 unit 留在原地空转;直接返空让 caller 进 "stuck" 状态有意义 — M6a `_test_fully_enclosed_returns_empty` 行为保留

## 期间踩坑提醒(累积)

- **M0-M4 累积坑** 见 [`archive/2026-05-04-rts-m3-m4-hierarchical/Next-Steps.md`](archive/2026-05-04-rts-m3-m4-hierarchical/Next-Steps.md) "期间踩坑提醒"
- **M5 新增坑**:
  - **GDScript class_name cache race(再次踩到)** — M5 加 6 个新 class(RtsLongPathRequest / RtsWaypointPath / RtsPathGoal / RtsLongPathfinder / RtsPathfinderFacade + 3 smoke)首次跑 unreachable / determinism smoke 时 godot 卡死(banner 后 _ready 不到)。**Lesson**:加新 class_name 后必须**先单跑 1 个 simple smoke 让 cache stabilize**(我跑 basic 后 cache 已 register 才能跑 unreach / det)
  - **LongPath direct-path fallback 是 attack/harvest/drop 的关键** — target=actor 中心可能落 footprint / inflate 区,A* 找不到 path → 必须返回单 waypoint = 原 goal.center 让 unit "直接走过去" + distance check 决定 in_range(否则 worker harvest gold=0 / unit attack 0 次)。**Lesson**:facade.compute_path_direct + LongPath direct-path fallback 是 spec §M4b.3 wire fail lesson 的真正解法,不是 "AI 不过 canonicalize" 单条
  - **canonicalize=true vs canonicalize=false 区分** — 玩家 click move(target=地图坐标)走 canonicalize=true 让点不可达点 unit 走最近 reachable;actor 中心 target(attack/harvest/drop)走 canonicalize=false + direct-path fallback。**Lesson**:nav_agent.set_target 加 canonicalize 参数 + activity 端按语义区分,**不是** 全局 canonicalize 一刀切
  - **新 baseline 接受流程** — 跑 smoke 双次确认 byte-identical → cp 到 submodule baselines/ → submodule commit。M5 算法变化 baseline 968343 bytes(+17%)接受
  - **M5.5 RtsBattleGrid 删除工作量被低估** — spec §M5.5 写 "M5 末删除文件" 但实际 25+ smoke 引用 + 5 production callsite + frontend 重命名 = 8-10h wallclock work。**Lesson**:spec scope 估计要看实际 caller 数量,纯 cleanup work 推迟不损失 functionality
