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

- [x] **M1.1** — 引入 `RtsPassabilityClassConfig`(Resource) + `RtsPassabilityClassRegistry`(RefCounted),注册 `default` / `air` 两 class ✅ **2026-05-04 done**
  - **Evidence**: `addons/.../logic/grid/rts_passability_class_config.gd`(6 字段:class_name_id / bit_index=-1 / clearance=14.0 / max_water_depth / min_water_depth / min_shore_distance);`addons/.../logic/grid/rts_passability_class_registry.gd`(RefCounted + PASS_CLASS_BITS=16 + SPECIAL_PASS_CLASS_INDEX=15 + register/get_pass_class/get_mask/max_clearance/size API;`get_pass_class` 命名避开 RefCounted 内建 `get_class()` 签名冲突)
  - **World 字段**: `RtsWorldGameplayInstance` 加 `passability_registry: RtsPassabilityClassRegistry = null`
  - **Procedure 注册**: `_init` 末尾按固定顺序 `register(default, clearance=14.0)` → `register(air, clearance=8.0)` 写 `world.passability_registry`(R5 决策:顺序固化让 mask 数字 0x1/0x2 跨 run 不漂)
  - **Verify**: LGF 73/73 PASS;`smoke_rts_auto_battle` ticks=347 attacks=74 melee=32 ranged=42 melee_max=24.00 deaths=6 detoured=4 **完全对齐 baseline,0 漂移**
  - **AC1 完整验收**(get_mask 数字 + duplicate assert_crash):留 M1.5 `smoke_navcell_grid_passability` 集体验
- [x] **M1.2** — 引入 `RtsNavcellGrid`(RefCounted),内部 `PackedInt32Array` 存 16-bit 位掩码 + `PackedByteArray` 存 dirtiness ✅ **2026-05-04 done**
  - **Evidence**: `addons/.../logic/grid/rts_navcell_grid.gd`(NAVCELL_SIZE_PX=32 + _width/_height/_data:PackedInt32Array/_dirtiness:PackedByteArray;API: get_data 边界外 -1 / is_passable 边界外 false / set_data 立即 dirty / or_data + and_data 仅值变时 dirty / mark_dirty / is_dirty / clear_dirty / width / height / navcell_center_world / nearest_navcell)
  - **Dirty lifecycle**: 显式注释 R5 P1-2 决策(rasterize/hierarchical 只读;`RtsWorld.tick` step 7 末统一 clear)
  - **Verify**: `--import` exit=0 + LGF 73/73 PASS(NavcellGrid 还未被 facade 接入,smoke 不变)
  - **AC2 完整验收**(or_data + is_passable 行为):留 M1.5 `smoke_navcell_grid_passability` 集体验
- [x] **M1.3** — `RtsBattleGrid` 改成 facade,内部委托给 `RtsNavcellGrid`(spec 假设的 `RtsCell` 类不存在 — 当前是 ultra-grid-map plugin 的 `model.is_tile_blocking`,facade 用 dual-write 同步)✅ **2026-05-04 done**
  - **Evidence**: `addons/.../logic/grid/rts_battle_grid.gd` 加 `_navcell_grid` / `_passability_registry` / `_default_class_mask` / `_half_cols` / `_half_rows` 字段;新 API: `attach_passability_registry` / `has_navcell_grid` / `get_navcell_grid` / `is_blocking(coord)` / `mark_obstacle_cell(coord)` / `unmark_obstacle_cell(coord)`;`is_passable_for_layer` 改走 `is_blocking`(NavcellGrid 路径优先,fallback model);`place_building` / `remove_building` 双写 model + NavcellGrid
  - **HexCoord ↔ NavcellGrid 偏移映射**: HexCoord 范围 [-half..+half], NavcellGrid 0-indexed → `i = coord.q + _half_cols, j = coord.r + _half_rows`
  - **生产路径迁移**: `frontend/scene/rts_battle_map.gd:48` `model.set_tile_blocking` → `mark_obstacle_cell`;`logic/commands/rts_building_placement.gd:67` `model.is_tile_blocking` → `grid.is_blocking`
  - **Backward compat**: smoke 直读 `grid.model.is_tile_blocking` 的 5 处(diag/smoke 内部断言)由 dual-write 兜底,不破
  - **Verify(NavcellGrid 未 attach 路径)**: LGF 73/73 + smoke_rts_auto_battle 0 漂移
  - **Spec drift 记录**: M1.3 AC3 "删除 cells: Dictionary[Vector2i, RtsCell]" literal 不适用(类不存在);AC3 spirit "替换 per-cell is_blocking 存储" 已通过 dual-write + NavcellGrid 接管 is_passable 查询达成
- [x] **M1.4** — `rts_auto_battle_procedure.gd` 启动时初始化 PassabilityRegistry + NavcellGrid;footprint placement 在新 grid 上正确刷写 default class bit ✅ **2026-05-04 done**
  - **Evidence**: procedure._init 末尾 `world.rts_grid.attach_passability_registry(world.passability_registry)`;attach 时按 `model.get_all_coords()` 同步已有 obstacle cells(frontend `_ready` 在 procedure._init 之前调 `mark_obstacle_cell` 时 NavcellGrid 还未 attach,sync 兜底)
  - **AC4 验收**: smoke 跑后 `world.rts_grid.has_navcell_grid()` == true(NavcellGrid 已接管查询)
  - **AC9 验收**: `GridPathfinding.find_path` → `grid.is_passable_for_layer` → `grid.is_blocking` → NavcellGrid.is_passable;路径输出与 M0 bit-identical
  - **关键漂移修复**: 第一次 attach 漏 sync 已有 model obstacle → AC2 violated(单位走穿 obstacle 墙) → 加 `model.get_all_coords()` 扫描 sync 修复
  - **Verify**: LGF 73/73 + smoke_rts_auto_battle ticks=347 attacks=74 0 漂移 + smoke_castle_war_minimal ticks=193 + **smoke_replay_bit_identical seed=42 frames=9 events=20 deep-equal**(determinism 关键过线)+ smoke_player_command PASS(双写 backward compat 验证)
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
