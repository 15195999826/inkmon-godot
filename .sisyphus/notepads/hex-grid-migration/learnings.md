# Learnings - hex-grid-migration

## 写入大文件注意事项
- **问题**: 一次性写入过多内容会导致 write 工具调用失败
- **解决方案**: 对于大文件，使用分段写入或优先使用 edit 命令进行增量修改
- **适用场景**: 单次 write 内容超过 15KB 时需要分段

## GridLayout 配置模式分析 (Task 0)

### 1. GridLayout 初始化参数
从 `GridMapModel.initialize()` (grid_map_model.gd:85-91):
```gdscript
_layout = _GridLayout.new(
    config.grid_type,        # GridMapConfig.GridType.HEX
    config.size,             # float (hex_size)
    config.origin,           # Vector2.ZERO
    config.orientation,      # GridMapConfig.Orientation.FLAT/POINTY
    config.tile_size         # Vector2 (用于矩形，六边形不使用)
)
```

### 2. 参数来源 (battle_replay_scene.gd:139-182)
- **hex_size**: 从 replay_data["mapConfig"]["hexSize"] 获取，默认 10.0
- **orientation**: 从 replay_data["mapConfig"]["orientation"] 获取，默认 "flat"
- **draw_mode**: 从 replay_data["mapConfig"]["draw_mode"] 获取，默认 "row_column"
- **rows/columns**: 从 replay_data["mapConfig"] 获取，默认 9x9
- **radius**: 从 replay_data["mapConfig"]["radius"] 获取，默认 4

### 3. 方向枚举映射
```gdscript
# 旧 API (FrontendHexGridConfig)
const ORIENTATION_FLAT = 0
const ORIENTATION_POINTY = 1

# 新 API (GridMapConfig)
enum Orientation {
    FLAT,       # 0 - 平顶六边形
    POINTY,     # 1 - 尖顶六边形
    HORIZONTAL, # 2 - 水平矩形
    VERTICAL,   # 3 - 垂直矩形
}

# 转换逻辑 (battle_replay_scene.gd:166)
grid_config.orientation = GridMapConfig.Orientation.FLAT if orientation_str == "flat" else GridMapConfig.Orientation.POINTY
```

### 4. 坐标转换实现对比

#### 旧 API: FrontendHexGridConfig.hex_to_world()
```gdscript
# hex_grid_config.gd:41-60
func hex_to_world(hex: Vector2i) -> Vector3:
    var world_2d := _hex_to_world_2d(Vector2(hex.x, hex.y))
    return Vector3(world_2d.x, 0.0, world_2d.y) + origin  # Z=0

func _hex_to_world_2d(hex: Vector2) -> Vector2:
    if orientation == ORIENTATION_FLAT:
        x = hex_size * (3.0 / 2.0 * hex.x)
        y = hex_size * (sqrt(3.0) / 2.0 * hex.x + sqrt(3.0) * hex.y)
    else:  # POINTY
        x = hex_size * (sqrt(3.0) * hex.x + sqrt(3.0) / 2.0 * hex.y)
        y = hex_size * (3.0 / 2.0 * hex.y)
    return Vector2(x, y)
```

#### 新 API: GridLayout.coord_to_pixel()
```gdscript
# grid_layout.gd:239-246
func _hex_to_pixel(coord: Vector2i) -> Vector2:
    var f0: float = _matrix["f0"]  # 从 FLAT_ORIENTATION/POINTY_ORIENTATION 获取
    var f1: float = _matrix["f1"]
    var f2: float = _matrix["f2"]
    var f3: float = _matrix["f3"]
    var x: float = (f0 * coord.x + f1 * coord.y) * size
    var y: float = (f2 * coord.x + f3 * coord.y) * size
    return Vector2(x, y) + origin
```

#### 方向矩阵 (grid_layout.gd:28-50)
```gdscript
# FLAT_ORIENTATION (平顶)
const FLAT_ORIENTATION := {
    "f0": 1.5,              # 对应 3.0/2.0
    "f1": 0.0,
    "f2": SQRT3 / 2.0,      # 对应 sqrt(3.0)/2.0
    "f3": SQRT3,            # 对应 sqrt(3.0)
}

# POINTY_ORIENTATION (尖顶)
const POINTY_ORIENTATION := {
    "f0": SQRT3,            # 对应 sqrt(3.0)
    "f1": SQRT3 / 2.0,      # 对应 sqrt(3.0)/2.0
    "f2": 0.0,
    "f3": 1.5,              # 对应 3.0/2.0
}
```

### 5. Z 轴处理
- **旧实现**: `Vector3(world_2d.x, 0.0, world_2d.y)` - Y 轴为 0
- **新实现**: 需要手动转换 `Vector2 -> Vector3`
  ```gdscript
  var pixel := layout.coord_to_pixel(coord)
  var world := Vector3(pixel.x, 0.0, pixel.y)  # 保持 Y=0
  ```

### 6. 关键差异
| 特性 | 旧 API | 新 API |
|------|--------|--------|
| 返回类型 | `Vector3` | `Vector2` |
| 原点处理 | 内置 `origin: Vector3` | 内置 `origin: Vector2` |
| 方向枚举 | `ORIENTATION_FLAT/POINTY` | `GridMapConfig.Orientation.FLAT/POINTY` |
| 数学实现 | 硬编码公式 | 矩阵驱动 (更通用) |
| 逆转换 | `world_to_hex(Vector3)` | `pixel_to_coord(Vector2)` |

### 7. 迁移要点
1. **GridLayout 构造**: 使用 `GridMapConfig` 配置，通过 `GridMapModel.initialize()` 创建
2. **坐标转换**: `coord_to_pixel()` 返回 `Vector2`，需手动转 `Vector3(x, 0, y)`
3. **逆转换**: `world_to_hex(Vector3)` → `pixel_to_coord(Vector2(world.x, world.z))`
4. **方向映射**: 字符串 "flat"/"pointy" → `GridMapConfig.Orientation.FLAT/POINTY`
5. **原点**: `Vector3` → `Vector2` (忽略 Y 分量)

## RenderWorld 迁移经验 (Task 1)

### 1. 修改内容总结
- **文件**: `core/render_world.gd`, `core/visualizer_context.gd`
- **变更**:
  - `_hex_config: FrontendHexGridConfig` → `_layout: GridLayout`
  - 构造函数移除 `hex_config` 参数
  - `initialize_from_replay()` 中创建 GridLayout
  - 所有 `hex_to_world()` → `coord_to_pixel()` + Vector3 转换
  - 所有 `world_to_hex()` → `pixel_to_coord()`

### 2. GridLayout 初始化模式
```gdscript
# 从 mapConfig 创建 GridLayout
var hex_size: float = float(map_config.get("hexSize", 10.0))
var orientation_str: String = str(map_config.get("orientation", "flat"))
var orientation := GridMapConfig.Orientation.FLAT if orientation_str == "flat" else GridMapConfig.Orientation.POINTY

_layout = GridLayout.new(
    GridMapConfig.GridType.HEX,
    hex_size,
    Vector2.ZERO,
    orientation,
    Vector2.ONE
)
```

### 3. 坐标转换模式
```gdscript
# 旧: hex_to_world(Vector2i) -> Vector3
return _hex_config.hex_to_world(Vector2i(q, r))

# 新: coord_to_pixel(Vector2i) -> Vector2, 手动转 Vector3
var pixel := _layout.coord_to_pixel(Vector2i(q, r))
return Vector3(pixel.x, 0.0, pixel.y)

# 旧: world_to_hex(Vector3) -> Vector2i
return _hex_config.world_to_hex(world_pos)

# 新: pixel_to_coord(Vector2) -> Vector2i
return _layout.pixel_to_coord(Vector2(world_pos.x, world_pos.z))
```

### 4. VisualizerContext 接口变更
```gdscript
# 旧接口
func get_hex_config() -> FrontendHexGridConfig

# 新接口
func get_layout() -> GridLayout
```

### 5. 测试验证
- **编译测试**: 通过（修复 lomolib Log 引用问题后）
- **回放流程测试**: 通过（Godot 4.6 rc1 有内存泄漏警告，但功能正常）
- **注意**: Godot 4.6 rc1 退出时有 RID 泄漏警告，属于引擎问题，不影响功能

### 6. 副作用修复
- **问题**: `addons/lomolib/camera/lomo_camera_rig.gd` 引用了不存在的 `Log` 类
- **修复**: 将 `Log.info()` 替换为 `print()`
- **位置**: line 321, 333

### 7. 关键要点
1. GridLayout 构造需要 5 个参数（grid_type, size, origin, orientation, tile_size）
2. 坐标转换返回类型变化：Vector3 → Vector2，需手动转换
3. 逆转换需要提取 Vector3 的 x, z 分量作为 Vector2
4. 方向枚举使用 `GridMapConfig.Orientation.FLAT/POINTY`
5. VisualizerContext 也需要同步修改接口

## Task 1 补充经验

### 1. as_context() 临时禁用
- **原因**: VisualizerContext 构造函数签名未同步修改
- **方法**: 返回 null + push_error() 提示
- **位置**: render_world.gd:370-380

### 2. 编译验证方法
```bash
godot --headless --script <file.gd> --check-only
```
- 比 lsp_diagnostics 更可靠（LSP 有时超时）
- 输出为空表示编译成功


## Task 2 完成

### 修改内容
1. **visualizer_context.gd**:
   - Line 23: `var _hex_config: FrontendHexGridConfig` → `var _layout: GridLayout`
   - Line 28-37: 构造函数参数 `hex_config` → `layout`
   - Line 43-46: `get_actor_position()` 使用 `coord_to_pixel()` + Vector3 转换
   - Line 106-108: `get_hex_config()` → `get_layout()`
   - Line 113-115: `hex_to_world()` 使用 `coord_to_pixel()` + Vector3 转换

2. **render_world.gd**:
   - Line 370-377: 恢复 `as_context()` 方法，传递 `_layout` 参数

### 验证结果
- ✅ visualizer_context.gd 编译通过
- ✅ render_world.gd 编译通过
- ✅ as_context() 方法恢复正常

### 接口变更
- `get_hex_config() -> FrontendHexGridConfig` → `get_layout() -> GridLayout`
- 调用方需要同步修改（如果有）


## lomo_camera_rig.gd Log 引用修复

### 问题
- **文件**: addons/lomolib/camera/lomo_camera_rig.gd
- **原因**: 引用了不存在的 `Log` 类
- **位置**: Line 321, 333

### 修复方法
```gdscript
# 旧代码
Log.info("LomoCameraRig", "Begin tracing: %s" % target.name)

# 新代码
print("[LomoCameraRig] Begin tracing: %s" % target.name)
```

### 验证
- ✅ `godot --check-only` 编译通过
- ✅ 保持日志格式一致（添加 [LomoCameraRig] 前缀）


## battle_replay_scene.gd 迁移到新 API

### 修改内容
1. **Line 25**: `var _hex_grid_renderer: HexGridRenderer3D` → `GridMapRenderer3D`
2. **Line 31**: `var _hex_world: HexGridWorld` → `GridMapModel`
3. **Line 129**: `HexGridRenderer3D.new()` → `GridMapRenderer3D.new()`
4. **Line 139-182**: `_setup_hex_grid_from_replay()` 重写
   - 创建 `GridMapConfig` 对象
   - 设置 `grid_type`, `size`, `origin`, `orientation`
   - 转换 `draw_mode` 枚举（"row_column" → `GridMapConfig.DrawMode.ROW_COLUMN`）
   - 使用 `GridMapModel.new()` + `initialize(config)`
5. **Line 302**: `var pixel: Vector2 = _hex_world.coord_to_pixel(hex_coord)` - 显式类型标注修复类型推断

### GridMapConfig 配置模式
```gdscript
var grid_config := GridMapConfig.new()
grid_config.grid_type = GridMapConfig.GridType.HEX
grid_config.size = float(map_config.get("hexSize", 10.0))
grid_config.origin = Vector2.ZERO
grid_config.orientation = GridMapConfig.Orientation.FLAT if orientation_str == "flat" else GridMapConfig.Orientation.POINTY

# 绘制模式
if draw_mode_str == "row_column":
    grid_config.draw_mode = GridMapConfig.DrawMode.ROW_COLUMN
    grid_config.rows = int(map_config.get("rows", 9))
    grid_config.columns = int(map_config.get("columns", 9))
elif draw_mode_str == "radius":
    grid_config.draw_mode = GridMapConfig.DrawMode.RADIUS
    grid_config.radius = int(map_config.get("radius", 4))

# 初始化模型
_hex_world = GridMapModel.new()
_hex_world.initialize(grid_config)
```

### 验证结果
- ✅ 编译通过
- ✅ test_compilation.gd 所有测试通过
- ⚠️ 已知问题：GridMapModel 类名冲突警告（不影响功能）
- ⚠️ 已知问题：内存泄漏警告（Godot 4.6 rc1 引擎问题）

