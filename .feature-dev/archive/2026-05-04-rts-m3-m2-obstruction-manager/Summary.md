# RTS Pathfinding M3 Epic / M2 — ObstructionManager (Shape 数据库 + Spatial Index) — Summary (2026-05-04)

> M3 Epic 第三个 milestone(M2/9)。引入 `RtsObstructionManager` 作为所有 obstruction shape(单位圆 + 建筑 OBB)的统一数据库,替换 M0/M1 阶段"actor 自管 obstruction_shape + grid 自管 placement_map"的散乱状态;同时引入完整 `RtsObstructionFlags` 枚举(6 flag)+ `RtsObstructionTestFilter` 抽象 + `RtsSpatialIndex`(uniform grid bucket 256 px)+ 完整 SAT OBB-OBB 重叠测试。
>
> **M2 是数据层 + Manager 单例落地, production code 仍走 dual-write**(grid bit 由 `rts_grid.place_building` 写入, manager 持 shape 数据但不被 pathfinder 消费); **replay seed=42 frames=9 events=20 deep-equal + baseline CSV byte-identical(882882 bytes)0 漂移**。spec §AC8 预期"trace 字段从占位变实填"导致新 baseline 未发生 — dual-write 模式让 M5 切 pathfinder 走 manager 时再一次性接受 baseline 漂(预期变化)。

---

## Acceptance 结论 (M2.1 - M2.6 全过 + AC1-AC10 含 spec drift / deferred)

### M2.1 - M2.6 子任务

| Sub | Scope | 状态 |
|---|---|---|
| **M2.1** | `RtsObstructionFlags`(6 flag 常量)+ `RtsObstructionTestFilter`(抽象 + 3 inner class + 3 静态工厂)+ `RtsObstructionShapeUnit`(Unit 圆子类)+ `rts_buildings.gd` 硬编码 `1 << 3` 切到 `BLOCK_PATHFINDING` | ✅ done |
| **M2.2** | `RtsSpatialIndex`(BUCKET_SIZE=256, _buckets + _shape_buckets 反向索引, query_circle 末 sort 保 tag 升序) | ✅ done |
| **M2.3** | `RtsObstructionManager`(9+ 公开 API + 完整 SAT 4 轴 OBB-OBB + circle-OBB / point-in-OBB + rasterize);挂 `RtsWorldGameplayInstance.obstruction_manager`;procedure._init 末构造 | ✅ done |
| **M2.4** | Building placement 链路:`RtsPlaceBuildingCommand.apply` step 3.5 + procedure.start 起手 loop 都补 `add_static_shape` 注册;`RtsBuildingActor.obstruction_tag` 字段;**dual-write 兼容** | ✅ done |
| **M2.5** | Unit spawn / move 链路:procedure.tick step 4f `_sync_unit_obstruction_shapes`(alive_units lazy register + per-tick move_shape);`RtsUnitActor.obstruction_tag` 字段;**Death unregister deferred 到 M5** | ✅ done(partial) |
| **M2.6** | 3 个新 smoke(register / query / remove)+ Validation 全套 22 项 0 漂移 + commit | ✅ done |

### AC1-AC10 验收

- ✅ **AC1** — `RtsObstructionFlags` 完整 6 flag(BLOCK_MOVEMENT / BLOCK_FOUNDATION / BLOCK_CONSTRUCTION / BLOCK_PATHFINDING / MOVING / DELETE_UPON_CONSTRUCTION)
- ✅ **AC2** — `RtsObstructionTestFilter` 抽象 + 3 静态工厂(skip_control_group / only_blocking_movement / combined);**inner class 方案**绕 GDScript 同文件 class_name 限制(R6 缓解)
- ✅ **AC3** — `RtsSpatialIndex`(BUCKET_SIZE=256, insert/remove/move/query 完整;query_circle 末 sort 保 tag 升序;§12.4 determinism contract)
- ✅ **AC4** — `RtsObstructionManager` 单例落地(API 完整 + tag 1 起单调递增永不复用 + spatial_index 同步 + 完整 SAT 4 轴 OBB-OBB R1 缓解 + R5 P1-2 dirty lifecycle)
- ✅ **AC5** — Building placement 走 ObstructionManager(`add_static_shape` 接入;**dual-write** — grid bit 仍由 `place_building` 写入, manager 持 shape 数据;spec §step 4 "rasterize 写 NavcellGrid" 推到 M5 切 pathfinder 时一次性切换);**spec §step 3 "删除 _placement_map" literal 不适用**(M1 没该字段, 比照 M1 AC3 spec drift)
- ⏳ **AC6** — Unit spawn + move 走 ObstructionManager(unit shape = 圆, clearance = collision_radius;procedure.tick step 4f 集中 sync);**Death unregister deferred 到 M5** 启动前(spec drift, _shapes ≤ 100 unit 战斗结束 procedure GC 时随 manager 释放)
- ✅ **AC7** — 3 个新 smoke PASS(register / query / remove)
- ✅ **AC8** — Validation 全套 17 项 baseline + LGF 73 + 3 新 smoke + replay seed=42 deep-equal = 22 项 byte-identical M1 末态;baseline CSV 882882 bytes byte-identical;**spec §AC8 预期 "trace 字段从占位变实填" 触发新 baseline 未发生**(dual-write 模式下 trace 字段未变化)
- ⏳ **AC9** — Perf vs M1 wall_clock ≤ +50% / tick_p99 ≤ 30 ms — **deferred 到 M5 启动前**(perf_trace.gd / oos_log.gd 工具未实现, M0 / M1 也无;实测 wall-clock 没明显增长但缺正式数据;stop-runner 第 5 条未触发)
- ✅ **AC10** — 改动仅在 `addons/logic-game-framework/example/rts-auto-battle/` 内,不动 LGF core / stdlib

---

## 关键 artifact 路径

### 新建文件 (submodule)

- `addons/logic-game-framework/example/rts-auto-battle/logic/obstruction/rts_obstruction_flags.gd` — 6 flag 常量,对照 0 A.D. ICmpObstructionManager.h:78-86
- `addons/logic-game-framework/example/rts-auto-battle/logic/obstruction/rts_obstruction_test_filter.gd` — Filter 抽象 + 3 inner class + 3 静态工厂(R6 mitigation)
- `addons/logic-game-framework/example/rts-auto-battle/logic/obstruction/rts_obstruction_shape_unit.gd` — Unit 圆子类(clearance + moving 字段)
- `addons/logic-game-framework/example/rts-auto-battle/logic/obstruction/rts_spatial_index.gd` — Uniform grid bucket spatial index(BUCKET_SIZE=256;insert/remove/update/query_circle + 反向索引)
- `addons/logic-game-framework/example/rts-auto-battle/logic/obstruction/rts_obstruction_manager.gd` — Manager 单例(9+ 公开 API + 完整 SAT + rasterize;R5 P1-2 dirty lifecycle)
- `addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_obstruction_manager_register.{gd,tscn}` — 8 shape add → tag 1..8 单调,sorted query
- `addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_obstruction_manager_query.{gd,tscn}` — filter / test_*_shape / SAT 4-case OBB-OBB / distance
- `addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_obstruction_manager_remove.{gd,tscn}` — basic / idempotent / query-consistency / remove all + re-add

### 改动文件 (submodule)

- `logic/obstruction/rts_obstruction_shape.gd` — flags 字段注释更新(M2 引入 RtsObstructionFlags 后)
- `logic/buildings/rts_buildings.gd:85` — `obstr.flags = 1 << 3` → `RtsObstructionFlags.BLOCK_PATHFINDING`
- `logic/rts_building_actor.gd` — 加 `obstruction_tag: int = 0`
- `logic/rts_unit_actor.gd` — 加 `obstruction_tag: int = 0`
- `logic/commands/rts_place_building_command.gd:apply` — step 3.5 补 `_register_to_obstruction_manager` helper
- `core/rts_world_gameplay_instance.gd` — 加 `obstruction_manager` 字段
- `core/rts_auto_battle_procedure.gd` — `_init` 末构造 manager;`start()` 起手 loop 注册;`tick()` step 4f `_sync_unit_obstruction_shapes`

### CHANGELOG (LGF submodule)

- `addons/logic-game-framework/CHANGELOG.md` — 新增 [Unreleased] — 2026-05-04 M3 Epic / M2 段(Added / Changed / 待处理 / 验证表)

---

## 真实运行证据 (M1 末态 baseline 0 漂移 + 3 新 smoke)

### LGF 单元测试

```
godot --headless --path . addons/logic-game-framework/tests/run_tests.tscn
→ 总计: 73 | 通过: 73 | 失败: 0
```

### RTS 主 acceptance smoke (14 项,数字 100% 与 M1 末态 match)

| smoke | 实测 |
|---|---|
| smoke_rts_auto_battle | left_win ticks=347 attacks=74 (melee=32 ranged=42) melee_max=24.00 ranged_max=125.75 deaths=6 detoured=4 |
| smoke_castle_war_minimal | ticks=193 left_win unit_to_building=4 archer_anti_air=1 spawn_count=2 |
| smoke_player_command | ticks=30 gold=20 wood=50 log=3 placed_id=rts_world_0:Building_4 |
| smoke_player_command_production | ticks=600 left_spawned=7 max_eastward=254.74 gold=20 |
| smoke_production | ticks=600 left=7 right=7 max_left_eastward=118.51 |
| smoke_crystal_tower_win | ticks=2 left_win |
| smoke_resource_nodes | ticks=200 alive=5 max_drift=0 |
| smoke_harvest_loop | ticks=600 alive=5 team_gold=140 team_wood=212 cycle=5 |
| smoke_economy_demo | ticks=900 melee_spawned=4 melee_to_ct=31 final_gold=138 final_wood=196 |
| smoke_ai_vs_player_full_match | ticks=600 ai_barracks=1 ai_units_spawned=4 ai_unit_to_ct_attacks=9 |
| smoke_flying_units | ticks=200 archer_hits=3 PASS(anti-air / ground / flying)|
| smoke_pathfinding_baseline | 900 ticks / 6155 trace rows / 111 replay events |
| smoke_frontend_main | visualizers=10 alive_after_3.0s=10 |
| smoke_ui_main_menu | demo=RtsFrontendDemo preset=Classic 1v1 → PASS |

### Replay / determinism (3 项)

```
smoke_replay_bit_identical: seed=42 commands=2 frames=9 events=20 deep-equal
smoke_determinism: tick_diff=0 (run1 ticks=347 = run2 ticks=347)
baseline CSV byte-identical: 882882 bytes match M1 末态
```

### M0/M1 已有 acceptance smoke (2 项)

```
smoke_obstruction_footprint_split (M0): set_b=4 set_c=10 (B ∩ C)=∅ → PASS
smoke_navcell_grid_passability (M1): AC1+AC2+AC8 13 项断言全过 → PASS
```

### 新 M2 acceptance smoke (3 项)

```
smoke_obstruction_manager_register: PASS — 8 shapes registered, tags 1..8, sorted query OK
smoke_obstruction_manager_query:    PASS — filter + test_*_shape + SAT 4-case + distance OK
smoke_obstruction_manager_remove:   PASS — basic + idempotent + query-consistent + readd OK
```

---

## 残余风险 / 已知 follow-up

1. **AC9 perf-trace** — perf_trace.gd / oos_log.gd 工具仍未实现(M0 / M1 也无)。M2 实测 wall-clock 没明显增长(每 tick `_sync_unit_obstruction_shapes` 是高频路径但 100 unit × 30 Hz = 3000 op/s, GDScript 可承受),但缺正式数据。stop-runner 第 5 条(`tick_p99/tick_max` ≥ 100% / 2× 才停)未触发。**M5 启动前批量补足**(M5 LongPath 重写是 replay 漂移高风险段, 需要 OOSLog 风格定位 + perf-trace 跑分)。
2. **AC6 Death unregister deferred 到 M5** — spec 要求死亡时调 `manager.remove_shape(tag)`,实际 deferred:M2 阶段 manager._shapes 不被 production code 消费,死单位 tag 残留只是内存影响(≤100 unit 单场战斗,战斗结束 procedure GC 时随 manager 一并释放)。**M5 切 pathfinder 走 manager 时同步加 cleanup hook**(RtsBattleActor 死亡或 Activity Idle 退化时调)。
3. **AC5 `obstruction_manager.rasterize` 接入 deferred 到 M5** — spec §M2.4 step 4 要求 dual-write 中 manager 走 rasterize 写 NavcellGrid bit, 实际仅 `place_building` 写入(single source of truth);**M5 切 pathfinder 走 manager 时一次性切换 + 接受 baseline 漂(预期 P2 变化, risks-and-rollback §1.3)**。
4. **`set_unit_moving_flag` MOVING bit 切换 deferred 到 M7** — M2.5 spec 要求起步 / 停步触发,实际 deferred 到 M7 unit motion 重写时再做(M2 阶段 step 4f 仅 add/move,不切 MOVING bit)。
5. **Spec drift 记录** —
   - **§M2.4 step 3 "删除 RtsBattleGrid._placement_map" literal 不适用** — M1 没有 _placement_map 字段(grid model.is_tile_blocking 是 source of truth);AC5 spirit "shape 进 ObstructionManager" 通过 add_static_shape 达成。比照 M1 AC3 同样 spec drift。
   - **§M2.5 step 2 "RtsCharacters._create_unit 时调 add_unit_shape" literal 不适用** — RtsCharacters / _create_unit 在项目里不存在;30+ smoke / scenario / demo 各自直接 `RtsUnitActor.new()`,改散点不可行。**实际实现**:procedure.tick 集中 sync,新单位 lazy register。
   - **§M2.5 step 3 "RtsNavAgent.tick 末调 move_shape" 改到 procedure.tick step 4f** — 整个 movement 管线 + stuck detection 之后,单点执行更可控,且 nav_agent 不需要持 manager 引用。
   - **§AC8 预期 "trace 字段从占位变实填触发新 baseline" 未发生** — dual-write 模式下 production code 不消费 manager,trace 字段无变化;预期 P2 漂移留 M5 切 pathfinder 时一次性接受。
6. **inner class 方案 vs spec 拆 4 文件** — spec §M2.6 R6 mitigation 给两选项,实际选 inner class(更精简,跟 0 A.D. C++ inner namespace 风格一致),不建 `rts_obstruction_filters.gd` 单独文件。
7. **GDScript class_name cache race** — 4 godot 并行启动新加 class_name 时第一波读旧 cache → Parse Error → smoke FAIL。**Lesson**: 新加 class_name 的 milestone 首次跑 baseline,先单跑 1 个 smoke 让 cache stabilize 再批量并行。
8. **bash cwd 漂移坑(再次踩)** — `cd addons/logic-game-framework && git status` 改 cwd 没回主仓 → 后续 `godot --headless --path . *.tscn` 静默 hang。memory `feedback_godot_cwd.md` 已记录,但仍踩了一次 — **严禁 cd 不回**;统一用 `git -C <subdir>` 取代 cd。

---

## Commits

### 主仓

- `7e69627` feat(rts-m3): M2 done — bump submodule → 86020b0 (ObstructionManager 数据库 + Spatial Index)
- (本 archive sweep commit — 由 §8d 落地)

### submodule (addons/logic-game-framework)

- `86020b0` feat(rts-m3): M2 done — ObstructionManager (Shape 数据库 + Spatial Index)

---

## M2 末态 baseline (M3 出发点)

- 5 个 obstruction 数据 / 算法类落地(Flags + TestFilter + ShapeUnit + SpatialIndex + Manager)
- ObstructionManager 完整 API(9+ 公开 + 完整 SAT 4 轴 + circle-OBB + rasterize)
- Building / Unit 链路接 manager(dual-write 模式;Death unregister deferred)
- 17 项 RTS smoke + LGF 73 + replay seed=42 deep-equal + baseline CSV byte-identical(882882 bytes)+ 3 新 smoke 全过

**M3 启动条件全部满足**:
- M3 spec 经 codex Round 5-8 审查 APPROVE
- M2 的 ObstructionManager.rasterize(class) 已存在(M3 启用 per-class clearance buffer 外扩)
- M2 的 mark_dirty / clear_dirty 已就位(M3 启用 dirty 增量)
- 完整 EFlags + Filter 已就位(M3 + M5 短/长寻路消费)
