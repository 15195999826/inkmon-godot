# Progress — RTS Pathfinding M3 Epic / 当前 milestone

**Status**: 🟡 M4 待启动(M0 + M1 + M2 + M3 done + archived 2026-05-04)。

**Active feature**: M4 — HierarchicalPathfinder
**完整 spec**: [`task-plan/m3-0ad-pathfinding-migration/milestones/M4-hierarchical.md`](task-plan/m3-0ad-pathfinding-migration/milestones/M4-hierarchical.md)

---

## 0. 已完成 milestones

✅ M0 done + archived(2026-05-04)— [`archive/2026-05-04-rts-m3-m0-footprint-split/Summary.md`](archive/2026-05-04-rts-m3-m0-footprint-split/Summary.md)
✅ M1 done + archived(2026-05-04)— [`archive/2026-05-04-rts-m3-m1-navcell-grid/Summary.md`](archive/2026-05-04-rts-m3-m1-navcell-grid/Summary.md)
✅ M2 done + archived(2026-05-04)— [`archive/2026-05-04-rts-m3-m2-obstruction-manager/Summary.md`](archive/2026-05-04-rts-m3-m2-obstruction-manager/Summary.md)
✅ **M3 done + archived**(2026-05-04)— [`archive/2026-05-04-rts-m3-m3-clearance/Summary.md`](archive/2026-05-04-rts-m3-m3-clearance/Summary.md)

M3 末态 baseline(M4 出发点):ObstructionManager.rasterize 两步(原 cell 占用 + clearance 外扩 inflate, brute-force / 圆形 buffer / `buffer_px = ceilf(clearance/cell)*cell`)+ procedure.tick_once `rasterize_if_dirty` 走 manager._shapes 单一数据源增量重写 NavcellGrid + R5 P1-2 dirty lifecycle invariant 落地 + NavcellGrid `_origin_world` 修坐标系错位 + 装饰 obstacle 自动注册到 manager + RtsPassabilityClassConfig.affects_pathfinding 替字符串比较;LGF 73/73 + 17 RTS smoke 全 PASS + replay seed=42 frames=11 events=20 deep-equal + baseline CSV byte-identical 829520 bytes(M2 882882 → M3 inflate 让单位绕路 path 偏移,P1 接受新 baseline)+ `smoke_clearance_inflate` 4 sub-test 全过。

---

## 1. M4 子任务 checklist

完整定义见 [`M4-hierarchical.md`](task-plan/m3-0ad-pathfinding-migration/milestones/M4-hierarchical.md) §2 子任务拆分。runner 启动 M4 时按 spec 镜像填入(M4a / M4b / M4c sub-phase 拆分,体验点 ✋2 用户审 — risks-and-rollback §1.1 + §3 重点关注 replay bit-identical)。

---

## 2. AC1-ACN 验收

由 runner 读 M4-hierarchical.md 后镜像填入。

---

## 3. 残余风险

完整列表见 M4-hierarchical.md §6 + risks-and-rollback.md;主要:
- HierarchicalPathfinder 增量更新触发逻辑跟 M3 dirty lifecycle 接口对齐
- regions Dictionary 迭代序 / GlobalRegion BFS 起点顺序 deterministic(replay 漂 P0 风险)
- canonicalize 算法路径选(spec §M4b)+ ✋2 体验点用户验收

---

## 4. 下一步动作

由 `/autonomous-feature-runner` 接 M4 起步。详见 Next-Steps.md。
