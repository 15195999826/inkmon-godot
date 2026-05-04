# Next Steps — 2026-05-04 (M6a done;M6b 待启动)

## 当前目标

🚧 **M6 milestone 进行中** — M6a (static-OBB only) **done 2026-05-04**(submodule commit `d4eda45`),下一步推 **M6b** virtual goal + terrain edges + best-so-far。

> **M3 Epic 进度**: M0+M1+M2+M3+M4+M5 archived + M6a done(sub-phase),6.33/9 milestone。剩余 M6b/M6c → M7 (UnitMotion) / M8 (Group Push) + EPIC 末 cleanup phase (M5.5b-e RtsBattleGrid 完整删除)。
> Epic 总览 [`task-plan/m3-0ad-pathfinding-migration/README.md`](task-plan/m3-0ad-pathfinding-migration/README.md)。

**M6a 末态(M6b 出发点)**:
- RtsShortPathRequest / RtsLineOfSight / RtsVertexPathfinder / RtsPathfinderHeap(LongPath/Vertex 共享 heap insert+key_less)4 个新 class 落地
- VertexPathfinder static-OBB only:search bounds toward goal shift(detail #1)+ range boundary 4 角(detail #2)+ lazy visibility A*(detail #5)+ tie-break (obstr.tag, corner_index) deterministic(detail #9)
- LineOfSight.segment_clear:enclose-radius 早出 + axis-aligned fast-path + t-stepping 100 sample fallback
- smoke_vertex_static_obb 8 sub-test PASS(进 rts/pathfinding manifest);proto_vertex_obb headless PASS(M6c 末删,R6 缓解)
- LongPath._heap_insert / _key_less 抽出 RtsPathfinderHeap,LongPath baseline-identical
- M6a 不接 facade / production:0 baseline 漂移 + tick_p99 / tick_max 不变;M6c.4 才 wire facade.compute_short_path_immediate
- Validation:-Required 12/12 + rts/pathfinding 13/13 PASS;LGF 73 + replay seed=42 deep-equal + baseline CSV byte-identical;9 条 stop runner 全 clear

## 下一步

**M6b — Virtual Goal + Terrain Edges + Best-So-Far**(完整 spec [`M6-vertex-pathfinder.md §M6b`](task-plan/m3-0ad-pathfinding-migration/milestones/M6-vertex-pathfinder.md#m6b--virtual-goal--terrain-edges--best-so-far-15-周))。

M6b sub-phase 子任务(spec §M6b.1-5):
1. **Virtual goal vertex(detail #3)** — RtsPathGoal.nearest_point_on_goal 扩 CIRCLE/SQUARE 几何;在 search bounds 内找 goal 边界离 start 最近可达点作 vertex,替代 M6a 的 goal.center 兜底
2. **Terrain edges(detail #4)** — 沿 search box 内 grid 边界扫,passable / impassable 邻居对中点作 vertex;水陆交界 / 不可走地形边
3. **Best-so-far fallback(detail #6)** — A* 跑完没到 goal_idx 时,返回扩展过的 vertices 中**离 goal 最近**那个的路径(让 unit 至少朝 goal 方向走一段)
4. **smoke_vertex_virtual_goal** — CIRCLE goal 边界点 + terrain 水陆交界
5. **segment-vs-OBB 精确化** — t-stepping 换 Liang-Barsky / SAT(spec M6b 末);保留 enclose-radius 早出

M6b 收口后 → M6c(dynamic units + group filter + facade wire + prototype 退役)→ M6 整 milestone done → archive + 等 ✋3 用户审。

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

- ❌ 不启动 M6c(M6b 末再起;sub-phase 间不需要 milestone-chain 等用户但应 update progress)
- ❌ 不实现 dynamic units / group filter(M6c)
- ❌ 不接 facade / production wire(M6c.4)
- ❌ 不删 prototype scene(M6c.6 末删)
- ❌ 不修改 LGF submodule core/ 或 stdlib/(项目硬约束)
- ❌ 不主动跑 `/ultrareview` 或 push commit(commit 是本地节点,push 等用户)

## 等待动作

`/autonomous-feature-runner` 接 **M6b** 起步(sub-phase 间自治推进,不再等用户授权 — milestone-chain 仅在 M6 整 milestone 末触发)。runner 进入后应:

1. 读 [`task-plan/m3-0ad-pathfinding-migration/milestones/M6-vertex-pathfinder.md §M6b`](task-plan/m3-0ad-pathfinding-migration/milestones/M6-vertex-pathfinder.md#m6b--virtual-goal--terrain-edges--best-so-far-15-周)
2. M6a 末态 baseline:见 Progress.md §0 / §5(submodule HEAD `d4eda45`)
3. 按 M6b.1 → M6b.5 顺序推进;每个子任务 done 时 update Progress.md
4. M6b 末再次跑 phase-close gate 7a-7c(simplify + re-validate + AC-doc consistency)+ commit
5. M6b 完成后接 M6c(无需重新等用户授权)

## 期间踩坑提醒(累积)

- **M0-M4 累积坑** 见 [`archive/2026-05-04-rts-m3-m4-hierarchical/Next-Steps.md`](archive/2026-05-04-rts-m3-m4-hierarchical/Next-Steps.md) "期间踩坑提醒"
- **M5 累积坑** 见前一版 Next-Steps `archive/2026-05-04-rts-m3-m5-long-pathfinder/`
- **M6a 新增坑**:
  - **GDScript class_name cache race(再次踩)** — 加新 class(RtsLineOfSight / RtsShortPathRequest / RtsVertexPathfinder / RtsPathfinderHeap)首次 smoke 报"Identifier not declared"。**Lesson 同 M5**:加新 class_name 后必须先跑 `godot --headless --path . --import` 让 cache stabilize 才跑 smoke
  - **Bash `cd submodule_root` 漂 cwd** — `cd addons/logic-game-framework && git status` 后再调 godot,主仓 project.godot 找不到 → headless 卡死。**Lesson**:godot 调用永远用绝对路径 `--path D:/...inkmon-godot`,不依赖 shell pwd
  - **浮点 distance round-off 让 visibility A* path 不"最短"** — start, bounds_TL, goal 三点共线时(几何 corner case),A* 选 via-bounds_TL(累加浮点 sum 反比 direct distance 小 1 ulp),path size=2 而非 size=1。**Lesson**:visibility graph A* 的"路径形状"对几何 corner case 敏感,但语义等价(unit 走的轨迹相同),不是 bug — smoke 不应 hard-assert "size=1"

## 期间踩坑提醒(累积)

- **M0-M4 累积坑** 见 [`archive/2026-05-04-rts-m3-m4-hierarchical/Next-Steps.md`](archive/2026-05-04-rts-m3-m4-hierarchical/Next-Steps.md) "期间踩坑提醒"
- **M5 新增坑**:
  - **GDScript class_name cache race(再次踩到)** — M5 加 6 个新 class(RtsLongPathRequest / RtsWaypointPath / RtsPathGoal / RtsLongPathfinder / RtsPathfinderFacade + 3 smoke)首次跑 unreachable / determinism smoke 时 godot 卡死(banner 后 _ready 不到)。**Lesson**:加新 class_name 后必须**先单跑 1 个 simple smoke 让 cache stabilize**(我跑 basic 后 cache 已 register 才能跑 unreach / det)
  - **LongPath direct-path fallback 是 attack/harvest/drop 的关键** — target=actor 中心可能落 footprint / inflate 区,A* 找不到 path → 必须返回单 waypoint = 原 goal.center 让 unit "直接走过去" + distance check 决定 in_range(否则 worker harvest gold=0 / unit attack 0 次)。**Lesson**:facade.compute_path_direct + LongPath direct-path fallback 是 spec §M4b.3 wire fail lesson 的真正解法,不是 "AI 不过 canonicalize" 单条
  - **canonicalize=true vs canonicalize=false 区分** — 玩家 click move(target=地图坐标)走 canonicalize=true 让点不可达点 unit 走最近 reachable;actor 中心 target(attack/harvest/drop)走 canonicalize=false + direct-path fallback。**Lesson**:nav_agent.set_target 加 canonicalize 参数 + activity 端按语义区分,**不是** 全局 canonicalize 一刀切
  - **新 baseline 接受流程** — 跑 smoke 双次确认 byte-identical → cp 到 submodule baselines/ → submodule commit。M5 算法变化 baseline 968343 bytes(+17%)接受
  - **M5.5 RtsBattleGrid 删除工作量被低估** — spec §M5.5 写 "M5 末删除文件" 但实际 25+ smoke 引用 + 5 production callsite + frontend 重命名 = 8-10h wallclock work。**Lesson**:spec scope 估计要看实际 caller 数量,纯 cleanup work 推迟不损失 functionality
