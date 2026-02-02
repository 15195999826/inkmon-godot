# 框架重构讨论：`has_method` 与 `Variant` 使用评估

> **生成时间**: 2026-02-01  
> **评估范围**: `addons/logic-game-framework/` 全部代码  
> **触发原因**: 用户编码标准要求"优先使用继承多态，避免鸭子类型"

---

## 📊 现状统计

- **has_method 使用**: 65 处（19 个文件）
- **Variant 类型声明**: 36 处（17 个文件）

---

## ✅ 已完成的高优先级修复

### 修复内容：消除临时变量的不必要 Variant 标注

以下 **10 处明显违反类型标注最佳实践** 的代码已被修复：

| 文件 | 原代码 | 修复后 | 原因 |
|------|--------|--------|------|
| `reflect_damage_action.gd:31` | `var current_event: Variant = ...` | `var current_event: Dictionary = ...` | 返回值明确为 Dictionary |
| `reflect_damage_action.gd:69` | `var event_processor: Variant = GameWorld.event_processor` | `var event_processor: EventProcessor = ...` | GameWorld.event_processor 是全局单例 EventProcessor |
| `damage_action.gd:69` | `var event_processor: Variant = ...` | `var event_processor: EventProcessor = ...` | 同上 |
| `damage_action.gd:85` | `var mutable: Variant = ...` | `var mutable: MutableEvent = ...` | process_pre_event 返回 MutableEvent |
| `skill_abilities.gd:39` | `var evt: Variant = ctx.get_current_event()` | `var evt: Dictionary = ...` | get_current_event 返回 Dictionary |
| `apply_move_action.gd:59` | `var occupant: Variant = grid.get_occupant(...)` | `var occupant: Actor = ...` | get_occupant 返回 Actor |
| `battle_replay_scene.gd:164` | `var orientation_val: Variant = ...` | `var orientation_val = ...` | 类型推断即可 |
| `battle_replay_scene.gd:171` | `var draw_mode_val: Variant = ...` | `var draw_mode_val = ...` | 类型推断即可 |
| `replay_data.gd:95` | `var team: Variant = 0` | `var team: int = 0` | 明确为 int |
| `battle_recorder.gd:112` | `var subscription: Variant = ...` | `var subscription = ...` | 类型推断即可 |
| `battle_recorder.gd:136` | `func(event: Variant)` | `func(event: Dictionary)` | 事件明确为 Dictionary |

**收益**:
- ✅ 编译时类型检查
- ✅ IDE 自动补全和错误提示
- ✅ 代码可读性提升
- ✅ 零架构风险

---

## ⚠️ 中优先级：需权衡的设计决策

### 1. ~~组件查询系统（Ability.gd）~~ ✅ 已移除

**发现**: `get_component()`, `get_components()`, `has_component()` 这三个方法在整个代码库中 **从未被调用过**。

**行动**: 已从 `ability.gd` 完全移除：
- ❌ `func get_component(ctor: Variant)` 
- ❌ `func get_components(ctor: Variant)`
- ❌ `func has_component(ctor: Variant)`
- ❌ `func _component_matches(component, ctor: Variant)`

**搜索证据**:
- 搜索范围: 177 个 .gd 文件
- 调用次数: **0**
- 唯一出现: 仅在本文档的示例代码中

**保留的方法**:
- ✅ `get_all_components()` - 实际被使用

**收益**:
- 移除 33 行未使用代码
- 消除不必要的 `Variant` 参数
- 简化 API 表面

---

### 2. AbilitySet 接口检测 ✅ 已优化

#### 当前设计

```gdscript
# ability_set.gd:229-230
static func is_ability_set_provider(obj: Variant) -> bool:
    return obj != null and typeof(obj) == TYPE_OBJECT and obj.has_method("get_ability_set_for_actor")
```

#### 为什么使用 has_method

检查对象是否实现"能力集提供者"接口，但 GDScript **无 `interface` 关键字**。

#### 重构方案对比

| 方案 | 代码示例 | 优点 | 缺点 |
|------|---------|------|------|
| **A. 保持鸭子类型检查** | `obj.has_method("get_ability_set_for_actor")` | ✅ 灵活<br>✅ 无耦合<br>✅ GDScript 惯用方式 | ⚠️ 运行时检查 |
| **B. 引入基类** | `class AbilitySetProvider:`<br>  `func get_ability_set_for_actor(...)`<br><br>`obj is AbilitySetProvider` | ✅ 类型安全<br>✅ IDE 支持 | ❌ 强制继承<br>❌ 破坏现有代码<br>❌ 降低扩展性 |

**推荐**: **方案 A**（保持现状）

**理由**:
- 这是 GDScript 实现接口的 **惯用方式**（鸭子类型）
- 框架扩展性 > 类型安全（用户可能使用无法修改继承链的第三方类）
- Godot 官方代码库大量使用 `has_method` 检测接口

**类比**: 类似 Python 的 `hasattr(obj, 'method')` 或 TypeScript 的 `'method' in obj`

---

### 3. battle_logger.gd 的兼容性参数

#### 当前设计

```gdscript
# battle_logger.gd:296
## @param from_hex: 起始坐标 (HexCoord 或 Dictionary {"q": int, "r": int})
## @param to_hex: 目标坐标 (HexCoord 或 Dictionary {"q": int, "r": int})
func actor_moved(actor_id: String, from_hex: Variant, to_hex: Variant) -> void:
    var from_q: int = from_hex.q if from_hex is RefCounted else from_hex.get("q", 0)
    var from_r: int = from_hex.r if from_hex is RefCounted else from_hex.get("r", 0)
    # ...
```

#### 为什么使用 Variant

Logger 需要兼容两种来源：
- **逻辑层**: 传递 `HexCoord` 对象
- **录像数据**: 传递序列化的 `Dictionary {"q": ..., "r": ...}`

#### 重构方案对比

| 方案 | 代码示例 | 优点 | 缺点 |
|------|---------|------|------|
| **A. 保持 Variant + 注释** | `from_hex: Variant  # HexCoord \| Dictionary` | ✅ 灵活兼容<br>✅ 零破坏性 | ⚠️ 运行时检查 |
| **B. 统一为 Dictionary** | `from_hex: Dictionary` | ✅ 类型明确 | ❌ 调用方需转换<br>❌ 降低逻辑层可读性 |
| **C. 方法重载（不存在）** | 两个方法签名 | ✅ 类型安全 | ❌ **GDScript 不支持** |

**推荐**: **方案 A**（保持现状 + 改进文档）

**理由**:
- 实际需求：兼容两种数据格式
- 强制统一格式会增加调用方负担
- 这是合理的"适配器"模式

**改进建议**:
```gdscript
## 记录移动
## @param from_hex HexCoord 对象或 Dictionary {"q": int, "r": int}
## @param to_hex HexCoord 对象或 Dictionary {"q": int, "r": int}
func actor_moved(actor_id: String, from_hex: Variant, to_hex: Variant) -> void:
```

---

## 🔴 低优先级/不建议重构

以下使用 `has_method` 和 `Variant` 的场景是 **框架设计的核心部分**，重构成本 > 收益。

---

### 1. GameplayInstance 的系统/Actor 生命周期管理 ⚠️ 优化了一次， 但是存在bug， 记录在了文档尾部

#### 当前设计

```gdscript
# gameplay_instance.gd:34-38
for system in _systems:
    if system != null and system.has_method("get_enabled") and system.get_enabled():
        if system.has_method("tick"):
            system.tick(_actors, dt)

# gameplay_instance.gd:63-67
for actor in _actors:
    if actor != null and actor.has_method("on_despawn"):
        actor.on_despawn()
for system in _systems:
    if system != null and system.has_method("on_unregister"):
        system.on_unregister()
```

#### 设计意图

- `_systems: Array` 和 `_actors: Array` 是 **未类型化数组**
- 允许用户自定义任意 System/Actor 子类，**无需强制继承**
- **可选接口模式**：有 `get_enabled` 方法就检查，没有就跳过

#### 如果改为继承多态

```gdscript
# 需要定义强制基类
class_name System extends RefCounted
func get_enabled() -> bool: return true  # 强制所有系统实现
func tick(actors: Array, dt: float) -> void: pass
func on_register() -> void: pass
func on_unregister() -> void: pass

# 所有用户自定义系统必须继承
class MyCustomSystem extends System:
    func tick(actors: Array, dt: float) -> void:
        # 实现逻辑
```

#### 架构权衡

| 项目 | 鸭子类型（现状） | 继承多态（重构后） |
|------|-----------------|-------------------|
| **扩展性** | ✅ 用户可用任意对象 | ❌ 必须继承 System 基类 |
| **类型安全** | ❌ 运行时检查 | ✅ 编译时检查 |
| **可选接口** | ✅ 有方法就调用 | ❌ 需要空实现所有虚方法 |
| **IDE 支持** | ❌ 无自动补全 | ✅ 完整补全 |
| **框架复杂度** | ✅ 简单直观 | ⚠️ 需要维护基类层次 |
| **第三方兼容** | ✅ 可集成任意类 | ❌ 无法修改继承链的类无法使用 |

**推荐**: **保持现状**

**理由**:
1. **框架设计理念**: 组合 > 继承
2. **GDScript 限制**: 无 `interface` 关键字，强制继承损失灵活性
3. **实际需求**: 用户可能需要集成无法修改继承链的第三方类
4. **可选接口**: 不是所有系统都需要 `get_enabled`，强制实现空方法违背设计初衷

**折中方案**（仅文档改进）:
```gdscript
## System 协议要求:
## - get_enabled() -> bool (可选，默认启用)
## - tick(actors: Array, dt: float) -> void (必需)
## - on_register(instance: GameplayInstance) -> void (可选)
## - on_unregister() -> void (可选)
##
## 示例:
##   class MySystem extends RefCounted:
##       func tick(actors: Array, dt: float) -> void:
##           # 系统逻辑
var _systems: Array = []
```

---

### 2. Ability 组件系统的可选生命周期钩子

#### 当前设计

```gdscript
# ability.gd:38-39
for component in _components:
    if component and component.has_method("initialize"):
        component.initialize(self)

# ability.gd:91-93
if component and component.has_method("get_state") and component.get_state() == "active":
    if component.has_method("on_tick"):
        component.on_tick(dt)

# ability.gd:146-148
if component.has_method("on_event"):
    if component.on_event(event, context, game_state_provider):
        triggered_components.append(_get_component_name(component))
```

#### 设计意图

**可选生命周期钩子** - 不是所有组件都需要所有钩子：
- 不是所有组件都需要 `initialize`（有些组件无状态）
- 不是所有组件都需要 `on_tick`（有些组件是一次性效果）
- 不是所有组件都需要 `on_event`（有些组件不响应事件）

#### 如果改为继承

```gdscript
class_name AbilityComponent extends RefCounted
func initialize(ability: Ability) -> void: pass  # 强制空实现
func get_state() -> String: return "active"
func on_tick(dt: float) -> void: pass  # 强制空实现
func on_event(event: Dictionary, context: Dictionary, provider: Variant) -> bool: return false
func on_apply(context: Dictionary) -> void: pass  # 强制空实现
func on_remove(context: Dictionary) -> void: pass  # 强制空实现
func serialize() -> Dictionary: return {}  # 强制空实现

# 所有组件必须继承并实现（即使是空方法）
class NoInstanceComponent extends AbilityComponent:
    func initialize(ability: Ability) -> void: pass  # 不需要但必须写
    func on_tick(dt: float) -> void: pass  # 不需要但必须写
    # ...
```

**问题**: 强制所有组件实现 7+ 个空方法，违背最小化接口原则

**推荐**: **保持现状**

**理由**:
- **可选钩子模式** 是组件系统的核心设计
- 强制实现空方法是反模式（参考 Java 的 Adapter 类就是为了解决这个问题）
- GDScript 无默认接口实现（不像 C# 的 `default interface methods`）

---

### 3. RecordingUtils 的兼容性检查

#### 当前设计

```gdscript
# recording_utils.gd:7-11
static func record_attribute_changes(attr_set: Variant, ctx: Dictionary) -> Array:
    if not attr_set.has_method("addChangeListener"):
        return unsubscribes  # 不支持监听，直接返回
    # ...

# recording_utils.gd:152-158
static func record_tag_changes(tag_source: Variant, ctx: Dictionary) -> Callable:
    var has_snake_case: bool = tag_source.has_method("on_tag_changed")
    var has_camel_case: bool = tag_source.has_method("onTagChanged")
    if not has_snake_case and not has_camel_case:
        return func(): pass  # 不支持，返回空函数
```

#### 设计意图

**兼容性适配层**:
1. **跨语言移植兼容**: 支持 TS 移植代码的 `addChangeListener`（驼峰命名）
2. **命名风格兼容**: 同时支持 `on_tag_changed`（GDScript 风格）和 `onTagChanged`（TS 风格）
3. **可选功能**: 如果对象不支持监听，静默失败而不报错

**推荐**: **保持现状**

**理由**:
- 这是实用的 **适配器模式**，不是设计缺陷
- 框架需要兼容不同实现和命名约定
- 强制统一会破坏现有代码

---

### 4. 测试框架的泛型断言

#### 当前设计

```gdscript
# test_framework.gd:74,245
static func expect(actual: Variant) -> Expectation:
func _init(actual: Variant, framework: TestFramework) -> void:

# test_framework.gd:203,253,271
static func assert_equal(expected: Variant, actual: Variant) -> void:
func to_be(expected: Variant) -> void:
func to_equal(expected: Variant) -> void:
```

**推荐**: **保持现状**

**理由**:
- 测试框架 **必须接受任意类型** 进行断言
- 这是 `Variant` 的 **合理用途**（类似 TypeScript 的 `any` 在测试框架中的使用）
- 所有测试框架都使用泛型（Jest、Mocha、GTest 等）

---

## 📈 架构权衡总结

### 核心矛盾

| 方面 | 鸭子类型（框架现状） | 继承多态（编码标准期望） |
|------|---------------------|------------------------|
| **扩展性** | ✅ 用户自由组合，无强制继承 | ❌ 必须继承指定基类 |
| **类型安全** | ❌ 运行时检查，无编译错误 | ✅ 编译时检查，IDE 完整支持 |
| **学习曲线** | ✅ 简单直观，组合优先 | ⚠️ 需要理解类层次结构 |
| **IDE 体验** | ❌ 补全有限，需查文档 | ✅ 完整自动补全和跳转 |
| **GDScript 适配** | ✅ 惯用方式，无 interface 的替代 | ❌ 模拟 interface 笨重且不优雅 |
| **框架理念** | ✅ 组合 > 继承（现代设计） | ❌ 强制继承（传统 OOP） |
| **第三方兼容** | ✅ 可集成任意类 | ❌ 无法修改继承链的类无法使用 |

### GDScript 类型系统现状

GDScript **缺失的特性**（对比 TypeScript/C#）:
- ❌ **接口 (interface)**: 无法定义纯契约
- ❌ **类型联合 (Union Types)**: 无法表达 `Script | String`
- ❌ **方法重载**: 无法同名方法不同签名
- ❌ **默认接口实现**: 无法在接口提供默认行为
- ❌ **协变返回类型**: 继承时无法细化返回类型

**现实**: GDScript 的鸭子类型 **不是缺陷，是特性**（类似 Python）

---

## 🎯 最终建议

### 立即执行（已完成 ✅）

1. ✅ **修复临时变量不必要的 Variant** (10 处)
   - 零风险，纯收益
   - 提升代码质量和可维护性

### 可选优化（文档改进）

2. **为合理的 Variant 参数添加文档注释**:
   ```gdscript
   ## @param obj 任意对象，检查是否实现 get_ability_set_for_actor 方法
   static func is_ability_set_provider(obj: Variant) -> bool:
   ```

3. **为数组添加协议文档**:
   ```gdscript
   ## System 协议: get_enabled() -> bool (可选), tick(actors, dt) -> void (必需)
   var _systems: Array = []
   ```

### 不建议重构（保持现状）

4. **保持框架核心的鸭子类型设计**:
   - ✅ GameplayInstance 的 System/Actor 管理
   - ✅ Ability 组件的可选生命周期钩子
   - ✅ AbilitySet 的接口检测
   - ✅ RecordingUtils 的兼容性检查
   - ✅ 测试框架的泛型断言

**原因**: 这些是 **框架设计理念的核心**，重构会：
- ❌ 破坏扩展性（强制继承）
- ❌ 增加用户学习成本
- ❌ 降低代码灵活性
- ❌ 违背 GDScript 惯用方式

---

--- 新问题
死亡角色现在是直接移除的， 保存会存在被系统/event继续处理的问题。但我又希望记录哪个actor死亡了， 需要一种设计技能保存这些actor， 又不会影响其它系统。
📌 你需要确认的语义点
现在 “死亡 = 立即移除”，所有系统都不会再处理死亡角色。
如果你希望仍保留“死亡但可回放/展示尸体”的行为，需要额外补充。

需要我继续做：

🔧 补删除/移除时的录像事件同步？
🧪 跑测试或手动验证流程？
🧹 再清理可能残留的 isActive 字段？

bug:
死亡不消失， 角色扣血动画不见了。
---

```
DamageAction.gd:85, 这是要干嘛？
# 获取 actors 列表（用于 Post 阶段广播）
var actors := HexBattleGameStateUtils.get_actors_for_event_processor(battle)
	

character_actor.to_event_processor_dict 是个什么东西？
```
---

## 💡 编码标准的适用性讨论

### 原则

> "优先使用继承多态，避免鸭子类型"

### 适用场景

✅ **业务逻辑代码**（明确继承关系）:
```gdscript
class Enemy extends Actor:  # 明确的 "is-a" 关系
class Boss extends Enemy:
```

❌ **框架/库代码**（需要最大灵活性）:
```gdscript
# 框架不应强制用户的类继承链
func process_systems(systems: Array):  # 接受任意实现 tick() 的对象
```

### 建议

**分层应用编码标准**:
| 层级 | 推荐方式 | 理由 |
|------|---------|------|
| **框架层** | 鸭子类型 + 文档 | 最大化扩展性，符合 GDScript 惯用方式 |
| **游戏逻辑层** | 继承多态 | 明确 "is-a" 关系，业务逻辑清晰 |
| **工具/适配层** | 混合使用 | 根据具体需求选择最合适的方式 |

---

## 📊 工作量估算

| 优先级 | 内容 | 工作量 | 状态 |
|--------|------|--------|------|
| **高** | 修复临时变量 Variant | ~30 分钟 | ✅ 已完成 |
| **中** | 文档注释改进 | ~1 小时 | ⏳ 可选 |
| **低** | 框架架构重构 | ~数天 + 破坏性变更 | ❌ 不建议 |

---

## 🔖 参考

### GDScript 官方文档
- [GDScript 静态类型](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/static_typing.html)
- [GDScript 风格指南](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html)

### 设计模式
- **鸭子类型**: "如果它走起来像鸭子，叫起来像鸭子，那它就是鸭子"
- **组合优于继承**: Gang of Four 设计原则
- **最小化接口**: 只要求客户端需要的方法

---

**结论**: 框架层保持现状是合理的架构决策，符合 GDScript 语言特性和框架设计最佳实践。
