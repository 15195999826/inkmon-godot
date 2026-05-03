# RTS Pathfinding M3 Epic / M0 — Footprint / Obstruction Shape 拆分 + Bug 1 修复 — Summary (2026-05-04)

> M3 Epic 第一个 milestone(M0/9)。把建筑的"渲染锚点 / 寻路占地 / UI 选择"从 `position_2d + footprint_size + collision_radius` 杂糅状态拆成 3 个独立 data(`Position` 不变 / `RtsObstructionShape` / `RtsFootprintShape`),自然修复 Bug 1(footprint 几何中心和 sprite 锚点偏 12-42 px 导致单位视觉穿建筑)。
>
> M0 是 Epic **唯一**改动 frontend 渲染锚点的 milestone;M1-M8 logic-only。

---

## Acceptance 结论 (M0.1 - M0.7 全过 + AC1-AC10 全 PASS)

### M0.1 - M0.7 子任务

| Sub | Scope | 状态 |
|---|---|---|
| **M0.1** | path_trace_v2 + smoke_pathfinding_baseline + 0ad-baseline-master.csv (882 KB / 6155 行,byte-identical 跨 run) | ✅ done(Step B 配套时由 Agent 落地)|
| **M0.2** | 3 data class:`RtsObstructionShape`(基类 RefCounted + Type{UNIT,STATIC} + entity_id/center/flags/control_group/control_group_2/tag)/ `RtsObstructionShapeStatic`(width/height/rotation_rad + get_corners 4 角 + get_axes [u,v])/ `RtsFootprintShape`(Type{CIRCLE,SQUARE} + center_offset/size + contains + get_world_aabb) | ✅ done |
| **M0.3** | `RtsBuildingConfig.StatBlock` 加 4 字段(obstruction_size / obstruction_offset / footprint_shape_type / selection_footprint_size)+ `_CELL_SIZE_FALLBACK = 32.0` 内部常量 + `get_stats` fallback 派生(raw 没显式时从旧 footprint_size × cell_size 派生)| ✅ done |
| **M0.4** | `RtsBuildingActor` 加 `obstruction_shape: RtsObstructionShapeStatic = null` + `footprint_shape: RtsFootprintShape = null` 字段;`get_footprint_cells(grid)` 双路径分支(obstruction_shape != null 走新路径用 obstruction_shape.center;null 时 fallback 到旧 footprint_size)+ `sync_obstruction_shape()` 把 center 设为 `position_2d + stats.obstruction_offset` | ✅ done |
| **M0.5** | `RtsBuildings._create_from_kind` 工厂注入 + 6 sync_obstruction_shape() call sites + `RtsBuildingPlacement._compute_footprint_cells_core(center, w, h)` core helper 抽取 + ghost preview 对齐 + 自动填 entity_id + lazy sync 兜底 | ✅ done |
| **M0.6** | Frontend visualizer:`_footprint_shape` 字段 + `bind()` 加 `p_footprint_shape` 参数;`_draw()` 优先用 `_footprint_shape.get_world_aabb(Vector2.ZERO)` 算外接矩形,null fallback 旧路径;F4-A 决策(sprite 锚点 = position_2d 不变)| ✅ done |
| **M0.7** | 新 smoke `smoke_obstruction_footprint_split` PASS(5 项断言 + AC8 客观验证)+ `assert_crash` 兜底 + simplify pass(把 `_compute_*` 改 public,smoke 用 `HexCoord.to_key/equals`)| ✅ done |

### AC1-AC10 全过

- ✅ **AC1** — 3 data class 落地,`--import` 通过(0 type error)
- ✅ **AC2** — `RtsBuildingConfig.StatBlock` 4 新字段 + `obstruction_offset = ZERO` fallback 派生
- ✅ **AC3** — `RtsBuildingActor.get_footprint_cells` 改用 `obstruction_shape.center`;`obstruction_offset = ZERO` 时跟旧实现 bit-identical(smoke_rts_auto_battle 0 漂移验证)
- ✅ **AC4** — `RtsBuildings` 工厂 + 6 个 sync 站全部接入;Placement core helper 抽取避免双份漂移
- ✅ **AC5** — Frontend visualizer 选择圈走 footprint_shape;sprite 锚点 = position_2d 不变(F4-A)
- ✅ **AC6** — Ghost preview cells = 最终 obstruction cells(玩家看到 = 实际放下)
- ✅ **AC7** — Validation 全套 14+1 项 0 漂移
- ✅ **AC8** — 新 smoke 5 项断言 + (Set A=ghost) ∩ (Set C=path) = ∅
- ✅ **AC9** — Logic 侧验证通过;UI click-to-select 等 M2.3 后续 polish
- ✅ **AC10** — Replay seed=42 frames=9 events=20 deep-equal,bit-identical 0 漂移

---

## 关键 artifact 路径

### 新建文件 (submodule)

- `addons/logic-game-framework/example/rts-auto-battle/logic/obstruction/rts_obstruction_shape.gd` — 基类
- `addons/logic-game-framework/example/rts-auto-battle/logic/obstruction/rts_obstruction_shape_static.gd` — Static 子类(width/height/rotation_rad + get_corners + get_axes)
- `addons/logic-game-framework/example/rts-auto-battle/logic/obstruction/rts_footprint_shape.gd` — Footprint(CIRCLE/SQUARE + contains + get_world_aabb)
- `addons/logic-game-framework/example/rts-auto-battle/logic/tools/path_trace_v2.gd` — 24 字段 CSV writer(M0.1 落地 baseline 工具)
- `addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_pathfinding_baseline.{tscn,gd}` — baseline trace + replay snapshot smoke
- `addons/logic-game-framework/example/rts-auto-battle/tests/baselines/0ad-baseline-master.csv` (882 KB / 6155 行,byte-identical 跨 run)
- `addons/logic-game-framework/example/rts-auto-battle/tests/baselines/0ad-baseline-master.replay.json` (34 KB)
- `addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_obstruction_footprint_split.{tscn,gd}` — M0 验收 smoke

### 改动文件

- `logic/config/rts_building_config.gd` — StatBlock 4 字段 + fallback 派生
- `logic/rts_building_actor.gd` — obstruction_shape / footprint_shape 字段 + 双路径 get_footprint_cells + sync_obstruction_shape() + assert_crash 兜底 + lazy sync
- `logic/rts_buildings.gd` — _create_from_kind 工厂注入 shape 默认字段
- `logic/rts_building_placement.gd` — `compute_footprint_cells_from_shape` / `compute_footprint_cells_core` public helper(simplify pass 去 `_` 前缀)
- `logic/commands/rts_place_building_command.gd` — apply 后调 sync
- `logic/rts_auto_battle_procedure.gd` — start get_footprint_cells 前调 sync
- `frontend/visualizers/rts_building_visualizer.gd` — _footprint_shape 字段 + bind 加参 + _draw 用 get_world_aabb
- `frontend/world_view.gd` — bld_vis.bind 调点同步加 footprint_shape
- `frontend/demo_rts_frontend.gd` — 双 ct sync + ghost preview 对齐 obstruction_size
- `frontend/demo_rts_pathfinding.gd` — 4 处 sync(OBSTACLE_POSITIONS 循环 + dummy + 动态 spawn)
- `tests/rts_scenario_harness.gd` — 2 处 sync

---

## 真实运行证据 (M2.3 末态 baseline 0 漂移 + 新 smoke)

### LGF 单元测试

```
godot --headless --path . addons/logic-game-framework/tests/run_tests.tscn
→ 总计: 73 | 通过: 73 | 失败: 0
```

### RTS 主 acceptance smoke (11 项,数字 100% 与 M2.3 末态 match)

| smoke | 实测 |
|---|---|
| smoke_rts_auto_battle | left_win ticks=347 attacks=74 (melee=32 ranged=42) melee_max=24.00 ranged_max=125.75 deaths=6 detoured=4 |
| smoke_castle_war_minimal | ticks=193 left_win unit_to_building=4 archer_anti_air=1 |
| smoke_player_command | gold=20 wood=50 log=3 |
| smoke_player_command_production | ticks=600 left_spawned=7 max_eastward=254.74 gold=20 |
| smoke_production | ticks=600 left=7 right=7 max_left_eastward=118.51 |
| smoke_crystal_tower_win | ticks=2 left_win |
| smoke_resource_nodes | ticks=200 alive=5 max_drift=0 |
| smoke_harvest_loop | ticks=600 alive=5 team_gold=140 team_wood=212 cycle=5 |
| smoke_economy_demo | ticks=900 melee_to_ct=31 |
| smoke_ai_vs_player_full_match | ai_barracks=1 ai_units_spawned=4 ai_unit_to_ct_attacks=9 |
| smoke_flying_units | PASS(anti-air / ground / flying)|

### Replay / determinism (3 项,含 baseline)

```
smoke_replay_bit_identical: seed=42 commands=2 frames=9 events=20 deep-equal
smoke_determinism: tick_diff=0 (run1 ticks=347 = run2 ticks=347)
smoke_pathfinding_baseline (新): 900 ticks / 6155 trace rows / 111 replay events / baseline CSV byte-identical 跨 run
```

### Frontend (2 项)

```
smoke_frontend_main: visualizers=10 alive_after_3.0s=10
smoke_ui_main_menu: demo=RtsFrontendDemo preset=Classic 1v1 → PASS
```

### 新 M0 acceptance smoke (1 项)

```
smoke_obstruction_footprint_split: PASS
- position_2d unchanged after mutate (sprite 锚点 F4-A 不动)
- obstruction.center == position_2d + (32, 32) = (192, 192)
- get_footprint_cells 中心在 obstruction.center 所在 cell(6,6) 而非 position_2d 所在 cell(5,5)
- footprint.contains(原位置, 原位置) == true (玩家点 sprite 中心能选中)
- AC8 part 1: Set A (ghost preview cells) == Set B (placed cells, 4 cells [(5,5),(6,5),(5,6),(6,6)])
- AC8 part 2: (Set B ∩ Set C unit_path 10 cells) == ∅ (A* 绕开 obstruction cells)
```

### F6 视觉验证 ✋1 (用户已验)

- 进 build mode + 放 1 barracks + 1 archer_tower 不同位置
- spawn 4-6 单位绕走
- 客观验证: ghost cells = obstruction cells = 单位绕走 cells **三者一致**
- 录屏 `0ad-migration-M0-after.mp4`(本地留底,不进 git)
- 用户反馈通过 → archive M0 + 启动 M1

---

## 期间附带的既有 bug 修复 (不在原 M0 scope,顺手修)

| 问题 | 修复 commit | 说明 |
|---|---|---|
| `ResourceNode` 没对齐 `IAbilitySetOwner` 约束(F6 debug 模式 fatal) | `de0cfb0` (submodule) / `8554ed5` (主仓) | `get_alive_actor_ids` 过滤 ability_set==null 纯 data actor |
| placement `event.position` 屏幕坐标当世界坐标(Camera zoom=3 偏离) | `18ae582` (submodule) / `4099597` (主仓) | scene-driven UI 重构时统一改 `get_global_mouse_position()` |
| spawn unit 不 rally(关掉左队 AI 后 melee 堆 spawn 点) | `18ae582` (submodule) / `4099597` (主仓) | 玩家手控 demo 配置加 rally point + 拨正 spawn idle 行为 |
| demo UI 全代码动态生成(反 Godot scene-driven 规范) | `18ae582` (submodule) / `4099597` (主仓) | scene-driven UI 重构 main_menu / demo_rts_frontend 子树 |

---

## 残余风险 / 已知 follow-up

1. **`get_alive_actor_ids` 过滤 ability_set==null 是临时兜底** — 真正的修法是把 ResourceNode 抽离 actor registry 或者重新审 `IAbilitySetOwner` 接口契约;留 follow-up 给 M2/M3 重审 actor 抽象
2. **`process_post_event` 是否该 assert** — 当前对 `ability_set==null` 静默 skip 但 procedure 之外的代码仍可能误调;未来迁移到完整 ObstructionManager 时统一处理
3. **F4-A 决策的视觉差异有限** — sprite 锚点 = position_2d 不变,真正"贴墙绕角不穿建筑 sprite"完整体感需 M6 vertex pathfinder 加 32px 亚 cell 精度才能完成。M0 修的是"ghost / placed / path 三者 cells 精确一致" — 这是后续 M2-M6 的基础
4. **bbox 中心算法重复** (M2.3 残余) — 已通过 `RtsBuildingPlacement.compute_footprint_cells_core` 收敛,M0 这轮已收口,残余只剩 demo._bbox_center_offset 一处(后续 phase 视需求处理)
5. **死者留 world** — 2026-04-26 起逻辑层 hp≤0 不调 world.remove_actor;死者留 registry 清格子保留 view;未来视需求评估,不属于 M0 scope
6. **`.claude/tmp/` 多个 diag_path_trace / verify_buffer / mm_repro 文件** — M0 期间 diag 工具,未 staged 不进 commit;留给用户决定是否清理

---

## Commits

### 主仓

- `067cc3b` feat(rts-m3): M3 Epic 规划 + M0.1+M0.2 落地 (bump submodule → 5adb591)
- `4115caf` feat(rts-m3): M0.3 done — config 4 字段 + bump submodule → 20c92c0
- `ee30415` feat(rts-m3): M0.4 done — actor 字段 + 双路径算法 + bump submodule → 0650c81
- `8273b07` feat(rts-m3): M0.5 done — 工厂注入 + 6 sync + Placement helper + bump submodule → f2ad109
- `bf08537` feat(rts-m3): M0.6 + M0.7 done — bump submodule → 55104ce + Progress / Next-Steps
- `8554ed5` fix(rts): bump submodule → de0cfb0 (process_post_event ResourceNode hotfix)
- `4099597` refactor(rts-frontend): bump submodule → 18ae582 (scene-driven UI + placement 修)
- (final archive sweep commit — 由本 archive 落地)

### submodule (addons/logic-game-framework)

- `5adb591` feat(rts-m3): M0.1 baseline 落地 + M0.2 obstruction data class
- `20c92c0` feat(rts-m3): M0.3 — RtsBuildingConfig.StatBlock 加 4 字段 (obstruction shape)
- `0650c81` feat(rts-m3): M0.4 — RtsBuildingActor 加 obstruction_shape / footprint_shape 字段 + 改 get_footprint_cells 双路径
- `f2ad109` feat(rts-m3): M0.5 — 工厂注入 + 6 sync sites + Placement core helper
- `55104ce` feat(rts-m3): M0.6 + M0.7 done — frontend visualizer footprint_shape + 新 smoke + Placement helpers public
- `de0cfb0` fix(rts): get_alive_actor_ids 过滤 ability_set==null 纯 data actor (ResourceNode)
- `18ae582` refactor(rts-frontend): scene-driven UI + 修 placement 链路 + 玩家手控 demo 配置

---

## Codex 审查闭环回顾 (Step A + Step B 阶段 R1-R8)

完整反馈记录见 [`Handoff-2026-05-03-0ad-migration-planning.md`](../../Handoff-2026-05-03-0ad-migration-planning.md) §11.6 / §11.7 + [`Handoff-2026-05-03-step-b-codex-review.md`](../../Handoff-2026-05-03-step-b-codex-review.md) §10 / §11 / §12。

| Round | 结论 | 关键反馈 |
|---|---|---|
| R1 | REQUEST CHANGES | 4 P1 + 7 项审查意见 — RegionID packed int64 / M0 sync 时机 / 字段命名 / §12 determinism contract |
| R2 | REQUEST CHANGES (P2) | 真实 API 名 + §12.5 motion tick 顺序显式 + M0.5 sync 6 call sites |
| R3 | REQUEST CHANGES | Q4 闭环风格 + RtsRandomSeq 残留 + RtsRng.next_* 不存在 + §11 缺 R2 记录 |
| R4 | ✅ APPROVE for Step B | 进 Step B |
| R5 | REQUEST CHANGES (3 P1) | actor.get_id 字典序 ≥ 10 unit 漂 / dirty bits 在 hierarchical update 前清 / isolated region 不进 GlobalRegionID |
| R6 | REQUEST CHANGES | interfaces §6.3 仍 actor.get_id / Handoff 旧疑虑 / validation §3.2 wall_clock 主句 |
| R7 | REQUEST CHANGES (1 P1) | interfaces §10.2 仍按 actor.get_id 字典序 |
| R8 | ✅ APPROVE for Step C | 启动 Step C(M0 实施)|

### M0 落地后回顾 R5 P1-1 决策

R5 P1-1 反馈:tick 排序 key = `(kind: String, spawn_seq: int)` 数值复合 key,**不**用 actor.get_id() 字典序(IdGenerator 真实输出 `Character_10 < Character_2` 漂移)。

M0 阶段实际未涉及 actor 排序漂(get_footprint_cells 是 building-level,不需要 unit 排序),但 M1 起 unit ↔ navcell 写入顺序需要严格遵循 R5 P1-1 contract。M0.5 自动填的 entity_id 来自 `actor.get_id`(字符串),M0 阶段 building 数 ≤ 4,字典序无漂移,但 M2 ObstructionManager 介入后必须切到数值 key。

---

## M0 末态 baseline (M1 出发点)

- 3 个 obstruction shape data class 落地、`RtsBuildingActor` 双路径 get_footprint_cells、`RtsBuildings` 工厂注入、6 个 sync sites 接入、Placement core helper 抽取、frontend visualizer 选择圈走 footprint_shape
- 14 项 smoke + LGF 73 + replay seed=42 deep-equal + 新 baseline smoke + 新 M0 acceptance smoke 全过
- 0 A.D. 本地副本 sparse checkout (9.2 MB,addons submodule .gitignore 屏蔽) 供后续 milestone 对照参考
- M3 Epic 规划文档完整(README + data-structures + interfaces + validation-strategy + risks-and-rollback + 9 milestone + deferred)

**M1 启动条件全部满足**:
- M1 spec 经 codex Round 5-8 审查 APPROVE
- M0 落地的 obstruction_shape 是 M1 NavcellGrid rasterize 的输入(M1 暂不用,但 M2 直接读)
- baseline CSV byte-identical → M1 数据层重构验收基准就绪
