# Next Steps — 2026-05-03 (M3 Epic / M0.6 下一步)

## 当前目标

**RTS Pathfinding M3 Epic — M0 sub-feature**: Footprint / Obstruction shape 拆分 + Bug 1 修复(单位绕建筑 sprite 视觉对齐前置)。

> M3 Epic = "RTS 寻路全面迁移到 0 A.D. 方案",分 9 个 milestone(M0-M8)+ Formation 推到下个 Epic。
> Epic 总览见 [`task-plan/m3-0ad-pathfinding-migration/README.md`](task-plan/m3-0ad-pathfinding-migration/README.md)。
> Epic 经过 codex Round 1-8 审查,Step A + Step B 全部 APPROVE,可进 Step C/D 实施。

**当前 active sub-feature = M0**(完整 spec: [`task-plan/m3-0ad-pathfinding-migration/milestones/M0-footprint-split.md`](task-plan/m3-0ad-pathfinding-migration/milestones/M0-footprint-split.md))。

## 下一步

按 M0.md §2 子任务顺序:**M0.1 - M0.5 全 done**(baseline + data class + StatBlock 4 字段 + actor 字段 / 算法 + 工厂注入 + 6 sync sites + Placement core helper 抽取 + replay 0 漂移)→ 进 **M0.6 — Frontend visualizer 选择圈 / ghost 渲染对齐**:

1. `frontend/visualizers/rts_building_visualizer.gd`:
   - sprite 锚点保持 `actor.position_2d` 不变(F4 决策 A,M2.3 既有逻辑不动)
   - 选择圈渲染(P2.x M2.3 加的)切到用 `actor.footprint_shape.get_world_aabb(actor.position_2d)` 算外接矩形
2. `frontend/visualizers/rts_unit_visualizer.gd`:
   - sprite 锚点 = position_2d 不变(M0 单位无 footprint_shape;选择圈走 actor.collision_radius)
3. ghost cells 高亮(可选 — 现 ghost 是 ColorRect 不是 cells,M0.5 已切到 obstruction_size,M0.6 看是否需进一步用 cells 高亮)

**完成标志**:
- demo_rts_frontend F6 跑(编辑器手验),sprite 渲染位置不变(玩家看不出移位)
- 玩家鼠标点击 sprite 中心仍能选中建筑(footprint_shape.contains 正确)
- ghost 占地高亮跟最终 obstruction 占地一致(M0.5 已通过 obstruction_size + offset 对齐)

完整步骤见 M0.md §M0.6。M0.6 完成后接 M0.7(新 smoke + Validation 全套 14 项 + commit + 体验点 ✋1 录屏)。

## 验收准则

### 必过(M0 完成标志,详细见 M0.md §3 AC1-AC10)

- ✅ 3 个 data class (`RtsObstructionShape` 基类 + Static + Footprint) 落地,`--import` 通过
- ✅ `RtsBuildingActor.get_footprint_cells` 改用 `obstruction_shape.center` 算 cells;`obstruction_offset = ZERO` 时跟旧实现 bit-identical
- ✅ `RtsBuildings` 工厂 + 6 个 sync_obstruction_shape() call sites(含 production:5 个 + match preset)全部接入
- ✅ Frontend visualizer:sprite 锚点保持 `actor.position_2d` 不变;选择圈 + ghost cells 高亮走 footprint_shape / obstruction_shape
- ✅ 新 smoke `smoke_obstruction_footprint_split` PASS:验证 ghost cells == placed cells == unit path cells (Set A == Set B 且 B ∩ C = ∅)
- ✅ Validation 全套 0 漂移:14 项 smoke 数字 byte-identical(ticks=347 attacks=74 melee=32 ranged=42 melee_max=24.00 等)+ LGF 73/73 + replay seed=42 frames=9 events=20 deep-equal
- ✅ baseline CSV byte-identical(M0 不改 trace 字段;rerun 同 seed = 上轮 baseline)
- ✅ 不动 LGF submodule core/ 或 stdlib/

### 体验点 ✋1 (M0 完成时,stop runner 等用户)

用户 F6 跑 `frontend/demo_rts_frontend.tscn`:
- 进 build mode,鼠标 hover 看 ghost 高亮
- 放下 1 个 barracks + 1 个 archer_tower
- spawn 4-6 单位绕走
- 验证视觉:**ghost 高亮 cells = 放下后 obstruction cells = 单位绕走 cells** 三者一致(客观 smoke 已验,体验点是直观确认)
- 录屏 `0ad-migration-M0-after.mp4`(本地留底,不进 git)

> 完整"贴墙绕角不穿建筑 sprite"体感等 ✋3 (M6) — M0 不期望此效果。

### Stop Runner 触发条件

⚠️ **runner 启动前必读** [`task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md`](task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md) **§3 完整 9 条**(包括 perf 主指标 `tick_p99/tick_max` ≥ 100% 增长 / R5 P1 #2 dirty lifecycle invariant 违反 / R5 P1 #1 actor sort 用字典序而非 `(kind, spawn_seq)` 数值 key 等)。

任一触发立即停下问用户。**不在本文件内联枚举**(避免双源漂移),risks-and-rollback §3 是唯一权威。runner 必须显式读完该 9 条后再启动 M0.2。

## 非下一步

- ❌ 不启动 M1-M8(每个 milestone 末等 codex / 用户授权再起下一个)
- ❌ 不实现 ObstructionManager / Pathfinder / Hierarchical / Formation(分别在 M2 / M5-M6 / M4 / 下个 Epic)
- ❌ 不修改 LGF submodule core/ 或 stdlib/(项目硬约束)
- ❌ 不主动跑 `/ultrareview` 或 commit(运行至子任务 done 时由 runner 按协议 commit)

## 等待动作

由 `/autonomous-feature-runner` 接 M0.2 起步。runner 进入后应:

1. 先读 [`task-plan/m3-0ad-pathfinding-migration/milestones/M0-footprint-split.md`](task-plan/m3-0ad-pathfinding-migration/milestones/M0-footprint-split.md) **顶部 Status block + §2 子任务 + §3 AC + §5 子任务进度 + §6 风险**(完整 spec ~35 KB,token-conscious 可只读这几节;状态指明 M0.1 ✅ done / M0.2 ⏭️ 下一步)
2. **必读** [`task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md`](task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md) **§3 stop runner 9 条触发条件**(本 Next-Steps 不内联,避免双源漂移)
3. 顺手过 [`task-plan/m3-0ad-pathfinding-migration/data-structures.md`](task-plan/m3-0ad-pathfinding-migration/data-structures.md) §2 + §3(Obstruction / Footprint shape 字段定义)
4. **Step B 实施前置 grep**(R5/R6 反馈记录中提醒): `tests/**/*.gd` 中 `create_*` 后直调 `get_footprint_cells()` 的 diagnostics/smoke 路径(M0.5 sync 6 个 call sites 之外可能还有)
5. 按 M0.2 → M0.3 → M0.4 → M0.5 → M0.6 → M0.7 顺序推进;每个子任务 done 时 update Progress.md(包括 M0.md §5 + AC 状态同步,避免双源漂移)
6. M0 全部 AC 通过后 stop runner 等用户 ✋1 体验点反馈
7. ✋1 通过后才 archive M0 + 启动 M1
