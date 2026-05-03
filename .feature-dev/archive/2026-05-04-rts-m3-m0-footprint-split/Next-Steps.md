# Next Steps — 2026-05-03 (M3 Epic / M0 全 AC 通过, 等用户 ✋1 体验点)

## 当前目标

**RTS Pathfinding M3 Epic — M0 sub-feature**: Footprint / Obstruction shape 拆分 + Bug 1 修复 — **代码侧全部完成,Validation 全套 PASS,等用户 F6 demo 验收 ✋1 录屏后 archive M0 + 启动 M1**。

> M3 Epic = "RTS 寻路全面迁移到 0 A.D. 方案",分 9 个 milestone(M0-M8)+ Formation 推到下个 Epic。
> Epic 总览见 [`task-plan/m3-0ad-pathfinding-migration/README.md`](task-plan/m3-0ad-pathfinding-migration/README.md)。
> Epic 经过 codex Round 1-8 审查,Step A + Step B 全部 APPROVE,Step C 实施期 M0 收口。

**当前 active sub-feature = M0**(完整 spec: [`task-plan/m3-0ad-pathfinding-migration/milestones/M0-footprint-split.md`](task-plan/m3-0ad-pathfinding-migration/milestones/M0-footprint-split.md))。

## 下一步

**M0.1 - M0.7 全 done**(7/7 子任务通过 + 5 项 AC1-AC5 + AC6 + AC7 + AC8 + AC10 全 PASS;AC9 logic 侧验证通过,UI click-to-select 等 M2.3 后续 polish)。

**等用户 ✋1 体验点**(stop runner 由用户解锁):

1. F6 跑 `addons/logic-game-framework/example/rts-auto-battle/frontend/demo_rts_frontend.tscn`(编辑器手验)
2. 进 build mode (左下角 BuildPanel 点 Barracks 或 Archer Tower) → 鼠标 hover 看 ghost 高亮
3. 放 1 个 barracks + 1 个 archer_tower 不同位置
4. spawn 4-6 个单位绕走(可点 minimap 让单位移动)
5. 视觉确认:**ghost 占地高亮 = 放下后 obstruction 占地 = 单位实际绕走 cells** 三者一致(客观 smoke 已严格断言, 体验点是直观确认)
6. 录屏 `0ad-migration-M0-after.mp4`(本地留底, 不进 git)
7. 反馈通过 → archive M0 + 启动 M1 (Navcell Grid + 16-bit Passability)

> **诚实告知**: M0 完成时 sprite 锚点未变 (F4 决策 A),所以视觉差异有限;真正"贴墙绕角不穿建筑 sprite"完整体感需 M6 vertex pathfinder 加 32px 亚 cell 精度才能完成。M0 的 Bug 1 修复体现在"ghost / placed / path 三者 cells 精确一致" — 这是后续 M2-M6 的基础。

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
