# GDScript 编码规范

## 1. 避免变量名遮蔽

### 不要使用基类方法名作为变量名
```gdscript
# ❌ 错误
var set := RawAttributeSet.new()

# ✅ 正确
var attr_set := RawAttributeSet.new()
```

### 全局类直接使用，不要 preload
```gdscript
# ❌ 错误：遮蔽全局类
const TestFramework = preload("res://tests/test_framework.gd")

# ✅ 正确：直接使用 class_name 声明的全局类
TestFramework.register_test("test", _test)
```

## 2. 避免变量名混淆

同一函数不同分支中的变量使用不同名称：
```gdscript
# ❌ 错误：同名变量混淆
if condition:
    var base_value := 1.0
    return base_value
var base_value := 2.0  # 混淆

# ✅ 正确：使用不同名称
if condition:
    var fallback_base := 1.0
    return fallback_base
var base_value := 2.0
```

## 3. Lambda 捕获变量

Lambda 无法修改外部简单类型，使用字典包装：
```gdscript
# ❌ 错误：无法修改外部变量
var hit := false
var callback := func():
    hit = true  # 不会修改外部的 hit

# ✅ 正确：使用字典
var state := { "hit": false }
var callback := func():
    state["hit"] = true  # 可以修改
```

## 4. 显式类型标注

### 函数参数和返回值必须显式标注类型
```gdscript
# ❌ 错误：缺少类型标注
func get_tile(coord) -> GridTileData:
func process_data(data):

# ✅ 正确：显式标注所有参数和返回值类型
func get_tile(coord: HexCoord) -> GridTileData:
func process_data(data: Dictionary) -> void:
```

### 类型不明确时使用 `as` 转换
```gdscript
# ❌ 错误：类型推断失败
var failures: int = framework.run()

# ✅ 正确：显式转换
var failures: int = framework.run() as int
```

## 5. Autoload 要求

Autoload 必须继承 Node：
```gdscript
# ❌ 错误
extends RefCounted

# ✅ 正确
extends Node
```

## 6. 测试脚本继承要求

使用 `godot --script` 运行的脚本必须继承 `SceneTree` 或 `MainLoop`：

```gdscript
# ❌ 错误：RefCounted/Node 无法直接运行
extends RefCounted

# ✅ 正确：继承 SceneTree
extends SceneTree

func _init():
    var success := run_tests()
    quit(0 if success else 1)

func run_tests() -> bool:
    # 测试逻辑
    return true
```
