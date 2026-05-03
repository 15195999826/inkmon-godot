# Next Steps — 2026-05-04 (M4 待启动 / M3 已 archived)

## 当前目标

**RTS Pathfinding M3 Epic — M4 sub-feature**: HierarchicalPathfinder — 把 NavcellGrid(M1 落地)+ ObstructionManager(M2 落地)+ Clearance inflate(M3 落地)之上,引入 region-based 分层寻路。M4 是 0 A.D. 路径求解器的核心算法层,提供"长路径快速判可达"+"短路径精确避障"的双层架构基础。

> M3 Epic = "RTS 寻路全面迁移到 0 A.D. 方案",分 9 个 milestone(M0-M8)+ Formation 推到下个 Epic。
> Epic 总览见 [`task-plan/m3-0ad-pathfinding-migration/README.md`](task-plan/m3-0ad-pathfinding-migration/README.md)。
> Epic 经过 codex Round 1-8 审查,Step A + Step B 全部 APPROVE,**M0 + M1 + M2 + M3 已 archived 于 2026-05-04**。

**当前 active sub-feature = M4**(完整 spec: [`task-plan/m3-0ad-pathfinding-migration/milestones/M4-hierarchical.md`](task-plan/m3-0ad-pathfinding-migration/milestones/M4-hierarchical.md))。

## 下一步

启动 **M4 — HierarchicalPathfinder**(由 runner 读 M4-hierarchical.md 后按 spec §M4a / M4b / M4c sub-phase 推进):

1. M4a — Region 数据结构 + initial recompute(全图 BFS 划分 region per pass_class)
2. M4b — Canonicalize 算法(region edge 内/外切换边界点 deterministic 选择)
3. M4c — Incremental update(消费 M3 dirty 集合,只重算 dirty regions)
4. ✋2 体验点 — 用户跑 demo 验证 hierarchical 寻路启用后表现正确

后续 M5-M8 → 见 Progress.md §1。

## 验收准则

完整 AC 见 [`M4-hierarchical.md §3`](task-plan/m3-0ad-pathfinding-migration/milestones/M4-hierarchical.md);Progress.md §2 由 runner 启动时镜像填入。

### 关键过线条件

- ✅ HierarchicalPathfinder 落地(per-class regions + edges + global region)
- ✅ Canonicalize 算法 deterministic(R5 §12.4 / risks §1.1 重点)
- ✅ Incremental update 消费 M3 dirty 集合,不全图重算
- ✅ Validation 全套 17 项 baseline 数字 + LGF 73 + replay seed=42 deep-equal
- ✅ Baseline CSV(M4 path 变化预期 P1,接受新 baseline;详见 [risks-and-rollback §1.3](task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md))
- ✅ Perf vs M3:`tick_p99 / tick_max` ≤ +50%
- ✅ 改动仅在 `addons/logic-game-framework/example/rts-auto-battle/` 内,不动 LGF core/ stdlib/
- ✅ ✋2 体验点用户跑 demo 反馈

### Stop Runner 触发条件

⚠️ **runner 启动前必读** [`task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md`](task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md) **§3 完整 9 条**(包括 perf 主指标 `tick_p99/tick_max` ≥ 100% 增长 / R5 P1 #2 dirty lifecycle invariant 违反 / R5 P1 #1 actor sort 用字典序而非 `(kind, spawn_seq)` 数值 key 等)。

任一触发立即停下问用户。**不在本文件内联枚举**(避免双源漂移),risks-and-rollback §3 是唯一权威。runner 必须显式读完该 9 条后再启动 M4。

## 非下一步

- ❌ 不启动 M5-M8(每个 milestone 末等 codex / 用户授权再起下一个)
- ❌ 不实现 LongPath / VertexPath / Motion / Push pass(分别在 M5 / M6 / M7 / M8)
- ❌ 不修改 LGF submodule core/ 或 stdlib/(项目硬约束)
- ❌ 不主动跑 `/ultrareview` 或 commit(运行至子任务 done 时由 runner 按协议 commit)

## 等待动作

由 `/autonomous-feature-runner` 接 M4 起步。runner 进入后应:

1. 先读 [`task-plan/m3-0ad-pathfinding-migration/milestones/M4-hierarchical.md`](task-plan/m3-0ad-pathfinding-migration/milestones/M4-hierarchical.md)
2. **必读** [`task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md`](task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md) **§3 stop runner 9 条触发条件**
3. 顺手过 [`task-plan/m3-0ad-pathfinding-migration/data-structures.md`](task-plan/m3-0ad-pathfinding-migration/data-structures.md) §3(HierarchicalPathfinder)
4. **M3 末态 baseline 数据**:见 `Current-State.md` "测试基线" 表 — 17 项 + LGF 73 + replay seed=42 deep-equal + baseline CSV byte-identical(829520 bytes)+ `smoke_clearance_inflate` 4 sub-test 全过
5. 按 M4a → M4b → M4c 顺序推进(sub-phase 独立 rollback 点);每个子任务 done 时 update Progress.md
6. M4 全 AC 通过后:milestone-chain 协议 — 直接 archive M4 + 等用户审 ✋2 体验点 → 启动 M5

## 期间踩坑提醒(M3 阶段累积)

- **NavcellGrid 跟 RtsBattleGrid 坐标系**:NavcellGrid `_origin_world` 必须 attach 时 set,否则 ObstructionManager 用 world/cell 索引会跟 RtsBattleGrid HexCoord+half_offset 错位;**M2 阶段 rasterize 没被 caller 调过没暴露,M3 一启用就报 baseline regression**。M4 引入 hierarchical region grid 时若也用 world 坐标索引 NavcellGrid,务必走 `world_to_navcell_i/j` helper。
- **Dirty lifecycle R5 P1-2 invariant**:M3 已落地"rasterize / hierarchical update 都只读 dirty 不清,procedure.tick_once 末端统一 clear_dirty"。M4 hierarchical update 必须在 M3 step 6.6 rasterize_if_dirty 之后(或并行)读 dirty,**不**清 dirty;末端 step 7.5 仍由 procedure 统一清。任一中途清 = stop runner 第 8 条 P0。
- **bash cwd 漂移坑** — `cd <subdir>` 不回主仓 → `godot --headless --path . *.tscn` 静默 hang。统一用 `git -C <subdir>` 取代 cd。
- **GDScript class_name cache race** — 4 godot 并行启动新加 class_name 时第一波读旧 cache → Parse Error。**Lesson**: 新加 class_name 的 milestone 首次跑 baseline,先单跑 1 个 smoke 让 cache stabilize 再批量并行。
- **装饰 obstacle 隐式 baseline regression**(M3 暴露的 hidden dependency):frontend `mark_obstacle_cell` 在 `_ready` 阶段调,procedure._init 之前;若不补登记到 manager,`rasterize_if_dirty` 第一次跑会清掉。M3 已 fix(`_register_decorative_obstacles_to_manager`),M4+ 引入 region grid 时同理需检查 frontend-only 路径写入的 cells 是否被 manager 覆盖。
