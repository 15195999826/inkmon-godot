# Next Steps — 2026-05-04 (M4a + M4b done / M4-perf-gate 待启动)

## 当前目标

**RTS Pathfinding M3 Epic — M4 sub-feature**: HierarchicalPathfinder — 把 NavcellGrid(M1 落地)+ ObstructionManager(M2 落地)+ Clearance inflate(M3 落地)之上,引入 region-based 分层寻路。M4 是 0 A.D. 路径求解器的核心算法层,提供"长路径快速判可达"+"短路径精确避障"的双层架构基础。

> M3 Epic = "RTS 寻路全面迁移到 0 A.D. 方案",分 9 个 milestone(M0-M8)+ Formation 推到下个 Epic。
> Epic 总览见 [`task-plan/m3-0ad-pathfinding-migration/README.md`](task-plan/m3-0ad-pathfinding-migration/README.md)。
> Epic 经过 codex Round 1-8 审查,Step A + Step B 全部 APPROVE,**M0 + M1 + M2 + M3 已 archived 于 2026-05-04**。

**当前 active sub-feature = M4**(完整 spec: [`task-plan/m3-0ad-pathfinding-migration/milestones/M4-hierarchical.md`](task-plan/m3-0ad-pathfinding-migration/milestones/M4-hierarchical.md))。

**M4a sub-phase ✅ done**(2026-05-04):RtsRegionIdHelper + RtsHierarchicalChunk + Pathfinder.recompute(per-class chunks + edges + global regions, R5 P1 #3 isolated region 修订)+ wire 进 `world.hierarchical_pathfinder` + procedure step 6.7 lazy recompute。Production code 不消费 → 0 baseline 漂移。

**M4b sub-phase ✅ done**(2026-05-04):`get_region` / `get_global_region` / `is_goal_reachable_point` / `make_goal_reachable_point` / `find_nearest_passable_navcell` + spiral ring scan helpers。**M4b 阶段语义偏离 spec**:reachable → no-op(不动 goal,保 baseline)+ 不可达 → 跟 start 同 GlobalRegion 离 goal 最近 navcell;原 spec "总是 navcell 中心" 推迟 M5 LongPathfinder。**M4b.3 wire DEFERRED 到 M5**:spec 假设 target=玩家 click,AI attack-move target=enemy actor 中心(落在 building footprint),canonicalize 拽到 ct 旁但 attack range 外 → ai_vs_player unit-to-ct attacks 7→0,wire 已 revert 保 baseline。详见 Progress.md §5 M4b sub-phase done。

## 下一步

**M4-perf-gate** — 测 M4a full recompute 在 100 unit / 16 building 规模下的 per-tick 耗时;**> 30 ms / tick 才启动 M4c sub-phase,否则跳过 M4c 直接 M4 收口**(spec §1 R5 反馈)。

具体步骤:

1. 写 perf 探针(可选 — 直接 hook 现有 castle_war / determinism smoke 加 timing block 即可,不必新 smoke):跑 `RtsHierarchicalPathfinder.recompute` 100 次取 p99 / max
2. 跑 castle_war(典型 1v1 demo 规模)+ determinism smoke 拉 60s 录数据
3. 阈值判:
   - p99 ≤ 30 ms / tick → **跳 M4c**,直接 M4-validation + M4 整 milestone archive(M4c.* checklist 标记 cancelled)
   - p99 > 30 ms / tick → 启 M4c.1 → M4c.3(spec §M4c)+ R5 P1 #2 dirty snapshot 协议
4. 数据写到 Progress.md §5 M4-perf-gate done evidence

M4-perf-gate 收口后(无论是否启 M4c):
- M4 整 milestone validation 全套 17 项 + LGF + replay deep-equal + baseline CSV byte-identical
- ✋2 用户体验点 — **跟 wire 一起推到 M5**(M4b.3 deferred,体验点 demo 玩家点不可达点 → unit 走最近 → 这个体验依赖 wire,M5 才能验)
- M4 整体 archive + 启动 M5(LongPathfinder)

后续 M5-M8 → 见 [`task-plan/m3-0ad-pathfinding-migration/README.md`](task-plan/m3-0ad-pathfinding-migration/README.md)。

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

由 `/autonomous-feature-runner` 接 **M4-perf-gate** 起步。runner 进入后应:

1. 先读 [`task-plan/m3-0ad-pathfinding-migration/milestones/M4-hierarchical.md`](task-plan/m3-0ad-pathfinding-migration/milestones/M4-hierarchical.md) §1 perf 阈值 + §M4c spec
2. **必读** [`task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md`](task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md) **§3 stop runner 9 条触发条件**(perf 第 5 条 tick_p99/tick_max ≥ 100% 增长是关键)
3. **M4a + M4b 末态 baseline**:见 Progress.md §5 — LGF 73 + replay seed=42 frames=11 events=20 deep-equal + baseline CSV byte-identical 829520 bytes + 5 RTS smoke baseline-identical + 3 hierarchical smoke 全 PASS
4. 决定阈值:p99 ≤ 30 ms / tick → 跳 M4c → M4 整体收口(✋2 跟 wire 一起推 M5);p99 > 30 ms → 启 M4c.1 → M4c.3 + R5 P1 #2 dirty snapshot
5. perf-gate 收口后 M4 整 milestone validation + archive(✋2 体验点跟 M4b.3 wire 一起 deferred 到 M5,**不阻塞 M4 archive**)

## 期间踩坑提醒(M3 阶段累积)

- **NavcellGrid 跟 RtsBattleGrid 坐标系**:NavcellGrid `_origin_world` 必须 attach 时 set,否则 ObstructionManager 用 world/cell 索引会跟 RtsBattleGrid HexCoord+half_offset 错位;**M2 阶段 rasterize 没被 caller 调过没暴露,M3 一启用就报 baseline regression**。M4 引入 hierarchical region grid 时若也用 world 坐标索引 NavcellGrid,务必走 `world_to_navcell_i/j` helper。
- **Dirty lifecycle R5 P1-2 invariant**:M3 已落地"rasterize / hierarchical update 都只读 dirty 不清,procedure.tick_once 末端统一 clear_dirty"。M4 hierarchical update 必须在 M3 step 6.6 rasterize_if_dirty 之后(或并行)读 dirty,**不**清 dirty;末端 step 7.5 仍由 procedure 统一清。任一中途清 = stop runner 第 8 条 P0。
- **bash cwd 漂移坑** — `cd <subdir>` 不回主仓 → `godot --headless --path . *.tscn` 静默 hang。统一用 `git -C <subdir>` 取代 cd。
- **GDScript class_name cache race** — 4 godot 并行启动新加 class_name 时第一波读旧 cache → Parse Error。**Lesson**: 新加 class_name 的 milestone 首次跑 baseline,先单跑 1 个 smoke 让 cache stabilize 再批量并行。
- **装饰 obstacle 隐式 baseline regression**(M3 暴露的 hidden dependency):frontend `mark_obstacle_cell` 在 `_ready` 阶段调,procedure._init 之前;若不补登记到 manager,`rasterize_if_dirty` 第一次跑会清掉。M3 已 fix(`_register_decorative_obstacles_to_manager`),M4+ 引入 region grid 时同理需检查 frontend-only 路径写入的 cells 是否被 manager 覆盖。
