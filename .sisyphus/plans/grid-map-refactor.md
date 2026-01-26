# GridMap 插件重构工作计划

## Context

### Original Request
将当前 Godot 的 `hex-grid` 插件重构为通用的 `grid-map` 插件，参考 UE 侧的 GridPathFinding 架构，支持多种格子地图模式。

### Interview Summary
**Key Discussions**:
- 地图类型: 支持全部 4 种（六边形、六方向矩形、正方形、矩形）
- 渲染维度: 同时支持 2D 和 3D
- API 兼容性: 完全重写，不需要兼容旧 API
- Token 系统: 暂不实现，但设计上预留空间
- 环境类型: 简化版本（cost + is_blocking），预留扩展空间
- 高度系统: 需要
- 事件系统: 需要
- Chunk 分区: 不需要
- 插件名称: grid-map
- 重构方式: 原地重构（重命名 hex-grid → grid-map）
- Autoload: 需要 GridMap 全局单例
- 测试: 需要单元测试

**Research Findings**:
- UE 侧使用 Cube 坐标系统，Godot 可用 Vector2i 统一
- 现有 hex-grid 有良好基础：HexCoord、HexMath、HexPathfinding
- 需要泛化坐标系统以支持正方形/矩形

### Metis Review
**Identified Gaps** (addressed):
- 坐标系统统一: 使用 Vector2i 作为统一坐标类型
- Height 类型: float，范围 0.0-∞，默认 1.0
- 批量修改 API: 提供 set_tiles_batch() 方法

---

## UE 参考架构总结

> 以下是从 UE GridPathFinding 插件提取的关键设计决策，供 Godot 实现参考。

### GridType 枚举定义

| 类型 | 说明 | 邻居数 | 邻居方向 |
|------|------|--------|----------|
| HEX | 标准六边形 | 6 | 右、右上、左上、左、左下、右下 |
| RECT_SIX_DIR | 六方向矩形 | 6 | 上、下、左、右 + 左上、右下（交错） |
| SQUARE | 标准正方形 | 4 | 上、下、左、右 |
| RECT | 标准矩形 | 4 | 上、下、左、右（与 SQUARE 相同，但支持非正方形尺寸）|

### 坐标系统设计

| 类型 | 内部坐标 | 说明 |
|------|----------|------|
| HEX | Axial (q, r) | 使用 Vector2i，内部可转 Cube (q, r, s=-q-r) |
| RECT_SIX_DIR | Axial (q, r) | 与 HEX 相同的坐标系统，但像素布局不同 |
| SQUARE | Cartesian (x, y) | 直接使用 Vector2i(x, y) |
| RECT | Cartesian (x, y) | 直接使用 Vector2i(x, y) |

### 距离计算算法

| 类型 | 算法 | 公式 |
|------|------|------|
| HEX | Cube 距离 | `(abs(dq) + abs(dr) + abs(ds)) / 2` |
| RECT_SIX_DIR | Cube 距离 | 与 HEX 相同 |
| SQUARE | 曼哈顿距离 | `abs(dx) + abs(dy)` |
| RECT | 曼哈顿距离 | `abs(dx) + abs(dy)` |

### 邻居方向常量

```gdscript
# HEX / RECT_SIX_DIR 邻居方向 (Axial)
const HEX_DIRECTIONS: Array[Vector2i] = [
    Vector2i(1, 0),    # 右 (E)
    Vector2i(1, -1),   # 右上 (NE)
    Vector2i(0, -1),   # 左上 (NW)
    Vector2i(-1, 0),   # 左 (W)
    Vector2i(-1, 1),   # 左下 (SW)
    Vector2i(0, 1),    # 右下 (SE)
]

# SQUARE / RECT 邻居方向 (Cartesian)
const SQUARE_DIRECTIONS: Array[Vector2i] = [
    Vector2i(1, 0),    # 右
    Vector2i(0, -1),   # 上
    Vector2i(-1, 0),   # 左
    Vector2i(0, 1),    # 下
]
```

### 像素转换公式

**HEX (Flat-top)**:
```
pixel.x = size * 1.5 * q
pixel.y = size * sqrt(3) * (r + q/2)
```

**HEX (Pointy-top)**:
```
pixel.x = size * sqrt(3) * (q + r/2)
pixel.y = size * 1.5 * r
```

**SQUARE / RECT**:
```
pixel.x = coord.x * tile_width + origin.x
pixel.y = coord.y * tile_height + origin.y
```

**RECT_SIX_DIR**:
```
pixel.x = coord.x * tile_width + origin.x
pixel.y = coord.y * tile_height + origin.y
```

**说明**:
- RECT_SIX_DIR 使用标准矩形像素布局（与 SQUARE/RECT 相同）
- 六方向移动通过邻居方向的奇偶行差异实现（见 Task 4 的 RECT_SIX_DIR 邻居方向定义）
- 像素坐标计算不受奇偶行影响，只有邻居查询时才区分奇偶行
- 逆转换: `coord.x = floor((pixel.x - origin.x) / tile_width)`, `coord.y = floor((pixel.y - origin.y) / tile_height)`

### 高度系统规范

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| height | float | 1.0 | 格子高度，范围 0.0-∞ |

**寻路规则**（简化版本）:
- 允许跨越任意高度差
- 高度差不影响移动成本（预留扩展空间）

**渲染规则**:
- 2D: 高度不影响渲染位置（仅用于逻辑）
- 3D: `tile.position.y = tile.height * height_scale`

### 事件系统规范

| 信号 | 参数 | 触发时机 |
|------|------|----------|
| tile_changed | (coord: Vector2i, old_data, new_data) | set_tile() 调用时 |
| height_changed | (coord: Vector2i, old_height: float, new_height: float) | set_tile_height() 调用时 |
| occupant_changed | (coord: Vector2i, old_occupant, new_occupant) | place/remove_occupant() 调用时 |

---

## Work Objectives

### Core Objective
将 hex-grid 插件重构为支持多种网格类型的通用 grid-map 插件，保持架构清晰、可扩展。

### Concrete Deliverables
- `addons/grid-map/` 插件目录（从 hex-grid 重命名）
- `GridMapModel` 数据+逻辑层
- `GridMapRenderer2D` / `GridMapRenderer3D` 渲染层
- `GridPathfinding` 寻路模块
- `GridMap` Autoload 单例
- 单元测试覆盖核心功能

### Definition of Done
- [x] 所有 4 种地图类型可正常创建和使用
- [x] 坐标转换（Coord ↔ World）对所有类型正确
- [x] 寻路算法对所有类型正确
- [x] 2D/3D 渲染器可正常渲染所有类型
- [x] 事件系统正常工作
- [x] 单元测试全部通过

### Must Have
- 4 种地图类型支持（HEX, RECT_SIX_DIR, SQUARE, RECT）
- 统一的坐标系统（Vector2i）
- 坐标转换（coord_to_world, world_to_coord）
- 邻居查询（get_neighbors）
- 距离计算（get_distance）
- 高度系统（tile.height）
- 占用管理（is_occupied, place_occupant, remove_occupant）
- 事件系统（tile_changed, height_changed）
- A* 寻路
- 2D/3D 渲染器
- Autoload 单例

### Must NOT Have (Guardrails)
- Chunk 分块系统
- Token 系统业务逻辑（只预留接口）
- 复杂的 Environment 类型系统
- 多层地图
- 网络同步
- 地图编辑器 UI
- 在公共 API 中硬编码 cost/is_blocking

---

## Verification Strategy

### Test Decision
- **Infrastructure exists**: YES（项目有 tests/ 目录）
- **User wants tests**: TDD / Tests-after
- **Framework**: Godot --script 运行测试

### Test Coverage
1. 坐标转换测试（所有 4 种类型）
2. 邻居查询测试（所有 4 种类型）
3. 距离计算测试
4. 寻路算法测试
5. 事件系统测试

---

## Task Flow

```
Phase 1: 基础架构
  Task 1 (重命名插件) → Task 2 (枚举和配置)

Phase 2: 核心模块
  Task 3 (GridCoord) → Task 4 (GridMath) → Task 5 (GridLayout)
  ↓
  Task 6 (GridMapModel)

Phase 3: 寻路和渲染
  Task 7 (GridPathfinding) ← depends on Task 6
  Task 8 (GridMapRenderer2D) ← depends on Task 6
  Task 9 (GridMapRenderer3D) ← depends on Task 6

Phase 4: 集成
  Task 10 (GridMap Autoload) ← depends on Task 6
  Task 11 (单元测试) ← depends on all above
  Task 12 (清理和文档)
```

## Parallelization

| Group | Tasks | Reason |
|-------|-------|--------|
| A | 7, 8, 9 | 独立模块，都依赖 Task 6 |

| Task | Depends On | Reason |
|------|------------|--------|
| 3 | 2 | 需要枚举定义 |
| 4 | 3 | 需要坐标类型 |
| 5 | 3 | 需要坐标类型 |
| 6 | 3, 4, 5 | 整合所有基础模块 |
| 7, 8, 9 | 6 | 需要 Model 接口 |
| 10 | 6 | 需要 Model |
| 11 | 7, 8, 9, 10 | 需要所有模块完成 |

---

## TODOs

- [x] 1. 重命名插件目录并重组结构

  **What to do**:
  - 将 `addons/hex-grid/` 重命名为 `addons/grid-map/`
  - 更新 `plugin.cfg` 中的插件名称和描述
  - 更新 `plugin.gd` 中的 Autoload 注册
  - 重组目录结构（见下方迁移策略）

  **Must NOT do**:
  - 不要修改任何 GDScript 代码逻辑
  - 不要删除任何文件（只重命名/移动）

  **Parallelizable**: NO (第一步)

  **References**:
  - `addons/hex-grid/plugin.cfg` - 当前插件配置，需要更新 name 和 description
  - `addons/hex-grid/plugin.gd` - 当前插件脚本，需要更新 Autoload 路径

  **Directory Structure Migration Strategy**:
  
  **Current Structure** (hex-grid):
  ```
  addons/hex-grid/
  ├── plugin.cfg
  ├── plugin.gd
  ├── hex_grid.gd              # Autoload 单例
  ├── src/
  │   ├── hex_coord.gd         # 坐标转换
  │   ├── hex_math.gd          # 数学运算
  │   ├── hex_layout.gd        # 像素转换
  │   ├── hex_map.gd           # 存储模式
  │   ├── hex_grid_world.gd    # 整合模型
  │   ├── hex_pathfinding.gd   # 寻路算法
  │   └── hex_grid_compat.gd   # 兼容层
  ├── renderer/
  │   ├── hex_grid_renderer_2d.gd
  │   ├── hex_grid_renderer_3d.gd
  │   ├── test_renderer_2d.gd
  │   ├── test_renderer_3d.gd
  │   └── README.md
  └── tests/
      └── test_hex_grid.gd
  ```

  **Target Structure** (grid-map):
  ```
  addons/grid-map/
  ├── plugin.cfg
  ├── plugin.gd
  ├── grid_map.gd              # Autoload 单例 (from hex_grid.gd)
  ├── core/                    # 新目录：核心模块
  │   ├── grid_types.gd        # 新文件：枚举和配置
  │   ├── grid_coord.gd        # from src/hex_coord.gd
  │   ├── grid_math.gd         # from src/hex_math.gd
  │   └── grid_layout.gd       # from src/hex_layout.gd
  ├── model/                   # 新目录：数据模型
  │   └── grid_map_model.gd    # from src/hex_grid_world.gd + hex_map.gd
  ├── pathfinding/             # 新目录：寻路模块
  │   └── grid_pathfinding.gd  # from src/hex_pathfinding.gd
  ├── renderer/                # 保持不变
  │   ├── grid_map_renderer_2d.gd  # from hex_grid_renderer_2d.gd
  │   ├── grid_map_renderer_3d.gd  # from hex_grid_renderer_3d.gd
  │   ├── test_renderer_2d.gd      # 保留
  │   ├── test_renderer_3d.gd      # 保留
  │   └── README.md                # 保留
  └── tests/
      └── test_grid_map.gd     # from test_hex_grid.gd
  ```

  **Migration Steps**:
  1. `git mv addons/hex-grid addons/grid-map`
  2. `mkdir addons/grid-map/core`
  3. `mkdir addons/grid-map/model`
  4. `mkdir addons/grid-map/pathfinding`
  5. `git mv addons/grid-map/hex_grid.gd addons/grid-map/grid_map.gd`
  6. 移动 src/ 文件到对应新目录（后续任务中逐步完成）

  **Acceptance Criteria**:
  - [x] 目录已重命名为 `addons/grid-map/`
  - [x] `plugin.cfg` 中 name="Grid Map"
  - [x] 创建了 `core/`, `model/`, `pathfinding/` 子目录
  - [x] Godot 编辑器可正常加载插件（可能有警告，后续任务修复）

  **Commit**: YES
  - Message: `refactor(grid-map): rename hex-grid to grid-map and restructure directories`
  - Files: `addons/grid-map/`

---

- [x] 2. 创建枚举和配置类型

  **What to do**:
  - 创建 `addons/grid-map/core/grid_types.gd` 定义核心枚举和配置
  - GridType 枚举: HEX, RECT_SIX_DIR, SQUARE, RECT
  - Orientation 枚举: FLAT, POINTY (六边形), HORIZONTAL, VERTICAL (矩形)
  - DrawMode 枚举: ROW_COLUMN, RADIUS
  - GridMapConfig Resource 类
  - 定义 GridMapConfig 的属性和默认值
  - 实现基本的 _init() 方法（设置默认值）
  - 不需要实现复杂的验证逻辑（在 Task 6 的 GridMapModel.initialize() 中处理）

  **Must NOT do**:
  - 不要实现任何业务逻辑
  - 不要实现复杂的验证逻辑（留给 GridMapModel）

  **Parallelizable**: NO (depends on 1)

  **References**:
  - UE `EGridMapType` 枚举定义（见 "UE 参考架构总结" 部分）
  - 现有 `addons/hex-grid/src/hex_grid_world.gd:30-34` - DrawMode 枚举参考

  **GridMapConfig 与 GridMapModel 关系说明**:
  
  ```gdscript
  # GridMapConfig 是一个 Resource，用于配置地图参数
  # GridMapModel 在初始化时接收 GridMapConfig
  
  # 使用方式：
  var config := GridMapConfig.new()
  config.grid_type = GridType.HEX
  config.orientation = Orientation.POINTY
  config.size = 32.0
  config.draw_mode = DrawMode.ROW_COLUMN
  config.rows = 10
  config.columns = 10
  
  var model := GridMapModel.new()
  model.initialize(config)  # 使用配置初始化模型
  
  # GridMapConfig 属性说明：
  # - grid_type: GridType - 网格类型
  # - orientation: Orientation - 方向（HEX: FLAT/POINTY, RECT: HORIZONTAL/VERTICAL）
  # - draw_mode: DrawMode - 绘制模式（ROW_COLUMN 或 RADIUS）
  # - size: float - 格子大小（HEX/SQUARE 使用单一值）
  # - tile_size: Vector2 - 格子大小（RECT 使用 Vector2）
  # - origin: Vector2 - 原点偏移
  # - rows: int - 行数（ROW_COLUMN 模式）
  # - columns: int - 列数（ROW_COLUMN 模式）
  # - radius: int - 半径（RADIUS 模式）
  ```

  **Acceptance Criteria**:
  - [x] `addons/grid-map/core/grid_types.gd` 文件存在
  - [x] 所有枚举定义完整（GridType, Orientation, DrawMode）
  - [x] GridMapConfig 包含: grid_type, orientation, draw_mode, size, tile_size, origin, rows, columns, radius
  - [x] GridMapConfig 继承 Resource（可序列化）

  **Commit**: YES
  - Message: `feat(grid-map): add grid types and config`
  - Files: `addons/grid-map/core/grid_types.gd`

---

- [x] 3. 实现 GridCoord 坐标系统

  **What to do**:
  - 创建 `addons/grid-map/core/grid_coord.gd` 统一坐标转换
  - 保留六边形的 Cube/Axial/Offset 转换
  - 添加正方形/矩形的坐标转换
  - 使用 Vector2i 作为统一坐标类型

  **Must NOT do**:
  - 不要删除现有的六边形坐标转换逻辑

  **Parallelizable**: NO (depends on 2)

  **References**:
  - 现有 `addons/hex-grid/src/hex_coord.gd` - 六边形坐标转换实现，迁移并扩展
  - UE Cube 坐标定义（见 "UE 参考架构总结" 部分）

  **Acceptance Criteria**:
  - [x] `grid_coord.gd` 文件存在
  - [x] 六边形坐标转换正确（从 hex_coord.gd 迁移）
  - [x] 正方形坐标转换正确
  - [x] 矩形坐标转换正确

  **Concrete Test Cases** (验证时必须通过):
  ```gdscript
  # Axial → Cube 转换
  assert(GridCoord.axial_to_cube(Vector2i(1, 2)) == Vector3i(1, 2, -3))
  assert(GridCoord.axial_to_cube(Vector2i(0, 0)) == Vector3i(0, 0, 0))
  assert(GridCoord.axial_to_cube(Vector2i(-1, 3)) == Vector3i(-1, 3, -2))
  
  # Cube → Axial 转换
  assert(GridCoord.cube_to_axial(Vector3i(1, 2, -3)) == Vector2i(1, 2))
  
  # Offset → Axial 转换 (odd-r)
  assert(GridCoord.offset_to_axial(Vector2i(0, 0), GridCoord.OffsetType.ODD_R) == Vector2i(0, 0))
  assert(GridCoord.offset_to_axial(Vector2i(1, 1), GridCoord.OffsetType.ODD_R) == Vector2i(1, 1))
  
  # Square/Rect 坐标 (直接映射，无转换)
  assert(GridCoord.cartesian_to_axial(Vector2i(3, 4)) == Vector2i(3, 4))
  ```

  **Commit**: YES
  - Message: `feat(grid-map): implement GridCoord coordinate system`
  - Files: `addons/grid-map/core/grid_coord.gd`

---

- [x] 4. 实现 GridMath 数学运算

  **What to do**:
  - 创建 `addons/grid-map/core/grid_math.gd` 统一数学运算
  - 距离计算（所有类型）
  - 邻居查询（6方向/4方向/8方向）
  - 范围查询
  - 线段绘制
  - 旋转和反射

  **Must NOT do**:
  - 不要实现寻路算法（在 GridPathfinding 中）

  **Parallelizable**: NO (depends on 3)

  **References**:
  - 现有 `addons/hex-grid/src/hex_math.gd` - 六边形数学运算，迁移并扩展
  - UE 距离和邻居算法（见 "UE 参考架构总结" 部分）

  **RECT_SIX_DIR 邻居方向定义** (关键实现细节):
  
  RECT_SIX_DIR 是一种特殊的矩形网格，使用交错布局实现 6 方向移动。
  
  ```gdscript
  # RECT_SIX_DIR 邻居方向（取决于行的奇偶性）
  # 偶数行 (row % 2 == 0):
  const RECT_SIX_DIR_EVEN: Array[Vector2i] = [
      Vector2i(1, 0),    # 右
      Vector2i(0, -1),   # 上
      Vector2i(-1, -1),  # 左上
      Vector2i(-1, 0),   # 左
      Vector2i(-1, 1),   # 左下
      Vector2i(0, 1),    # 下
  ]
  
  # 奇数行 (row % 2 == 1):
  const RECT_SIX_DIR_ODD: Array[Vector2i] = [
      Vector2i(1, 0),    # 右
      Vector2i(1, -1),   # 右上
      Vector2i(0, -1),   # 上
      Vector2i(-1, 0),   # 左
      Vector2i(0, 1),    # 下
      Vector2i(1, 1),    # 右下
  ]
  
  # 获取 RECT_SIX_DIR 邻居的方法：
  static func get_rect_six_dir_neighbors(coord: Vector2i) -> Array[Vector2i]:
      var directions := RECT_SIX_DIR_EVEN if coord.y % 2 == 0 else RECT_SIX_DIR_ODD
      var neighbors: Array[Vector2i] = []
      for dir in directions:
          neighbors.append(coord + dir)
      return neighbors
  ```
  
  **距离计算** (RECT_SIX_DIR):
  RECT_SIX_DIR 使用与 HEX 相同的 Cube 距离算法，因为它本质上是六边形网格的矩形表示。
  需要先将 offset 坐标转换为 axial 坐标，然后计算 Cube 距离。

  **Acceptance Criteria**:
  - [x] `grid_math.gd` 文件存在
  - [x] 六边形距离计算正确
  - [x] 正方形距离计算正确（曼哈顿/切比雪夫）
  - [x] 邻居查询对所有类型正确

  **Concrete Test Cases** (验证时必须通过):
  ```gdscript
  # HEX 距离计算 (Cube 距离)
  assert(GridMath.hex_distance(Vector2i(0, 0), Vector2i(1, 0)) == 1)
  assert(GridMath.hex_distance(Vector2i(0, 0), Vector2i(2, -1)) == 2)
  assert(GridMath.hex_distance(Vector2i(0, 0), Vector2i(3, -3)) == 3)
  
  # SQUARE 距离计算 (曼哈顿)
  assert(GridMath.manhattan_distance(Vector2i(0, 0), Vector2i(3, 4)) == 7)
  assert(GridMath.manhattan_distance(Vector2i(1, 1), Vector2i(4, 5)) == 7)
  
  # SQUARE 距离计算 (切比雪夫，8方向时使用)
  assert(GridMath.chebyshev_distance(Vector2i(0, 0), Vector2i(3, 4)) == 4)
  
  # HEX 邻居查询
  var hex_neighbors := GridMath.get_neighbors(Vector2i(0, 0), GridType.HEX)
  assert(hex_neighbors.size() == 6)
  assert(Vector2i(1, 0) in hex_neighbors)   # 右
  assert(Vector2i(-1, 0) in hex_neighbors)  # 左
  
  # SQUARE 邻居查询
  var square_neighbors := GridMath.get_neighbors(Vector2i(0, 0), GridType.SQUARE)
  assert(square_neighbors.size() == 4)
  assert(Vector2i(1, 0) in square_neighbors)   # 右
  assert(Vector2i(0, 1) in square_neighbors)   # 下
  ```

  **Commit**: YES
  - Message: `feat(grid-map): implement GridMath operations`
  - Files: `addons/grid-map/core/grid_math.gd`

---

- [x] 5. 实现 GridLayout 像素转换

  **What to do**:
  - 创建 `addons/grid-map/core/grid_layout.gd` 像素坐标转换
  - coord_to_pixel / pixel_to_coord
  - 角点计算（用于渲染）
  - 支持所有网格类型

  **Must NOT do**:
  - 不要实现渲染逻辑

  **Parallelizable**: YES (with 4, both depend on 3)

  **References**:
  - 现有 `addons/hex-grid/src/hex_layout.gd` - 六边形像素转换，迁移并扩展
  - UE 像素转换公式（见 "UE 参考架构总结" 部分）

  **Acceptance Criteria**:
  - [x] `grid_layout.gd` 文件存在
  - [x] 六边形像素转换正确
  - [x] 正方形像素转换正确
  - [x] 矩形像素转换正确

  **Concrete Test Cases** (验证时必须通过):
  ```gdscript
  # 假设 size = 32, origin = Vector2(0, 0)
  var layout := GridLayout.new(GridType.HEX, 32.0, Vector2.ZERO, GridLayout.Orientation.POINTY)
  
  # HEX coord_to_pixel (Pointy-top)
  # pixel.x = size * sqrt(3) * (q + r/2)
  # pixel.y = size * 1.5 * r
  var pixel := layout.coord_to_pixel(Vector2i(1, 0))
  assert(is_equal_approx(pixel.x, 32.0 * sqrt(3)))  # ≈ 55.4
  assert(is_equal_approx(pixel.y, 0.0))
  
  # HEX pixel_to_coord (逆转换)
  var coord := layout.pixel_to_coord(Vector2(55.4, 0.0))
  assert(coord == Vector2i(1, 0))
  
  # SQUARE coord_to_pixel
  var square_layout := GridLayout.new(GridType.SQUARE, 32.0, Vector2.ZERO)
  var sq_pixel := square_layout.coord_to_pixel(Vector2i(2, 3))
  assert(sq_pixel == Vector2(64.0, 96.0))  # 2*32, 3*32
  
  # SQUARE pixel_to_coord
  var sq_coord := square_layout.pixel_to_coord(Vector2(70.0, 100.0))
  assert(sq_coord == Vector2i(2, 3))  # floor(70/32), floor(100/32)
  
  # RECT coord_to_pixel (非正方形尺寸)
  var rect_layout := GridLayout.new(GridType.RECT, Vector2(48.0, 32.0), Vector2.ZERO)
  var rect_pixel := rect_layout.coord_to_pixel(Vector2i(1, 2))
  assert(rect_pixel == Vector2(48.0, 64.0))  # 1*48, 2*32
  ```

  **Commit**: YES
  - Message: `feat(grid-map): implement GridLayout pixel conversion`
  - Files: `addons/grid-map/core/grid_layout.gd`

---

- [x] 6. 实现 GridMapModel 核心模型

  **What to do**:
  - 创建 `addons/grid-map/model/grid_map_model.gd` 核心数据模型
  - TileData 类（coord, height, cost, is_blocking, tokens预留）
  - 格子存储（使用 Dictionary）
  - 占用管理（occupants）
  - 事件系统（tile_changed, height_changed 信号）
  - 坐标转换代理方法

  **Must NOT do**:
  - 不要实现 Token 业务逻辑
  - 不要实现 Chunk 分区

  **Parallelizable**: NO (depends on 3, 4, 5)

  **References**:
  - UE GridMapModel 设计（见 "UE 参考架构总结" 部分）
  - 现有 `addons/hex-grid/src/hex_grid_world.gd` - 整合模型，迁移并扩展
  - 现有 `addons/hex-grid/src/hex_map.gd` - 存储模式，整合到 GridMapModel

  **TileData 类定义**:
  ```gdscript
  class TileData:
      var coord: Vector2i          # 格子坐标
      var height: float = 1.0      # 格子高度，默认 1.0
      var cost: float = 1.0        # 移动成本，默认 1.0
      var is_blocking: bool = false # 是否阻挡
      var occupant: Variant = null  # 占用者（预留给 Token 系统）
      var metadata: Dictionary = {} # 自定义元数据（预留扩展）
  ```

  **高度系统实现细节**:
  ```gdscript
  # 高度相关方法
  func set_tile_height(coord: Vector2i, height: float) -> void:
      var tile := get_tile(coord)
      if tile:
          var old_height := tile.height
          tile.height = clampf(height, 0.0, INF)  # 范围 0.0-∞
          height_changed.emit(coord, old_height, tile.height)
  
  func get_tile_height(coord: Vector2i) -> float:
      var tile := get_tile(coord)
      return tile.height if tile else 1.0  # 默认高度 1.0
  
  # 批量设置高度
  func set_tiles_height_batch(coords: Array[Vector2i], height: float) -> void:
      for coord in coords:
          set_tile_height(coord, height)
  
  # 高度在 3D 渲染中的应用
  # GridMapRenderer3D 会读取 tile.height 并设置 mesh 的 Y 位置
  # position.y = tile.height * height_scale
  ```

  **事件系统参数类型说明**:
  ```gdscript
  # 信号定义
  signal tile_changed(coord: Vector2i, old_data: TileData, new_data: TileData)
  signal height_changed(coord: Vector2i, old_height: float, new_height: float)
  signal occupant_changed(coord: Vector2i, old_occupant: Variant, new_occupant: Variant)
  
  # old_data/new_data 可能为 null（创建/删除时）
  # old_occupant/new_occupant 可能为 null（放置/移除时）
  ```

  **Acceptance Criteria**:
  - [x] `addons/grid-map/model/grid_map_model.gd` 文件存在
  - [x] 可创建所有 4 种类型的地图
  - [x] coord_to_world / world_to_coord 正确
  - [x] get_neighbors 正确
  - [x] 占用管理正确（place_occupant, remove_occupant, move_occupant）
  - [x] 高度系统正确（set_tile_height, get_tile_height）
  - [x] 事件信号正常触发（tile_changed, height_changed, occupant_changed）

  **Commit**: YES
  - Message: `feat(grid-map): implement GridMapModel core`
  - Files: `addons/grid-map/model/grid_map_model.gd`

---

- [x] 7. 实现 GridPathfinding 寻路模块

  **What to do**:
  - 创建 `addons/grid-map/pathfinding/grid_pathfinding.gd` 寻路算法
  - A* 寻路（支持所有类型）
  - BFS 可达性分析
  - 视野计算（FOV）
  - 射线投射

  **Must NOT do**:
  - 不要硬编码特定网格类型的逻辑

  **Parallelizable**: YES (with 8, 9, all depend on 6)

  **References**:
  - 现有 `addons/hex-grid/src/hex_pathfinding.gd` - 六边形寻路实现，迁移并泛化
  - UE 寻路接口设计（见 "UE 参考架构总结" 部分）

  **Acceptance Criteria**:
  - [x] `addons/grid-map/pathfinding/grid_pathfinding.gd` 文件存在
  - [x] A* 寻路对所有类型正确
  - [x] BFS 可达性正确
  - [x] 视野计算正确

  **Commit**: YES
  - Message: `feat(grid-map): implement GridPathfinding`
  - Files: `addons/grid-map/pathfinding/grid_pathfinding.gd`

---

- [x] 8. 实现 GridMapRenderer2D 渲染器

  **What to do**:
  - 创建 `addons/grid-map/renderer/grid_map_renderer_2d.gd` 2D 渲染器
  - 网格线框渲染
  - 高亮和填充
  - 支持所有网格类型的形状绘制

  **Must NOT do**:
  - 不要实现 3D 渲染逻辑

  **Parallelizable**: YES (with 7, 9)

  **References**:
  - 现有 `addons/hex-grid/renderer/hex_grid_renderer_2d.gd` - 六边形 2D 渲染，迁移并扩展
  - UE 渲染器设计（见 "UE 参考架构总结" 部分）

  **Acceptance Criteria**:
  - [x] `addons/grid-map/renderer/grid_map_renderer_2d.gd` 文件存在
  - [x] 六边形渲染正确
  - [x] 正方形渲染正确
  - [x] 矩形渲染正确
  - [x] 高亮和填充功能正常

  **Commit**: YES
  - Message: `feat(grid-map): implement GridMapRenderer2D`
  - Files: `addons/grid-map/renderer/grid_map_renderer_2d.gd`

---

- [x] 9. 实现 GridMapRenderer3D 渲染器

  **What to do**:
  - 创建 `addons/grid-map/renderer/grid_map_renderer_3d.gd` 3D 渲染器
  - 使用 ImmediateMesh 渲染
  - 网格线框渲染
  - 高亮和填充
  - 支持所有网格类型
  - 高度系统集成（position.y = tile.height * height_scale）

  **Must NOT do**:
  - 不要实现 2D 渲染逻辑

  **Parallelizable**: YES (with 7, 8)

  **References**:
  - 现有 `addons/hex-grid/renderer/hex_grid_renderer_3d.gd` - 六边形 3D 渲染，迁移并扩展
  - UE 渲染器设计（见 "UE 参考架构总结" 部分）

  **Acceptance Criteria**:
  - [x] `addons/grid-map/renderer/grid_map_renderer_3d.gd` 文件存在
  - [x] 六边形渲染正确
  - [x] 正方形渲染正确
  - [x] 矩形渲染正确
  - [x] 高亮和填充功能正常
  - [x] 高度系统正确应用到 Y 轴位置

  **Commit**: YES
  - Message: `feat(grid-map): implement GridMapRenderer3D`
  - Files: `addons/grid-map/renderer/grid_map_renderer_3d.gd`

---

- [x] 10. 实现 GridMap Autoload 单例

  **What to do**:
  - 创建 `addons/grid-map/grid_map.gd` Autoload 单例
  - 全局访问 GridMapModel
  - 便捷方法代理
  - 配置和清除方法

  **Must NOT do**:
  - 不要实现业务逻辑

  **Parallelizable**: NO (depends on 6)

  **References**:
  - 现有 `addons/hex-grid/hex_grid.gd` - 六边形 Autoload，迁移并扩展
  - UE 的全局访问模式

  **Acceptance Criteria**:
  - [x] `addons/grid-map/grid_map.gd` 文件存在
  - [x] configure() 方法正常工作
  - [x] 便捷方法正确代理到 model
  - [x] `addons/grid-map/plugin.gd` 正确注册 Autoload

  **Commit**: YES
  - Message: `feat(grid-map): implement GridMap autoload singleton`
  - Files: `addons/grid-map/grid_map.gd`, `addons/grid-map/plugin.gd`

---

- [x] 11. 编写单元测试

  **What to do**:
  - 创建 `addons/grid-map/tests/test_grid_map.gd` 测试脚本
  - 坐标转换测试（所有类型）
  - 邻居查询测试（所有类型）
  - 距离计算测试
  - 寻路算法测试
  - 事件系统测试

  **Must NOT do**:
  - 不要测试渲染器（需要图形环境）

  **Parallelizable**: NO (depends on all above)

  **References**:
  - 现有 `addons/hex-grid/tests/test_hex_grid.gd` - 六边形测试（参考测试结构）

  **Test Script Structure** (必须遵循):
  ```gdscript
  # addons/grid-map/tests/test_grid_map.gd
  extends SceneTree
  
  func _init() -> void:
      var success := run_tests()
      quit(0 if success else 1)
  
  func run_tests() -> bool:
      var passed := 0
      var failed := 0
      
      # 运行所有测试
      if test_grid_coord(): passed += 1
      else: failed += 1
      
      if test_grid_math(): passed += 1
      else: failed += 1
      
      if test_grid_layout(): passed += 1
      else: failed += 1
      
      if test_grid_map_model(): passed += 1
      else: failed += 1
      
      if test_grid_pathfinding(): passed += 1
      else: failed += 1
      
      if test_event_system(): passed += 1
      else: failed += 1
      
      print("Tests: %d passed, %d failed" % [passed, failed])
      return failed == 0
  
  func test_grid_coord() -> bool:
      print("Testing GridCoord...")
      # 使用 Task 3 中的 Concrete Test Cases
      return true
  
  func test_grid_math() -> bool:
      print("Testing GridMath...")
      # 使用 Task 4 中的 Concrete Test Cases
      return true
  
  func test_grid_layout() -> bool:
      print("Testing GridLayout...")
      # 使用 Task 5 中的 Concrete Test Cases
      return true
  
  func test_grid_map_model() -> bool:
      print("Testing GridMapModel...")
      # 测试所有 4 种类型的地图创建
      # 测试 coord_to_world / world_to_coord
      # 测试 get_neighbors
      # 测试占用管理
      return true
  
  func test_grid_pathfinding() -> bool:
      print("Testing GridPathfinding...")
      # 测试 A* 寻路
      # 测试 BFS 可达性
      return true
  
  func test_event_system() -> bool:
      print("Testing Event System...")
      # 测试 tile_changed 信号
      # 测试 height_changed 信号
      # 测试 occupant_changed 信号
      return true
  ```

  **Detailed Test Coverage** (每个测试函数必须覆盖):

  **test_grid_coord()**:
  - [ ] Axial ↔ Cube 转换（使用 Task 3 的 Concrete Test Cases）
  - [ ] Offset ↔ Axial 转换（ODD_R, EVEN_R, ODD_Q, EVEN_Q）
  - [ ] 坐标取整（cube_round, axial_round）
  - [ ] 边界情况（负坐标、零坐标）

  **test_grid_math()**:
  - [ ] 距离计算（使用 Task 4 的 Concrete Test Cases）
  - [ ] HEX 邻居查询（6 个邻居）
  - [ ] RECT_SIX_DIR 邻居查询（6 个邻居，奇偶行不同）
  - [ ] SQUARE 邻居查询（4 个邻居）
  - [ ] RECT 邻居查询（4 个邻居）
  - [ ] 范围查询（axial_range）
  - [ ] 线段绘制（axial_line）

  **test_grid_layout()**:
  - [ ] coord_to_pixel ↔ pixel_to_coord 往返（使用 Task 5 的 Concrete Test Cases）
  - [ ] HEX Flat-top 和 Pointy-top
  - [ ] SQUARE 和 RECT 像素转换
  - [ ] 角点计算（hex_corners）

  **test_grid_map_model()**:
  - [ ] 创建所有 4 种类型的地图
  - [ ] coord_to_world / world_to_coord 正确性
  - [ ] get_neighbors 返回正确数量
  - [ ] 占用管理（place_occupant, remove_occupant, move_occupant）
  - [ ] 高度系统（set_tile_height, get_tile_height）

  **test_grid_pathfinding()**:
  - [ ] A* 寻路（所有 4 种类型）
  - [ ] BFS 可达性（所有 4 种类型）
  - [ ] 阻挡检测（is_blocking = true 的格子不可通过）
  - [ ] 成本计算（cost 影响路径选择）

  **test_event_system()**:
  - [ ] tile_changed 信号触发（set_tile 时）
  - [ ] height_changed 信号触发（set_tile_height 时）
  - [ ] occupant_changed 信号触发（place/remove_occupant 时）
  - [ ] 信号参数正确性（old_value, new_value）

  **Acceptance Criteria**:
  - [x] `addons/grid-map/tests/test_grid_map.gd` 文件存在
  - [x] 脚本继承 `SceneTree`（不是 RefCounted 或 Node）
  - [x] 运行命令: `godot --headless --script addons/grid-map/tests/test_grid_map.gd`
  - [x] 预期输出: `Tests: 6 passed, 0 failed`
  - [x] 退出码: 0
  - [x] 覆盖所有 4 种网格类型（HEX, RECT_SIX_DIR, SQUARE, RECT）

  **Commit**: YES
  - Message: `test(grid-map): add unit tests`
  - Files: `addons/grid-map/tests/test_grid_map.gd`

---

- [x] 12. 清理和文档

  **What to do**:
  - 删除旧的 hex_* 文件（已迁移的）
  - 更新 `addons/grid-map/renderer/README.md`:
    - 将所有 "Hex Grid" 替换为 "Grid Map"
    - 将所有 "HexGridWorld" 替换为 "GridMapModel"
    - 添加对 4 种网格类型的说明
    - 更新 API 参考中的类名（HexGridRenderer2D → GridMapRenderer2D）
  - 创建 `addons/grid-map/README.md` (插件主文档):
    - 插件简介和功能列表
    - 支持的网格类型说明（HEX, RECT_SIX_DIR, SQUARE, RECT）
    - 快速开始示例
    - API 参考链接
  - 确保所有 class_name 正确
  - 确保所有 .uid 文件正确

  **Must NOT do**:
  - 不要删除测试场景（可能有用）

  **Parallelizable**: NO (最后一步)

  **References**:
  - 现有 `addons/grid-map/renderer/README.md`（重命名后的路径）

  **Files to Delete** (已迁移的旧文件):
  - [ ] `addons/grid-map/src/hex_coord.gd` → 已迁移到 `core/grid_coord.gd`
  - [ ] `addons/grid-map/src/hex_math.gd` → 已迁移到 `core/grid_math.gd`
  - [ ] `addons/grid-map/src/hex_layout.gd` → 已迁移到 `core/grid_layout.gd`
  - [ ] `addons/grid-map/src/hex_grid_world.gd` → 已迁移到 `model/grid_map_model.gd`
  - [ ] `addons/grid-map/src/hex_map.gd` → 已整合到 `model/grid_map_model.gd`
  - [ ] `addons/grid-map/src/hex_pathfinding.gd` → 已迁移到 `pathfinding/grid_pathfinding.gd`
  - [ ] `addons/grid-map/src/hex_grid_compat.gd` → 兼容层，不再需要
  - [ ] `addons/grid-map/src/` 目录 → 清空后删除整个目录
  - [ ] `addons/grid-map/renderer/hex_grid_renderer_2d.gd` → 已迁移到 `grid_map_renderer_2d.gd`
  - [ ] `addons/grid-map/renderer/hex_grid_renderer_3d.gd` → 已迁移到 `grid_map_renderer_3d.gd`
  - [ ] `addons/grid-map/tests/test_hex_grid.gd` → 已迁移到 `test_grid_map.gd`

  **Files to Keep** (保留的文件):
  - [ ] `addons/grid-map/renderer/test_renderer_2d.gd` → 测试场景，保留
  - [ ] `addons/grid-map/renderer/test_renderer_3d.gd` → 测试场景，保留
  - [ ] `addons/grid-map/renderer/README.md` → 文档，更新内容

  **Files to Update** (需要更新引用的文件):
  - [ ] `addons/grid-map/grid_map.gd` → 更新 preload 路径
  - [ ] `addons/grid-map/plugin.gd` → 更新 Autoload 路径
  - [ ] `addons/grid-map/renderer/grid_map_renderer_2d.gd` → 更新 class_name 引用
  - [ ] `addons/grid-map/renderer/grid_map_renderer_3d.gd` → 更新 class_name 引用
  - [ ] `addons/grid-map/renderer/test_renderer_2d.gd` → 更新引用（如果有）
  - [ ] `addons/grid-map/renderer/test_renderer_3d.gd` → 更新引用（如果有）

  **class_name 更新清单**:
  - [ ] `HexCoord` → `GridCoord`
  - [ ] `HexMath` → `GridMath`
  - [ ] `HexLayout` → `GridLayout`
  - [ ] `HexMap` → (删除，整合到 GridMapModel)
  - [ ] `HexGridWorld` → `GridMapModel`
  - [ ] `HexPathfinding` → `GridPathfinding`
  - [ ] `HexGridRenderer2D` → `GridMapRenderer2D`
  - [ ] `HexGridRenderer3D` → `GridMapRenderer3D`
  - [ ] `HexGrid` → `GridMap`

  **Acceptance Criteria**:
  - [x] 无冗余的 hex_* 文件
  - [x] `src/` 目录已删除
  - [x] README.md 更新为 GridMap 文档
  - [x] 所有 class_name 使用 Grid* 前缀
  - [x] Godot 编辑器无报错
  - [x] 插件可正常启用/禁用

  **Commit**: YES
  - Message: `chore(grid-map): cleanup and documentation`
  - Files: `addons/grid-map/`

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 1 | `refactor(grid-map): rename hex-grid to grid-map` | addons/grid-map/ | 插件可加载 |
| 2 | `feat(grid-map): add grid types and config` | core/grid_types.gd | 枚举定义完整 |
| 3 | `feat(grid-map): implement GridCoord` | core/grid_coord.gd | 坐标转换正确 |
| 4 | `feat(grid-map): implement GridMath` | core/grid_math.gd | 数学运算正确 |
| 5 | `feat(grid-map): implement GridLayout` | core/grid_layout.gd | 像素转换正确 |
| 6 | `feat(grid-map): implement GridMapModel` | model/grid_map_model.gd | 模型功能完整 |
| 7 | `feat(grid-map): implement GridPathfinding` | pathfinding/ | 寻路正确 |
| 8 | `feat(grid-map): implement GridMapRenderer2D` | renderer/ | 2D渲染正确 |
| 9 | `feat(grid-map): implement GridMapRenderer3D` | renderer/ | 3D渲染正确 |
| 10 | `feat(grid-map): implement GridMap autoload` | grid_map.gd | Autoload正常 |
| 11 | `test(grid-map): add unit tests` | tests/ | 测试通过 |
| 12 | `chore(grid-map): cleanup and documentation` | 全部 | 无报错 |

---

## Success Criteria

### Verification Commands
```bash
# 运行单元测试
godot --headless --script addons/grid-map/tests/test_grid_map.gd

# 预期输出:
# Testing GridCoord...
# Testing GridMath...
# Testing GridLayout...
# Testing GridMapModel...
# Testing GridPathfinding...
# Testing Event System...
# Tests: 6 passed, 0 failed

# 退出码: 0 (成功) 或 1 (失败)
echo $?  # Linux/Mac
echo %ERRORLEVEL%  # Windows
```

### Manual Verification (如果 headless 测试不可用)
```bash
# 在 Godot 编辑器中打开项目
# 1. 确认插件可正常启用: Project > Project Settings > Plugins > Grid Map
# 2. 创建测试场景，添加 GridMapRenderer2D 节点
# 3. 运行场景，验证网格渲染正确
```

### Final Checklist
- [x] 所有 "Must Have" 功能已实现
- [x] 所有 "Must NOT Have" 未实现
- [x] 所有单元测试通过
- [x] Godot 编辑器无报错
- [x] 插件可正常启用/禁用
