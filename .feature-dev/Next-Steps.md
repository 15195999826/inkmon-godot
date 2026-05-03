# Next Steps — 2026-05-04 (M3 Epic / M1 archived; M2 active 等 runner 启动)

## 当前目标

**RTS Pathfinding M3 Epic — M2 sub-feature**: ObstructionManager (Shape 数据库) — 引入 `RtsObstructionManager` 单例,统一管理所有 obstruction shape(单位圆 + 建筑 OBB),替换 M0/M1 阶段"actor 自管 obstruction_shape + grid 自管 placement_map"的散乱状态。M2 引入完整 EFlags 枚举(6 flag)+ spatial index(uniform grid bucket)+ 替换 `RtsBattleGrid.place_building` 为 `add_static_shape` + rasterize。

> M3 Epic = "RTS 寻路全面迁移到 0 A.D. 方案",分 9 个 milestone(M0-M8)+ Formation 推到下个 Epic。
> Epic 总览见 [`task-plan/m3-0ad-pathfinding-migration/README.md`](task-plan/m3-0ad-pathfinding-migration/README.md)。
> Epic 经过 codex Round 1-8 审查,Step A + Step B 全部 APPROVE,**M0 + M1 已 archived 于 2026-05-04**。

**当前 active sub-feature = M2**(完整 spec: [`task-plan/m3-0ad-pathfinding-migration/milestones/M2-obstruction-manager.md`](task-plan/m3-0ad-pathfinding-migration/milestones/M2-obstruction-manager.md))。

## 下一步

启动 **M2.1 — RtsObstructionFlags + Filter 基础设施**:

1. 新建 `addons/.../logic/obstruction/rts_obstruction_flags.gd`(6 flag 常量:BLOCK_MOVEMENT / BLOCK_FOUNDATION / BLOCK_CONSTRUCTION / BLOCK_PATHFINDING / MOVING / DELETE_UPON_CONSTRUCTION)
2. 新建 `addons/.../logic/obstruction/rts_obstruction_test_filter.gd`(RefCounted 抽象基类 + 3 静态工厂:by_class / exclude_self / merging_friendly_units)
3. M0 阶段 `RtsObstructionShape` 基类的 `flags` 字段从硬编码 `1<<3` 切换到 `RtsObstructionFlags.BLOCK_PATHFINDING` 常量

后续 M2.2 → M2.6 见 Progress.md §1。

## 验收准则

完整 AC1-AC10 见 [`M2-obstruction-manager.md §3`](task-plan/m3-0ad-pathfinding-migration/milestones/M2-obstruction-manager.md);Progress.md §2 镜像 checklist。

### 关键过线条件

- ✅ 3 个 smoke PASS(`smoke_obstruction_manager_register / _query / _remove`)
- ✅ Validation 全套 14 项 + LGF 73/73 + replay seed=42 deep-equal
- ✅ Baseline CSV(M2 引入 obstruction trace 字段从占位 -1 / "" 变实填,**P2 预期变化**,接受新 baseline;详见 [risks-and-rollback §1.3](task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md))
- ✅ Perf vs M1:wall_clock ≤ +50%,tick_p99 ≤ 30 ms
- ✅ 改动仅在 `addons/logic-game-framework/example/rts-auto-battle/` 内,不动 LGF core/ stdlib/

### Stop Runner 触发条件

⚠️ **runner 启动前必读** [`task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md`](task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md) **§3 完整 9 条**(包括 perf 主指标 `tick_p99/tick_max` ≥ 100% 增长 / R5 P1 #2 dirty lifecycle invariant 违反 / R5 P1 #1 actor sort 用字典序而非 `(kind, spawn_seq)` 数值 key 等)。

任一触发立即停下问用户。**不在本文件内联枚举**(避免双源漂移),risks-and-rollback §3 是唯一权威。runner 必须显式读完该 9 条后再启动 M2.1。

## 非下一步

- ❌ 不启动 M3-M8(每个 milestone 末等 codex / 用户授权再起下一个)
- ❌ 不实现 Clearance 外扩 / Hierarchical / LongPath / VertexPath / Motion(分别在 M3 / M4 / M5 / M6 / M7)
- ❌ 不修改 LGF submodule core/ 或 stdlib/(项目硬约束)
- ❌ 不主动跑 `/ultrareview` 或 commit(运行至子任务 done 时由 runner 按协议 commit)

## 等待动作

由 `/autonomous-feature-runner` 接 M2.1 起步。runner 进入后应:

1. 先读 [`task-plan/m3-0ad-pathfinding-migration/milestones/M2-obstruction-manager.md`](task-plan/m3-0ad-pathfinding-migration/milestones/M2-obstruction-manager.md) **顶部 Status block + §0 + §1 + §2 子任务 + §3 AC + §6 风险**(spec 较长,token-conscious 可先读这几节)
2. **必读** [`task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md`](task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md) **§3 stop runner 9 条触发条件**
3. 顺手过 [`task-plan/m3-0ad-pathfinding-migration/data-structures.md`](task-plan/m3-0ad-pathfinding-migration/data-structures.md) §2(Obstruction 层 EFlags / Filter / SpatialIndex / Manager 字段定义)+ §12(determinism contract)
4. **M1 末态 baseline 数据**(AC8 0 漂移基准):见 `Current-State.md` "测试基线" 表 — 14+1+1+1 项 + LGF 73 + replay seed=42 deep-equal + baseline CSV byte-identical(882882 bytes)
5. 按 M2.1 → M2.2 → M2.3 → M2.4 → M2.5 → M2.6 顺序推进;每个子任务 done 时 update Progress.md(checkbox + AC 状态同步)
6. M2 全部 AC 通过后:milestone-chain 协议(详见 [`task-plan/README.md`](task-plan/README.md) §收口条件)— 直接 archive M2 + 启动 M3,**不**逐 milestone reset Progress/Current-State,Epic 级 reset 留到 M8 完成后
