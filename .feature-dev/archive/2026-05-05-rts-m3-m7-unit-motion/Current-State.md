# Current State — 2026-05-04 baseline (M3 Epic / M0-M6 done; M7 待启动)

inkmon-godot baseline 事实快照. M3 Epic / M7 启动用.

> **Active feature**: ⏸ 等用户审 M6 archive + 授权启 M7(UnitMotion 整合 long+short 双轨).
>
> **M0 + M1 + M2 + M3 + M4 + M5 + M6 sub-feature**: ✅ 整体完成 + archived
> - M0 (Footprint 拆分) → `archive/2026-05-04-rts-m3-m0-footprint-split/`
> - M1 (Navcell Grid + Passability) → `archive/2026-05-04-rts-m3-m1-navcell-grid/`
> - M2 (ObstructionManager + Spatial Index) → `archive/2026-05-04-rts-m3-m2-obstruction-manager/`
> - M3 (Clearance + 外扩 per-class buffer) → `archive/2026-05-04-rts-m3-m3-clearance/`
> - M4 (HierarchicalPathfinder + canonicalize API) → `archive/2026-05-04-rts-m3-m4-hierarchical/`
> - M5 (LongPathfinder 朴素 A* + Facade + wire) → `archive/2026-05-04-rts-m3-m5-long-pathfinder/`
> - M6 (VertexPathfinder 算法层 + Liang-Barsky 精确化 + facade API) → `archive/2026-05-04-rts-m3-m6-vertex-pathfinder/`
>
> **M3 Epic 状态**: M0-M6 done(7/9 milestone)+ 12 -Required smoke + 16 rts/pathfinding smoke(M5 13 + M6 4)+ LGF 73/73 + replay seed=42 frames=11 events=24 deep-equal + baseline CSV byte-identical 968343 bytes(同 M5 末态;M6 算法层不接 production → 0 漂移;M7 production wire 时预期 short path 字段从占位变实填 P1 接受).
>
> **M6 deferred → M7 wire 触发**:✋3 demo F6 visual 验证 / baseline `short_path_*` 字段实填 / perf 实测 — 全部依赖 M7 UnitMotion 整合双轨把 vertex pathfinder 接 production callsite。
>
> **M5 deferred → EPIC 末 cleanup phase**:**M5.5b-e RtsBattleGrid 完整删除**(用户决策推迟 — 8-10h wallclock 纯 cleanup work,production code 已走 NavcellGrid 直接,删除 RtsBattleGrid 不影响 functionality)。
>
> phase 实现细节 / 决策来源 → 见对应 archive 的 `Summary.md` 或 `task-plan/m3-0ad-pathfinding-migration/`.

---

## 工程结构

- 主仓 `D:\GodotProjects\inkmon\inkmon-godot`,Godot 4.6 项目
- `addons/` 是单一 git submodule (→ `godot-addons.git`),含 3 个 addon:`logic-game-framework` / `lomolib` / `ultra-grid-map`
- 主仓 entry:`scenes/Simulation.tscn` + `scripts/SimulationManager.gd` (Web/headless 桥接)
- `project.godot` autoload:`Log` / `IdGenerator` / `GameWorld` / `TimelineRegistry` / `WaitGroupManager` / `ItemSystem` / `UGridMap` / `RtsRng`

## 当前 baseline 能力 (M4 末态 = M5 出发点)

M4 末态 RTS 完整可玩 1v1 skirmish + AI vs AI 观战 demo + ObstructionManager 单一数据源 inflate-aware 寻路 + HierarchicalPathfinder 算法层落地(production code 暂不消费,等 M5 LongPathfinder wire)。M0 / M1 / M2 / M3 / M4 增量(详见对应 archive Summary.md):

- **M0**(footprint 拆分): obstruction shape 数据类 + building footprint sync 链路
- **M1**(NavcellGrid + Passability): `RtsPassabilityClassConfig/Registry` + `RtsNavcellGrid` 16-bit 位掩码 multi-class + `RtsBattleGrid` dual-write facade
- **M2**(ObstructionManager + Spatial Index): 5 个 obstruction 数据/算法类 + 完整 SAT 4 轴 OBB-OBB + Building/Unit shape 链路接 manager(dual-write 兼容)
- **M3**(Clearance + 外扩 per-class buffer):
  - `RtsObstructionManager.rasterize` 改两步: 原 cell 占用 + clearance 外扩 inflate(brute-force / 圆形 buffer Euclidean / `buffer_px = ceilf(clearance/cell)*cell` 至少 1 cell)
  - `procedure.tick_once` step 6.6 `rasterize_if_dirty` 走 manager._shapes 单一数据源增量重写 NavcellGrid + step 7.5 末端统一 `clear_dirty`(R5 P1-2 dirty lifecycle invariant)
  - `RtsNavcellGrid._origin_world` 字段 + `set_origin_world / world_to_navcell_i/j / has_any_dirty / collect_dirty_cells` helpers
  - `RtsPassabilityClassConfig.affects_pathfinding: bool = true` 字段(air class 设 false)替 `class_name_id == "air"` 字符串比较
  - 装饰 obstacle 自动注册 manager + Unit shape 不 mark navcell dirty(perf-critical 修正)
- **M4**(HierarchicalPathfinder full recompute + canonicalize API):
  - `RtsRegionIdHelper` / `RtsHierarchicalChunk` / `RtsHierarchicalPathfinder` per-class chunks + edges + global_regions
  - 公开查询 API + spiral ring scan;Wire `world.hierarchical_pathfinder` + step 6.7 lazy recompute
  - **M4b 阶段语义** `make_goal_reachable_point` reachable→no-op 临时方案 → M5 切换
  - **Perf**:realistic demo p99=28 ms ≤ 30 ms 阈值,M4c CANCEL
- **M5**(LongPathfinder 朴素 A* + PathfinderFacade + wire):
  - **新 class**(logic/pathfinding/):
    - `RtsLongPathRequest` data class(ticket / start / goal / pass_mask / notify_entity)
    - `RtsWaypointPath` 反向存储 PackedVector2Array(`waypoints[0]`=goal,`back()`=next step,O(1) push/pop_back)
    - `RtsPathGoal` 5 种 type enum POINT/CIRCLE/SQUARE/INVERTED_*(M5 阶段仅 POINT)
    - `RtsLongPathfinder` 朴素 A* on NavcellGrid(8-邻居 deterministic + COST_HV=65536 / COST_DIAG=92682 整数 cost + 5 元组 lex compare bsearch+insert heap + reconstruct 反向存储 + grid<65536 _pack_cell assert + **direct-path fallback**:终点 navcell impassable → 单 waypoint = goal.center 跟老 RtsPathfinding 一致行为)
    - `RtsPathfinderFacade` 顶层入口:`compute_path_immediate`(玩家 click,过 canonicalize)/ `compute_path_direct`(actor 中心 target,不过 canonicalize)/ `is_goal_reachable` / `make_goal_reachable`
  - **Hierarchical canonicalize 切换**:加 `make_goal_reachable_pathgoal`(M5 PathGoal-aware,**总是 mutate goal 到 navcell 中心 POINT**;M4b reachable→no-op 临时方案被替代)
  - **Nav agent / activity wire**:`RtsNavAgent` 加 `facade` + `_pass_mask` 字段 + `attach_pathfinder(facade,registry)`;`set_target` 加 `canonicalize: bool = true` 参数,facade 优先(facade null fallback 老 RtsPathfinding 路径);AttackActivity / HarvestActivity / ReturnAndDropActivity 显式 canonicalize=false(target=actor 中心 → direct-path fallback 让 unit 走到原 actor 中心 in-range);MoveToActivity 默认 canonicalize=true(玩家 click)
  - `procedure._init` 末构造 facade + 遍历 _unit_runtimes attach_pathfinder
  - `world.navcell_grid: RtsNavcellGrid` 一等公民字段(M5.5a 提升;production code 走此直接,不再通过 rts_grid wrapper);**M5.5b-e RtsBattleGrid 完整删除 DEFERRED 到 EPIC 末 cleanup**(用户决策推迟 8-10h wallclock 纯 cleanup work)
  - **新 baseline CSV** 968343 bytes(M4 829520→+17% LongPath 路径变化 P1 接受);trace_rows 5769→6748 / events 97→125;byte-identical 跨 2 runs
  - ✋2 体验点 headless mock PASS(玩家点墙后不可达点 → unit 走最近 reachable navcell,不死循环);demo 实操推迟到用户跑 demo 时验

## M3 Epic 已落地的基础设施

- **完整规划文档** (`.feature-dev/task-plan/m3-0ad-pathfinding-migration/`):README + data-structures + interfaces + validation-strategy + risks-and-rollback + 9 milestone (M0-M8 含 sub-phase 拆分) + deferred/0ad-formation-design
- **Trace 基础设施** (M0.1):
  - `addons/.../tools/path_trace_v2.gd` (24 字段 CSV writer)
  - `addons/.../tests/battle/smoke_pathfinding_baseline.{tscn,gd}` (PASS 900 ticks / 5769 rows / 97 events;M3 末态)
  - `addons/.../tests/baselines/0ad-baseline-master.csv` (829520 bytes,byte-identical 跨 run + M3 末态接受新 baseline)
  - `addons/.../tests/baselines/0ad-baseline-master.replay.json` (30 KB)
- **0 A.D. 本地参考副本**: `addons/.../docs/references/0ad-source/` (sparse `source/simulation2/`,9.2 MB,git ignore)
- **acceptance smoke**:
  - M0 `tests/battle/smoke_obstruction_footprint_split.{tscn,gd}` (footprint shape 拆分验收)
  - M1 `tests/battle/smoke_navcell_grid_passability.{tscn,gd}` (Registry + NavcellGrid + multi-class isolation)
  - M2 `tests/battle/smoke_obstruction_manager_{register,query,remove}.{tscn,gd}` (3 smoke 覆盖 ObstructionManager AC4/AC7/SAT R1)
  - M3 `tests/battle/smoke_clearance_inflate.{tscn,gd}` (4 sub-test: AC1 inflate basic / AC2+AC8 air independent / AC3 dirty lifecycle / rasterize_if_dirty noop+triggered)
  - M4 `tests/battle/smoke_region_id_helper.{tscn,gd}` (4 sub-test: pack/unpack 可逆 + 0 = invalid 与 (ci=0,cj=0,r=N) 区分)
  - M4 `tests/battle/smoke_hierarchical_recompute.{tscn,gd}` (6 sub-test: AC2+AC8 单 chunk + 跨 chunk + determinism)
  - M4 `tests/battle/smoke_hierarchical_isolated_region.{tscn,gd}` (3 sub-test: R5 P1 #3 isolated region 全量 packed RID 起点)
  - M4 `tests/battle/smoke_hierarchical_unreachable.{tscn,gd}` (6 sub-test: AC3 reachable / unreachable / goal-in-wall / start-in-wall / pure-query / split-by-wall)
  - M4 `tests/battle/smoke_hierarchical_perf.{tscn,gd}` (M4-perf-gate: realistic demo p99 阈值判 + synthetic future-warning info)

## 测试基线 (M5 末态 = 17 项 + LGF 73 + 3 obstruction_manager + 1 clearance_inflate + 5 hierarchical smoke + 3 long_pathfinder smoke)

| 入口 | 末态 |
|---|---|
| `addons/logic-game-framework/tests/run_tests.tscn` | **73/73 PASS** |
| `tests/battle/smoke_rts_auto_battle.tscn` | left_win, ticks=264, attacks=65, melee=33, ranged=32, melee_max=24.16, deaths=4, detoured=4 |
| `tests/battle/smoke_castle_war_minimal.tscn` | left_win, ticks=193, unit_to_building_attacks=4, archer_anti_air=1 |
| `tests/battle/smoke_player_command.tscn` | placement applied + dup/zone reject |
| `tests/battle/smoke_player_command_production.tscn` | ticks=600 left_spawned=7 max_eastward=254.74 |
| `tests/battle/smoke_production.tscn` | ticks=600 left=7 right=7 max_left_eastward=132.25 |
| `tests/battle/smoke_crystal_tower_win.tscn` | ticks=2 left_win |
| `tests/battle/smoke_resource_nodes.tscn` | 5 workers idle (HarvestStrategy fallback) |
| `tests/battle/smoke_harvest_loop.tscn` | ticks=600 gold=140 wood=213 |
| `tests/battle/smoke_economy_demo.tscn` | ticks=900 melee_spawned=4 final_gold=134 final_wood=249 |
| `tests/battle/smoke_ai_vs_player_full_match.tscn` | ai_barracks=1 ai_units_spawned=4 ai_unit_to_ct=7 |
| `tests/battle/smoke_flying_units.tscn` | archer_hits=3 PASS |
| `tests/replay/smoke_replay_bit_identical.tscn` | seed=42 frames=11 events=20 deep-equal |
| `tests/replay/smoke_determinism.tscn` | tick_diff=0 (run1=run2 ticks=264 winner=left_win) |
| `tests/frontend/smoke_frontend_main.tscn` | visualizers=10 |
| `tests/frontend/smoke_ui_main_menu.tscn` | demo=RtsFrontendDemo |
| `tests/battle/smoke_pathfinding_baseline.tscn` | ticks=900 trace=5769 events=97 + baseline CSV byte-identical **829520 bytes** |
| `tests/battle/smoke_obstruction_footprint_split.tscn` | (M0)set_b=4 set_c=10 (B ∩ C)=∅ |
| `tests/battle/smoke_navcell_grid_passability.tscn` | (M1)AC1+AC2+AC8 13 项断言全过 |
| `tests/battle/smoke_obstruction_manager_register.tscn` | (M2)8 shapes tags 1..8, sorted query OK |
| `tests/battle/smoke_obstruction_manager_query.tscn` | (M2)filter + test_*_shape + SAT 4-case + distance OK |
| `tests/battle/smoke_obstruction_manager_remove.tscn` | (M2)basic + idempotent + query-consistent + readd OK |
| `tests/battle/smoke_clearance_inflate.tscn` | (M3)15 default-blocked + 25 air-passable + dirty cleanup |
| `tests/battle/smoke_region_id_helper.tscn` | (M4)4 sub-test: pack/unpack + boundary case 全过 |
| `tests/battle/smoke_hierarchical_recompute.tscn` | (M4)6 sub-test: AC2+AC8 单 / 跨 chunk + determinism 全过 |
| `tests/battle/smoke_hierarchical_isolated_region.tscn` | (M4)3 sub-test: R5 P1 #3 isolated region 全量起点全过 |
| `tests/battle/smoke_hierarchical_unreachable.tscn` | (M4 新)6 sub-test: AC3 canonicalize 全过 |
| `tests/battle/smoke_hierarchical_perf.tscn` | (M4)realistic demo p99=28 ms ≤ 阈值 PASS;synthetic future-warning info |
| `tests/battle/smoke_long_pathfinder_basic.tscn` | (M5)7 sub-test:data class + same-cell + direct line + back()=next step + unreachable + determinism + integer cost ratio |
| `tests/battle/smoke_long_pathfinder_unreachable.tscn` | (M5 新)5 sub-test:facade canonicalize 可达/不可达 + direct-path fallback + 纯查询 + ✋2 体验点 mock |
| `tests/battle/smoke_long_pathfinder_determinism.tscn` | (M5 新)5 sub-test:5 元组 lex byte-identical 跨 direct/绕障/缝隙/长路径/facade |

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

- 主仓 master ahead of origin/master(M3 Epic + M0-M5 实施期间累积 commit 待推)
- submodule `addons/logic-game-framework` HEAD=ae2790d(M5 末态:M5.1-M5.4 algo+facade+wire + M5.5a navcell_grid 提升 + M5.6 smoke+baseline)
- M5 archive sweep 通过本轮 archive commit 完成

## 决策来源 (历史 sub-feature → archive)

- **M5 LongPathfinder + Facade** (2026-05-04): `archive/2026-05-04-rts-m3-m5-long-pathfinder/` ← **最近**
- **M4 HierarchicalPathfinder** (2026-05-04): `archive/2026-05-04-rts-m3-m4-hierarchical/`
- **M3 Clearance + 外扩** (2026-05-04): `archive/2026-05-04-rts-m3-m3-clearance/`
- **M2 ObstructionManager** (2026-05-04): `archive/2026-05-04-rts-m3-m2-obstruction-manager/`
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
