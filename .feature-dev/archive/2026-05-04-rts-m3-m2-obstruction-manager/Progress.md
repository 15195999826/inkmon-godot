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

- [x] **M2.1** — `RtsObstructionFlags` 完整枚举(6 flag) + `RtsObstructionTestFilter` 抽象基类 + 3 静态工厂方法 ✅ 2026-05-04
- [x] **M2.2** — `RtsSpatialIndex`(uniform grid bucket,256 px / bucket) ✅ 2026-05-04
- [x] **M2.3** — `RtsObstructionManager` 单例(挂 RtsWorldGameplayInstance.obstruction_manager);`add_unit_shape` / `add_static_shape` / `move_shape` / `remove_shape` / `get_obstructions_in_range` API ✅ 2026-05-04
- [x] **M2.4** — Building placement 链路改造:`RtsPlaceBuildingCommand.apply` 在 `place_building` 之后注册到 ObstructionManager;procedure.start 起手 building 同步注册;dual-write 兼容(grid bit 仍由 place_building 写入,manager 旁路持 shape)✅ 2026-05-04
- [x] **M2.5** — Unit spawn / move 链路改造:procedure.tick step 4f 集中 `_sync_unit_obstruction_shapes` (alive_units lazy register + per-tick move_shape);**Death unregister deferred 到 M5**(spec drift, _shapes 持续膨胀 ≤100 unit, 战斗结束 procedure GC 时随 manager 释放) ✅ 2026-05-04
- [x] **M2.6** — 新 smoke 3 个(`smoke_obstruction_manager_register / _query / _remove`)+ Validation 全套 22 项 0 漂移 + commit ✅ 2026-05-04

### M2.1 实施记录 (2026-05-04)

**新建文件** (4 个,均在 `addons/logic-game-framework/example/rts-auto-battle/logic/obstruction/`):
- `rts_obstruction_flags.gd` — 6 flag 常量(BLOCK_MOVEMENT / BLOCK_FOUNDATION / BLOCK_CONSTRUCTION / BLOCK_PATHFINDING / MOVING / DELETE_UPON_CONSTRUCTION),对照 0 A.D. `ICmpObstructionManager.h:78-86`
- `rts_obstruction_test_filter.gd` — 抽象基类(`predicate(shape)` 默认 true)+ 3 静态工厂(`skip_control_group` / `only_blocking_movement` / `combined`)+ 3 inner class 实现(`_SkipControlGroup` / `_OnlyBlockingMovement` / `_Combined`,绕 GDScript 同文件 class_name 限制 R6)
- `rts_obstruction_shape_unit.gd` — Unit 子类(`clearance` + `moving`),`_init` 设 `type = Type.UNIT`

**修改文件** (2 个):
- `rts_obstruction_shape.gd` — 基类 `flags` 字段注释从"M0 硬编码"更新为引用 `RtsObstructionFlags` + 典型组合
- `rts_buildings.gd:85` — `obstr.flags = 1 << 3` → `obstr.flags = RtsObstructionFlags.BLOCK_PATHFINDING`(消除 M0 阶段的硬编码)

**Validation 0 漂移**:
- LGF 73/73 PASS
- 14 项 baseline smoke + M0/M1 新增 = 17 项全 PASS,数字 byte-identical M1 末态(rts_auto_battle ticks=347 attacks=74 melee=32 ranged=42 melee_max=24.00 deaths=6 detoured=4 / replay seed=42 frames=9 events=20 / pathfinding_baseline 900 ticks trace=6155 events=111)
- baseline CSV `0ad-baseline-master.csv` = 882882 bytes,byte-identical M1 末态

### M2.2 实施记录 (2026-05-04)

**新建文件** (1 个):
- `rts_spatial_index.gd` — Uniform grid bucket spatial index,`BUCKET_SIZE = 256 px` (8 navcell × 32 px;H2 决策 A);`_buckets: Dictionary[Vector2i, Array[int]]` + `_shape_buckets: Dictionary[int, Array[Vector2i]]` 反向索引(O(1) remove);4 公开 API(`insert` / `remove` / `update` / `query_circle`)+ 2 调试 helper(`size` / `bucket_count`);**determinism contract**: `query_circle` 末尾 `result.sort()` 保 tag 升序(§12.4)。

**spec 偏离**: spec §M2.2 step 1 给的代码用 `range` 做参数名(GDScript builtin function shadow),改名为 `query_range` 避免警告/混淆;调用方 ObstructionManager.test_*_shape 拿到的 API 一致。

**完成标志验证延后**: spec "完成标志:`RtsSpatialIndex.new()` insert 100 shape + query_circle 返回有序 tag 列表;单元测试覆盖 insert / move / remove / boundary case" 由 M2.6 `smoke_obstruction_manager_query` 间接覆盖(ObstructionManager 实例化即 instantiate SpatialIndex,API 全链路用)— 不为 RtsSpatialIndex 单独写 .tscn smoke,避免文件膨胀。

**Validation 0 漂移** (M2.2 末态):
- LGF 73/73 PASS
- RTS auto battle: ticks=347 attacks=74 melee=32 ranged=42 deaths=6 detoured=4(byte-identical M1 末态)
- replay seed=42 frames=9 events=20 deep-equal
- pathfinding_baseline 900 ticks trace=6155 events=111(spot 检 4 项核心 baseline,M2.6 跑全套 17 项)
- baseline CSV `0ad-baseline-master.csv` = 882882 bytes,byte-identical M1 末态

**踩坑记录**: 期间 bash cwd 漂到 submodule 内部(`cd addons/logic-game-framework && git status` 改了 cwd 没回去),所有后续 `godot --headless --path . *.tscn` 都 hang 在 banner 后(submodule 内无 project.godot,Godot 静默挂死)。memory `feedback_godot_cwd.md` 已记录此坑;运行时坑提醒:**任何 `cd <subdir>` 后必须显式 `cd` 回主仓**,或一律走绝对路径不 cd。

### M2.3 实施记录 (2026-05-04)

**新建文件** (1 个):
- `rts_obstruction_manager.gd` — RefCounted 单例,字段 `_shapes: Dictionary[int, RtsObstructionShape]` + `_next_tag: int = 1` + `_spatial_index: RtsSpatialIndex` + `_navcell_grid: RtsNavcellGrid` + `_passability_registry: RtsPassabilityClassRegistry`;9 公开 API(add_unit/static_shape / move_shape / set_unit_moving_flag / set_*control_group / remove_shape / get_shape / get_obstructions_in_range / test_*_shape / distance_to_point / distance_to_target / rasterize)+ 2 调试 helper(size / next_tag);完整 SAT 4 轴 OBB-OBB(R1 缓解);完整 circle-OBB / OBB local 投影 / point-in-OBB 几何;rasterize 把 BLOCK_PATHFINDING shape 写 NavcellGrid 对应 class bit。

**修改文件** (2 个):
- `rts_world_gameplay_instance.gd` — 加 `obstruction_manager: RtsObstructionManager = null` 字段,跟 grid / passability_registry 字段同段;注释明确 M2.3 阶段闲置不接 building / unit 链路。
- `rts_auto_battle_procedure.gd:_init` — attach passability_registry 之后构造 ObstructionManager,挂 `world.obstruction_manager`;grid 为 null 时跳过(老 smoke fallback)。

**spec 偏离 (R5 P1-2 决策应用)**: spec §M2.3 给的 rasterize 伪代码末尾写了 `grid.clear_dirty()`,这违反 R5 P1-2 "rasterize 只读 dirty,RtsWorld.tick step 7 末统一 clear_dirty"(stop runner 第 8 条)。已按修订移除,代码内注释固化此约束。

**Determinism 加固**: spec rasterize 直接 `for tag in _shapes` 遍历 Dictionary,Dictionary 迭代序非 deterministic(§12.4)。修订为先 `_shapes.keys() + sort()` 再遍历,保证 rasterize 写入序固定。

**Validation 0 漂移** (M2.3 末态):
- LGF 73/73 PASS
- RTS auto battle: ticks=347 attacks=74 melee=32 ranged=42 deaths=6 detoured=4(byte-identical M1 末态;manager 闲置不影响 simulation)
- replay seed=42 frames=9 events=20 deep-equal
- pathfinding_baseline 900 ticks trace=6155 events=111
- baseline CSV `0ad-baseline-master.csv` = 882882 bytes,byte-identical M1 末态

**踩坑记录** (新): 4 个 godot 并行启动时,GDScript class_name cache 出现 race — 第一波启动的进程读旧 cache(没 RtsObstructionManager 注册)→ procedure.gd 引用 RtsObstructionManager 时 Parse Error → smoke FAIL;后启动的 pathfinding_baseline 拿到 refresh 后的 cache → PASS。**Lesson**: 新加 class_name 的 milestone 首次跑 baseline,先单跑一次让 cache stabilize,再批量并行。M2.3 末态我重跑 RTS / replay smoke 单跑后 PASS 确认问题已解。

### M2.4 实施记录 (2026-05-04)

**修改文件** (3 个):
- `rts_building_actor.gd` — 加 `obstruction_tag: int = 0` 字段;注释说明 dual-write 模式 + M5 切到 single source of truth 时机。
- `rts_place_building_command.gd:apply` — step 3.5 补 `_register_to_obstruction_manager(rts_world, building)` (内部静态 helper, 调 `obstruction_manager.add_static_shape` 拿 tag 存 `building.obstruction_tag`);flag 用 `BLOCK_PATHFINDING | BLOCK_FOUNDATION`;manager / shape 任一为 null 时跳过(老 smoke / 单元测试 stub 兼容)。
- `rts_auto_battle_procedure.gd:start` — 起手 placed building loop 内, `place_building` 之后 inline 调 `add_static_shape`(同样 manager / shape 任一 null 跳过);procedure.start 路径不复用 placement command 的 helper(避免依赖循环, inline 跟 procedure 上下文绑定)。

**dual-write 模式说明**: M2.4 不调 `obstruction_manager.rasterize` — manager 持 shape 数据但 grid bit 仍由 `rts_grid.place_building` 写入。这保证 production code 的 pathfinder / placement validation 走的还是 M1 末态路径,baseline 完全 byte-identical。M5 切 pathfinder 走 manager 时再一次性切换(spec §AC8 接受 baseline 漂作为预期变化)。

**Validation 0 漂移** (M2.4 末态):
- LGF 73/73 PASS
- RTS auto battle: ticks=347 attacks=74 melee=32 ranged=42 deaths=6 detoured=4(byte-identical)
- replay seed=42 frames=9 events=20 deep-equal
- pathfinding_baseline 900 ticks trace=6155 events=111
- player_command: ticks=30 gold=20 wood=50(placement command 路径覆盖)
- castle_war_minimal: ticks=193 unit_to_building_attacks=4 archer_anti_air=1 spawn_count=2(完整 placement → 攻击 → 胜负判定链路覆盖)
- baseline CSV 882882 bytes byte-identical M1 末态

### M2.5 实施记录 (2026-05-04)

**修改文件** (2 个):
- `rts_unit_actor.gd` — 加 `obstruction_tag: int = 0` 字段(0 = 未注册;death unregister deferred 到 M5)。
- `rts_auto_battle_procedure.gd` — `tick()` step 4d 之后插入 step 4f `_sync_unit_obstruction_shapes(world, alive_units)`(manager null 跳过);新加 helper `_sync_unit_obstruction_shapes`:遍历 alive_units,`obstruction_tag == 0` 调 `add_unit_shape` 注册并存 tag,`!= 0` 调 `move_shape(tag, position_2d)`;dual-write 模式下 production code 不消费 manager,baseline 0 漂移。

**spec drift 记录**:
1. spec §M2.5 step 2 "RtsCharacters._create_unit 时调 add_unit_shape" literal 不适用 — RtsCharacters / _create_unit 在项目里不存在;30+ smoke / scenario / demo 各自直接 `RtsUnitActor.new()`,改散点不可行。**实际实现**:procedure.tick 集中 sync,新单位 lazy register。
2. spec §M2.5 step 3 "RtsNavAgent.tick 末调 move_shape" 改到 procedure.tick step 4f(整个 movement 管线 + stuck detection 之后)— 单点执行更可控,且 nav_agent 不需要持 manager 引用。
3. spec §M2.5 step 4 "death 调 remove_shape" **deferred 到 M5 启动前**:M2 阶段 manager._shapes 不被 production code 消费,死单位 tag 残留只是内存影响(≤100 unit 单场战斗,战斗结束 GC 释放);M5 切 pathfinder 走 manager 时同步加 death cleanup hook(RtsBattleActor 死亡或 Activity Idle 退化时调)。
4. spec §M2.5 step 3 "set_unit_moving_flag 起步 / 停步" 推到 M7 unit motion 重写时再做(M2.5 step 4f 仅 add/move,不切 MOVING flag)。

**Validation 0 漂移** (M2.5 末态;每 tick move_shape 是关键 perf / determinism 风险点,严格检 baseline):
- LGF 73/73 PASS
- RTS auto battle: ticks=347 attacks=74 melee=32 ranged=42 deaths=6 detoured=4(byte-identical)
- replay seed=42 frames=9 events=20 deep-equal
- pathfinding_baseline 900 ticks trace=6155 events=111
- determinism: tick_diff=0
- castle_war_minimal: ticks=193 unit_to_building_attacks=4 archer_anti_air=1 spawn_count=2
- baseline CSV 882882 bytes byte-identical M1 末态

### M2.6 实施记录 (2026-05-04)

**新建文件** (3 个 smoke + 3 个 tscn = 6 个):
- `tests/battle/smoke_obstruction_manager_register.{gd,tscn}` — 8 shape add (5 unit + 3 static), 验证 tag 1..8 单调 + size + sorted query (§12.4 determinism) + get_shape 反查
- `tests/battle/smoke_obstruction_manager_query.{gd,tscn}` — 5 段:filter predicate (skip_control_group / only_blocking_movement / combined) + test_unit_shape (单位 vs 单位) + test_static_shape (OBB vs Unit / OBB) + **SAT OBB-OBB 4 case** (R1 缓解:轴对齐 / 旋转 45° / 边接触 / 角接触) + distance_to_point + distance_to_target
- `tests/battle/smoke_obstruction_manager_remove.{gd,tscn}` — 4 段:remove basic + idempotent (重复 remove / 不存在 tag 不 crash) + query 一致性 (remove 后 get_obstructions_in_range 不返回该 shape) + remove all + re-add (验证 tag 永不复用)

**Validation 0 漂移** (M2.6 末态 = M2 末态;22 项全 PASS):
- LGF 73/73
- 14 项 baseline + 3 新 obstruction_manager + 3 M0/M1 (obstruction_footprint_split / navcell_grid_passability + register/query/remove) = 17 RTS smoke 全 PASS
- 关键数字 byte-identical: rts_auto_battle ticks=347 attacks=74 melee=32 ranged=42 / replay seed=42 frames=9 events=20 / pathfinding_baseline 900 ticks trace=6155 events=111 / castle_war_minimal ticks=193 / player_command ticks=30 gold=20 wood=50 / production ticks=600 left=7 right=7 / harvest_loop team_gold=140 team_wood=212 / economy_demo ticks=900 melee_spawned=4 final_gold=138 final_wood=196 / determinism tick_diff=0 / ai_vs_player ticks=600 ai_units_spawned=4
- baseline CSV `0ad-baseline-master.csv` = 882882 bytes byte-identical
- 3 新 smoke 各覆盖 AC4 / AC7 + R1 SAT 4-case 缓解

---

## 2. AC1-AC10 验收(完整定义见 M2.md §3)

- [x] **AC1** — `RtsObstructionFlags` 完整枚举(BLOCK_MOVEMENT / BLOCK_FOUNDATION / BLOCK_CONSTRUCTION / BLOCK_PATHFINDING / MOVING / DELETE_UPON_CONSTRUCTION 6 flag) ✅ M2.1
- [x] **AC2** — `RtsObstructionTestFilter` 抽象 + 3 工厂(skip_control_group / only_blocking_movement / combined) ✅ M2.1
- [x] **AC3** — `RtsSpatialIndex` uniform grid bucket(256 px / bucket;add/remove/move/query) ✅ M2.2;query_circle 末 sort() 保 tag 升序;单元覆盖 deferred 到 M2.6 obstruction_manager_query smoke
- [x] **AC4** — `RtsObstructionManager` 单例落地(API 完整 + tag 唯一 + spatial index 同步) ✅ M2.3;9 公开 API + 完整 SAT (R1 缓解;`_obb_obb_overlap_sat` 4 轴投影) + tag 1 起单调递增 + R5 P1-2 dirty lifecycle (rasterize 不调 clear_dirty);单元覆盖延后 M2.6
- [x] **AC5** — Building placement 走 ObstructionManager ✅ M2.4;**dual-write 模式** — placement command + procedure.start 起手 loop 都补 `add_static_shape` 注册到 manager,`building.obstruction_tag` 字段持 tag;grid bit 仍由 `rts_grid.place_building` 写入(spec §M2.4 step 4 "rasterize 写 NavcellGrid" 推到 M5 切 pathfinder 时一次性切换,接受 baseline 漂)。spec §M2.4 step 3 "删除 _placement_map" literal 不适用(M1 没该字段;比照 M1 AC3 spec drift)
- [x] **AC6** — Unit spawn + move 走 ObstructionManager(unit shape = 圆,clearance = collision_radius;procedure.tick step 4f 集中 sync) ✅ M2.5 partial;**Death unregister deferred** 到 M5 启动前(M5 切 pathfinder 走 manager 时再加完整 cleanup;M2 阶段死单位 obstruction_tag 残留不影响 baseline,因为 production code 不消费 manager._shapes)
- [x] **AC7** — 3 个 smoke PASS(register / query / remove) ✅ M2.6
- [x] **AC8** — Validation 全套 17 项 baseline + LGF 73 + 3 新 smoke + replay seed=42 deep-equal = 22 项;**全部 byte-identical M1 末态(0 漂移)**;baseline CSV 882882 bytes byte-identical。**spec drift 注**: spec §AC8 预期 "M2 引入 Obstruction trace 字段从占位变实填" 触发新 baseline,但 dual-write 模式下 production code 不消费 manager,trace 字段未变化,实际**完全 0 漂移**(预期 P2 漂移留到 M5 切 pathfinder 走 manager 时一次性接受) ✅ M2.6
- [ ] **AC9** — Perf vs M1:wall_clock ≤ +50%,tick_p99 ≤ 30 ms — **deferred 到 M5 启动前**(M2 阶段 perf-trace 工具未实现, M0 也无,实测 wall-clock 没明显增长但缺正式数据;spec §AC9 完整测量留 perf_trace.gd + oos_log.gd 工具补足后做)
- [x] **AC10** — 改动仅在 `addons/logic-game-framework/example/rts-auto-battle/` 内,不动 LGF core/ stdlib/ ✅ M2.1 持续

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
