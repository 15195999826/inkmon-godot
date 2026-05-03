# Progress — RTS Pathfinding M3 Epic / M3 sub-feature

**Status**: 🟡 M3 active(M0 + M1 + M2 已 done + archived 2026-05-04;runner 起步 M3.1)。

**Active feature**: M3 — Clearance + 外扩(per-class buffer)
**完整 spec**: [`task-plan/m3-0ad-pathfinding-migration/milestones/M3-clearance.md`](task-plan/m3-0ad-pathfinding-migration/milestones/M3-clearance.md)

---

## 0. M0 + M1 + M2 收口

✅ **M0 done + archived**(2026-05-04)— [`archive/2026-05-04-rts-m3-m0-footprint-split/Summary.md`](archive/2026-05-04-rts-m3-m0-footprint-split/Summary.md)
✅ **M1 done + archived**(2026-05-04)— [`archive/2026-05-04-rts-m3-m1-navcell-grid/Summary.md`](archive/2026-05-04-rts-m3-m1-navcell-grid/Summary.md)
✅ **M2 done + archived**(2026-05-04)— [`archive/2026-05-04-rts-m3-m2-obstruction-manager/Summary.md`](archive/2026-05-04-rts-m3-m2-obstruction-manager/Summary.md)

M2 末态 baseline(M3 出发点):5 个 obstruction 数据/算法类(Flags + TestFilter + ShapeUnit + SpatialIndex + Manager)+ 完整 SAT 4 轴 OBB-OBB(R1)+ Building / Unit 链路接 manager(dual-write 兼容;Death unregister deferred 到 M5);17 项 RTS smoke + LGF 73 + replay seed=42 deep-equal + baseline CSV byte-identical(882882 bytes)+ 3 新 obstruction_manager smoke 全过。

---

## 1. M3 子任务 checklist (M3.1 → M3.X)

完整定义见 [`M3-clearance.md`](task-plan/m3-0ad-pathfinding-migration/milestones/M3-clearance.md) §2。

子任务由 runner 启动 M3.1 时按 spec 拆分;预期主轴包含:
- per-class clearance buffer 注入 RtsPassabilityClassConfig
- ObstructionManager.rasterize 启用 dirty_only=true 增量(M2 已 ready)
- EDT 或 brute-force inflate 算法选型
- 切 pathfinder 走 manager 数据(M2 deferred 的 baseline 漂在此 milestone 一次性接受)

---

## 2. AC1-ACN 验收(完整定义见 M3.md §3)

由 runner 读 M3-clearance.md 后镜像填入。

---

## 3. 残余风险(M3 启动前预判,详见 M3.md §6)

- **R1** Clearance inflate brute-force 跟 building 数量平方增长(perf)
- **R2** baseline CSV 漂(M3 引入 path 变化预期 P1,详见 risks-and-rollback §1.3)
- **R3** Multi-class rasterize 时 default + air 两 class 都要 inflate

---

## 4. 下一步动作(给 runner)

1. 读 [`M3-clearance.md`](task-plan/m3-0ad-pathfinding-migration/milestones/M3-clearance.md)(完整 spec)
2. **必读** [`risks-and-rollback.md §3`](task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md) stop runner 9 条触发条件
3. 顺手过 [`data-structures.md §1`](task-plan/m3-0ad-pathfinding-migration/data-structures.md)(NavcellGrid + per-class clearance)
4. 按 M3.1 → M3.X 顺序推进
5. 每子任务 done 时 update 本文件(checkbox + AC 状态)
6. M3 全 AC 通过后:milestone-chain 协议 → archive M3 + 启动 M4(详见 task-plan/README §收口条件)
