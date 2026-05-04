# Next Steps — 2026-05-04 (M4 done + archived;等用户授权 M5 启动)

## 当前目标

⏸ **等待用户审 M4 archive + 授权启动 M5**(milestone-chain 协议:每 milestone 末等审阅再起下一个)。

> **M3 Epic 进度**: M0 + M1 + M2 + M3 + M4 已 archived(2026-05-04),5/9 milestone done。剩余 M5-M8(LongPathfinder / VertexPathfinder / Motion / Group Push)。
> Epic 总览 [`task-plan/m3-0ad-pathfinding-migration/README.md`](task-plan/m3-0ad-pathfinding-migration/README.md)。

**M4 末态 baseline**(M5 出发点):
- HierarchicalPathfinder 算法层落地(per-class chunks + edges + global_regions + canonicalize API)
- Production code 不消费 hierarchical(M4b.3 wire deferred 到 M5)→ 0 baseline 漂移
- LGF 73/73 + replay seed=42 frames=11 events=20 deep-equal + baseline CSV byte-identical 829520 bytes
- 8 RTS smoke baseline-identical(rts_auto / castle_war / flying / determinism / clearance_inflate / region_id / recompute / isolated_region / unreachable / perf)
- M4-perf-gate realistic demo p99=28 ms ≤ 30 ms 阈值 → M4c CANCEL
- ✋2 体验点 + M4b.3 wire DEFERRED 到 M5(spec 假设 target=玩家 click 与 AI attack-move target=enemy actor 中心语义冲突)

详见 [`archive/2026-05-04-rts-m3-m4-hierarchical/Summary.md`](archive/2026-05-04-rts-m3-m4-hierarchical/Summary.md)。

## 下一步

**M5 — LongPathfinder**(完整 spec [`task-plan/m3-0ad-pathfinding-migration/milestones/M5-long-pathfinder.md`](task-plan/m3-0ad-pathfinding-migration/milestones/M5-long-pathfinder.md))。

M5 启动会一次性兑现 M4 deferred 项:
1. **LongPathfinder 实现** — 朴素 A* 在 NavcellGrid 上跑(D6:不做 JPS)
2. **Canonicalize 语义切换** — `make_goal_reachable_point` 改 "总是 mutate 到 navcell 中心"(M4b 阶段 reachable → no-op 临时方案被替代);接受 P1 baseline CSV 漂(target 偏 0-16 px → 改路径,M5 预期算法变化)
3. **Wire 进玩家命令链路** — `RtsMoveUnitsCommand` / `RtsPlaceBuildingCommand` 启动寻路前调 `facade.make_goal_reachable`
4. **AI attack-move 走单独路径** — `rts_ai_strategy.gd` 决策直接传 enemy actor 中心,**不**过 canonicalize(避免 M4b.3 试 wire 时 unit-to-ct attacks 7→0 的 bug)
5. **✋2 用户体验点验收** — demo_rts_frontend 玩家右键点不可达点 → 单位走最近可达 navcell,不死循环

M5 收口后 → M6 VertexPathfinder。

## 验收准则

M5 完整 AC 见 [`M5-long-pathfinder.md §3`](task-plan/m3-0ad-pathfinding-migration/milestones/M5-long-pathfinder.md);Progress.md §2 由 runner 启动时镜像填入。

### 关键过线条件(M5)

- ✅ LongPathfinder 朴素 A* 落地(NavcellGrid 上跑 + per-class mask + clearance-aware)
- ✅ Wire 进玩家 / AI 命令链路(玩家 click 过 canonicalize + AI attack-move 不过 canonicalize)
- ✅ ✋2 体验点 — demo 玩家点不可达点不死循环
- ✅ 4 hierarchical smoke 不退化(M4 baseline 保持)
- ✅ Validation 全套 17 项 + LGF 73 + replay seed=42 deep-equal
- ✅ Baseline CSV(M5 切 canonicalize "总是 navcell 中心" 是 P1 预期算法变化,接受新 baseline;详见 [risks-and-rollback §1.3](task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md))
- ✅ Perf vs M4:`tick_p99 / tick_max` ≤ +50%
- ✅ 改动仅在 `addons/logic-game-framework/example/rts-auto-battle/` 内,不动 LGF core/ stdlib/

### Stop Runner 触发条件

⚠️ **M5 runner 启动前必读** [`risks-and-rollback.md §3 完整 9 条`](task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md)。

## 非下一步

- ❌ 不启动 M6-M8(每个 milestone 末等用户授权再起下一个)
- ❌ 不实现 VertexPath / Motion / Push pass(分别在 M6 / M7 / M8)
- ❌ 不修改 LGF submodule core/ 或 stdlib/(项目硬约束)
- ❌ 不主动跑 `/ultrareview` 或 push commit(commit 是本地节点,push 等用户)

## 等待动作

由 `/autonomous-feature-runner` 接 **M5** 起步(用户授权后)。runner 进入后应:

1. 先读 [`task-plan/m3-0ad-pathfinding-migration/milestones/M5-long-pathfinder.md`](task-plan/m3-0ad-pathfinding-migration/milestones/M5-long-pathfinder.md)
2. **必读** [`task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md`](task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md) **§3 stop runner 9 条触发条件**
3. **M4 末态 baseline 数据**:见 `Current-State.md` "测试基线" 表 — 17 项 + LGF 73 + replay seed=42 deep-equal + baseline CSV byte-identical 829520 bytes + 4 hierarchical smoke 全过 + smoke_clearance_inflate 4 sub-test 全过
4. M5 deferred 项一次性兑现(LongPath + canonicalize 切换 + wire + AI 路径 + ✋2);P1 baseline 漂接受
5. M5 全 AC 通过后 → archive M5 + 等用户审 → 启动 M6

## 期间踩坑提醒(M3 阶段累积 + M4 新增)

- **M0-M3 累积坑** 见 [`archive/2026-05-04-rts-m3-m3-clearance/Next-Steps.md`](archive/2026-05-04-rts-m3-m3-clearance/Next-Steps.md) "期间踩坑提醒"
- **M4 新增坑**:
  - **M4b 阶段 canonicalize "reachable → no-op" 是临时方案** — M4b smoke `make_goal_reachable_point` reachable 时不 mutate goal,保 baseline 不漂;但这跟 0 A.D. spec 不一致,M5 LongPathfinder 落地时**必须**切到 "总是 navcell 中心" + 接受 P1 baseline 漂
  - **M4b.3 wire 试 `RtsMoveUnitsCommand` 失败 lesson** — spec §M4b.3 假设 target=玩家 click 点(地图 free space);AI attack-move target=enemy actor 中心(可能落 building footprint 内)。Canonicalize 把 enemy 中心 → ct 旁外缘 navcell → unit 走到那站住但 ct 在 attack range 外。**M5 必须先把 AI attack-move 拆成单独路径(不过 canonicalize)再 wire 玩家命令**
  - **M4-perf-gate 28 ms 离阈值小** — realistic demo (96² + 16 building) p99=28 ms ≤ 30 ms 但仅 7% 余地。M5 加 LongPath + 触发 dirty rasterize 频率上升 + grid 扩大 → 可能击穿阈值,需要复测;若超阈则补 M4c(dirty 增量更新)
  - **GDScript BFS overhead** — recompute 每 navcell ~3 us(0 A.D. C++ ~0.03 us),100× 慢。算法已 cursor + PackedInt32Array 优化,继续 micro-optimize 收益边际;真正解法是 GDExtension 重写关键 hot path(留给 perf 真冲突时再做)
