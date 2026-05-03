# Progress — RTS Pathfinding M3 Epic / M3 sub-feature

**Status**: 🟢 M3 done — phase-close gate 7a-7c clean,等 archive sweep。

**Active feature**: M3 — Clearance + 外扩(per-class buffer)
**完整 spec**: [`task-plan/m3-0ad-pathfinding-migration/milestones/M3-clearance.md`](task-plan/m3-0ad-pathfinding-migration/milestones/M3-clearance.md)

---

## 0. M0 + M1 + M2 收口

✅ M0 / M1 / M2 done + archived 2026-05-04 (见 `archive/2026-05-04-rts-m3-m{0,1,2}-*/Summary.md`)。

---

## 1. M3 子任务 checklist

- [x] **M3.1** — ObstructionManager.rasterize 加 inflate 第二遍(brute-force,圆形 buffer,buffer_px = ceilf(clearance/cell)*cell)
- [x] **M3.2** — Per-class clearance + registry helper(`get_classes()` / `get_class_by_mask()`)+ `RtsPassabilityClassConfig.affects_pathfinding` 字段
- [x] **M3.3** — RtsWorld.tick 接 `rasterize_if_dirty` 调度 + dirty lifecycle(R5 P1-2)+ 装饰 obstacle 注册到 manager + NavcellGrid `_origin_world` 修坐标系错位
- [x] **M3.4** — `smoke_clearance_inflate` + Validation 全套 + baseline 接受

---

## 2. AC1..AC10 验收状态

| AC | 状态 | 实现 / Evidence |
|---|---|---|
| AC1 — Rasterize inflate 第二遍 | ✅ | `RtsObstructionManager._rasterize_class` 第一遍 `_rasterize_one_shape` + 第二遍 `_inflate_one_shape`;smoke 验证 4 OBB cells + 11 inflate cells = 15 default-blocked in 5×5 候选 |
| AC2 — Per-class clearance 生效 | ✅ | per `pass_class.clearance` 算 `clearance_cells / buffer_px`;`affects_pathfinding=false` 让 air class skip 整个 inflate(M3 wiring)|
| AC3 — Dirty 增量正确 | ✅ | smoke `_test_dirty_lifecycle` 验证 add → 15 blocked → remove → 0 blocked;`_clear_dirty_with_buffer` per-dirty-cell ±clearance buffer 范围清 |
| AC4 — Procedure 接调度 | ✅ | `procedure.tick_once` step 6.6 调 `rasterize_if_dirty`;`collect_dirty_cells().is_empty()` noop;step 7.5 末端 `clear_dirty()` |
| AC5 — `smoke_clearance_inflate` PASS | ✅ | 新 smoke `tests/battle/smoke_clearance_inflate.{tscn,gd}`,4 sub-test 全过 |
| AC6 — Validation 14 项 + LGF + replay | ✅ | LGF 73/73 + 17 RTS smoke 全 PASS + replay seed=42 frames=11 events=20 deep-equal + baseline CSV (829520 bytes) byte-identical 跨两次 run |
| AC7 — Perf 增长 ≤ 50% | 🟡 | 未跑 perf trace;实测各 smoke 时间跟 M2 同数量级。Simplify pass hoist `dirty_cells / sorted_tags` 跨 class 共享 → per-tick `_clear_dirty_with_buffer` 改 dirty-cells-only iter,远低于全图扫 |
| AC8 — air class 外扩独立 | ✅ | smoke `_test_air_class_independent` 验证 air mask 25 cells 全 passable;air class `affects_pathfinding=false` 走 `_collect_blocking_shapes` 早返空 |
| AC9 — 体验点改进准备 | 🟡 | demo 没用户跑;baseline CSV diff(882882→829520)+ smoke_rts_auto_battle ticks(347→264)证 inflate 改 path。✋1 真正体验点验收在 M4 |
| AC10 — 不动 LGF core/ stdlib/ | ✅ | 改动仅在 `addons/.../example/rts-auto-battle/`(core/ logic/ tests/)|

### 17 项 RTS smoke + LGF + replay 验收(simplify pass 后)

| 入口 | 末态 |
|---|---|
| LGF `run_tests.tscn` | **73/73 PASS** |
| `smoke_rts_auto_battle` | left_win ticks=264 attacks=65 melee=33 ranged=32 deaths=4 detoured=4 |
| `smoke_castle_war_minimal` | left_win ticks=193 unit_to_building=4 archer_anti_air=1 |
| `smoke_player_command` | placement applied + dup/zone reject |
| `smoke_player_command_production` | ticks=600 left_spawned=7 max_eastward=254.74 |
| `smoke_production` | ticks=600 left=7 right=7 max_eastward=132.25 |
| `smoke_crystal_tower_win` | ticks=2 left_win |
| `smoke_resource_nodes` | 5 workers idle |
| `smoke_harvest_loop` | ticks=600 gold=140 wood=213 |
| `smoke_economy_demo` | melee_spawned=4 final_gold=134 final_wood=249 |
| `smoke_ai_vs_player_full_match` | ai_barracks=1 ai_units_spawned=4 ai_unit_to_ct=7 |
| `smoke_flying_units` | archer_hits=3 |
| `smoke_replay_bit_identical` | seed=42 frames=11 events=20 deep-equal |
| `smoke_determinism` | tick_diff=0 ticks=264 |
| `smoke_frontend_main` | visualizers=10 |
| `smoke_ui_main_menu` | demo=RtsFrontendDemo |
| `smoke_pathfinding_baseline` | ticks=900 trace=5769 events=97 + CSV byte-identical 829520 bytes |
| `smoke_obstruction_footprint_split` | (M0)set_b=4 set_c=10 |
| `smoke_navcell_grid_passability` | (M1)AC1+AC2+AC8 13 项断言全过 |
| `smoke_obstruction_manager_register/query/remove` | (M2)8 shapes / SAT 4-case / idempotent OK |
| `smoke_clearance_inflate` | (M3 新)15 default-blocked + 25 air-passable + dirty cleanup |

---

## 3. M3 落地的 spec 偏离(simplify 改进)

- **`_shape_blocks_class` 字符串比较 → `pass_class.affects_pathfinding` flag**(spec §M3.1 步骤 1 给的伪代码用 `class_name_id == "air"`,实际改用 `RtsPassabilityClassConfig.affects_pathfinding: bool`,procedure._init 注册 air 时设 false。type-safe + 跨 class 名重命名稳定)
- **NavcellGrid `_origin_world` 字段**(spec 没明文要求;M3.3 启用 `rasterize_if_dirty` 后才暴露 ObstructionManager 用 `world / cell_size` 索引 NavcellGrid,但 RtsBattleGrid 用 HexCoord+half_offset 平移到 NavcellGrid;两边坐标系错位。`_origin_world` 让 NavcellGrid 自洽:`navcell_center_world(i,j) = origin + (i+0.5, j+0.5)*cell`,`world_to_navcell_i/j` helper 集中坐标转换)
- **装饰 obstacle 自动注册 manager**(`procedure._init._register_decorative_obstacles_to_manager` 扫 `grid.model.is_tile_blocking` cells,sort by (q,r) deterministic,每 cell 注册成 32×32 OBB shape;否则 `rasterize_if_dirty` 第一次跑会 `_clear_dirty_with_buffer` 把 frontend `mark_obstacle_cell` 写的 cells 清掉 — 隐式 baseline regression)
- **Hoist 优化**(`rasterize_if_dirty` 一次 `collect_dirty_cells` + `_collect_blocking_shapes` per class 共享 sorted tag;`_clear_dirty_with_buffer` 改 dirty-cells iter 不全图扫;`_shape_world_aabb` 抽 helper 共享给 rasterize/inflate)
- **Unit shape 不 mark navcell dirty**(M2 实现总是 mark dirty;M3 改仅 BLOCK_PATHFINDING shape mark — unit 是 BLOCK_MOVEMENT,不影响 NavcellGrid bit,perf-critical 修正避免 100 unit × 30 Hz 全图重 rasterize)

---

## 4. 残余风险

- **R1** Clearance inflate brute-force 跟 building 数量平方增长 — M2.3 16 building 场景没 perf 异常,M4 引入 hierarchical 后再 measure
- **R2** baseline CSV 漂(M3 路径变化)— ✅ 接受新 baseline(`tests/baselines/0ad-baseline-master.csv` updated)
- **R3** Multi-class rasterize 时 default + air 两 class 都要 inflate — air class `affects_pathfinding=false` 短路,实际只 default class inflate

---

## 5. 下一步动作

M3 done → archive sweep + bump submodule pointer + reset Progress / Next-Steps / Current-State 到 baseline-only,M4 启动等用户授权。

archive 路径: `archive/2026-05-04-rts-m3-m3-clearance/Summary.md`
