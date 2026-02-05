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

**Headless 模式运行方式**：
- ❌ 错误：`godot --headless --script main.gd` (Autoload 不加载)
- ✅ 正确：`godot --headless main.tscn` (场景模式，Autoload 正常)

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

## 8.纯静态工具类声明

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

---

## 9. 接口模拟：静态工具类模式

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
