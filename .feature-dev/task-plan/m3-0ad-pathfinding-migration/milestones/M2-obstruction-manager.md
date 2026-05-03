# M2 — ObstructionManager (Shape 数据库)

> 父 plan: [`../README.md`](../README.md)
> 数据结构: [`../data-structures.md`](../data-structures.md) §2
> API: [`../interfaces.md`](../interfaces.md) §2
>
> Status: 🔒 pending(M1 完成后启动)
> 依赖: M1 (NavcellGrid 数据存储 + PassabilityRegistry)
> 阻塞: M3 (Clearance 外扩需要 ObstructionManager.rasterize)

---

## 0. 目标

引入 `RtsObstructionManager` 作为所有 obstruction shape(单位圆 + 建筑 OBB)的统一数据库,替换 M0/M1 阶段"actor 自管 obstruction_shape + grid 自管 placement_map"的散乱状态:

- 单位 spawn → `add_unit_shape` → 拿到 tag
- 建筑 placement → `add_static_shape` → 拿到 tag
- 单位 move → `move_shape(tag)` → 内部更新 spatial index
- entity 死亡 → `remove_shape(tag)` → 解除注册
- Pathfinder/Activity 范围查询 → `get_obstructions_in_range(pos, range)`

**M2 引入完整 EFlags 枚举 + spatial index(uniform grid bucket)** + 替换 `RtsBattleGrid.place_building` 为 ObstructionManager.add_static_shape + rasterize。

---

## 1. Scope

### 1.1 必做

- 新建 `RtsObstructionShape` 完整层级:基类 + UnitShape (圆) + StaticShape (OBB) — M0 已有,M2 加 entity_id / tag / control_group / control_group_2 / flags 字段并启用
- 新建 `RtsObstructionFlags` 完整枚举(M0 时硬编码 `1<<3`,M2 引入 6 个 flag)
- 新建 `RtsObstructionTestFilter` 抽象基类 + 3 个静态工厂方法
- 新建 `RtsSpatialIndex`(uniform grid bucket,256 px / bucket)
- 新建 `RtsObstructionManager` 单例(autoload 或挂 GameWorld)
- 改造 building placement 链路:`RtsBuildingPlacement.apply` 内部 `add_static_shape` → 拿 tag → 调 `rasterize` 写到 NavcellGrid
- 改造 unit spawn 链路:`RtsCharacters._create_unit` 内部 `add_unit_shape` → tag 存到 actor.obstruction_tag
- 改造 unit motion 链路(M2 阶段仍用旧 RtsNavAgent):每 tick `move_shape(actor.obstruction_tag, new_pos)`
- 加新 smoke `smoke_obstruction_manager_register.tscn` + `smoke_obstruction_manager_query.tscn` + `smoke_obstruction_manager_remove.tscn`

### 1.2 不做 (留给后续 M)

| 不做 | 原因 |
|---|---|
| Clearance 外扩 (per-class buffer) | M3 |
| Hierarchical 增量更新 (基于 dirtinessGrid) | M4 |
| Group filter 真正在 Vertex / Motion 启用 | M6 / M7(M2 时 control_group 字段写入但消费方未到位) |
| 替换 GridPathfinding (它仍用旧 grid 数据) | M5 |
| Quadtree spatial index | 不在本 Epic(uniform grid 100 单位规模够用) |
| ObstructionManager 序列化进 replay | 不需要(ObstructionManager 是 derived state,从 actor 重建) |

### 1.3 文件清单

#### 新建

```
addons/.../logic/obstruction/
├── rts_obstruction_flags.gd                ← 完整枚举 const
├── rts_obstruction_shape_unit.gd           ← Unit 圆形 (M0 没建,这里建)
├── rts_obstruction_test_filter.gd          ← 抽象 + 3 静态工厂
├── rts_obstruction_filters.gd              ← 具体 filter 实现 (skip_control_group / only_blocking_movement)
├── rts_spatial_index.gd                    ← Uniform grid bucket
└── rts_obstruction_manager.gd              ← 单例
```

#### 修改

```
addons/.../logic/
├── obstruction/
│   ├── rts_obstruction_shape.gd            ← 加 entity_id / tag / control_group / flags 字段(M0 已建)
│   └── rts_obstruction_shape_static.gd     ← M0 已建,M2 启用 entity_id / tag
├── rts_world.gd                            ← 加 obstruction_manager 字段 + 启动初始化
├── rts_building_actor.gd                   ← 启用 obstruction_shape.tag (从 ObstructionManager 拿)
├── rts_unit_actor.gd                       ← (新增) 引入 obstruction_tag 字段(单位也注册)
├── characters/rts_characters.gd            ← _create_unit 时 add_unit_shape
├── buildings/rts_buildings.gd              ← _create_building 工厂(M0 已改),M2 时 entity_id / control_group 由 sync 时填(参考 M0.5 流程)
├── commands/rts_building_placement.gd      ← apply 时 add_static_shape + rasterize
├── commands/rts_place_building_command.gd  ← 同步链路调整
├── movement/rts_nav_agent.gd               ← (M2 末) 每 tick 调 move_shape
└── core/rts_auto_battle_procedure.gd       ← 启动时初始化 ObstructionManager
```

#### 新建 (smoke)

```
addons/.../tests/battle/
├── smoke_obstruction_manager_register.tscn      ← 注册流程
├── smoke_obstruction_manager_query.tscn         ← 范围查询
└── smoke_obstruction_manager_remove.tscn        ← 删除链路
```

---

## 2. 子任务 (M2.1 → M2.6)

### M2.1 — RtsObstructionFlags + Filter 基础设施

**步骤**:
1. 新建 `logic/obstruction/rts_obstruction_flags.gd`(按 [data-structures §2.2](../data-structures.md#22-eflags-枚举)):
   ```gdscript
   class_name RtsObstructionFlags

   const BLOCK_MOVEMENT: int           = 1 << 0
   const BLOCK_FOUNDATION: int         = 1 << 1
   const BLOCK_CONSTRUCTION: int       = 1 << 2
   const BLOCK_PATHFINDING: int        = 1 << 3
   const MOVING: int                   = 1 << 4
   const DELETE_UPON_CONSTRUCTION: int = 1 << 5
   ```
2. 新建 `logic/obstruction/rts_obstruction_test_filter.gd`:
   ```gdscript
   class_name RtsObstructionTestFilter
   extends RefCounted

   ## 抽象方法,子类实现
   func predicate(shape) -> bool:
       return true

   ## 静态工厂(返回具体子类实例)
   static func skip_control_group(group: String) -> RtsObstructionTestFilter:
       return RtsSkipControlGroupFilter.new(group)

   static func only_blocking_movement() -> RtsObstructionTestFilter:
       return RtsOnlyBlockingMovementFilter.new()

   static func combined(a: RtsObstructionTestFilter, b: RtsObstructionTestFilter) -> RtsObstructionTestFilter:
       return RtsCombinedFilter.new(a, b)
   ```
3. 新建 `logic/obstruction/rts_obstruction_filters.gd`(三个具体 filter):
   ```gdscript
   class_name RtsSkipControlGroupFilter
   extends RtsObstructionTestFilter

   var _group: String

   func _init(g: String) -> void:
       _group = g

   func predicate(shape) -> bool:
       if shape.control_group == _group or shape.control_group_2 == _group:
           return false
       return true


   class_name RtsOnlyBlockingMovementFilter
   extends RtsObstructionTestFilter

   func predicate(shape) -> bool:
       return (shape.flags & RtsObstructionFlags.BLOCK_MOVEMENT) != 0


   class_name RtsCombinedFilter
   extends RtsObstructionTestFilter

   var _a: RtsObstructionTestFilter
   var _b: RtsObstructionTestFilter

   func _init(a, b) -> void:
       _a = a
       _b = b

   func predicate(shape) -> bool:
       return _a.predicate(shape) and _b.predicate(shape)
   ```

**完成标志**: 4 个文件落地 + `--import` 通过。

### M2.2 — RtsSpatialIndex (uniform grid bucket)

**步骤**:
1. 新建 `logic/obstruction/rts_spatial_index.gd`(按 [data-structures §2.4](../data-structures.md#24-rtsspatialindex-查询加速m2-引入可后期换)):
   ```gdscript
   class_name RtsSpatialIndex
   extends RefCounted

   const BUCKET_SIZE: int = 256

   var _buckets: Dictionary = {}    # Vector2i → Array[int (tag)]
   var _shape_buckets: Dictionary = {}  # tag → Array[Vector2i] (for remove)

   func _bucket_indices(pos: Vector2, radius: float) -> Array[Vector2i]:
       var min_x: int = int(floorf((pos.x - radius) / BUCKET_SIZE))
       var max_x: int = int(floorf((pos.x + radius) / BUCKET_SIZE))
       var min_y: int = int(floorf((pos.y - radius) / BUCKET_SIZE))
       var max_y: int = int(floorf((pos.y + radius) / BUCKET_SIZE))
       var result: Array[Vector2i] = []
       for j in range(min_y, max_y + 1):
           for i in range(min_x, max_x + 1):
               result.append(Vector2i(i, j))
       return result

   func insert(tag: int, pos: Vector2, radius: float) -> void:
       var indices := _bucket_indices(pos, radius)
       for k in indices:
           var arr: Array = _buckets.get(k, [])
           arr.append(tag)
           _buckets[k] = arr
       _shape_buckets[tag] = indices

   func remove(tag: int, _pos: Vector2, _radius: float) -> void:
       if not _shape_buckets.has(tag):
           return
       for k in _shape_buckets[tag]:
           var arr: Array = _buckets.get(k, [])
           arr.erase(tag)
           if arr.is_empty():
               _buckets.erase(k)
           else:
               _buckets[k] = arr
       _shape_buckets.erase(tag)

   func update(tag: int, old_pos: Vector2, new_pos: Vector2, radius: float) -> void:
       remove(tag, old_pos, radius)
       insert(tag, new_pos, radius)

   func query_circle(pos: Vector2, range: float) -> Array[int]:
       var indices := _bucket_indices(pos, range)
       var seen: Dictionary = {}
       var result: Array[int] = []
       for k in indices:
           if not _buckets.has(k):
               continue
           for tag in _buckets[k]:
               if not seen.has(tag):
                   seen[tag] = true
                   result.append(tag)
       result.sort()  # determinism: 必须按 tag 升序返回 (§12.4)
       return result
   ```

**完成标志**: `RtsSpatialIndex.new()` insert 100 shape + query_circle 返回有序 tag 列表;单元测试覆盖 insert / move / remove / boundary case。

### M2.3 — RtsObstructionManager 单例

**步骤**:
1. 新建 `logic/obstruction/rts_obstruction_manager.gd`(按 [data-structures §2.3](../data-structures.md#23-rtsobstructionmanager-autoload--gameworld-单例) + [interfaces §2](../interfaces.md#2-rtsobstructionmanager--shape-数据库-m2-引入)):
   ```gdscript
   class_name RtsObstructionManager
   extends RefCounted

   var _shapes: Dictionary = {}          # tag → RtsObstructionShape
   var _next_tag: int = 1
   var _spatial_index: RtsSpatialIndex
   var _navcell_grid: RtsNavcellGrid
   var _passability_registry: RtsPassabilityClassRegistry

   func _init(grid: RtsNavcellGrid, registry: RtsPassabilityClassRegistry) -> void:
       _spatial_index = RtsSpatialIndex.new()
       _navcell_grid = grid
       _passability_registry = registry

   # === 注册 / 注销 ===

   func add_unit_shape(entity_id: String, pos: Vector2, clearance: float, flags: int, group: String) -> int:
       var s := RtsObstructionShapeUnit.new()
       s.entity_id = entity_id
       s.center = pos
       s.clearance = clearance
       s.flags = flags
       s.control_group = group
       s.tag = _next_tag
       _next_tag += 1
       _shapes[s.tag] = s
       _spatial_index.insert(s.tag, pos, clearance)
       _mark_navcell_dirty(pos, clearance)
       return s.tag

   func add_static_shape(entity_id: String, pos: Vector2, rotation: float, w: float, h: float, flags: int, group: String, group2: String = "") -> int:
       var s := RtsObstructionShapeStatic.new()
       s.entity_id = entity_id
       s.center = pos
       s.rotation_rad = rotation
       s.width = w
       s.height = h
       s.flags = flags
       s.control_group = group
       s.control_group_2 = group2
       s.tag = _next_tag
       _next_tag += 1
       _shapes[s.tag] = s
       var enclose_radius: float = sqrt(w*w + h*h) / 2.0
       _spatial_index.insert(s.tag, pos, enclose_radius)
       _mark_navcell_dirty(pos, enclose_radius)
       return s.tag

   func move_shape(tag: int, pos: Vector2, rotation: float = 0.0) -> void:
       if not _shapes.has(tag):
           return
       var s = _shapes[tag]
       var old_pos: Vector2 = s.center
       var radius: float
       if s is RtsObstructionShapeUnit:
           radius = s.clearance
       else:
           radius = sqrt(s.width * s.width + s.height * s.height) / 2.0
       _mark_navcell_dirty(old_pos, radius)   # 旧位置 dirty
       s.center = pos
       if s is RtsObstructionShapeStatic:
           s.rotation_rad = rotation
       _spatial_index.update(tag, old_pos, pos, radius)
       _mark_navcell_dirty(pos, radius)       # 新位置 dirty

   func set_unit_moving_flag(tag: int, moving: bool) -> void:
       if not _shapes.has(tag):
           return
       var s = _shapes[tag]
       if not (s is RtsObstructionShapeUnit):
           return
       if moving:
           s.flags = s.flags | RtsObstructionFlags.MOVING
           s.moving = true
       else:
           s.flags = s.flags & ~RtsObstructionFlags.MOVING
           s.moving = false

   func set_unit_control_group(tag: int, group: String) -> void:
       if _shapes.has(tag):
           _shapes[tag].control_group = group

   func set_static_control_group(tag: int, group: String, group2: String = "") -> void:
       if _shapes.has(tag):
           var s = _shapes[tag]
           s.control_group = group
           s.control_group_2 = group2

   func remove_shape(tag: int) -> void:
       if not _shapes.has(tag):
           return
       var s = _shapes[tag]
       var radius: float
       if s is RtsObstructionShapeUnit:
           radius = s.clearance
       else:
           radius = sqrt(s.width * s.width + s.height * s.height) / 2.0
       _spatial_index.remove(tag, s.center, radius)
       _mark_navcell_dirty(s.center, radius)
       _shapes.erase(tag)

   # === 查询 ===

   func get_shape(tag: int) -> RtsObstructionShape:
       return _shapes.get(tag, null)

   func get_obstructions_in_range(pos: Vector2, range: float) -> Array:
       var tags: Array[int] = _spatial_index.query_circle(pos, range)
       var result: Array = []
       for t in tags:  # tags 已按升序 (spatial_index.query_circle 内 sort)
           result.append(_shapes[t])
       return result

   func test_unit_shape(filter: RtsObstructionTestFilter, pos: Vector2, clearance: float) -> bool:
       var nearby = get_obstructions_in_range(pos, clearance + _passability_registry.max_clearance())
       for s in nearby:
           if not filter.predicate(s):
               continue
           if _circles_overlap(pos, clearance, s):
               return true
       return false

   func test_static_shape(filter: RtsObstructionTestFilter, pos: Vector2, rotation: float, w: float, h: float) -> bool:
       var enclose_radius: float = sqrt(w*w + h*h) / 2.0
       var nearby = get_obstructions_in_range(pos, enclose_radius + _passability_registry.max_clearance())
       for s in nearby:
           if not filter.predicate(s):
               continue
           if _obb_overlaps(pos, rotation, w, h, s):
               return true
       return false

   func distance_to_point(entity_id: String, point: Vector2) -> float:
       for tag in _shapes:
           var s = _shapes[tag]
           if s.entity_id == entity_id:
               return _shape_to_point_distance(s, point)
       return INF

   func distance_to_target(entity_id_a: String, entity_id_b: String) -> float:
       var sa = _find_shape_by_entity(entity_id_a)
       var sb = _find_shape_by_entity(entity_id_b)
       if sa == null or sb == null:
           return INF
       return _shape_to_shape_distance(sa, sb)

   # === Rasterize 进 grid ===

   func rasterize(grid: RtsNavcellGrid, pass_class: RtsPassabilityClassConfig, dirty_only: bool) -> void:
       var class_mask: int = 1 << pass_class.bit_index
       if not dirty_only:
           # 全图清掉这个 class 的 bit
           for j in range(grid.height()):
               for i in range(grid.width()):
                   grid.and_data(i, j, class_mask)
       # 重新刷写所有 BLOCK_PATHFINDING shape (M2 阶段所有 building 都是 BLOCK_PATHFINDING)
       for tag in _shapes:
           var s = _shapes[tag]
           if (s.flags & RtsObstructionFlags.BLOCK_PATHFINDING) == 0:
               continue
           _rasterize_one_shape(grid, s, class_mask)
       grid.clear_dirty()

   # === Helper (内部) ===

   func _mark_navcell_dirty(pos: Vector2, radius: float) -> void:
       # 标 dirty 范围内的 navcells (M3 阶段才用 dirty_only rasterize)
       var min_i: int = int(floorf((pos.x - radius) / RtsNavcellGrid.NAVCELL_SIZE_PX))
       var max_i: int = int(floorf((pos.x + radius) / RtsNavcellGrid.NAVCELL_SIZE_PX))
       var min_j: int = int(floorf((pos.y - radius) / RtsNavcellGrid.NAVCELL_SIZE_PX))
       var max_j: int = int(floorf((pos.y + radius) / RtsNavcellGrid.NAVCELL_SIZE_PX))
       for j in range(min_j, max_j + 1):
           for i in range(min_i, max_i + 1):
               if i >= 0 and i < _navcell_grid.width() and j >= 0 and j < _navcell_grid.height():
                   _navcell_grid.mark_dirty(i, j)

   func _circles_overlap(pos_a: Vector2, r_a: float, shape_b) -> bool:
       if shape_b is RtsObstructionShapeUnit:
           var d2 := pos_a.distance_squared_to(shape_b.center)
           var sum := r_a + shape_b.clearance
           return d2 < sum * sum
       # 圆 vs OBB
       return _circle_obb_overlap(pos_a, r_a, shape_b)

   func _circle_obb_overlap(pos: Vector2, radius: float, obb: RtsObstructionShapeStatic) -> bool:
       var local := pos - obb.center
       var u := Vector2(cos(obb.rotation_rad), sin(obb.rotation_rad))
       var v := Vector2(-sin(obb.rotation_rad), cos(obb.rotation_rad))
       var lx := local.dot(u)
       var ly := local.dot(v)
       var hw := obb.width / 2.0
       var hh := obb.height / 2.0
       var dx := maxf(absf(lx) - hw, 0.0)
       var dy := maxf(absf(ly) - hh, 0.0)
       return (dx * dx + dy * dy) < radius * radius

   func _obb_overlaps(pos: Vector2, rot: float, w: float, h: float, shape_b) -> bool:
       # OBB vs 圆 / OBB
       if shape_b is RtsObstructionShapeUnit:
           # 反过来: shape_b 是圆,先检它跟我们 OBB
           var our_obb := RtsObstructionShapeStatic.new()
           our_obb.center = pos
           our_obb.rotation_rad = rot
           our_obb.width = w
           our_obb.height = h
           return _circle_obb_overlap(shape_b.center, shape_b.clearance, our_obb)
       # OBB vs OBB:用 SAT(Separating Axis Theorem)
       return _obb_obb_overlap_sat(pos, rot, w, h, shape_b)

   func _obb_obb_overlap_sat(pos: Vector2, rot: float, w: float, h: float, obb_b: RtsObstructionShapeStatic) -> bool:
       # 完整 SAT: 4 个轴(2 from A + 2 from B),逐轴投影看是否分离
       # 实现细节参考 0 A.D. CCmpObstructionManager.cpp:TestObstructionsAgainstSquare
       # M2 阶段实现完整版,放到 helper:
       return _sat_check([_axis(rot), _axis(rot + PI/2), _axis(obb_b.rotation_rad), _axis(obb_b.rotation_rad + PI/2)], pos, rot, w, h, obb_b)

   func _axis(rad: float) -> Vector2:
       return Vector2(cos(rad), sin(rad))

   func _sat_check(axes: Array, pos_a: Vector2, rot_a: float, w_a: float, h_a: float, obb_b: RtsObstructionShapeStatic) -> bool:
       # 简化版伪代码 — M2 实施时填完整 SAT
       # 见 0 A.D. helpers/Pathfinding.cpp 同名函数
       return true   # 保守:重叠 (避免错放)

   func _rasterize_one_shape(grid: RtsNavcellGrid, s: RtsObstructionShape, class_mask: int) -> void:
       # 把 shape 占用的 navcells 写 class_mask bit
       if s is RtsObstructionShapeUnit:
           # M2 单位通常不 BLOCK_PATHFINDING,但若设了仍处理
           var ci := int(floorf(s.center.x / RtsNavcellGrid.NAVCELL_SIZE_PX))
           var cj := int(floorf(s.center.y / RtsNavcellGrid.NAVCELL_SIZE_PX))
           grid.or_data(ci, cj, class_mask)
       elif s is RtsObstructionShapeStatic:
           # 用 OBB 4 角的 AABB 包围,逐 cell test 是否在 OBB 内
           var corners: Array[Vector2] = s.get_corners()
           var min_x: float = INF
           var max_x: float = -INF
           var min_y: float = INF
           var max_y: float = -INF
           for c in corners:
               min_x = minf(min_x, c.x)
               max_x = maxf(max_x, c.x)
               min_y = minf(min_y, c.y)
               max_y = maxf(max_y, c.y)
           var i0: int = int(floorf(min_x / RtsNavcellGrid.NAVCELL_SIZE_PX))
           var i1: int = int(floorf(max_x / RtsNavcellGrid.NAVCELL_SIZE_PX))
           var j0: int = int(floorf(min_y / RtsNavcellGrid.NAVCELL_SIZE_PX))
           var j1: int = int(floorf(max_y / RtsNavcellGrid.NAVCELL_SIZE_PX))
           for j in range(j0, j1 + 1):
               for i in range(i0, i1 + 1):
                   var center: Vector2 = grid.navcell_center_world(i, j)
                   if _point_in_obb(center, s):
                       grid.or_data(i, j, class_mask)

   func _point_in_obb(p: Vector2, obb: RtsObstructionShapeStatic) -> bool:
       var local := p - obb.center
       var u := Vector2(cos(obb.rotation_rad), sin(obb.rotation_rad))
       var v := Vector2(-sin(obb.rotation_rad), cos(obb.rotation_rad))
       var lx := local.dot(u)
       var ly := local.dot(v)
       return absf(lx) <= obb.width / 2.0 and absf(ly) <= obb.height / 2.0

   func _find_shape_by_entity(eid: String) -> RtsObstructionShape:
       for tag in _shapes:
           if _shapes[tag].entity_id == eid:
               return _shapes[tag]
       return null

   func _shape_to_point_distance(s: RtsObstructionShape, p: Vector2) -> float:
       if s is RtsObstructionShapeUnit:
           return maxf(0.0, p.distance_to(s.center) - s.clearance)
       # OBB 到点最短距离:把点投影到 OBB local 坐标,clamp 到 hw/hh
       var local := p - s.center
       var u := Vector2(cos(s.rotation_rad), sin(s.rotation_rad))
       var v := Vector2(-sin(s.rotation_rad), cos(s.rotation_rad))
       var lx := clampf(local.dot(u), -s.width/2.0, s.width/2.0)
       var ly := clampf(local.dot(v), -s.height/2.0, s.height/2.0)
       var nearest := s.center + u * lx + v * ly
       return p.distance_to(nearest)

   func _shape_to_shape_distance(a: RtsObstructionShape, b: RtsObstructionShape) -> float:
       # 简化:以 center 距离减去两 enclose_radius;精确版留给 M6 vertex pathfinder 用
       var ar: float = a.clearance if a is RtsObstructionShapeUnit else sqrt(a.width*a.width + a.height*a.height)/2.0
       var br: float = b.clearance if b is RtsObstructionShapeUnit else sqrt(b.width*b.width + b.height*b.height)/2.0
       return maxf(0.0, a.center.distance_to(b.center) - ar - br)
   ```

**完成标志**: 100 shape add + query + remove 都通;`get_obstructions_in_range` 返回按 tag 升序。

### M2.4 — Building placement 链路改造

**步骤**:
1. 修改 `logic/commands/rts_building_placement.gd`:
   - `apply` 内**先** `add_static_shape` → 拿 tag → 写到 `actor.obstruction_tag` 字段(actor 上加这字段)
   - 走 `obstruction_manager.rasterize(grid, default_class, dirty_only=true)`(M2 阶段单 class)
2. 修改 `logic/commands/rts_place_building_command.gd`:
   - M0 已加 `actor.sync_obstruction_shape()` 在 `place_building` 前 → M2 时改为:
     ```gdscript
     building.position_2d = world_pos
     building.team_id = team_id
     ...
     building.sync_obstruction_shape()
     # M2 新:走 obstruction_manager 注册
     var stats := RtsBuildingConfig.get_stats(building.building_kind)
     var tag := obstruction_manager.add_static_shape(
         building.get_id(),
         building.obstruction_shape.center,
         0.0,
         stats.obstruction_size.x,
         stats.obstruction_size.y,
         RtsObstructionFlags.BLOCK_PATHFINDING | RtsObstructionFlags.BLOCK_FOUNDATION,
         str(building.team_id)
     )
     building.obstruction_tag = tag
     # rasterize → 写到 grid (M3 之前是单 class,M3 引入 per-class clearance 外扩)
     obstruction_manager.rasterize(rts_world.rts_grid.get_navcell_grid(), passability_registry.get_class("default"), true)
     ```
3. **删除** `RtsBattleGrid._placement_map`(M1 facade 用的);改成 ObstructionManager 是 single source of truth。`grid.is_blocking()` 内部走 `_navcell_grid.is_passable(coord, default_mask) == false` 即可。
4. `RtsBattleGrid.place_building / remove_building` 标记 deprecated,内部转发到 ObstructionManager(M5 移除 facade 时一起删)。

**完成标志**: building placement 后 ObstructionManager 持有 tag + grid 上写了 default bit + `is_blocking(coord)` 返回 true。

### M2.5 — Unit spawn / move / death 链路改造

**步骤**:
1. 修改 `logic/rts_unit_actor.gd`(若不存在则按需扩充 RtsActor):
   - 加 `var obstruction_tag: int = 0` 字段
2. 修改 `logic/characters/rts_characters.gd._create_unit`:
   - spawn 后取 `actor.position_2d` + `actor.collision_radius`(M2 时 unit 暂用 collision_radius 做 clearance,M3 时换 RtsMotionComponent.clearance)
   - 调 `obstruction_manager.add_unit_shape(actor.get_id(), actor.position_2d, actor.collision_radius, RtsObstructionFlags.BLOCK_MOVEMENT, str(actor.team_id))`
   - 把返回的 tag 存到 `actor.obstruction_tag`
3. 修改 `logic/movement/rts_nav_agent.gd`:
   - 每 tick 末 `obstruction_manager.move_shape(actor.obstruction_tag, actor.position_2d)`
   - 起步/停步触发 `obstruction_manager.set_unit_moving_flag(tag, moving)`
4. RtsActor 死亡链路(M2.3 末态死者留 world):
   - `_pre_destroy` (或 RtsActor.kill) 时调 `obstruction_manager.remove_shape(actor.obstruction_tag)`
   - 死者 tag 不再出现在 spatial index / 查询结果

**完成标志**: spawn 100 unit + move 30s + 死掉若干 → ObstructionManager._shapes 数量 = 活单位数 + 建筑数;move tick 更新 spatial index;dead unit shape 已 remove。

### M2.6 — 新 smoke + Validation 全套 + commit

**步骤**:
1. 新建 `tests/battle/smoke_obstruction_manager_register.gd`:
   - 创 ObstructionManager + grid
   - add_unit_shape 5 个 + add_static_shape 3 个 → tag 1..8
   - 验证 _shapes.size() == 8
   - 验证 get_obstructions_in_range(中心, 大半径) 返回 8 个 shape,按 tag 升序
2. `smoke_obstruction_manager_query.gd`:
   - add 单位 + 建筑各若干
   - test_unit_shape 模拟单位想走到某点,filter = only_blocking_movement → 检测建筑挡 / 单位挡
   - test_static_shape 模拟放建筑,filter = skip_control_group("0") → 同队建筑不算冲突
3. `smoke_obstruction_manager_remove.gd`:
   - add → remove → 验证 _shapes / _spatial_index 都清掉
   - remove 不存在的 tag 不 crash
4. 跑 14 项 + LGF + replay + 3 新 smoke。
5. baseline CSV 跑两次 byte-identical;diff 上一 milestone (M1) baseline:仅"obstruction_radius 字段从 -1 变实填"(M0 时就实填了 collision_radius,M2 时仍实填 — 应无新变化)。
6. perf-trace 加 M2 行;ObstructionManager 引入会增加 obstruction_total_ms 字段(M2 引入,之前是 0)。
7. submodule commit + 主仓 bump:
   ```
   feat(rts-m3): M2 done — ObstructionManager (Shape 数据库 + Spatial Index)
   ```

---

## 3. 验收准则 (10 AC)

### AC1 — RtsObstructionFlags 完整枚举 🔒 pending
- 6 个 flag (BLOCK_MOVEMENT / BLOCK_FOUNDATION / BLOCK_CONSTRUCTION / BLOCK_PATHFINDING / MOVING / DELETE_UPON_CONSTRUCTION) 定义正确

### AC2 — RtsObstructionTestFilter 抽象 + 3 工厂 🔒 pending
- skip_control_group / only_blocking_movement / combined 行为正确

### AC3 — RtsSpatialIndex (uniform grid bucket) 🔒 pending
- insert / move / remove / query_circle 单元测试 PASS
- query_circle 返回按 tag 升序

### AC4 — RtsObstructionManager 单例落地 🔒 pending
- 9 个公开 API ([interfaces §2.2](../interfaces.md#22-公开-api)) 都实现
- _next_tag 单调递增,从 1 起;0 永不分配

### AC5 — Building placement 走 ObstructionManager 🔒 pending
- 放下 1 building → ObstructionManager._shapes 加 1 entry + grid 上对应 cells default bit 写入
- _placement_map 移除 (single source of truth)

### AC6 — Unit spawn / move / death 走 ObstructionManager 🔒 pending
- spawn 100 unit → 100 unit shape registered
- move 30s → spatial index 持续更新,query 不丢失
- death → 对应 shape 立即 remove

### AC7 — 3 个 smoke PASS 🔒 pending
- register / query / remove 三个 scene PASS,exit code 0

### AC8 — Validation 全套 0 漂移 🔒 pending
- 14 项 + LGF 73 + replay seed=42 deep-equal
- baseline CSV byte-identical (M2 不改 trace 字段)

### AC9 — Perf 增长 ≤ 50% 🔒 pending
- ObstructionManager add/move/remove 操作 + spatial index 维护开销
- vs M1 wall_clock ≤ +50%

### AC10 — 不动 LGF submodule core/ stdlib/ 🔒 pending

---

## 4. 决策表 (H 系列)

### H1 — RtsObstructionManager 是 RefCounted vs Autoload Node?

- **A. RefCounted,挂 GameWorld**(跟现有 RtsWorld 子系统风格一致) — Recommended
- B. Autoload Node(全局便利)

> default A;跟 RtsWorld 同生命周期,procedure end 时一起销毁;不污染全局 autoload 列表。

### H2 — Spatial index BUCKET_SIZE = 256 vs 512?

- **A. 256 px**(8 navcells × 32 px,bucket 数适中) — Recommended
- B. 512 px(更稀疏,大 query 更省)

> default A;100 单位 × 平均 5 个 bucket = 500 entries,小 BUCKET 查询更精准;若 perf 不够 M3 时可改。

### H3 — `rasterize` 全图重刷 vs 增量

- **A. M2 用 dirty_only=true 增量**(减少 perf 开销) — Recommended
- B. M2 用 full,M3 优化

> default A;M2 已加 mark_dirty,顺手用上;M3 启用 clearance 外扩时 dirty 范围扩大,顺势调优。

### H4 — Single-class rasterize vs multi-class

- **A. M2 单 class (default)**(M3 引入 air class rasterize) — Recommended
- B. M2 双 class

> default A;M2 不引入飞行单位,air bit 全 0(可通行)够用;M3 飞行单位 obstruction 加上时同步 rasterize air。

### H5 — distance_to_target 精度

- **A. 简化版 center-to-center 减 enclose_radius**(够 M2 用,M3 / activity 距离判定接受小误差) — Recommended
- B. M2 引入完整精确算法(OBB 到 OBB 最短距离 SAT 内积)

> default A;Activity attack 距离判定用这个,误差 ≤ 单位半径,接受;M6 vertex pathfinder 用精确版另起 helper。

---

## 5. 子任务进度

- [ ] M2.1 — Flags + Filter 基础设施
- [ ] M2.2 — Spatial Index
- [ ] M2.3 — ObstructionManager 单例
- [ ] M2.4 — Building placement 链路
- [ ] M2.5 — Unit spawn/move/death 链路
- [ ] M2.6 — 新 smoke + Validation

---

## 6. 残余风险

| # | 风险 | 缓解 |
|---|---|---|
| R1 | OBB-vs-OBB SAT 实现 bug → building 重叠 / 漏检 | M2.3 写 _obb_obb_overlap_sat 时严格按 0 A.D. 同名函数,加单元测试覆盖 4 种 case (轴对齐 / 旋转 45° / 边接触 / 角接触) |
| R2 | spatial index 大半径 query (max_clearance 加 enclose_radius) 性能问题 | uniform grid 100 单位规模够用;若 ≥500 单位 perf 超 50% → M3 时换 quadtree |
| R3 | Unit move 每 tick spatial index update 开销 | 100 unit × 30 Hz = 3000 update/s,uniform grid update 是 O(buckets) ~10 → 30K op/s, GDScript 应可承受 |
| R4 | bit-identical 漂移:_shapes Dictionary 迭代序 | rasterize / get_obstructions_in_range 内部都走 sort by tag,不依赖迭代序 |
| R5 | Tag 重用 (remove 后 _next_tag 不复用旧 tag) → 长期游戏 tag 耗尽 | int 64-bit, 30 Hz × 100 单位 spawn/death/s = 1B tag/year,够 ;不复用避免引入 ABA 问题 |
| R6 | Filter 静态工厂用了 class_name 但 GDScript 同一文件不能多 class_name | 拆 4 个 filter 文件 (skip_control_group / only_blocking_movement / combined / 抽象基类),或者 class_name 留在基类,具体 filter 用 inner class |

---

## 7. 决策来源

- 数据结构: data-structures §2 (含 codex R1 修订)
- API: interfaces §2
- 0 A.D. 对照: components/CCmpObstructionManager.cpp (TestObstructionsAgainstSquare / Rasterize)
- M1 末态 baseline: M1 完成时的 14 项 smoke 数字

---

## 8. 完成后下一步 (M3 启动)

M2 完成 → M3 Clearance + 外扩。

M3 依赖 M2:
- ObstructionManager.rasterize(class) 已存在(M3 启用 per-class buffer)
- mark_dirty / clear_dirty(M3 用 dirty 增量)
- 完整 EFlags + Filter

详见 [`M3-clearance.md`](M3-clearance.md)。
