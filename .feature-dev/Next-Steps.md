# Next Steps — 2026-05-04 (M3 Epic / M2 archived;M3 active 等 runner 启动)

## 当前目标

**RTS Pathfinding M3 Epic — M3 sub-feature**: Clearance + 外扩 — 给每个 PassabilityClass 引入 clearance buffer,在 ObstructionManager.rasterize 时把 obstruction 外扩 buffer 半径,让单位的圆 collision 在 grid 上以 cell-aligned 方式被预算入 obstacle bit。M3 是 M2 (manager 单例) 之上的算法层 — manager 已就位,M3 完成 inflate 算法 + 切 pathfinder 走 manager 数据。

> M3 Epic = "RTS 寻路全面迁移到 0 A.D. 方案",分 9 个 milestone(M0-M8)+ Formation 推到下个 Epic。
> Epic 总览见 [`task-plan/m3-0ad-pathfinding-migration/README.md`](task-plan/m3-0ad-pathfinding-migration/README.md)。
> Epic 经过 codex Round 1-8 审查,Step A + Step B 全部 APPROVE,**M0 + M1 + M2 已 archived 于 2026-05-04**。

**当前 active sub-feature = M3**(完整 spec: [`task-plan/m3-0ad-pathfinding-migration/milestones/M3-clearance.md`](task-plan/m3-0ad-pathfinding-migration/milestones/M3-clearance.md))。

## 下一步

启动 **M3.1 — Clearance buffer 数据结构**(由 runner 读 M3-clearance.md 后按 spec §2 子任务推进):

1. RtsPassabilityClassConfig 加 buffer 字段(若 spec 要求)/ 已有字段映射
2. ObstructionManager.rasterize 启用 inflate(M2 已 ready dirty_only=true)
3. 切 pathfinder 走 manager 写入的 grid bit(M2 deferred 的 single source of truth 切换在此 milestone 完成)

后续 M3.X → 见 Progress.md §1。

## 验收准则

完整 AC 见 [`M3-clearance.md §3`](task-plan/m3-0ad-pathfinding-migration/milestones/M3-clearance.md);Progress.md §2 由 runner 启动时镜像填入。

### 关键过线条件

- ✅ Clearance inflate 算法落地(EDT 或 brute-force,按 spec 选型)
- ✅ Validation 全套 17 项 baseline 数字 + LGF 73 + replay seed=42 deep-equal
- ✅ Baseline CSV(M3 path 变化预期 P1,接受新 baseline;详见 [risks-and-rollback §1.3](task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md))
- ✅ Perf vs M2:wall_clock ≤ +50%,tick_p99 ≤ 30 ms
- ✅ 改动仅在 `addons/logic-game-framework/example/rts-auto-battle/` 内,不动 LGF core/ stdlib/
- ✅ ✋2 体验点用户跑 demo 反馈(若 M3 含体验点)

### Stop Runner 触发条件

⚠️ **runner 启动前必读** [`task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md`](task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md) **§3 完整 9 条**(包括 perf 主指标 `tick_p99/tick_max` ≥ 100% 增长 / R5 P1 #2 dirty lifecycle invariant 违反 / R5 P1 #1 actor sort 用字典序而非 `(kind, spawn_seq)` 数值 key 等)。

任一触发立即停下问用户。**不在本文件内联枚举**(避免双源漂移),risks-and-rollback §3 是唯一权威。runner 必须显式读完该 9 条后再启动 M3.1。

## 非下一步

- ❌ 不启动 M4-M8(每个 milestone 末等 codex / 用户授权再起下一个)
- ❌ 不实现 Hierarchical / LongPath / VertexPath / Motion / Push pass(分别在 M4 / M5 / M6 / M7 / M8)
- ❌ 不修改 LGF submodule core/ 或 stdlib/(项目硬约束)
- ❌ 不主动跑 `/ultrareview` 或 commit(运行至子任务 done 时由 runner 按协议 commit)

## 等待动作

由 `/autonomous-feature-runner` 接 M3.1 起步。runner 进入后应:

1. 先读 [`task-plan/m3-0ad-pathfinding-migration/milestones/M3-clearance.md`](task-plan/m3-0ad-pathfinding-migration/milestones/M3-clearance.md)
2. **必读** [`task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md`](task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md) **§3 stop runner 9 条触发条件**
3. 顺手过 [`task-plan/m3-0ad-pathfinding-migration/data-structures.md`](task-plan/m3-0ad-pathfinding-migration/data-structures.md) §1(NavcellGrid + Passability)
4. **M2 末态 baseline 数据**:见 `Current-State.md` "测试基线" 表 — 17 项 + LGF 73 + replay seed=42 deep-equal + baseline CSV byte-identical(882882 bytes)+ 3 obstruction_manager smoke
5. 按 M3.1 → M3.X 顺序推进;每个子任务 done 时 update Progress.md(checkbox + AC 状态同步)
6. M3 全 AC 通过后:milestone-chain 协议 — 直接 archive M3 + 启动 M4

## 期间踩坑提醒(M2 阶段累积)

- **bash cwd 漂移坑** — `cd <subdir>` 不回主仓 → `godot --headless --path . *.tscn` 静默 hang。统一用 `git -C <subdir>` 取代 cd;memory `feedback_godot_cwd.md` 已记录。
- **GDScript class_name cache race** — 4 godot 并行启动新加 class_name 时第一波读旧 cache → Parse Error。**Lesson**: 新加 class_name 的 milestone 首次跑 baseline,先单跑 1 个 smoke 让 cache stabilize 再批量并行。
