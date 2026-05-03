# M3 数据结构定义

> 父文档: [`README.md`](README.md)
>
> 范围: 本 Epic (M0-M8) 引入或重构的所有数据结构,以 GDScript 为目标实现,跟 0 A.D. 源码字段逐一对照。
> 用途: codex 审查; M0-M8 实现时直接拷贝字段定义。
>
> **本文档不写算法,只写数据**。算法属于各 milestone 文档。

---

## 0. 命名约定

| 角色 | 前缀 / 风格 | 示例 |
|---|---|---|
| Logic 层 class | `Rts*` (沿用 RTS 例子既有约定) | `RtsNavcellGrid`, `RtsObstructionShape` |
| 接口契约 | `IRts*` (GDScript 没真接口,用命名约定 + 文档强约束) | `IRtsObstructionConsumer` |
| Component 风格 (LGF Actor 上挂的功能模块) | `Rts*Component` | `RtsObstructionComponent` |
| 单例 / 系统 | `Rts*System` 或挂在 GameWorld 的 `*Manager` | `RtsObstructionManager` |
| 配置 (Resource) | `Rts*Config` (沿用 RTS 例子既有约定) | `RtsPassabilityClassConfig` |

枚举: 全大写 + 下划线 (`PASS_CLASS_DEFAULT`, `EFLAG_BLOCK_MOVEMENT`)。

**坐标约定**: 沿用 RTS 例子既有 `Vector2` (px),内部寻路计算用 `Vector2i` (cell index)。**不引入 fixed-point**(D 决策)。

---

## 1. Grid 层 — Navcell + Passability

### 1.1 `RtsPassabilityClassConfig` (Resource)

对应 0 A.D. `simulation/data/pathfinder.xml` 的一个 `<PassabilityClass>` 段。

```gdscript
class_name RtsPassabilityClassConfig
extends Resource

@export var class_name_id: String           # 唯一 ID, e.g. "default" / "ground" / "air" / "ship"
@export var bit_index: int = -1             # 0..15, 自动分配 (RtsPassabilityClassRegistry 启动时填)
@export var clearance: float = 14.0         # 单位 px (我们 cell_size=32, 默认值贴近现有 collision_radius)
@export var max_water_depth: float = 0.0    # 0 = 不能下水; > 0 = 必须有深度上限 (我们当前没水机制, 留接口)
@export var min_water_depth: float = 0.0    # > 0 = 必须在水里 (船类用)
@export var min_shore_distance: float = 0.0 # 离岸最小距离 (留接口)
```

**0 A.D. 对照**:
- 字段顺序 / 命名跟 `pathfinder.xml` schema 一一对应
- `clearance` 单位换成 px (0 A.D. 是 navcell 数,我们 cell=32px,所以 0.8 navcell ≈ 25 px;默认值 14 是为了贴现有 RtsUnitClassConfig.collision_radius)

**本 Epic 实际只用 2 个 class** (M1 时用):
- `default` / `ground`: 步兵 / 战士 / 弓箭手 / worker / 建筑
- `air`: 飞行单位

留 14 个 bit 给未来 (mod / 扩展)。

### 1.2 `RtsPassabilityClassRegistry` (Autoload 或 GameWorld 子系统)

```gdscript
class_name RtsPassabilityClassRegistry
extends RefCounted   # 单例,挂 GameWorld 上

const PASS_CLASS_BITS: int = 16
const SPECIAL_PASS_CLASS_INDEX: int = 15   # 第 16 bit, 给 in-place 计算用

var _classes: Array[RtsPassabilityClassConfig] = []
var _by_name: Dictionary = {}              # String → RtsPassabilityClassConfig
var _next_bit: int = 0

func register(cfg: RtsPassabilityClassConfig) -> void
func get_class(name_id: String) -> RtsPassabilityClassConfig
func get_mask(name_id: String) -> int      # 1 << bit_index
func max_clearance() -> float              # 给 short pathfinder buffer 用
```

**0 A.D. 对照**: `ICmpPathfinder.h` 的 `GetPassabilityClass / GetPassabilityClasses / GetMaximumClearance`。
**实现位置**: `addons/logic-game-framework/example/rts-auto-battle/logic/grid/rts_passability_class_registry.gd`

### 1.3 `NavcellData` (类型别名)

```gdscript
# 不是 class, 是约定: int 当 16-bit 位掩码用
# 一个 navcell 一个 int, 每 bit 表示"对该 class 不能通过"
# IS_PASSABLE(cell_data, class_mask) = (cell_data & class_mask) == 0
```

**为什么不用 PackedInt32Array 包装**: GDScript 直接 `Dictionary[Vector2i, int]` 或 `PackedInt32Array` 索引访问够用,引入 wrapper 拖慢 + 增加复杂度。

**0 A.D. 对照**: `helpers/Pathfinding.h:130` `typedef u16 NavcellData`。

### 1.4 `RtsNavcellGrid` (替换 RtsBattleGrid 的核心数据结构)

```gdscript
class_name RtsNavcellGrid
extends RefCounted

const NAVCELL_SIZE_PX: int = 32             # 跟现有 RtsBattleGrid.cell_size 一致

var _width: int                             # navcell 数
var _height: int
var _data: PackedInt32Array                 # 长度 = width * height, 每个元素是 NavcellData
var _dirtiness: PackedByteArray             # 同样大小, 0=clean / 1=dirty (静态变更触发)

func _init(w: int, h: int) -> void
func get_data(i: int, j: int) -> int
func set_data(i: int, j: int, value: int) -> void
func or_data(i: int, j: int, mask: int) -> void   # 设 bit
func and_data(i: int, j: int, mask: int) -> void  # 清 bit (mask 是反掩码)
func is_passable(i: int, j: int, class_mask: int) -> bool
func mark_dirty(i: int, j: int) -> void
func clear_dirty() -> void
func width() -> int
func height() -> int

# 坐标转换 (内联 helper)
func navcell_center_world(i: int, j: int) -> Vector2
func nearest_navcell(world_pos: Vector2) -> Vector2i
```

**0 A.D. 对照**:
- 数据结构 = `Grid<NavcellData>` (`helpers/Grid.h`)
- API 风格沿用 0 A.D. (width / height / get / set)
- `_dirtiness` 对应 0 A.D. `dirtinessGrid` (用于 hierarchical 增量重算)

**实现位置**: `logic/grid/rts_navcell_grid.gd`

### 1.5 替换 `RtsBattleGrid` 的方案 (M1)

现有 `RtsBattleGrid`:
- `cells: Dictionary[Vector2i, RtsCell]`,每 cell 一个 RtsCell 对象 (含 `is_blocking: bool`)

替换后:
- `RtsNavcellGrid` 持有 `PackedInt32Array`,每 cell 一个 int 位掩码
- 旧的 `RtsCell` 对象树移除,但保留 `RtsBattleGrid` 作为 facade (M1 只换底层实现,API 暂时兼容,M5 时再彻底移除 facade)

---

## 2. Obstruction 层 — Shape 数据库

### 2.1 `RtsObstructionShape` (基类)

```gdscript
class_name RtsObstructionShape
extends RefCounted

enum Type {
    UNIT,       # 圆 (单位)
    STATIC,     # OBB (建筑 / 树 / 资源点)
}

var type: Type
var entity_id: String                       # owner entity (RtsActor.get_id())
var center: Vector2                         # 世界坐标
var flags: int                              # FlagBits 位掩码 (见下)
var control_group: String = ""              # = formation_id 或 owner_id, "" = 无 group
                                             # ⚠️ 此字段在 M6 (VertexPathfinder group filter) 和 M7 (Motion obstruction filter) 已是 API 输入,
                                             # 不是 M8 才用 (D9 / codex 反馈). M2 写入 + M6/M7 读取, M8 仅打开开关.
var control_group_2: String = ""            # 次组 (建筑可能跟两个 group, 例如领土 + owner)
var tag: int = 0                            # 由 ObstructionManager 分配, 用于 O(1) 反查

# Type-specific (下面两个子类填)
```

#### `RtsObstructionShapeUnit` (圆)

```gdscript
class_name RtsObstructionShapeUnit
extends RtsObstructionShape

# type = UNIT
var clearance: float                        # 半径 (= owner motion.clearance, 由 motion 同步)
var moving: bool = false                    # 当前是否在移动 (FLAG_MOVING)
```

#### `RtsObstructionShapeStatic` (OBB)

```gdscript
class_name RtsObstructionShapeStatic
extends RtsObstructionShape

# type = STATIC
var width: float                            # 沿 u 轴
var height: float                           # 沿 v 轴 (z 轴在 0 A.D., 我们用 y)
var rotation_rad: float = 0.0               # 弧度 (0 = u 轴沿 +x)

# Helper
func get_corners() -> Array[Vector2]        # 4 个 OBB 角点 (世界坐标)
func get_axes() -> Array[Vector2]           # u, v 单位向量
```

**0 A.D. 对照**:
- 基类 = `ObstructionManager` 内部 `Shape` 基类
- Unit 子类 = `UnitShape` (`CCmpObstructionManager.cpp:UnitShape`)
- Static 子类 = `StaticShape` 即 `ObstructionSquare` (`ICmpObstructionManager.h:55`)
- `tag` 对应 `tag_t`
- `flags` 对应 `flags_t` (8-bit 位掩码 with EFlags)

### 2.2 EFlags 枚举

```gdscript
class_name RtsObstructionFlags

const BLOCK_MOVEMENT: int           = 1 << 0  # 阻止单位穿过
const BLOCK_FOUNDATION: int         = 1 << 1  # 阻止盖建筑
const BLOCK_CONSTRUCTION: int       = 1 << 2  # 阻止施工
const BLOCK_PATHFINDING: int        = 1 << 3  # 阻止 A* 选这条路
const MOVING: int                   = 1 << 4  # 单位正在移动 (uimt motion 用)
const DELETE_UPON_CONSTRUCTION: int = 1 << 5  # 这个 entity 在 foundation 建到上面时删除 (例: 树)
```

**0 A.D. 对照**: `ICmpObstructionManager.h:78-86` EFlags 一一对应。

### 2.3 `RtsObstructionManager` (Autoload / GameWorld 单例)

```gdscript
class_name RtsObstructionManager
extends RefCounted

var _shapes: Dictionary = {}                # tag (int) → RtsObstructionShape
var _next_tag: int = 1                      # 0 = invalid
var _spatial_index: RtsSpatialIndex = null  # 见 §2.4

# 注册 / 注销
func add_unit_shape(entity_id: String, pos: Vector2, clearance: float, flags: int, group: String) -> int   # returns tag
func add_static_shape(entity_id: String, pos: Vector2, rotation: float, w: float, h: float, flags: int, group: String, group2: String = "") -> int
func move_shape(tag: int, pos: Vector2, rotation: float = 0.0) -> void
func set_unit_moving_flag(tag: int, moving: bool) -> void
func set_unit_control_group(tag: int, group: String) -> void
func set_static_control_group(tag: int, group: String, group2: String = "") -> void
func remove_shape(tag: int) -> void

# 查询
func test_unit_shape(filter: RtsObstructionTestFilter, pos: Vector2, clearance: float) -> bool   # true = 撞
func test_static_shape(filter: RtsObstructionTestFilter, pos: Vector2, rotation: float, w: float, h: float) -> bool
func get_shape(tag: int) -> RtsObstructionShape
func get_obstructions_in_range(pos: Vector2, range: float) -> Array[RtsObstructionShape]   # short pathfinder 用
func distance_to_point(entity_id: String, point: Vector2) -> float
func distance_to_target(entity_id_a: String, entity_id_b: String) -> float

# 序列化进 grid
func rasterize(grid: RtsNavcellGrid, pass_class: RtsPassabilityClassConfig, dirty_only: bool) -> void
```

**0 A.D. 对照**:
- API 一一对应 `ICmpObstructionManager.h` 的 `AddUnitShape / AddStaticShape / MoveShape / RemoveShape / TestUnitShape / TestStaticShape / DistanceToPoint / DistanceToTarget / Rasterize`
- 实现风格: 0 A.D. 用 std::vector + ordered std::map,我们用 GDScript Dictionary 够 (查询不那么频繁)

**实现位置**: `logic/obstruction/rts_obstruction_manager.gd`

### 2.4 `RtsSpatialIndex` (查询加速,M2 引入,可后期换)

M2 阶段先做 **uniform grid bucket** (按 256 px 分桶),足够 100 单位规模。
M6/M7 阶段如果 short pathfinder 慢可换成 quadtree。

```gdscript
class_name RtsSpatialIndex
extends RefCounted

const BUCKET_SIZE: int = 256

var _buckets: Dictionary = {}    # Vector2i → Array[int (tag)]

func insert(tag: int, pos: Vector2, radius: float) -> void
func remove(tag: int, pos: Vector2, radius: float) -> void
func update(tag: int, old_pos: Vector2, new_pos: Vector2, radius: float) -> void
func query_circle(pos: Vector2, range: float) -> Array[int]  # 返回 tag 列表
```

### 2.5 `RtsObstructionTestFilter` (谁算障碍)

```gdscript
class_name RtsObstructionTestFilter
extends RefCounted

# Predicate: 给 ObstructionManager.test_*_shape 用, 返回 true = 这个 shape 算障碍
# 实现成 abstract / Callable, 由调用方传

# 常用 filter (作为静态工厂)
static func skip_control_group(group: String) -> RtsObstructionTestFilter   # 同 group 不算
static func only_blocking_movement() -> RtsObstructionTestFilter             # 只看 BLOCK_MOVEMENT flag
static func combined(a: RtsObstructionTestFilter, b: RtsObstructionTestFilter) -> RtsObstructionTestFilter
```

**0 A.D. 对照**: `IObstructionTestFilter` (`helpers/Pathfinding.h` 转发声明,实现在 `helpers/Pathfinding.cpp` 的 `BasicSpatialQuery`)。

---

## 3. Footprint 层 — UI 视觉 shape (跟 Obstruction 独立)

### 3.1 `RtsFootprintShape` (data class)

```gdscript
class_name RtsFootprintShape
extends RefCounted

enum Type {
    CIRCLE,
    SQUARE,
}

var type: Type
var center_offset: Vector2 = Vector2.ZERO   # 相对 owner.position 的偏移 (UI 中心可与 obstruction / position 不重合)
var size: Vector2                           # CIRCLE: x=radius / SQUARE: 半宽 + 半高

# Helper
func contains(world_pos: Vector2, owner_pos: Vector2) -> bool
func get_world_aabb(owner_pos: Vector2) -> Rect2
```

**0 A.D. 对照**: `ICmpFootprint.h` (没拉源码看,但 API 等价)。

### 3.2 `RtsFootprintComponent` (挂 entity 的 UI 数据)

```gdscript
class_name RtsFootprintComponent
extends RefCounted

var owner: RtsActor
var shape: RtsFootprintShape

func _init(o: RtsActor, s: RtsFootprintShape)
```

**M0 范围**: 现有 `RtsBuildingActor` 把 `position_2d` / `footprint_cells` / `collision_radius` 拆开 → `position` (渲染锚点) + `RtsObstructionShapeStatic` (寻路) + `RtsFootprintShape` (UI)。详见 [`milestones/M0-footprint-split.md`](milestones/M0-footprint-split.md)。

---

## 4. Hierarchical 层 — 可达性 (M4)

### 4.1 `RtsRegionId` —— **Packed int64,不是 RefCounted**

> **codex 审查反馈 (2026-05-03)**: Godot 4.6 本地验证 — 两个字段相同的 RefCounted 实例作为 Dictionary key **不相等**,定义 `_eq` / `_hash` 也不会让 `Dictionary.has()` 走 value equality。所以 `_edges` / `_global_regions` 必须用 **value key**,不能用 RefCounted。
>
> **决策**: 用 packed 64-bit `int` 当 RegionID。**不照搬 0 A.D. 的 `u8|u8|u16` 24-bit 限制**(我们 GDScript int 是 64-bit,顺便扩宽避免 chunks > 256 时溢出)。

```gdscript
# RtsRegionId 是 packed int64, 不是 class.
# 字段布局 (从高位到低位):
#   bits 63..40 (24 bit) : ci (chunk i)       — 最大 16M chunks 一边
#   bits 39..16 (24 bit) : cj (chunk j)
#   bits 15..0  (16 bit) : r (chunk 内 local region ID, 0 = impassable)
#
# 这样 chunks_w / chunks_h 可达 2^24 = 16777216, 不会溢出.
# r 仍是 16 bit (跟 0 A.D. 一致, CHUNK_SIZE=96² ≤ 65535 region 上限够用).

class_name RtsRegionIdHelper
extends RefCounted

const CI_SHIFT: int = 40
const CJ_SHIFT: int = 16
const CI_MASK: int = (1 << 24) - 1   # 24 bit
const CJ_MASK: int = (1 << 24) - 1
const R_MASK: int = (1 << 16) - 1    # 16 bit
const INVALID: int = 0               # ci=0, cj=0, r=0 — 0 永远表示 "无效 / 不可通行"
                                     # 注意: 真正的 (ci=0, cj=0) chunk 内 region 1 编码成 1, 不是 0

static func pack(ci: int, cj: int, r: int) -> int:
    return (ci << CI_SHIFT) | (cj << CJ_SHIFT) | r

static func unpack_ci(rid: int) -> int:
    return (rid >> CI_SHIFT) & CI_MASK

static func unpack_cj(rid: int) -> int:
    return (rid >> CJ_SHIFT) & CJ_MASK

static func unpack_r(rid: int) -> int:
    return rid & R_MASK

static func is_invalid(rid: int) -> bool:
    return (rid & R_MASK) == 0   # 只看 r, ci/cj 为 0 时如果 r != 0 仍是合法 region
```

**Dictionary 用法**:

```gdscript
# _edges: Dictionary[RegionID(int), Array[RegionID(int)]]
# _global_regions: Dictionary[RegionID(int), GlobalRegionID(int)]

var rid := RtsRegionIdHelper.pack(ci, cj, local_r)
_global_regions[rid] = global_id     # int key, value equality, OK
if _global_regions.has(rid):         # 走 int 比较, OK
    ...
```

**0 A.D. 对照**: `helpers/HierarchicalPathfinder.h:60-90` `struct RegionID` (`u8 ci, u8 cj, u16 r`)。
**与 0 A.D. 的差异**:
- 0 A.D. 用 32-bit packed (`u8|u8|u16`),最大 256 chunks 一边 (256 × 96 = 24576 navcells = 24576 × 1 m,~24 km 边长地图)
- 我们 packed int64,最大 2^24 chunks 一边 (理论上限,实际游戏地图远不需要)
- 0 A.D. 把 RegionID 当 std::map key 用 `operator<`,我们用 int,直接 < 比较

**为什么不直接用 String key**: int 比较远快于 String,且 packing 后字段易访问。

### 4.2 `RtsGlobalRegionId` (类型别名)

```gdscript
# int. 单调递增, 0 = 不可通行, > 0 = 同号代表同一连通分量
```

**0 A.D. 对照**: `typedef u32 GlobalRegionID`。

### 4.3 `RtsHierarchicalChunk`

```gdscript
class_name RtsHierarchicalChunk
extends RefCounted

const CHUNK_SIZE: int = 96                  # 每 chunk 96×96 navcells (跟 0 A.D. 一致)

var ci: int
var cj: int
var regions_id: PackedInt32Array            # 此 chunk 内所有有效 region ID
var regions: PackedInt32Array               # 长度 = CHUNK_SIZE * CHUNK_SIZE, 每 navcell 属于哪个 region

func get_region(local_i: int, local_j: int) -> int   # 取 region ID
func region_center(r: int) -> Vector2i              # 区域中心 (用于 BFS heuristic)
func region_navcell_nearest(r: int, goal: Vector2i) -> Vector2i
func region_nearest_in_goal(r: int, start: Vector2i, goal: RtsPathGoal) -> Variant   # null or Vector2i
```

**0 A.D. 对照**: `helpers/HierarchicalPathfinder.h:175-205` `struct Chunk`。

### 4.4 `RtsHierarchicalPathfinder`

```gdscript
class_name RtsHierarchicalPathfinder
extends RefCounted

# 每个 pass_class 一份 chunk grid 和 edge map
var _chunks: Dictionary = {}                # pass_class_mask → Array[RtsHierarchicalChunk] (按 j*chunks_w + i 索引)
var _edges: Dictionary = {}                 # pass_class_mask → Dictionary[RegionID(int), Array[RegionID(int)]]
                                             # ↑ key 是 packed int64 (RtsRegionIdHelper.pack), 不是 RefCounted
var _global_regions: Dictionary = {}        # pass_class_mask → Dictionary[RegionID(int), GlobalRegionID(int)]
var _next_global_region: Dictionary = {}    # pass_class_mask → int (递增计数器)

var _chunks_w: int                          # 整图 chunk 数 (width / CHUNK_SIZE)
var _chunks_h: int

# 全图重建 (启动时 / passability grid 大改时)
func recompute(grid: RtsNavcellGrid, classes: Array[RtsPassabilityClassConfig]) -> void

# 增量更新 (基于 dirtinessGrid)
func update(grid: RtsNavcellGrid, dirty: PackedByteArray) -> void

# 查询
func get_region(i: int, j: int, pass_mask: int) -> int   # packed RegionID, 0 = invalid
func get_global_region(i: int, j: int, pass_mask: int) -> int

# 核心 API
func make_goal_reachable(start_i: int, start_j: int, goal: RtsPathGoal, pass_mask: int) -> bool
# 副作用: **总是修改 goal** (canonicalize) — codex 反馈纠正:
#   - 即使返回 true (原 goal 可达), 非 POINT goal 也会 canonicalize 成具体可达 navcell 上的 POINT goal
#     这是为了让 LongPathfinder 拿到的 goal 一定是单一确定点, 避免多解 / 边界 case
#   - 返回 false 时, goal 被替换成最近可达 navcell 的 POINT goal
# 返回:
#   true  = 原 goal 区域内有可达 navcell (canonicalize 到这里面最近的)
#   false = 原 goal 区域内无可达 navcell (替换成区域外最近可达点)

func is_goal_reachable(start_i: int, start_j: int, goal: RtsPathGoal, pass_mask: int) -> bool

func find_nearest_passable_navcell(start: Vector2i, pass_mask: int) -> Vector2i
```

**0 A.D. 对照**: `helpers/HierarchicalPathfinder.h:120-170` 全部公开 API。
**实现位置**: `logic/pathfinding/rts_hierarchical_pathfinder.gd`

---

## 5. PathGoal — 目标抽象

### 5.1 `RtsPathGoal`

```gdscript
class_name RtsPathGoal
extends RefCounted

enum Type {
    POINT,            # 单点
    CIRCLE,           # 圆内任意一点
    INVERTED_CIRCLE,  # 圆外任意一点
    SQUARE,           # 矩形内任意一点
    INVERTED_SQUARE,  # 矩形外任意一点
}

var type: Type
var center: Vector2
var hw: float                              # SQUARE: 半宽; CIRCLE: 半径
var hh: float                              # SQUARE: 半高; CIRCLE 不用
var u: Vector2 = Vector2(1, 0)             # SQUARE 的 u 轴 (单位向量)
var v: Vector2 = Vector2(0, 1)             # SQUARE 的 v 轴
var maxdist: float = 0.0                   # 两 waypoint 间最大距离 (0 = 不限)

# Helper
func navcell_contains_goal(i: int, j: int) -> bool
func navcell_rect_contains_goal(i0: int, j0: int, i1: int, j1: int) -> Variant   # null or Vector2i
func rect_contains_goal(world_rect: Rect2) -> bool
func distance_to_point(p: Vector2) -> float
func nearest_point_on_goal(p: Vector2) -> Vector2
```

**0 A.D. 对照**: `helpers/PathGoal.h:30-90` 一一对应。

---

## 6. LongPath — 全图寻路 (M5)

### 6.1 `RtsLongPathRequest` (data)

```gdscript
class_name RtsLongPathRequest
extends RefCounted

var ticket: int = 0
var start: Vector2
var goal: RtsPathGoal
var pass_mask: int                          # passability class mask
var notify_entity: String                   # 寻路完成 emit 给谁
```

### 6.2 `RtsWaypoint` + `RtsWaypointPath`

```gdscript
# Waypoint = Vector2 直接用 (不需要单独 class, 0 A.D. 是因为 entity_pos_t 是 fixed-point 才包了 Waypoint struct)

class_name RtsWaypointPath
extends RefCounted

var waypoints: PackedVector2Array          # 反向存储! back() = 下一目标

func size() -> int
func is_empty() -> bool
func back() -> Vector2
func pop_back() -> Vector2
func clear() -> void
```

**0 A.D. 对照**:
- `helpers/Pathfinding.h:47` `struct Waypoint { entity_pos_t x, z; }` → 我们直接用 `Vector2`
- `WaypointPath` 反向存储语义保留 (`back()` = 下一步)

### 6.3 `RtsLongPathfinder`

```gdscript
class_name RtsLongPathfinder
extends RefCounted

# 用一个独立线程 / 帧间分摊?
# M5 决策: 同步实现先, M5 末端如果性能炸再 async

func compute_path_immediate(start: Vector2, goal: RtsPathGoal, pass_mask: int) -> RtsWaypointPath

# A* 在 RtsNavcellGrid 上跑, 用 PathCost (整数) 做 heap key
# heuristic = octile distance (允许斜走)
```

**0 A.D. 对照**: `helpers/LongPathfinder.h/cpp`。
**算法**: 朴素 A* (D6 决策不做 JPS)。

### 6.4 `PathCost` (整数化成本) — codex 修正: **默认整数,不用 float**

> codex 反馈 (2026-05-03): 原文段自相矛盾 ("我们 GDScript 用 float 直接" vs "保守策略先复刻整数公式")。**统一为: 默认整数 tuple key,不等漂移后再改**。

**不用 RefCounted 包装,直接用 int 存** (跟 §4.1 RegionID 同思路 — RefCounted 当 heap key 性能差且易引入比较 bug):

```gdscript
# A* heap node 的 priority key 直接是 5 元组 (见 §12.1 determinism contract):
#   (f_cost: int, h_cost: int, i: int, j: int, insertion_seq: int)
#
# f_cost / h_cost 用整数 octile distance:
#   horizontal/vertical step ⇒ +65536
#   diagonal step ⇒ +92682  (≈ 65536 * sqrt(2))
#
# 这样 cost 总是整数, heap 比较走整数大小, 不引入浮点漂移.

const COST_HV: int = 65536       # 水平/垂直一步
const COST_DIAG: int = 92682     # 对角一步 (= round(65536 * sqrt(2)))

# 例: 计算 octile heuristic
static func octile_heuristic(i0: int, j0: int, i1: int, j1: int) -> int:
    var di := absi(i1 - i0)
    var dj := absi(j1 - j0)
    var diag := mini(di, dj)
    var hv := maxi(di, dj) - diag
    return hv * COST_HV + diag * COST_DIAG
```

**M5 实现细节**:
- 不用 `class RtsPathCost extends RefCounted` (省去对象分配)
- A* Open list 节点用 `Array[int]` 存 5 元组,直接整数比较
- 详细 heap 实现在 `milestones/M5-long-pathfinder.md` (Step B 写)

---

## 7. ShortPath — Vertex Pathfinder (M6)

### 7.1 `RtsShortPathRequest`

```gdscript
class_name RtsShortPathRequest
extends RefCounted

var ticket: int = 0
var start: Vector2
var clearance: float
var range: float                            # 搜索范围 (默认 56 navcells = 1792 px)
var goal: RtsPathGoal
var pass_mask: int
var avoid_moving_units: bool = true
var control_group: String                   # 同组不算障碍 (M6 已是输入, 不是 M8 才用; D9)
var notify_entity: String
```

### 7.2 `RtsVertexPathfinder` (核心算法,M6)

> codex 反馈 (2026-05-03): 原文版本"收集 obstruction → 角点外扩 → A*" 漏了 7 个 0 A.D. 关键细节,以下补全。Step B 写 M6 milestone 时**必须**逐项实现,否则 visibility graph 在边界 case 会崩。

```gdscript
class_name RtsVertexPathfinder
extends RefCounted

func compute_short_path_immediate(req: RtsShortPathRequest, obstr_mgr: RtsObstructionManager) -> RtsWaypointPath

# 内部 (按 0 A.D. 完整流程):
#
# 1. **Search bounds toward goal shift** (向目标偏移搜索框):
#    搜索范围不是以 start 为中心, 而是以 (start, goal) 中点偏向 goal 一侧 取 SHORT_PATH_MAX_SEARCH_RANGE.
#    这样 search box 朝 goal 倾斜, 避免在反向收集大量无用 obstruction.
#
# 2. **Range boundary edges** (搜索框边作为边界):
#    搜索框的 4 条边本身视为 "墙",防止 short pathfinder 跑出 search box (确保性能上界).
#
# 3. **Virtual goal vertex** (虚拟 goal 顶点):
#    如果 goal 是 PathGoal 的非 POINT 类型 (CIRCLE / SQUARE / INVERTED), 不直接加 goal.center 做顶点,
#    而是按 goal 的几何形状, 在搜索框内找"goal 边界上离 start 最近的可达点", 用这个做 virtual goal vertex.
#
# 4. **Terrain edges** (地形边):
#    除 obstruction 角点外, navcell grid 上"可通行 / 不可通行"边界 也要作为可见性 edge 考虑
#    (例如水陆交界 — 步兵碰水边界不能跨过).
#    具体实现: 沿 search box 内 grid 边界扫一遍, passable / impassable 邻居对的中点作 vertex.
#
# 5. **Lazy visibility** (懒可见性测试):
#    visibility graph 不预先建全图, A* expand 一个节点时再测试它跟哪些节点可见.
#    这样很多顶点不会被访问到, 省掉 O(V²) 全 line-of-sight.
#
# 6. **Best-so-far fallback** (兜底路径):
#    如果 A* 没找到能到 goal 的路径 (比如 search box 不够大), 返回 "best-so-far" — 已扩展过的离 goal 最近的节点路径.
#    这样单位至少能朝 goal 方向走一段, 而不是 has_target=true 但 path 空.
#    走完这段 best-so-far 后, m_FollowKnownImperfectPathCountdown 会触发重新规划.
#
# 7. **Moving unit square proxy** (移动单位的方形代理):
#    other unit obstruction (圆形) 在 visibility graph 中 **不**用切线 (会让顶点几何复杂), 而是把它近似成"轴对齐方形 (AABB)" 处理 (4 角作为 vertex).
#    这是 0 A.D. 的简化, 我们照搬 (visibility A* 中所有 obstruction 都是 OBB-like 顶点, 圆 → 方形代理).
#    代价: 单位绕单位时多走一点边角, 但避免几何 bug.
#
# 8. **Group filter** (D9 / codex 提示): 同 control_group 的 unit shape 直接跳过, 不进顶点候选.
#
# 9. **Tie-break order** (§12.3): obstruction 按 tag 字典序处理, vertex 按 index 字典序加入 graph,
#    A* 跑同 §12.1 5 元组 deterministic key.
```

**0 A.D. 对照**: `helpers/VertexPathfinder.cpp` (~1500 行 C++,我们重写 ~1500 行 GDScript;7 个细节 + group filter + tie-break = 9 大类边界 case)。
**最难的层**, M6 单独 milestone + 前置 prototype (M6 拆 M6a/b/c, 见 README §7)。

### 7.3 Line-of-Sight Helper

```gdscript
class_name RtsLineOfSight
extends RefCounted

# 给 vertex pathfinder 用: 两点之间的线段是否撞任何 shape
static func segment_clear(a: Vector2, b: Vector2, shapes: Array[RtsObstructionShape], clearance: float) -> bool

# Bresenham-style on grid (给 A* 后处理用, M6 也会用)
static func check_line_movement(grid: RtsNavcellGrid, a: Vector2, b: Vector2, pass_mask: int) -> bool
```

**0 A.D. 对照**:
- `helpers/Pathfinding.cpp` `CheckLineMovement` (grid raycast)
- `helpers/VertexPathfinder.cpp` 内部 segment clearance 测试

---

## 8. Motion 层 — Agent (M7)

### 8.1 `RtsMoveRequest` (替换现有 RtsNavAgent.final_target 的 4 种类型抽象)

```gdscript
class_name RtsMoveRequest
extends RefCounted

enum Type {
    NONE,
    POINT,         # 走到点附近 (距离 ∈ [min_range, max_range])
    ENTITY,        # 接近某 entity 到指定距离
    OFFSET,        # 跟随某 entity, 保持 offset (编队 slot 用)
}

var type: Type = Type.NONE
var entity_id: String = ""                  # ENTITY / OFFSET 用
var position: Vector2                       # POINT 用 / OFFSET 用 (offset)
var min_range: float = 0.0
var max_range: float = 0.0

# 工厂
static func to_point(pos: Vector2, min_r: float, max_r: float) -> RtsMoveRequest
static func to_entity(eid: String, min_r: float, max_r: float) -> RtsMoveRequest
static func with_offset(eid: String, off: Vector2) -> RtsMoveRequest
```

**0 A.D. 对照**: `CCmpUnitMotion.h:200-220` `struct MoveRequest`。

### 8.2 `RtsMotionTicket`

```gdscript
class_name RtsMotionTicket
extends RefCounted

enum Type {
    SHORT_PATH,
    LONG_PATH,
}

var ticket: int = 0
var type: Type = Type.SHORT_PATH

func clear() -> void
func is_active() -> bool
```

**0 A.D. 对照**: `CCmpUnitMotion.h:230-240` `struct Ticket`。

### 8.3 `RtsUnitMotion` (替换 RtsNavAgent + RtsUnitSteering)

```gdscript
class_name RtsUnitMotion
extends RefCounted

# === 静态模板 ===
var _template_walk_speed: float = 80.0
var _template_run_multiplier: float = 1.5
var _template_acceleration: float = 800.0
var _pass_class: RtsPassabilityClassConfig

# === 动态身体属性 ===
var _clearance: float                       # 单位半径 (= obstruction shape 圆的半径)
var _walk_speed: float
var _run_multiplier: float
var _face_point_after_move: bool = true
var _pushing: bool = true                   # 参与 push pass
var _block_movement: bool = true            # 阻挡其他单位

# === 反馈计数 (防卡死) ===
var _failed_movements: int = 0
const MAX_FAILED_MOVEMENTS: int = 35
var _follow_known_imperfect_path_countdown: int = 0
const KNOWN_IMPERFECT_PATH_RESET_COUNTDOWN: int = 12

# === 速度状态 ===
var _speed_multiplier: float = 1.0
var _speed: float
var _last_turn_speed: float
var _current_speed: float

# === 编队归属 ===
var _formation_controller: String = ""      # entity_id, "" = 不在编队中

# === 当前移动请求 ===
var _move_request: RtsMoveRequest

# === 异步 ticket ===
var _expected_path_ticket: RtsMotionTicket

# === 持有的两条路径 ===
var _long_path: RtsWaypointPath
var _short_path: RtsWaypointPath

# === 公开 API ===
func move_to(pos: Vector2, min_r: float, max_r: float) -> void
func move_to_entity(eid: String, min_r: float, max_r: float) -> void
func move_with_offset(eid: String, off: Vector2) -> void
func stop() -> void
func has_target() -> bool
func get_clearance() -> float
func set_clearance(c: float) -> void        # 同步通知 obstruction component

# === Tick (每 sim tick 调用) ===
func tick(delta: float, world: RtsWorld, pathfinder: IRtsPathfinderFacade) -> void

# === 内部状态机 ===
func _path_update_needed() -> bool
func _request_long_path(pathfinder) -> void
func _on_path_result(t: int, path: RtsWaypointPath) -> void
func _step(delta: float, world: RtsWorld) -> void
func _handle_obstructed_move() -> void
```

**0 A.D. 对照**: `CCmpUnitMotion.h:130-260` 全部主要字段。
**保留我们当前能用的**: stuck_detector / push_out 部分逻辑作为 `_handle_obstructed_move()` 内部实现。

### 8.4 `RtsMotionComponent` (Actor 上挂的 component)

```gdscript
class_name RtsMotionComponent
extends RefCounted

var owner: RtsActor
var motion: RtsUnitMotion                    # 上面 §8.3
```

**M7 替换链路**:
- 现有 `RtsNavAgent` + `RtsUnitSteering` → 移除
- 单位 actor 改挂 `RtsMotionComponent`
- `RtsActivity` 接 `motion.move_to(...)` API

---

## 9. Pathfinder Facade (统一入口,M5+M6 用)

### 9.1 `RtsPathfinderFacade` (单例)

```gdscript
class_name RtsPathfinderFacade
extends RefCounted

var _hierarchical: RtsHierarchicalPathfinder
var _long: RtsLongPathfinder
var _vertex: RtsVertexPathfinder
var _grid: RtsNavcellGrid
var _obstr_mgr: RtsObstructionManager
var _classes: RtsPassabilityClassRegistry

# === 公开 API (CCmpUnitMotion 调用) ===
func compute_path_immediate(start: Vector2, goal: RtsPathGoal, pass_mask: int) -> RtsWaypointPath
func compute_short_path_immediate(req: RtsShortPathRequest) -> RtsWaypointPath
func is_goal_reachable(start: Vector2, goal: RtsPathGoal, pass_mask: int) -> bool
func make_goal_reachable(start: Vector2, goal: RtsPathGoal, pass_mask: int) -> bool   # mutate goal
func check_movement(filter: RtsObstructionTestFilter, a: Vector2, b: Vector2, clearance: float, pass_mask: int) -> bool

# === 异步版 (M5 / M7 看是否需要 ===
# 暂时同步, 性能不够再加 async
```

**0 A.D. 对照**: `ICmpPathfinder.h` 全部 API。
**实现位置**: `logic/pathfinding/rts_pathfinder_facade.gd`

---

## 10. 字段对照速查表 (给 codex 审查用)

| 概念 | 0 A.D. C++ 字段 | 我们 GDScript 字段 | 类型差异 |
|---|---|---|---|
| navcell 可通行位掩码 | `NavcellData = u16` | `int` (内部 16 bit 用) | 我们没 u16,直接 int |
| passability class mask | `pass_class_t = u16` | `int` | 同上 |
| navcell 大小 | `NAVCELL_SIZE = 1` (单位 m) | `NAVCELL_SIZE_PX = 32` | 单位换算 |
| navcell 总宽 | `Grid<>.m_W: u16` | `RtsNavcellGrid._width: int` | 同 |
| obstruction 圆半径 | `UnitShape::m_Clearance: entity_pos_t` (fixed) | `RtsObstructionShapeUnit.clearance: float` | fixed → float |
| obstruction OBB 边长 | `StaticShape::m_Hw, m_Hh` (半宽半高) | `RtsObstructionShapeStatic.width, height` (全宽全高) | **注意! 0 A.D. 是半宽,我们用全宽,转换时 ÷2** |
| obstruction tag | `tag_t::n: u32` | `int` | 同 |
| EFlags | `flags_t = u8` | `int` | 同 |
| chunk size | `CHUNK_SIZE: u8 = 96` | `CHUNK_SIZE: int = 96` | 同 |
| RegionID | `(u8 ci, u8 cj, u16 r)` 32 bit packed | **`int` (packed int64, 24+24+16 bit)** | **必须用 packed int** (不能 RefCounted - GDScript Dict key 按实例身份比较, codex 验证过); 我们 ci/cj 给 24 bit 避免 chunks > 256 限制 |
| GlobalRegionID | `u32` | `int` | 同 |
| Waypoint 反向存储 | `WaypointPath::m_Waypoints` `back()` = next | `PackedVector2Array` `[size-1]` = next | 同语义 |
| MoveRequest | `MoveRequest{Type, eid, pos, min, max}` | 同结构 | 同 |
| Ticket | `Ticket{ticket: u32, type: enum}` | `RtsMotionTicket` | 同 |
| FailedMovements 阈值 | `MAX_FAILED_MOVEMENTS = 35` | `MAX_FAILED_MOVEMENTS = 35` | 复刻 |
| imperfect countdown | `KNOWN_IMPERFECT_PATH_RESET_COUNTDOWN = 12` | 同 | 复刻 |
| short path search range | `[12, 56] navcells` | `[384, 1792] px` (× 32) | 单位换算 |

---

## 11. 待确认 / codex 审查重点

| # | 问题 | 我的当前选择 | 风险 |
|---|---|---|---|
| Q1 | clearance 单位用 px 还是 navcell? | px (跟现有 collision_radius 一致,易迁移) | 跟 0 A.D. 不同,文档对照时要换算 |
| Q2 | navcell size 用 32 px 还是改成更细(比如 16 px)? | 32 px (跟现有 RtsBattleGrid.cell_size 一致) | 0 A.D. 默认 1 m navcell 4 个一个 tile,我们没 tile 概念,32 够细 |
| Q3 | obstruction OBB 用半宽半高还是全宽全高? | 全宽全高 (我们当前 RtsBuildingActor 风格) | 跟 0 A.D. 不同,需在 rasterize / 几何计算时 ÷2 |
| Q4 | ~~RegionID 用 RefCounted 还是 packed int?~~ **codex 已拍板** | **packed int64 (24+24+16 bit)** | ~~已解决~~。codex 本地验证 RefCounted 当 Dict key 走实例身份不走值相等;packed int64 一举解决,且 ci/cj 给 24 bit 比 0 A.D. u8 宽,避免大地图 chunks > 256 溢出。详见 §4.1 |
| Q5 | 异步寻路要不要做? | 暂时全同步 (M5 / M7 后再看) | 100 单位规模同步够;>200 时寻路 spike |
| Q6 | RtsBattleGrid facade 保留多久? | M1-M4 保留,M5 替换核心算法时移除 | 双 grid 维护代价 |
| Q7 | trace utility (path_trace_v2) 落到哪里? | `addons/.../tools/path_trace_v2.gd` | 跟实际 logic 分开,utility 独立 |
| Q8 | spatial index (M2) 用 uniform grid 还是 quadtree? | uniform grid (256 px 桶) | 100 单位规模 uniform 够;>500 时 quadtree |
| Q9 | LongPath 用 PriorityQueue 怎么实现? | GDScript 自带没 priority queue,用 SortedArray + binary search 或 RefCounted heap | M5 性能瓶颈点 |
| Q10 | ~~replay determinism: A* tie-break 用 entity_id parity?~~ **codex P1 #4 已纠正,见 §12** | 见 §12 完整总排序 contract | ~~已细化~~。原判断过度简化,新算法所有"两个候选打平"路径都必须有显式 deterministic tie-break key |

---

## 12. Determinism 总排序 Contract (codex P1 #4)

> **背景** (codex 反馈): 现有 `smoke_replay_bit_identical seed=42 frames=9 events=20` 之所以 PASS,**不是单靠 entity_id 字典序**,而是以下多重约束共同保证:
> - IdGenerator reset (seed=42 时 ID 序列固定)
> - Fixed seed (`RtsRng` autoload 走 BattleProcedure 的 seeded RNG, 不用全局 `randf`)
> - 固定 tick 顺序
> - 显式 sort (e.g. actor 列表迭代顺序固定)
> - Actor array order (GameWorld registry insertion order 保留)
> - Strict score 比较 (无"两值相等随便选"路径)
>
> **本节定义新 Pathfinding/Obstruction/Motion 系统必须满足的总排序 contract**。

### 12.0 Contract Summary

每一处涉及"两个候选打平时如何选" / "集合迭代顺序" / "异步操作顺序" 的代码,**必须**有显式 deterministic key,**禁止依赖以下不确定行为**:
- ❌ Dictionary / Set 迭代顺序 (Godot Dictionary 是 insertion-ordered,但 codex 不认为这是稳定保证)
- ❌ 全局 `randf` / `randi` / `RandomNumberGenerator.new()` 直接调 (走项目唯一 RNG 入口 `RtsRng` autoload,真实 API: `RtsRng.randf() / randi() / randf_range(min,max) / randi_range(min,max)`,见 `addons/.../logic/rts_rng.gd`;**注意**: `RtsRng` 是 autoload `Node`,方法名跟 GDScript 全局同名但作用域不同 — 必须显式 `RtsRng.randf()`,不写 `RtsRng` 前缀就走全局未 seed 的 RNG,会破坏 determinism)
- ❌ Float strict equality (用 epsilon 比较 + 整数 tie-break)
- ❌ Pointer / RefCounted instance 比较 (用值比较)
- ❌ `Time.get_ticks_msec()` / wall clock

### 12.1 LongPath A* (M5)

**Open list 优先级 key (按字典序比较)**:

```
priority = (
    f_cost: int,           # 主 key — A* 总成本 (整数化, 见 §6.4 PathCost)
    h_cost: int,           # 第二 key — heuristic, "更接近目标"优先
    i: int,                # 第三 key — navcell i 坐标
    j: int,                # 第四 key — navcell j 坐标
    insertion_seq: int,    # 第五 key — 进队序号 (单调递增, 解 i/j 也打平的极罕见情况)
)
```

**关键决策**:
- **不**用 entity_id parity (我们 entity 是 String, parity 不稳定)
- 用 `(i, j)` 作 cell tie-break,几何上稳定
- `insertion_seq` 是兜底:同 (f, h, i, j) 极少见 (cell 坐标唯一),但 push back 时仍可能有,显式 seq 保终极确定性

**Heap 实现**:
- 用 SortedArray + binary search insertion 或自己写 RefCounted heap
- **比较函数严格按上述 5 元组字典序**,不偷懒

### 12.2 Hierarchical Pathfinder (M4)

**Region flood-fill 顺序**:
- Per-chunk: BFS 起点按 `(local_i, local_j)` 字典序 (找下一个还没分配 region 的 navcell)
- Region ID 分配按 BFS 起点顺序递增 (chunk 内 1, 2, 3, ...)
- Chunk 之间 edge: 双 chunk 接壤的 navcell 都 passable 时,按"较小 ChunkID 先注册"加 edge

**GlobalRegion flood-fill 顺序**:
- 跨 chunk flood-fill 时,起点按 `(ci, cj, local_r)` 字典序 (= packed RegionID 自然顺序)
- GlobalRegionID 分配按 flood-fill 起点顺序递增

**MakeGoalReachable BFS 顺序**:
- 当 goal 不可达需找最近可达 navcell 时,BFS 队列按 `(distance², i, j)` 排序
- 同距离时 `(i, j)` 字典序 → deterministic

### 12.3 ShortPath VertexPathfinder (M6)

**Vertex 候选生成顺序**:
- 收集 obstructions in range: 按 `(obstruction.tag, corner_index)` 字典序 (tag 由 ObstructionManager 单调递增分配)
- corner_index 0..3 (OBB 4 角),按 +x→+y→-x→-y 固定顺序
- 圆形 obstruction 外切 4 点也按固定 4 方向顺序

**Visibility graph edge 添加顺序**:
- 双层 for: outer = vertex_a (顺序固定), inner = vertex_b (顺序固定)
- 同等可见性测试结果时,**按 (a_index, b_index) 添加 edge**

**A* tie-break**: 同 §12.1 5 元组,但 `(i, j)` 换成 `(vertex_x_int, vertex_y_int)` (用 `int(round(x*10))` 把浮点转成稳定整数 key)

### 12.4 ObstructionManager (M2)

**`get_obstructions_in_range` 返回顺序**:
- 必须按 `tag` 升序返回 (而不是 spatial bucket 迭代序)
- 实现: 收集所有候选 → 按 tag sort → 返回
- 这保证短路径 vertex 候选生成顺序确定

**Spatial bucket key 顺序**:
- bucket key = `(bucket_i, bucket_j)` 字典序
- bucket 内 tag 升序

**Tag 分配**:
- 单调递增 int,从 1 开始 (0 = invalid)
- 同 sim tick 内多个 add_*_shape 调用按调用顺序分配 tag — 调用顺序由 procedure / activity 系统决定,本身要 deterministic (这一层在 LGF EventProcessor 已保证)

### 12.5 UnitMotion (M7)

**Motion update 顺序** (deterministic 关键, codex R2 要求显式定义):
- 一个 sim tick 内, 所有 motion-bearing actors 用 **`String.casecmp_to`** (字典序, deterministic) 排序后逐个 tick
- 排序键 = `actor.get_id()` (这是 String, 由 IdGenerator 单调递增分配, fixed seed 下序列固定)
- 同步实现下, unit_A.tick() 先于 unit_B.tick() 时, **unit_A 在自己 tick 内对 ObstructionManager 的修改 (move_shape / set_unit_moving_flag) 对 unit_B 立刻可见**
- 这意味着 unit_B 的 short path 看到的 unit_A 位置是"unit_A 刚 step 完之后"的,而不是 tick 开始时
- M7 实现时这一条必须写成 unit test (smoke 跑两个 unit 同 tick 内交错),否则跨平台 GDScript Dictionary 迭代顺序不同会立刻漂

**`actor_id` 排序的 deterministic 保证**:
- IdGenerator 在 procedure 起始 reset (跟 RtsRng 一样),fixed seed 下 ID 序列固定
- ID 是 `<world>:<kind>_<seq>` 格式 (如 `rts_world_0:Character_3`),seq 单调递增
- 字典序排序对这种格式 deterministic (即使跨平台)

**Ticket 分配**:
- 单调递增 int,从 1 开始 (0 = no ticket)
- 同步寻路实现下 ticket 不重要,但保留递增分配以备 M5/M7 改 async 时不引入新漂移源

**`m_FailedMovements` 累加 / 重置时机**:
- 严格按 0 A.D. 复刻规则 (CCmpUnitMotion.h `MAX_FAILED_MOVEMENTS / BACKUP_HACK_DELAY / ALTERNATE_PATH_TYPE_DELAY` 三个常量值不变)
- 任何"random retry"必须走 **`RtsRng.randi()` / `RtsRng.randi_range(min, max)`** (项目唯一 RNG 入口 autoload,见 `logic/rts_rng.gd`;真实 API: `randf / randi / randf_range / randi_range`,**没有** `next_float / next_int`),不用全局 `randf` 或 `RandomNumberGenerator.new()`

### 12.6 同 tick command 处理顺序

- 已有 **`RtsPlayerCommandQueue`** (`logic/commands/rts_player_command_queue.gd`),按 enqueue 顺序保存 (insertion order)
- 同 tick 多 command 按 enqueue 顺序逐个 apply
- M0-M8 不改 `RtsPlayerCommandQueue` 内部存储或 dispatch 顺序,但所有新引入的"command-like"操作 (e.g. M2 `RtsObstructionManager.add_shape`) 必须:
  - 要么直接走 `RtsPlayerCommand` 子类入队 (e.g. M2 之后建筑 placement 触发的 obstruction 注册走 PlaceBuildingCommand 链路)
  - 要么显式声明"立即同步"语义 (e.g. unit obstruction shape 跟随 unit motion 在 unit motion tick 内同步,不入队)
- **关键不变量**: 同 sim tick 内"先入队的命令" 在 ObstructionManager 上的副作用对"后入队的命令" 立即可见,不得有"延后到下 tick"的隐式行为

### 12.7 浮点数值的 deterministic 处理

- **Position 比较**: 用 `epsilon=0.001` 容差比较 (`abs(a-b) < epsilon`),不用 `==`
- **Vector2 distance / length**: 必要时用 `length_squared()` (避免 sqrt 跨平台漂移),sqrt 只在最后展示阶段使用
- **角度计算 (rotation_rad)**: 必要时用 `(int(round(rad * 1000)))` 整数化 key,避免浮点 hash 漂移
- **A* heuristic / cost 算 octile distance**: 用整数公式 (PathCost.hv * 65536 + diag * 92682)

### 12.8 Acceptance: 每 milestone 必须验证

每个 M (M0-M8) 验收时:
- ✅ `smoke_replay_bit_identical seed=42` PASS (现有)
- ✅ `smoke_determinism tick_diff=0` PASS (现有)
- ✅ **新增**: `smoke_pathfinding_baseline` 跑两次,产出 `0ad-baseline-master.csv` 第一次 vs 第二次 byte-identical (本 Epic 新加的 deterministic 验证)

如果某 milestone 引入新漂移,**stop runner**,人工定位漂移源 (从 §12.1-12.6 contract 检查项逐条核对哪条违反了)。

---
