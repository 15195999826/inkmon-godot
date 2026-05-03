# Progress — RTS Pathfinding M3 Epic / M2 sub-feature

**Status**: 🟡 M2 active(M0 + M1 已 done + archived 2026-05-04;runner 起步 M2.1)。

**Active feature**: M2 — ObstructionManager (Shape 数据库)
**完整 spec**: [`task-plan/m3-0ad-pathfinding-migration/milestones/M2-obstruction-manager.md`](task-plan/m3-0ad-pathfinding-migration/milestones/M2-obstruction-manager.md)

---

## 0. M0 + M1 收口

✅ **M0 done + archived**(2026-05-04)— [`archive/2026-05-04-rts-m3-m0-footprint-split/Summary.md`](archive/2026-05-04-rts-m3-m0-footprint-split/Summary.md)
✅ **M1 done + archived**(2026-05-04)— [`archive/2026-05-04-rts-m3-m1-navcell-grid/Summary.md`](archive/2026-05-04-rts-m3-m1-navcell-grid/Summary.md)

M1 末态 baseline(M2 出发点):3 个 grid 数据类(PassabilityClassConfig + Registry + NavcellGrid)+ `RtsBattleGrid` facade(dual-write model + NavcellGrid;`is_blocking` / `mark_obstacle_cell` / `_coord_to_ij` helper)+ procedure 启动注册 default/air + attach grid;14 项 smoke + LGF 73 + replay seed=42 deep-equal + baseline CSV byte-identical(882882 bytes)+ 新 navcell smoke 全过。

---

## 1. M2 子任务 checklist (M2.1 → M2.6)

完整定义见 [`M2-obstruction-manager.md §2`](task-plan/m3-0ad-pathfinding-migration/milestones/M2-obstruction-manager.md)。

- [ ] **M2.1** — `RtsObstructionFlags` 完整枚举(6 flag) + `RtsObstructionTestFilter` 抽象基类 + 3 静态工厂方法
- [ ] **M2.2** — `RtsSpatialIndex`(uniform grid bucket,256 px / bucket)
- [ ] **M2.3** — `RtsObstructionManager` 单例(autoload 或挂 GameWorld);`add_unit_shape` / `add_static_shape` / `move_shape` / `remove_shape` / `get_obstructions_in_range` API
- [ ] **M2.4** — Building placement 链路改造:`RtsBuildingPlacement.apply` 内部 `add_static_shape` → 拿 tag → `rasterize` 写 NavcellGrid;替换 `RtsBattleGrid.place_building`
- [ ] **M2.5** — Unit spawn / move / death 链路改造:`RtsCharacters._create_unit` 内部 `add_unit_shape` 存 actor.obstruction_tag;每 tick `move_shape(tag, new_pos)`;death 调 `remove_shape`
- [ ] **M2.6** — 新 smoke 3 个(`smoke_obstruction_manager_register / _query / _remove`)+ Validation 全套 + commit

---

## 2. AC1-AC10 验收(完整定义见 M2.md §3)

- [ ] **AC1** — `RtsObstructionFlags` 完整枚举(BLOCK_FOUNDATION / BLOCK_CONSTRUCTION / BLOCK_PATHFINDING / BLOCK_MOVEMENT / DELETE_UPON_CONSTRUCTION / IS_FOUNDATION 等 6 flag)
- [ ] **AC2** — `RtsObstructionTestFilter` 抽象 + 3 工厂(by_class / exclude_self / merging_friendly_units)
- [ ] **AC3** — `RtsSpatialIndex` uniform grid bucket(256 px / bucket;add/remove/move/query)
- [ ] **AC4** — `RtsObstructionManager` 单例落地(API 完整 + tag 唯一 + spatial index 同步)
- [ ] **AC5** — Building placement 走 ObstructionManager(`add_static_shape` 取代 `place_building`;rasterize 写 NavcellGrid 默认 mask bit)
- [ ] **AC6** — Unit spawn / move / death 走 ObstructionManager(M2 阶段 unit shape 是圆,clearance 取自 `RtsUnitClassConfig`)
- [ ] **AC7** — 3 个 smoke PASS(register / query / remove)
- [ ] **AC8** — Validation 全套 14 项 + LGF 73 + replay seed=42 deep-equal + baseline CSV(M2 引入 Obstruction trace 字段从占位变实填,**预期 P2 接受新 baseline**;详见 risks-and-rollback §1.3)
- [ ] **AC9** — Perf vs M1:wall_clock ≤ +50%,tick_p99 ≤ 30 ms
- [ ] **AC10** — 改动仅在 `addons/logic-game-framework/example/rts-auto-battle/` 内,不动 LGF core/ stdlib/

---

## 3. 残余风险(M2 启动前预判,详见 M2.md §6)

- **R1** Spatial index bucket size 选 256 px:不够小则 query O(N²) 劣化、不够大则 bucket 数太多。256 px = 8 cell,平衡 100 单位规模。
- **R2** ObstructionManager iteration 序非 deterministic → replay 漂(R5 P1 决策:用 `tag` 数值排序,`tag` 自增 monotonic)
- **R3** rasterize 步进:M2 阶段 building OBB rasterize 用扫描线;clearance 外扩留 M3
- **R4** baseline CSV 漂(M2 引入 obstruction trace 字段从占位 -1 / "" 变实填)→ **P2 预期变化**,接受新 baseline(详见 risks-and-rollback §1.3)
- **R5** unit obstruction_tag 与现有 actor.obstruction_shape 双源 → tag 是 ObstructionManager 内部映射,actor 字段保持向后兼容

---

## 4. 下一步动作(给 runner)

1. 读 [`M2-obstruction-manager.md`](task-plan/m3-0ad-pathfinding-migration/milestones/M2-obstruction-manager.md) §0 + §1 + §2 子任务 + §3 AC + §6 风险
2. **必读** [`risks-and-rollback.md §3`](task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md) stop runner 9 条触发条件
3. 顺手过 [`data-structures.md §2`](task-plan/m3-0ad-pathfinding-migration/data-structures.md)(Obstruction 层 Flags / Filter / SpatialIndex / Manager 字段定义)
4. 按 M2.1 → M2.6 顺序推进
5. 每子任务 done 时 update 本文件(checkbox + AC 状态)
6. M2 全 AC 通过后:milestone-chain 协议 → archive M2 + 启动 M3(详见 task-plan/README §收口条件)
