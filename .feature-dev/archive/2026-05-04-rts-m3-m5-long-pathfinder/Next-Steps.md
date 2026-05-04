# Next Steps — 2026-05-04 (M5 done + archived;等用户授权 M6 启动)

## 当前目标

⏸ **等待用户审 M5 archive + 授权启动 M6**(milestone-chain 协议:每 milestone 末等审阅再起下一个)。

> **M3 Epic 进度**: M0 + M1 + M2 + M3 + M4 + M5 已 archived(2026-05-04),6/9 milestone done。剩余 M6 (VertexPathfinder) / M7 (UnitMotion) / M8 (Group Push) + EPIC 末 cleanup phase (M5.5b-e RtsBattleGrid 完整删除)。
> Epic 总览 [`task-plan/m3-0ad-pathfinding-migration/README.md`](task-plan/m3-0ad-pathfinding-migration/README.md)。

**M5 末态 baseline**(M6 出发点):
- LongPath 朴素 A* on NavcellGrid(8-邻居 deterministic + 整数 cost + 5 元组 lex compare 严格 byte-identical 跨 run + direct-path fallback for 终点 impassable case)
- PathfinderFacade 顶层(canonicalize+A* + is/make_goal_reachable)替代老 RtsPathfinding
- Hierarchical canonicalize 切到 spec "总是 navcell 中心 mutate"(M4b reachable→no-op 临时方案被替代)
- nav_agent / activity wire(玩家 click=canonicalize / actor 中心=direct)
- world.navcell_grid 一等公民字段(M5.5a 提升)
- 新 baseline CSV 968343 bytes(M4 829520→+17% LongPath 路径变化 P1 接受)
- LGF 73/73 + replay seed=42 frames=11 events=24 deep-equal + 8 RTS smoke + 5 hierarchical + 3 long_pathfinder smoke 全 PASS
- ✋2 体验点 headless mock PASS(玩家点墙后不可达点 → unit 走最近 reachable navcell,不死循环)

**M5 deferred → EPIC 末 cleanup phase**:
- **M5.5b-e RtsBattleGrid 完整删除**(2026-05-04 用户决策推迟):production code (rts_battle_actor / rts_building_placement / rts_place_building_command / procedure.start) 仍走 rts_grid wrapper 调 world_to_coord / place_building 等 method;frontend RtsBattleMap.grid 类型仍 RtsBattleGrid;22+ smoke `_grid = RtsBattleGrid.new(...)` 构造未改。删除工作量 8-10h wallclock 纯 cleanup,不影响 M6/M7/M8 启动 — 推到 M8 后 EPIC 收尾 cleanup phase 集中做。

详见 [`archive/2026-05-04-rts-m3-m5-long-pathfinder/Summary.md`](archive/2026-05-04-rts-m3-m5-long-pathfinder/Summary.md)。

## 下一步

**M6 — VertexPathfinder**(完整 spec [`task-plan/m3-0ad-pathfinding-migration/milestones/M6-vertex-pathfinder.md`](task-plan/m3-0ad-pathfinding-migration/milestones/M6-vertex-pathfinder.md))。

M6 引入"短程 visibility graph 寻路"层(0 A.D. VertexPathfinder 复刻):
1. **OBB corner vertex 生成** — 围绕 obstruction_manager._shapes 的 OBB 角点采样 + offset(让 unit 不撞 OBB)
2. **Visibility graph A***— vertex-to-vertex line-of-sight check + Dijkstra/A*
3. **Static OBB 单层(M6a)→ + group filter(M6b)→ + dynamic units(M6c)**
4. **✋3 体验点** — demo 单位贴墙绕角不撞 + 紧密走廊单位不卡死

M6 收口后 → M7 UnitMotion(替代 RtsNavAgent + steering 集成版)。

## 验收准则

M6 完整 AC 见 [`M6-vertex-pathfinder.md §3`](task-plan/m3-0ad-pathfinding-migration/milestones/M6-vertex-pathfinder.md);Progress.md §2 由 runner 启动时镜像填入。

### 关键过线条件(M6)

- ✅ Visibility graph 生成 deterministic(corner 顶点按 obstruction.tag, corner_index 字典序)
- ✅ Vertex-to-vertex visibility check 走 RtsLineOfSight(M6 引入)
- ✅ ✋3 体验点 — demo 单位贴墙绕角不撞 + 紧密走廊不卡
- ✅ Validation 全套 17 项 + LGF 73 + replay seed=42 deep-equal
- ✅ Baseline CSV(M6 短路径精确化 P1 预期算法变化,接受新 baseline)
- ✅ Perf vs M5:`tick_p99 / tick_max` ≤ +50%(M6 spec §AC8)
- ✅ 改动仅在 `addons/logic-game-framework/example/rts-auto-battle/` 内,不动 LGF core/ stdlib/

### Stop Runner 触发条件

⚠️ **M6 runner 启动前必读** [`risks-and-rollback.md §3 完整 9 条`](task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md)。

## 非下一步

- ❌ 不启动 M7/M8(每个 milestone 末等用户授权再起下一个)
- ❌ 不实现 UnitMotion / Push pass(分别在 M7 / M8)
- ❌ 不修改 LGF submodule core/ 或 stdlib/(项目硬约束)
- ❌ 不主动跑 `/ultrareview` 或 push commit(commit 是本地节点,push 等用户)
- ❌ **不在 M6 中做 RtsBattleGrid 删除**(推到 EPIC 末 cleanup phase)

## 等待动作

由 `/autonomous-feature-runner` 接 **M6** 起步(用户授权后)。runner 进入后应:

1. 先读 [`task-plan/m3-0ad-pathfinding-migration/milestones/M6-vertex-pathfinder.md`](task-plan/m3-0ad-pathfinding-migration/milestones/M6-vertex-pathfinder.md)
2. **必读** [`task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md`](task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md) **§3 stop runner 9 条触发条件**
3. **M5 末态 baseline 数据**:见 `Current-State.md` "测试基线" 表 — 17 项 + LGF 73 + replay seed=42 frames=11 events=24 deep-equal + baseline CSV byte-identical 968343 bytes + 5 hierarchical + 3 long_pathfinder smoke 全过
4. 按 M6a → M6b → M6c 顺序推进(sub-phase 独立 rollback 点);每个子任务 done 时 update Progress.md
5. M6 全 AC 通过后:milestone-chain 协议 — 直接 archive M6 + 等用户审 ✋3 体验点 → 启动 M7

## 期间踩坑提醒(累积)

- **M0-M4 累积坑** 见 [`archive/2026-05-04-rts-m3-m4-hierarchical/Next-Steps.md`](archive/2026-05-04-rts-m3-m4-hierarchical/Next-Steps.md) "期间踩坑提醒"
- **M5 新增坑**:
  - **GDScript class_name cache race(再次踩到)** — M5 加 6 个新 class(RtsLongPathRequest / RtsWaypointPath / RtsPathGoal / RtsLongPathfinder / RtsPathfinderFacade + 3 smoke)首次跑 unreachable / determinism smoke 时 godot 卡死(banner 后 _ready 不到)。**Lesson**:加新 class_name 后必须**先单跑 1 个 simple smoke 让 cache stabilize**(我跑 basic 后 cache 已 register 才能跑 unreach / det)
  - **LongPath direct-path fallback 是 attack/harvest/drop 的关键** — target=actor 中心可能落 footprint / inflate 区,A* 找不到 path → 必须返回单 waypoint = 原 goal.center 让 unit "直接走过去" + distance check 决定 in_range(否则 worker harvest gold=0 / unit attack 0 次)。**Lesson**:facade.compute_path_direct + LongPath direct-path fallback 是 spec §M4b.3 wire fail lesson 的真正解法,不是 "AI 不过 canonicalize" 单条
  - **canonicalize=true vs canonicalize=false 区分** — 玩家 click move(target=地图坐标)走 canonicalize=true 让点不可达点 unit 走最近 reachable;actor 中心 target(attack/harvest/drop)走 canonicalize=false + direct-path fallback。**Lesson**:nav_agent.set_target 加 canonicalize 参数 + activity 端按语义区分,**不是** 全局 canonicalize 一刀切
  - **新 baseline 接受流程** — 跑 smoke 双次确认 byte-identical → cp 到 submodule baselines/ → submodule commit。M5 算法变化 baseline 968343 bytes(+17%)接受
  - **M5.5 RtsBattleGrid 删除工作量被低估** — spec §M5.5 写 "M5 末删除文件" 但实际 25+ smoke 引用 + 5 production callsite + frontend 重命名 = 8-10h wallclock work。**Lesson**:spec scope 估计要看实际 caller 数量,纯 cleanup work 推迟不损失 functionality
