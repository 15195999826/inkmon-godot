# Logic Game Framework 使用规范

## 1. 属性访问规范

针对拥有attribute_set的actor

**直接访问 `actor.attribute_set`，不要为每个属性创建 getter/setter**

```gdscript
# ✅ 推荐
var hp := actor.attribute_set.hp
actor.attribute_set.hp -= damage

# ❌ 不推荐
func get_hp() -> float:
    return attribute_set.hp
```

**例外：语义化方法** - 只为包含业务逻辑的操作封装方法

```gdscript
class_name CharacterActor extends Node

var attribute_set: AttributeSet  # 公开访问

# ✅ 有业务逻辑
func is_alive() -> bool:
    return attribute_set.hp > 0

func take_damage(amount: float) -> void:
    var old_hp := attribute_set.hp
    attribute_set.hp = max(0, attribute_set.hp - amount)
    if old_hp > 0 and attribute_set.hp <= 0:
        emit_signal("died")

# ❌ 单纯转发
# func get_hp() -> float:
#     return attribute_set.hp
```

## 2. 实例化与状态约束

### 核心原则

框架中的对象分为两类：**Config 模式创建的独立实例**和**共享实例**。
它们的状态约束完全不同：

| 分类 | 创建方式 | 实例归属 | 可否持有状态 |
|------|---------|---------|-------------|
| Ability | `AbilityConfig` → `Ability._resolve_components()` 每角色创建新实例 | 每个角色独立 | ✅ 可以 |
| AbilityComponent | `ActiveUseComponent.new(cfg)` 等，每个 Ability 创建独立实例 | 每个 Ability 独立 | ✅ 可以 |
| **Action** | `HexBattleDamageAction.new(...)` 在 `static var` 中创建 | **所有角色共享** | ❌ 禁止 |
| **Condition** | 同 Action | **所有角色共享** | ❌ 禁止 |
| **Cost** | 同 Action | **所有角色共享** | ❌ 禁止 |
| **TriggerConfig** | `TriggerConfig.new(...)` 在 `static var` 或 Builder 中创建 | **所有角色共享** | ❌ 禁止（无需校验，结构简单） |

### 为什么会共享

技能配置使用 `static var`，类加载时只执行一次 `.new()`：

```gdscript
static var SLASH_ABILITY := (
    AbilityConfig.builder()
    .active_use(
        ActiveUseConfig.builder()
        .on_tag(TimelineTags.HIT, [DamageAction.new(...)])  # 只创建一次！
        .build()
    )
    .build()
)
```

虽然每个角色通过 `AbilityConfig` 创建独立的 `Ability` 和 `AbilityComponent`，
但 Component 内部的 Action/Condition/Cost **仍然是引用传递**，所有角色共享同一批实例：

```
AbilityConfig (static var, 单例)
    ↓ AbilityConfig 存储 ActiveUseConfig 引用
Ability._resolve_components()  → ✅ 每个角色创建新 Ability
    ↓ ActiveUseComponent.new(cfg)  → ✅ 每个 Ability 创建新 Component
ActiveUseComponent._init()
    ↓ ActivateInstanceConfig.new(config.tag_actions, ...)  → ⚠️ 引用传递！
ActivateInstanceComponent._init()
    ↓ _tag_actions = config.tag_actions  → ❌ Dictionary 引用拷贝，Action 对象共享！

结果：角色 A 和角色 B 的 Component 持有同一个 DamageAction 实例
```

### Action / Condition / Cost 的规则

`execute()` / `check()` / `pay()` 方法**禁止修改 `self` 的任何成员变量**。

```gdscript
# ❌ 错误：Action 内部有可变状态
class BadAction extends Action.BaseAction:
    var _count := 0
    
    func execute(ctx: ExecutionContext) -> void:
        _count += 1  # 禁止！修改了 self，会污染其他角色
        if _count % 2 == 0:
            do_something()

# ✅ 正确：状态存放在外部（AbilitySet.tag_container）
class GoodAction extends Action.BaseAction:
    func execute(ctx: ExecutionContext) -> void:
        var ability_set := _get_owner_ability_set(ctx)
        var count: int = ability_set.tag_container.get_stacks("my_counter")
        ability_set.tag_container.apply_tag("my_counter", -1.0, count + 1)
        if count % 2 == 0:
            do_something()
```

### 状态应该放在哪里

| 状态类型 | 存放位置 | 示例 |
|---------|---------|------|
| 跨技能状态 | `AbilitySet.tag_container` | Buff、全局效果 |
| 单技能跨次施法状态 | `AbilitySet.tag_container`（Tag + Stacks） | 连击计数、PRD |
| 单次施法内状态 | `execute()` 局部变量 | 弹跳目标列表 |

### Debug 检测

框架可通过项目设置启用 Action/Condition/Cost 状态检测。
启用后，如果 `execute()` / `check()` / `pay()` 修改了 `self`，会触发断言失败。

**启用方式**：在 `Project Settings` 中添加：
```
logic_game_framework/debug/action_state_check = true
```

或在代码中设置：
```gdscript
ProjectSettings.set_setting("logic_game_framework/debug/action_state_check", true)
```

详见：[Action 无状态设计决策](docs/design-decisions/action-stateless-design.md)