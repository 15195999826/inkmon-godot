# Progress — RTS Pathfinding M3 Epic / M0 sub-feature

**Status**: 🟢 M0.1 - M0.7 全 done,所有 10 AC 通过(AC1-AC4 落地,AC5/AC6/AC7/AC8/AC10 验证 PASS),等用户 ✋1 体验点录屏反馈才 archive M0 + 启动 M1。

**Active feature**: M0 — Footprint / Obstruction shape 拆分 + Bug 1 修复
**完整 spec**: [`task-plan/m3-0ad-pathfinding-migration/milestones/M0-footprint-split.md`](task-plan/m3-0ad-pathfinding-migration/milestones/M0-footprint-split.md)

---

## 0. Step A + Step B(规划阶段,已完成)

| 阶段 | 产出 | 状态 |
|---|---|---|
| **Step A**(2026-05-03 晚) | README + data-structures + M0 范本 + Handoff-2026-05-03-0ad-migration-planning.md(383 行) | ✅ done |
| **Step B**(2026-05-03 晚) | interfaces.md + validation-strategy.md + risks-and-rollback.md + M1-M8(8 个 milestone, M4/M6/M7 拆 sub-phase)+ deferred/0ad-formation-design.md | ✅ done |
| **Step B 配套**(Agent 后台落地) | path_trace_v2.gd + smoke_pathfinding_baseline + tests/baselines/0ad-baseline-master.csv (882 KB / 6155 行,byte-identical 跨 run) | ✅ done(M0.1 已落地) |
| **0 A.D. 源码本地副本**(顺手) | sparse checkout `source/simulation2/`(9.2 MB),供后续 milestone 对照参考 | ✅ done(addons submodule .gitignore 屏蔽) |

### Codex 审查闭环记录

| Round | 结论 | 反馈 | 我的修订 |
|---|---|---|---|
| **R1** | REQUEST CHANGES | 4 P1 + 7 项审查意见 | RegionID packed int64 / M0 sync 时机 / 字段命名 / §12 determinism contract — 全闭环 |
| **R2** | REQUEST CHANGES (P2 only) | 真实 API 名(RtsRng / RtsPlayerCommandQueue / RtsMatchPreset)+ §12.5 motion tick 顺序显式 + M0.5 sync 6 call sites | 全闭环 |
| **R3** | REQUEST CHANGES (1 P1 + 3 P2) | Q4 闭环风格 + RtsRandomSeq 残留 + RtsRng.next_* 不存在 + §11 缺 R2 记录 | 全闭环 |
| **R4** | ✅ APPROVE for Step B | (无 P1)| (进 Step B)|
| **R5** | REQUEST CHANGES (3 P1 + 1 P2) | actor.get_id 字典序 ≥ 10 unit 漂 / dirty bits 在 hierarchical update 前清 / isolated region 不进 GlobalRegionID / tick API 名 flush 不存在 | 全闭环 |
| **R6** | REQUEST CHANGES (1 P1 + 2 P2) | interfaces §6.3 仍 actor.get_id / Handoff 旧疑虑 / validation §3.2 wall_clock 主句 | 全闭环 |
| **R7** | REQUEST CHANGES (1 P1) | interfaces §10.2 仍按 actor.get_id 字典序 | 全闭环 |
| **R8** | ✅ APPROVE for Step C | (无 P1)| 启动 Step C(本轮)|

R1-R8 完整反馈记录见 `Handoff-2026-05-03-0ad-migration-planning.md` §11.6 / §11.7 + `Handoff-2026-05-03-step-b-codex-review.md` §10 / §11 / §12。

---

## 1. M0 子任务 checklist (M0.1 → M0.7)

完整定义见 [`task-plan/m3-0ad-pathfinding-migration/milestones/M0-footprint-split.md`](task-plan/m3-0ad-pathfinding-migration/milestones/M0-footprint-split.md) §2。

- [x] **M0.1** — Trace utility + baseline replay 准备(Step C 之前由 Agent 落地)
  - **Evidence**: `addons/.../tools/path_trace_v2.gd`(7910 B)+ `smoke_pathfinding_baseline.{tscn,gd}` + `tests/baselines/0ad-baseline-master.csv`(882 KB / 6155 行) + `0ad-baseline-master.replay.json`(34 KB)
  - **Smoke**: PASS — 900 ticks / 6155 trace rows / 111 replay events / exit code 0 / baseline CSV byte-identical 跨 run
  - **Regress**: `smoke_rts_auto_battle` 0 漂移(left_win ticks=347 attacks=74 melee=32 ranged=42 melee_max=24.00 完全对齐 CLAUDE.md baseline)
- [x] **M0.2** — 引入 3 个 data class(`RtsObstructionShape` 基类 + `Static` + `Footprint`,纯 data,不挂逻辑) ✅ **2026-05-03 done**
  - **Evidence**: 3 文件落地
    - `addons/.../logic/obstruction/rts_obstruction_shape.gd` (基类 RefCounted + enum Type{UNIT,STATIC} + entity_id/center/flags/control_group/control_group_2/tag)
    - `addons/.../logic/obstruction/rts_obstruction_shape_static.gd` (extends RtsObstructionShape + width/height/rotation_rad + get_corners 4 角 (+u+v→+u-v→-u-v→-u+v) + get_axes [u,v])
    - `addons/.../logic/obstruction/rts_footprint_shape.gd` (RefCounted + enum Type{CIRCLE,SQUARE} + center_offset/size + contains + get_world_aabb)
  - **Import**: `godot --headless --path . --import` exit=0,update_scripts_classes 注册 3 个新 class_name(RtsFootprintShape / RtsObstructionShape / RtsObstructionShapeStatic),无 type error
  - **Regress**: LGF 73/73 PASS;`smoke_rts_auto_battle` ticks=347 attacks=74 (melee=32 ranged=42) melee_max=24.00 deaths=6 detoured=4 — **完全对齐 baseline,0 漂移**
  - **F2 决策落地**: 不引入 RtsObstructionFlags 完整枚举,M0 阶段 flags 字段注释里说明 `1<<3 = BLOCK_PATHFINDING` 单 bit,M2 引入完整枚举
- [x] **M0.3** — `RtsBuildingConfig.StatBlock` 加 4 个新字段 ✅ **2026-05-03 done**
  - **Evidence**: `addons/.../logic/config/rts_building_config.gd` StatBlock 新增 4 字段 + `_CELL_SIZE_FALLBACK = 32.0` 内部常量 + `get_stats` 加 fallback 派生 (raw 没显式时从旧 footprint_size × cell_size 派生 obstruction_size, selection 派生 = max(w,h)*0.5)
  - **三建筑 fallback 数字** (raw config 未显式新字段,全走 fallback):
    - crystal_tower (footprint=(2,2)): obstruction_size=(64,64), selection=Vector2(32,0), offset=ZERO, shape_type=0(CIRCLE)
    - barracks (footprint=(2,2)): obstruction_size=(64,64), selection=Vector2(32,0)
    - archer_tower (footprint=(1,1)): obstruction_size=(32,32), selection=Vector2(16,0)
  - **Import**: exit=0,update_scripts_classes RtsBuildingConfig + InputHelper 注册,无 type error
  - **Regress**: LGF 73/73 + smoke_rts_auto_battle ticks=347 attacks=74 melee=32 ranged=42 melee_max=24.00 deaths=6 detoured=4 **0 漂移** + smoke_resource_nodes PASS (5 workers idle near spawn) + smoke_economy_demo PASS (full cycle harvest → cost → barracks → melee → attack ct) — **向后兼容验证通过**
  - **旧字段**: `footprint_size: Vector2i` 保留,M2 引入 ObstructionManager 后才删
- [x] **M0.4** — `RtsBuildingActor` 加 `obstruction_shape` / `footprint_shape` 字段 + 改 `get_footprint_cells` 算法 + 加 `sync_obstruction_shape()` 方法 ✅ **2026-05-03 done**
  - **Evidence**: `addons/.../logic/rts_building_actor.gd` 加 `obstruction_shape: RtsObstructionShapeStatic = null` + `footprint_shape: RtsFootprintShape = null` 字段;`get_footprint_cells(grid)` 双路径分支(obstruction_shape != null 走新路径用 obstruction_shape.center / width / height;null 时 fallback 到旧 footprint_size 路径,M0.4 阶段所有 path 走 fallback);新方法 `sync_obstruction_shape()` 把 center 设为 `position_2d + stats.obstruction_offset`;旧 `footprint_size: Vector2i` 保留(frontend 仍读)
  - **Import**: exit=0,RtsBuildingActor 重新注册无 type error(LSP cache stale 报"找不到类型"是 UI cache 问题,实际编译通过)
  - **Regress**: LGF 73/73 + smoke_rts_auto_battle ticks=347 attacks=74 melee=32 ranged=42 melee_max=24.00 deaths=6 detoured=4 **0 漂移** + smoke_castle_war_minimal PASS (player placed barracks / anti-air shot down flying / crystal tower died) + smoke_economy_demo PASS (full cycle harvest→cost→barracks→melee→attack ct) — **fallback 路径向后兼容 0 漂移**
  - **AC4 局部状态**: 新算法已就位等 M0.5 激活;现因 obstruction_shape == null 全走 fallback,M0.5 工厂注入后会切到新路径 (obstruction_offset=ZERO 时 cells 跟旧 bit-identical 由 M0.7 smoke 严格断言)
- [x] **M0.5** — `RtsBuildings` 工厂(只填默认字段)+ 6 个 sync_obstruction_shape() call sites + `RtsBuildingPlacement` 算法同步 ✅ **2026-05-03 done**
  - **工厂**: `RtsBuildings._create_from_kind` 注入 `RtsObstructionShapeStatic`(width/height/rotation_rad=0/flags=BLOCK_PATHFINDING)+ `RtsFootprintShape`(type/size/center_offset=ZERO),只填位置无关字段;center 由 sync 时填
  - **6 个 production sync sites**:
    - ✅ `rts_place_building_command.gd:apply` set position 后调 sync(玩家命令路径)
    - ✅ `rts_auto_battle_procedure.gd:start` get_footprint_cells 前调 sync(procedure 起手)
    - ✅ `demo_rts_frontend.gd` 双 ct(set position 后)
    - ✅ `demo_rts_pathfinding.gd` 4 处(OBSTACLE_POSITIONS 循环 + dummy + 动态 spawn 通过 K)
    - ✅ `rts_scenario_harness.gd` 2 处(scenario buildings + dynamic obstacle)
    - ✅ `rts_match_preset.gd` 不调 RtsBuildings.create_*,无需改
  - **Placement 同步**: `RtsBuildingPlacement` 加 `_compute_footprint_cells_core(center, cells_w, cells_h)` core helper + `_compute_footprint_cells_from_shape(shape, grid)` 重载;现有 `_compute_footprint_cells(center, footprint_size)` 内部调 core;**RtsBuildingActor.get_footprint_cells delegate 给 Placement core helper**,无双份算法漂移
  - **Ghost preview**: `demo_rts_frontend._enter_placement_mode` ghost size 切到 `stats.obstruction_size`;`_update_placement_ghost` bbox center 加 `obstruction_offset` 让 ghost 跟最终 obstruction 占地完全对齐
  - **Sync 自动填**: `sync_obstruction_shape()` 自动填 entity_id (来自 actor.get_id)+ control_group (来自 team_id),减少 site boilerplate
  - **Lazy sync 兜底**: get_footprint_cells 在 obstruction_shape.center == ZERO 且 position_2d != ZERO 时自动 sync 一次,救场漏 sync 的 tests / diagnostics 路径
  - **Verification**:
    - `--import` exit=0,RtsAutoBattleProcedure / RtsBuildingPlacement / 共 7 个 class 重新注册无 type error
    - LGF 73/73 PASS
    - smoke_rts_auto_battle: ticks=347 attacks=74 melee=32 ranged=42 melee_max=24.00 deaths=6 detoured=4 — **完全 baseline-aligned 0 漂移**
    - smoke_castle_war_minimal PASS / smoke_economy_demo PASS / smoke_player_command_production PASS
    - **smoke_replay_bit_identical PASS** — same seed + commands → bit-identical event_timeline + commands_log(determinism 关键测试)
- [x] **M0.6** — Frontend 选择圈 + ghost 渲染对齐 ✅ **2026-05-03 done**
  - **Evidence**: `frontend/visualizers/rts_building_visualizer.gd` 加 `_footprint_shape` 字段 + `bind()` 加 `p_footprint_shape: RtsFootprintShape` 参数(在 `p_footprint_size` 之后);`_draw()` 优先用 `_footprint_shape.get_world_aabb(Vector2.ZERO)` 算外接矩形,null 时 fallback 走旧 `_footprint_size × CELL_SIZE`(防御非 factory 路径)。`frontend/world_view.gd` `bld_vis.bind` 调点 同步加 `bld_actor.footprint_shape`。
  - **F4-A 决策落地**: sprite 锚点 = position_2d 不变(_draw 在 local 空间, owner_pos 传 ZERO);默认 fallback (selection_footprint_size = max(w,h)*0.5 for CIRCLE) → AABB 跟旧 `_footprint_size × CELL_SIZE` byte-identical, 无视觉回归。
  - **Regress**: smoke_frontend_main visualizers=10 alive_after_3.0s=10 PASS;`--import` exit=0 + RtsBuildingVisualizer / RtsWorldView 重新注册无 type error。
- [x] **M0.7** — 新 smoke + Validation 全套 + commit ✅ **2026-05-03 done**
  - **新 smoke**: `tests/battle/smoke_obstruction_footprint_split.{tscn,gd}` PASS,5 项断言 + AC8 客观验证全过:
    - position_2d unchanged after mutate (sprite 锚点 F4-A 不动)
    - obstruction.center == position_2d + (32, 32) = (192, 192) (mutate 模拟非默认 offset)
    - get_footprint_cells 中心在 obstruction.center 所在 cell(6,6) 而非 position_2d 所在 cell(5,5)
    - footprint.contains(原位置, 原位置) == true (玩家点 sprite 中心能选中)
    - AC8 part 1: Set A (ghost preview cells) == Set B (placed cells, 4 cells [(5,5),(6,5),(5,6),(6,6)])
    - AC8 part 2: (Set B ∩ Set C unit_path 10 cells) == ∅ (A* 绕开 obstruction cells, unit 走 row 6/7)
  - **assert_crash 兜底**: `RtsBuildingActor.get_footprint_cells` 入口加 `Log.assert_crash(obstruction_shape.center != ZERO or stats.obstruction_offset == ZERO)`;抓 factory 注入后调方漏 set position_2d 但 stats 配了非默认 offset 的 bug(lazy sync 救不回的边界条件)。
  - **Code reuse 收口** (simplify pass): 把 `RtsBuildingPlacement._compute_footprint_cells_from_shape` / `_compute_footprint_cells_core` (cross-file static helper, 被 actor + ghost preview + smoke 共用) 重命名为 public `compute_footprint_cells_from_shape` / `compute_footprint_cells_core`(去掉 `_` 前缀, 跟 GDScript 命名规范一致); smoke 的 `_cell_key` 删除改用 `HexCoord.to_key()`(与主仓 grid 反向索引格式一致), `_cells_contain` 改用 `HexCoord.equals()`,合并 `_cells_to_str` / `_cells_dict_to_str`(后者直接 `set_c.values()` 转 Array 调前者)。
  - **Validation 全套 PASS** (M2.3 末态 baseline 0 漂移 + 新 smoke):
    - `run_tests.tscn`: **73/73 PASS**
    - `smoke_rts_auto_battle`: ticks=347 attacks=74 (melee=32 ranged=42) deaths=6 melee_max_dist=24.00 ranged_max_dist=125.75 detoured=4
    - `smoke_castle_war_minimal`: ticks=193 left_win unit_to_building=4 archer_anti_air=1
    - `smoke_player_command`: gold=20 wood=50 log=3
    - `smoke_player_command_production`: ticks=600 left_spawned=7 max_eastward=254.74 gold=20
    - `smoke_production`: ticks=600 left=7 right=7 max_left_eastward=118.51
    - `smoke_crystal_tower_win`: ticks=2 left_win
    - `smoke_resource_nodes`: ticks=200 alive=5 max_drift=0
    - `smoke_harvest_loop`: ticks=600 alive=5 team_gold=140 team_wood=212 cycle=5
    - `smoke_economy_demo`: ticks=900 melee_to_ct=31
    - `smoke_ai_vs_player_full_match`: ai_barracks=1 ai_units_spawned=4 ai_unit_to_ct_attacks=9
    - `smoke_replay_bit_identical`: seed=42 frames=9 events=20 deep-equal
    - `smoke_determinism`: tick_diff=0
    - `smoke_frontend_main`: visualizers=10 alive_after_3.0s=10
    - `smoke_flying_units`: PASS (anti-air / ground / flying)
    - **`smoke_obstruction_footprint_split` (NEW)**: set_b=4 set_c=10 (B ∩ C)=∅
  - **commit**: 待 — submodule + 主仓 bump pointer (M0.7 末)

---

## 2. 体验点 ✋1(M0 完成时,stop runner)

- [ ] 用户 F6 跑 `frontend/demo_rts_frontend.tscn`
- [ ] 进 build mode,放 1 个 barracks + 1 个 archer_tower
- [ ] spawn 4-6 单位绕走
- [ ] 视觉确认:ghost cells = obstruction cells = 单位绕走 cells 三者一致
- [ ] 录屏 `0ad-migration-M0-after.mp4`(本地留底,不进 git)
- [ ] 用户反馈通过 → 启动 M0 archive + M1 sub-feature

---

## 3. 残余风险(M0 启动前预判,详见 M0.md §6)

| # | 风险 | 缓解 |
|---|---|---|
| R1 | 偶数 footprint_size 偏置方向跟旧不一致 → smoke 数字漂 | 严格保留 "上半左半" 偏置;单元测试比对旧算法 byte-identical |
| R2 | obstruction_offset = ZERO 时 cells 浮点精度 → 不 bit-identical | 用 `int(round(...))` 显式整数化 |
| R3 | sprite 锚点改逻辑后视觉错位 | 选 F4 A(锚点 = position_2d 不变),只动选择圈 |
| R5 | replay determinism 漂(M0 引入 obstruction_shape mutate)| M0.7 验证 seed=42 deep-equal |
| R6 | M0 完成后 demo 视觉差异不明显(M0 不能完整修 Bug 1)| ✋1 客观断言 ghost == placed == path,主观视觉差异留 ✋3 (M6) |
| R-EPIC-9 | M0.5 sync call sites 漏(diagnostics/smoke 路径)| Step C 进 runner 后**先** grep `tests/**/*.gd`,不依赖 R2 列的 6 个生产 sites |

---

## 4. 下一步动作(给 runner)

1. 读 [`task-plan/m3-0ad-pathfinding-migration/milestones/M0-footprint-split.md`](task-plan/m3-0ad-pathfinding-migration/milestones/M0-footprint-split.md) §2 + §3 + §6
2. 读 `data-structures.md` §2 + §3
3. grep `tests/**/*.gd` 找 diagnostics/smoke 中 `create_*` 后直调 `get_footprint_cells()` 路径(补充 M0.5 第 6 个 call site 表外漏的)
4. 按 M0.2 → M0.7 顺序推进
5. 每子任务 done 时 update 本文件 (Evidence 字段填实际产出 + commit hash)
6. M0 全 AC 通过后 stop runner 等 ✋1 反馈
