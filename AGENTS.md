# Godot/GDScript 开发指南

---

## 📋 目录

1. [GDScript 编码规范](#gdscript-编码规范)
2. [常见错误与解决方案](#常见错误与解决方案)

---

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

### 类型不明确时使用显式标注或 `as` 转换

```gdscript
# ❌ 错误：类型推断失败
var failures: int = framework.run()

# ✅ 正确：显式转换
var failures: int = framework.run() as int
```

### 动态加载脚本的类型标注

使用 `load()` 动态加载脚本后调用 `.new()` 时，必须显式标注类型：

```gdscript
# ❌ 错误：无法推断 load().new() 的类型
var instance := script.new()
# Parse Error: Cannot infer the type of "instance" variable because the value doesn't have a set type.

# ✅ 正确：显式标注基类类型
var instance: RefCounted = script.new()

# ✅ 或者：如果知道具体类型
var instance: MyClass = script.new()
```

**原因**：`load()` 返回 `Resource` 类型，调用 `.new()` 返回 `Variant`，GDScript 无法自动推断具体类型。

## 5. Autoload 要求

Autoload 必须继承 Node：
```gdscript
# ❌ 错误
extends RefCounted

# ✅ 正确
extends Node
```

## 6. 纯静态工具类声明

仅提供静态函数、不会被实例化的工具类，**不要写 `extends RefCounted`**：

```gdscript
# ✅ 正确：纯静态工具类，只写 class_name
class_name IAbilitySetOwner
## 协议要求: get_ability_set() -> AbilitySet

static func get_ability_set(owner: Object) -> AbilitySet:
    ...

# ❌ 错误：冗余的 extends RefCounted
extends RefCounted
class_name IAbilitySetOwner
```

**原因**：GDScript 默认继承 `RefCounted`，显式写出是冗余的。省略 `extends` 还能明确表达"这个类不需要实例化"。

## 7. 类型系统：优先使用继承多态，避免鸭子类型

### 原则
- ✅ 默认使用继承 + 类型化数组
- ❌ 非必要不使用 has_method（会损失类型检查与补全）

### 规范示例
```gdscript
var _conditions: Array[Condition] = []

func _check_conditions(ctx: Dictionary) -> bool:
    for condition in _conditions:
        if not condition.check(ctx):
            return false
    return true
```

## 8. 接口模拟：静态工具类模式

GDScript 无 `interface`，用静态工具类封装 `has_method`。

### 何时使用 `I*` 接口工具类

| 场景 | 方案 | 原因 |
|------|------|------|
| 已有明确继承体系 | ✅ 直接用基类类型 | 基类已保证方法存在，无需检查 |
| 跨模块、无共同基类 | ✅ 创建 `I*` 工具类 | 模块间不想有硬依赖 |
| 框架需兼容用户自定义类 | ✅ 创建 `I*` 工具类 | 用户可能不继承框架基类 |
| 真正的"协议"场景 | ✅ 创建 `I*` 工具类 | 只关心有没有某方法，不关心类型 |

```gdscript
# ❌ 错误：已有基类却用 has_method
var instance: GameplayInstance = _instances[id]
if instance.has_method("end"):  # 多余！基类已定义 end()
    instance.end()

# ✅ 正确：直接调用基类方法
var instance: GameplayInstance = _instances[id]
instance.end()
```

### 模式
```gdscript
class_name IAbilitySetOwner
## 协议要求: get_ability_set() -> AbilitySet

static func get_ability_set(owner: Object) -> AbilitySet:
    if owner == null or not owner.has_method("get_ability_set"):
        return null
    return owner.get_ability_set()

static func is_implemented(owner: Object) -> bool:
    return owner != null and owner.has_method("get_ability_set")
```

### 使用
```gdscript
# ❌ 散落检测
if actor.has_method("get_ability_set"):
    var ability_set = actor.get_ability_set()

# ✅ 通过工具类集中处理
var ability_set := IAbilitySetOwner.get_ability_set(actor)
if ability_set != null:
    ability_set.apply_tag(...)
```

### 要点
- 命名：`I` + 协议名（如 `IAbilitySetOwner`）
- **优先用继承**：如果有共同基类，直接用类型标注，不需要 `I*` 工具类
- 框架层/跨模块无共同基类时才用工具类
- 内部仍用 `has_method`，避免到处散落

---

# 常见错误与解决方案

## 1. 无头模式执行错误

### 错误：Can't load the script as it doesn't inherit from SceneTree or MainLoop

**完整错误信息**：
```
ERROR: Can't load the script "xxx.gd" as it doesn't inherit from SceneTree or MainLoop.
   at: start (main/main.cpp:4251)
```

**原因**：使用 `godot --script` 直接运行继承 `Node` 的脚本。

**解决方案**：

#### 方案 1：通过场景运行（推荐）

```bash
# ❌ 错误
godot --headless --script addons/logic-game-framework/tests/test_framework.gd

# ✅ 正确
godot --headless addons/logic-game-framework/tests/run_tests.tscn
```

**适用场景**：
- 测试脚本（需要 Autoload）
- 依赖场景树的逻辑
- 需要加载资源的脚本

#### 方案 2：改为继承 SceneTree 或 MainLoop

```gdscript
# 原代码
extends Node
class_name TestRunner

# 修改为
extends SceneTree  # 或 extends MainLoop
class_name TestRunner
```

**适用场景**：
- 独立工具脚本
- 不需要场景树的逻辑
- 不依赖 Autoload

### Autoload 加载规则

| 运行方式 | Autoload 是否加载 | 适用场景 |
|----------|-------------------|----------|
| `godot --script main.gd` | ❌ 不加载 | 独立脚本工具 |
| `godot main.tscn` | ✅ 加载 | 正常游戏运行 |
| `godot --headless main.tscn` | ✅ 加载 | 测试、服务器模式 |

**最佳实践**：
- **测试脚本**：创建 `.tscn` 场景文件，挂载继承 `Node` 的测试运行器脚本
- **工具脚本**：如需独立运行，继承 `SceneTree` 或 `MainLoop`
- **依赖 Autoload**：必须通过场景运行，不能使用 `--script`

