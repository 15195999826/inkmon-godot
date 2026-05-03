# Progress — RTS Pathfinding M3 Epic / M1 sub-feature

**Status**: 🟡 M1 active(M0 已 done + archived 2026-05-04;runner 起步 M1.1)。

**Active feature**: M1 — Navcell Grid + 16-bit Passability Class
**完整 spec**: [`task-plan/m3-0ad-pathfinding-migration/milestones/M1-navcell-grid.md`](task-plan/m3-0ad-pathfinding-migration/milestones/M1-navcell-grid.md)

---

## 0. M0 收口

✅ **M0 已 done + archived**(2026-05-04)— 详见 [`archive/2026-05-04-rts-m3-m0-footprint-split/Summary.md`](archive/2026-05-04-rts-m3-m0-footprint-split/Summary.md)。

M0 末态 baseline(M1 出发点):3 obstruction shape data class + RtsBuildingActor 双路径 get_footprint_cells + RtsBuildings 工厂注入 + 6 sync sites + Placement core helper + frontend visualizer 选择圈走 footprint_shape;14+1 项 smoke + LGF 73 + replay seed=42 deep-equal + baseline CSV byte-identical 全过。

---

## 1. M1 子任务 checklist (M1.1 → M1.5)

完整定义见 [`M1-navcell-grid.md §2`](task-plan/m3-0ad-pathfinding-migration/milestones/M1-navcell-grid.md)。

- [ ] **M1.1** — 引入 `RtsPassabilityClassConfig`(Resource) + `RtsPassabilityClassRegistry`(RefCounted),注册 `default` / `air` 两 class
- [ ] **M1.2** — 引入 `RtsNavcellGrid`(RefCounted),内部 `PackedInt32Array` 存 16-bit 位掩码 + `PackedByteArray` 存 dirtiness
- [ ] **M1.3** — `RtsBattleGrid` 改成 facade,内部委托给 `RtsNavcellGrid`(旧 `cells: Dictionary[Vector2i, RtsCell]` 移除)
- [ ] **M1.4** — `rts_auto_battle_procedure.gd` 启动时初始化 PassabilityRegistry + NavcellGrid;footprint placement 在新 grid 上正确刷写 default class bit
- [ ] **M1.5** — 新 smoke `smoke_navcell_grid_passability` + Validation 全套 14+1 项 0 漂移 + commit

---

## 2. AC1-AC10 验收(完整定义见 M1.md §3)

- [ ] **AC1** — Registry 注册 `default`/`air` 两 class,`get_mask("default")==0x1` / `get_mask("air")==0x2`,duplicate 时 assert_crash
- [ ] **AC2** — `RtsNavcellGrid` 落地,`or_data`/`and_data` 改 bit、`is_passable` 边界外返 false
- [ ] **AC3** — `RtsBattleGrid` facade 改造完成,旧 `cells` Dict 删除;公开 API 行为与 M0 末态等价
- [ ] **AC4** — Procedure 启动后 `rts_world.passability_registry` / `rts_world.rts_grid._navcell_grid` 非 null
- [ ] **AC5** — `smoke_navcell_grid_passability` PASS(default vs air 不互相影响)
- [ ] **AC6** — Validation 全套 14 项 0 漂移 + LGF 73/73 + replay seed=42 deep-equal + baseline CSV byte-identical(M1 不引入 trace 新字段)
- [ ] **AC7** — Perf vs M0:wall_clock ≤ +50%,tick_p99 ≤ 30 ms
- [ ] **AC8** — Multi-class 不互相干扰(smoke 自动验)
- [ ] **AC9** — 现有 `GridPathfinding.find_path` 内部改 `grid.is_blocking(c)`,路径输出与 M0 bit-identical
- [ ] **AC10** — 改动仅在 `addons/logic-game-framework/example/rts-auto-battle/` 内,不动 LGF core/ stdlib/

---

## 3. 残余风险(M1 启动前预判,详见 M1.md §6)

- **R1** PackedInt32Array 越界 → `is_passable` 边界外 false 兜底
- **R2** 旧 `cells: Dictionary` 删除时残留引用 → grep `RtsCell` 全删 + facade API 全 delegate
- **R3** Replay 漂(navcell 写顺序非 deterministic)→ R5 P1-1 contract 强制(kind, spawn_seq) 数值 key
- **R4** Perf 退化 → AC7 perf-trace.csv 比对兜底

---

## 4. 下一步动作(给 runner)

1. 读 [`M1-navcell-grid.md`](task-plan/m3-0ad-pathfinding-migration/milestones/M1-navcell-grid.md) §0 + §2 + §3 + §6
2. **必读** [`risks-and-rollback.md §3`](task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md) stop runner 9 条触发条件
3. 顺手过 [`data-structures.md §1`](task-plan/m3-0ad-pathfinding-migration/data-structures.md)(Grid 层 PassabilityClassConfig / Registry / NavcellGrid 字段定义)
4. 按 M1.1 → M1.5 顺序推进
5. 每子任务 done 时 update 本文件(checkbox + AC 状态)
6. M1 全 AC 通过后 stop runner 等用户 ✋(若 spec 标记需要)或直接 archive M1 + 启动 M2(milestone-chain 协议见 task-plan/README §收口条件)
