# Current State — 2026-05-04 baseline (M3 Epic / M0 + M1 + M2 done; M3 active)

inkmon-godot baseline 事实快照. M3 Epic / M3 启动用.

> **Active feature**: M3 Epic / M3 (Clearance + 外扩).
>
> **M0 + M1 + M2 sub-feature**: ✅ 整体完成 + archived
> - M0 (Footprint 拆分) → `archive/2026-05-04-rts-m3-m0-footprint-split/`
> - M1 (Navcell Grid + Passability) → `archive/2026-05-04-rts-m3-m1-navcell-grid/`
> - M2 (ObstructionManager + Spatial Index) → `archive/2026-05-04-rts-m3-m2-obstruction-manager/`
>
> **M3 Epic 状态**: codex Round 1-8 APPROVE + M0 + M1 + M2 done + 17 项 baseline 0 漂移 + replay deep-equal + baseline CSV byte-identical + 3 新 obstruction_manager smoke 全过.
>
> phase 实现细节 / 决策来源 → 见对应 archive 的 `Summary.md` 或 `task-plan/m3-0ad-pathfinding-migration/`.

---

## 工程结构

- 主仓 `D:\GodotProjects\inkmon\inkmon-godot`,Godot 4.6 项目
- `addons/` 是单一 git submodule (→ `godot-addons.git`),含 3 个 addon:`logic-game-framework` / `lomolib` / `ultra-grid-map`
- 主仓 entry:`scenes/Simulation.tscn` + `scripts/SimulationManager.gd` (Web/headless 桥接)
- `project.godot` autoload:`Log` / `IdGenerator` / `GameWorld` / `TimelineRegistry` / `WaitGroupManager` / `ItemSystem` / `UGridMap` / `RtsRng`

## 当前 baseline 能力 (M2 末态 = M3 出发点)

M2 末态 RTS 完整可玩 1v1 skirmish + AI vs AI 观战 demo 之上,M0 + M1 + M2 增量:

### M0 增量(2026-05-04)

- 3 obstruction shape data class:`RtsObstructionShape` 基类 + `Static` 子类(width/height/rotation_rad + get_corners + get_axes)+ `RtsFootprintShape`(CIRCLE/SQUARE + contains + get_world_aabb)
- `RtsBuildingActor` 双路径 `get_footprint_cells` + `sync_obstruction_shape`
- `RtsBuildingConfig.StatBlock` 4 新字段(obstruction_size / obstruction_offset / footprint_shape_type / selection_footprint_size)+ fallback 派生
- `RtsBuildings` 工厂 + 6 个 sync sites + Placement core helper + frontend visualizer 选择圈走 footprint_shape

### M1 增量(2026-05-04)

- 3 个 grid 数据类:`RtsPassabilityClassConfig`(Resource, 6 字段)+ `RtsPassabilityClassRegistry`(RefCounted, PASS_CLASS_BITS=16, register / get_pass_class / get_mask / max_clearance / size)+ `RtsNavcellGrid`(RefCounted, `_data: PackedInt32Array` + `_dirtiness: PackedByteArray`;or_data/and_data/is_passable/边界外 false / dirty lifecycle)
- `RtsBattleGrid` 改 facade:`_navcell_grid` + `_passability_registry` + `_default_class_mask` + `_half_cols`/`_half_rows` 字段;`attach_passability_registry` + `is_blocking` + `mark_obstacle_cell` + `_coord_to_ij` helper;dual-write model + NavcellGrid
- procedure._init 末按固定顺序 `register("default", clearance=14.0)` → `register("air", clearance=8.0)`(R5 决策:顺序固化让 mask 数字 0x1/0x2 跨 run 不漂);`attach_passability_registry` 到 grid

### M2 增量(2026-05-04)

- 5 个 obstruction 数据 / 算法类:`RtsObstructionFlags`(6 flag 常量)+ `RtsObstructionTestFilter`(抽象 + 3 inner class + 3 静态工厂;R6 mitigation)+ `RtsObstructionShapeUnit`(Unit 圆子类)+ `RtsSpatialIndex`(uniform grid bucket 256 px;query_circle 末 sort 保 tag 升序 §12.4)+ `RtsObstructionManager`(9+ 公开 API + 完整 SAT 4 轴 OBB-OBB R1 缓解 + circle-OBB / point-in-OBB / rasterize;R5 P1-2 dirty lifecycle)
- `rts_buildings.gd:85` 硬编码 `1 << 3` → `RtsObstructionFlags.BLOCK_PATHFINDING`
- `RtsBuildingActor` + `RtsUnitActor` 加 `obstruction_tag: int = 0` 字段
- `RtsPlaceBuildingCommand.apply` step 3.5 + `procedure.start` 起手 loop 都补 `add_static_shape` 注册(dual-write 兼容)
- `procedure.tick` step 4f `_sync_unit_obstruction_shapes`(alive_units lazy register + per-tick move_shape;Death unregister deferred 到 M5)
- 3 个新 smoke:obstruction_manager_register / _query / _remove(覆盖 AC4+AC7+R1 SAT 4-case)

## M3 Epic 已落地的基础设施

- **完整规划文档** (`.feature-dev/task-plan/m3-0ad-pathfinding-migration/`):README + data-structures + interfaces + validation-strategy + risks-and-rollback + 9 milestone (M0-M8 含 sub-phase 拆分) + deferred/0ad-formation-design
- **Trace 基础设施** (M0.1):
  - `addons/.../tools/path_trace_v2.gd` (24 字段 CSV writer)
  - `addons/.../tests/battle/smoke_pathfinding_baseline.{tscn,gd}` (PASS 900 ticks / 6155 rows / 111 events)
  - `addons/.../tests/baselines/0ad-baseline-master.csv` (882 KB,byte-identical 跨 run + M2 末态 byte-identical)
  - `addons/.../tests/baselines/0ad-baseline-master.replay.json` (34 KB)
- **0 A.D. 本地参考副本**: `addons/.../docs/references/0ad-source/` (sparse `source/simulation2/`,9.2 MB,git ignore)
- **acceptance smoke**:
  - M0 `tests/battle/smoke_obstruction_footprint_split.{tscn,gd}` (footprint shape 拆分验收)
  - M1 `tests/battle/smoke_navcell_grid_passability.{tscn,gd}` (Registry + NavcellGrid + multi-class isolation)
  - M2 `tests/battle/smoke_obstruction_manager_{register,query,remove}.{tscn,gd}` (3 smoke 覆盖 ObstructionManager AC4/AC7/SAT R1)

## 测试基线 (M2 末态 = 17 项 + LGF 73 + 3 新 obstruction_manager smoke)

| 入口 | 末态 |
|---|---|
| `addons/logic-game-framework/tests/run_tests.tscn` | **73/73 PASS** |
| `tests/battle/smoke_rts_auto_battle.tscn` | left_win, ticks=347, attacks=74, melee=32, ranged=42, melee_max=24.00, deaths=6, detoured=4 |
| `tests/battle/smoke_castle_war_minimal.tscn` | left_win, ticks=193, unit_to_building_attacks=4, archer_anti_air=1 |
| `tests/battle/smoke_player_command.tscn` | gold=20 wood=50 |
| `tests/battle/smoke_player_command_production.tscn` | ticks=600 left_spawned=7 max_eastward=254.74 |
| `tests/battle/smoke_production.tscn` | ticks=600 left=7 right=7 max_left_eastward=118.51 |
| `tests/battle/smoke_crystal_tower_win.tscn` | ticks=2 left_win |
| `tests/battle/smoke_resource_nodes.tscn` | ticks=200 alive=5 |
| `tests/battle/smoke_harvest_loop.tscn` | ticks=600 gold=140 wood=212 |
| `tests/battle/smoke_economy_demo.tscn` | ticks=900 melee_spawned=4 final_gold=138 final_wood=196 |
| `tests/battle/smoke_ai_vs_player_full_match.tscn` | ai_units_spawned=4 ai_unit_to_ct_attacks=9 |
| `tests/battle/smoke_flying_units.tscn` | archer_hits=3 PASS |
| `tests/replay/smoke_replay_bit_identical.tscn` | seed=42 frames=9 events=20 deep-equal |
| `tests/replay/smoke_determinism.tscn` | tick_diff=0 |
| `tests/frontend/smoke_frontend_main.tscn` | visualizers=10 |
| `tests/frontend/smoke_ui_main_menu.tscn` | demo=RtsFrontendDemo |
| `tests/battle/smoke_pathfinding_baseline.tscn` | ticks=900 trace=6155 events=111 + baseline CSV byte-identical 882882 bytes |
| `tests/battle/smoke_obstruction_footprint_split.tscn` | (M0)set_b=4 set_c=10 (B ∩ C)=∅ |
| `tests/battle/smoke_navcell_grid_passability.tscn` | (M1)AC1+AC2+AC8 13 项断言全过 |
| `tests/battle/smoke_obstruction_manager_register.tscn` | (M2 新)8 shapes tags 1..8, sorted query OK |
| `tests/battle/smoke_obstruction_manager_query.tscn` | (M2 新)filter + test_*_shape + SAT 4-case + distance OK |
| `tests/battle/smoke_obstruction_manager_remove.tscn` | (M2 新)basic + idempotent + query-consistent + readd OK |

## M3 Epic 关键决策(D 系列,详见 `task-plan/m3-0ad-pathfinding-migration/README.md` §0.3)

- **D1**: 混合避让方案 = 0 A.D. short path + 本项目 sep force 微调(⚠️ 有意偏离 0 A.D.)
- **D2**: 复刻 4 个独立 component (Position / Obstruction / Footprint / Motion);Motion.clearance ≡ Obstruction.radius
- **D6**: LongPath 用朴素 A*(⚠️ 有意简化,不做 JPS)
- **D9**: group_filter 在 M6/M7 已是 API 输入,M8 仅打开 + tune
- **D10**: RegionID 用 packed int64 (24+24+16 bit) — 不能用 RefCounted (Godot 4.6 实测 Dict key 走实例身份)
- **D11**: §12 determinism 总排序 contract 显式定义 — heap 5 元组 + spatial bucket / vertex / obstruction / commands 顺序 / 浮点处理
- **R5 P1-1**: tick 排序 key = `(kind: String, spawn_seq: int)` 数值复合 key
- **R5 P1-2**: dirty lifecycle = rasterize / hierarchical update 都只读,RtsWorld.tick step 7 末端统一 `clear_dirty()`
- **M2 H1**: ObstructionManager 是 RefCounted 挂 RtsWorldGameplayInstance,不做 autoload
- **M2 H2**: SpatialIndex BUCKET_SIZE = 256 px(8 navcell × 32 px;100 单位规模合适)
- **M2 H4**: M2 阶段单 class rasterize(default),air class M3 启动飞行单位时引入
- **M2 H5**: distance_to_target 简化版(center 距离 - enclose_radius_sum;精确版留 M6 vertex pathfinder)

## 关键约束 (跨 phase / sub-feature 不变)

来自 `Autonomous-Work-Protocol.md`:

1. **不修改 LGF submodule core / stdlib** — 新代码进 `addons/logic-game-framework/example/rts-auto-battle/`
2. **三层架构**: `core ← logic ← frontend`
3. **Headless 测试入口规范**: `SMOKE_TEST_RESULT: PASS|FAIL - <reason>` + 退出码 0
4. **跑 headless 不要 pipe**: redirect 到 `/tmp/*.txt` 再读
5. **不要 `godot --script`**: 永远用 `.tscn` 入口
6. **修改 `project.godot` autoload 需用户确认**

M3 Epic 新增约束:

7. **保持 replay bit-identical** — 每个 milestone 必须 PASS `smoke_replay_bit_identical seed=42 frames=9 events=20 deep-equal`
8. **Determinism §12 contract** — 任何 tie-break 路径必须有显式 deterministic key(详见 `data-structures.md §12`)
9. **bash cwd 严禁 cd 不回** — `cd <subdir>` 后必须显式 `cd` 回主仓,或一律走绝对路径不 cd;统一用 `git -C <subdir>` 取代 cd
10. **新加 class_name 时首次跑 baseline 单跑** — 让 GDScript class_name cache stabilize 再批量并行(M2.3 / M2.5 期间踩过 race)

## Git 状态

- 主仓 master ahead of origin/master(M3 Epic + M0 + M1 + M2 实施期间累积 commit 待推)
- submodule `addons/logic-game-framework` HEAD=86020b0(M2 末态)
- M2 archive sweep 待 commit(本文件 + Progress / Next-Steps / m3 README / M2.md status 修订 + Summary.md)

## 决策来源 (历史 sub-feature → archive)

- **M2 ObstructionManager** (2026-05-04): `archive/2026-05-04-rts-m3-m2-obstruction-manager/` ← **最近**
- **M1 Navcell Grid + Passability** (2026-05-04): `archive/2026-05-04-rts-m3-m1-navcell-grid/`
- **M0 Footprint 拆分 + Bug 1** (2026-05-04): `archive/2026-05-04-rts-m3-m0-footprint-split/`
- M2.3 UI/HUD/BuildPanel/关卡 (2026-05-03): `archive/2026-05-03-rts-m2-3-ui-hud/`
- M2.2 AI 对手 (2026-05-02): `archive/2026-05-02-rts-m2-2-ai-opponent/`
- M2.1 经济 (2026-05-02): `archive/2026-05-02-rts-m2-1-economy/`
- M1 RTS 重构 (2026-05-02): `archive/2026-05-02-rts-m1-refactor/`
- 早期 RTS 例子骨架 (2026-04-30): `archive/2026-04-30-rts-auto-battle/`
- M2 整体路线图: `task-plan/m2-roadmap.md`
- **M3 Epic 完整规划**: `task-plan/m3-0ad-pathfinding-migration/`
- **M3 Epic codex 审查记录**: `Handoff-2026-05-03-0ad-migration-planning.md` (R1-R4) + `Handoff-2026-05-03-step-b-codex-review.md` (R5-R8)
