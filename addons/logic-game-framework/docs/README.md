# Logic Game Framework 文档

本框架是一个用于构建回合制/ATB 战斗系统的 GDScript 框架，从 TypeScript 版本迁移而来。

## 快速开始

### 核心概念

- **Action**: 技能效果的最小执行单元（伤害、治疗、移动等）
- **Ability**: 技能配置，包含触发条件、消耗、Timeline 和 Actions
- **Timeline**: 定义技能执行的时间轴和关键帧（tags）
- **TargetSelector**: 目标选择器，决定 Action 作用于哪些目标
- **ExecutionContext**: 执行上下文，包含当前事件、Ability、game_state_provider 等

### 基本用法

```gdscript
# 创建一个伤害 Action
var damage_action = HexBattleDamageAction.new(
    TargetSelector.current_target(),  # 目标选择器
    50.0,                              # 伤害值
    DamageType.PHYSICAL                # 伤害类型
)

# 带回调的伤害 Action（暴击时额外伤害）
var damage_with_callback = HexBattleDamageAction.new(
    TargetSelector.current_target(),
    50.0,
    DamageType.PHYSICAL
).on_critical(
    HexBattleDamageAction.new(
        TargetSelector.current_target(),
        10.0,
        DamageType.PHYSICAL
    )
)
```

## 文档索引

### 核心参考

| 文档 | 描述 |
|------|------|
| [Action 系统](./reference/action-system.md) | Action 基类、构造函数规范、回调系统 |
| [TargetSelector](./reference/target-selector.md) | 目标选择器的使用方式 |

### 实践指南

| 文档 | 描述 |
|------|------|
| [逻辑层到表演层数据传递](../example/hex-atb-battle/docs/logic-to-presentation-guide.md) | StageCue 事件、Timeline 配置、数据流架构 |

## 重要约定

### 1. 子类必须显式调用 `super._init()`

所有继承 `Action.BaseAction` 的子类，**必须**在 `_init()` 中显式调用 `super._init(target_selector)`：

```gdscript
# ✅ 正确
func _init(
    target_selector: TargetSelector,
    damage: float
) -> void:
    super._init(target_selector)  # 必须调用！
    _damage = damage

# ❌ 错误 - 忘记调用 super._init()
func _init(
    target_selector: TargetSelector,
    damage: float
) -> void:
    _damage = damage  # _target_selector 未初始化！
```

**原因**: GDScript 不会自动调用父类构造函数。如果不调用 `super._init()`，`_target_selector` 将为 `null`，导致运行时错误。

### 2. 使用类型化构造函数

所有 Action 使用类型化参数，而非 Dictionary：

```gdscript
# ✅ 正确 - 类型化参数
HexBattleDamageAction.new(
    TargetSelector.current_target(),
    50.0,
    DamageType.PHYSICAL
)

# ❌ 错误 - Dictionary 参数（已废弃）
HexBattleDamageAction.new({
    "targetSelector": TargetSelector.current_target(),
    "damage": 50.0,
    "damage_type": DamageType.PHYSICAL,
})
```

### 3. TargetSelector 使用工厂方法

```gdscript
# 获取当前事件的目标
TargetSelector.current_target()

# 获取 Ability 的所有者
TargetSelector.ability_owner()

# 固定目标（测试用）
TargetSelector.fixed([actor_ref1, actor_ref2])
```

### 4. GameStateProvider 最佳实践

`ExecutionContext.game_state_provider` 是框架传递游戏状态的机制。**框架层不知道也不应该知道它的具体类型**，这是设计意图。

#### 框架层 vs 项目层

| 层级 | 职责 | 类型 |
|------|------|------|
| **框架层** | 传递游戏状态引用 | `Variant`（无类型） |
| **项目层** | 转换为具体类型并使用 | 项目定义的类型（如 `HexBattle`） |

#### 推荐做法：创建项目级 Utils 类

项目层应创建一个 `[ProjectName]GameStateUtils` 类，包含：
- 只有静态函数，不保存任何状态
- 显式指定 `game_state_provider` 的具体类型
- 封装所有需要访问游戏状态的辅助函数

```gdscript
## HexBattleGameStateUtils - 项目层的 GameState 辅助函数
class_name HexBattleGameStateUtils

## 获取角色显示名称
static func get_actor_display_name(actor_ref: ActorRef, game_state_provider: HexBattle) -> String:
    if actor_ref == null:
        return "???"
    if game_state_provider != null:
        var actor := game_state_provider.get_actor(actor_ref.id)
        if actor != null:
            return actor.get_display_name()
    return actor_ref.id

## 获取用于 EventProcessor 的角色列表
static func get_actors_for_event_processor(game_state_provider: HexBattle) -> Array:
    if game_state_provider == null:
        return []
    var actors: Array = game_state_provider.get_alive_actors()
    var result: Array = []
    for actor in actors:
        if actor != null and actor.has_method("to_event_processor_dict"):
            result.append(actor.to_event_processor_dict())
    return result
```

#### 在 Action 中使用

```gdscript
# 项目层 Action
class_name MyProjectDamageAction
extends Action.BaseAction

func execute(ctx: ExecutionContext) -> ActionResult:
    # 项目层负责类型转换
    var battle: HexBattle = ctx.game_state_provider
    
    # 使用 Utils 类获取类型安全的数据
    var actors := HexBattleGameStateUtils.get_actors_for_event_processor(battle)
    var name := HexBattleGameStateUtils.get_actor_display_name(target, battle)
    
    # ... 业务逻辑
```

#### 为什么这样设计？

1. **框架灵活性**：不同项目可以有完全不同的游戏状态结构
2. **类型安全**：项目层代码获得完整的类型检查和自动补全
3. **代码复用**：辅助函数集中在一处，避免重复
4. **关注点分离**：框架不依赖具体项目实现

## 项目结构

```
addons/logic-game-framework/
├── core/                    # 框架核心
│   ├── actions/            # Action 基类、TargetSelector
│   ├── abilities/          # Ability 系统
│   ├── events/             # 事件系统
│   └── timeline/           # Timeline 系统
├── stdlib/                  # 标准库
│   └── actions/            # 通用 Action（StageCueAction 等）
├── example/                 # 示例项目
│   └── hex-atb-battle/     # 六边形 ATB 战斗示例
│       ├── actions/        # 游戏特定 Action
│       ├── skills/         # 技能配置
│       ├── utils/          # 项目级辅助类（如 HexBattleGameStateUtils）
│       └── docs/           # 示例文档
└── docs/                    # 框架文档
    ├── README.md           # 本文件
    └── reference/          # 详细参考文档
```

## 逻辑表演分离架构 📦

本框架推荐使用三层架构设计，将游戏逻辑与表现层完全分离，提高代码可测试性和可维护性。

### 三层架构设计 🏗️

以 `hex-atb-battle` 示例项目为例，采用以下三层结构：

```
addons/logic-game-framework/example/
├── hex-atb-battle-core/        # 共享数据层（Core Layer）
│   └── events/                 # 强类型事件定义
│       └── battle_events.gd    # BattleEvents（DamageEvent, HealEvent 等）
│
├── hex-atb-battle/             # 逻辑层（Logic Layer）
│   ├── actions/                # 游戏特定 Action（伤害、治疗、移动）
│   ├── skills/                 # 技能配置
│   ├── battle.gd               # 战斗状态管理
│   └── utils/                  # 逻辑层辅助类
│
└── hex-atb-battle-frontend/    # 表演层（Presentation Layer）
    ├── visualizers/            # 事件可视化器（伤害数字、动画）
    ├── battle_player.gd        # 回放播放器
    └── scenes/                 # 3D 场景、UI
```

### 设计原则 🎯

1. **单向依赖**：`frontend → battle → core`
   - 表演层依赖逻辑层和共享层
   - 逻辑层仅依赖共享层
   - 共享层无依赖（纯数据）

2. **事件驱动**：逻辑层通过事件通知表演层
   - 逻辑层产生事件（DamageEvent, HealEvent）
   - 表演层订阅事件并渲染（伤害数字、动画）

3. **可测试性**：逻辑层独立于 Godot 节点系统
   - 逻辑层使用纯 GDScript 类（RefCounted）
   - 可在无渲染环境下运行单元测试

4. **可复用性**：共享层数据结构可被多个系统使用
   - 事件定义可用于回放、网络同步、AI 训练

### 事件类设计模式 ⚡

所有事件类必须实现以下 5 个方法，确保类型安全和序列化支持：

#### 1. `_init()` - 设置事件类型标识

```gdscript
func _init() -> void:
    kind = "damage"  # 事件类型唯一标识
```

#### 2. `static func create(...)` - 类型安全的工厂方法

```gdscript
static func create(
    target_actor_id: String,
    damage: float,
    damage_type: DamageType = DamageType.PHYSICAL
) -> DamageEvent:
    var e := DamageEvent.new()
    e.target_actor_id = target_actor_id
    e.damage = damage
    e.damage_type = damage_type
    return e
```

#### 3. `func to_dict() -> Dictionary` - 序列化为 JSON

```gdscript
func to_dict() -> Dictionary:
    return {
        "kind": kind,
        "targetActorId": target_actor_id,  # camelCase for JSON
        "damage": damage,
        "damageType": BattleEvents._damage_type_to_string(damage_type),
    }
```

#### 4. `static func from_dict(d: Dictionary)` - 反序列化

```gdscript
static func from_dict(d: Dictionary) -> DamageEvent:
    var e := DamageEvent.new()
    e.target_actor_id = d.get("targetActorId", "")
    e.damage = d.get("damage", 0.0)
    e.damage_type = BattleEvents.string_to_damage_type(d.get("damageType", "physical"))
    return e
```

#### 5. `static func is_match(d: Dictionary) -> bool` - 类型守卫

```gdscript
static func is_match(d: Dictionary) -> bool:
    return d.get("kind") == "damage"
```

### 完整事件类示例 💡

```gdscript
class_name BattleEvents
extends RefCounted

enum DamageType { PHYSICAL, MAGICAL, PURE }

class Base:
    var kind: String = ""
    
    func to_dict() -> Dictionary:
        return { "kind": kind }

class DamageEvent extends Base:
    var target_actor_id: String = ""
    var damage: float = 0.0
    var damage_type: DamageType = DamageType.PHYSICAL
    var source_actor_id: String = ""
    var is_critical: bool = false
    
    func _init() -> void:
        kind = "damage"
    
    static func create(
        target_actor_id: String,
        damage: float,
        damage_type: DamageType = DamageType.PHYSICAL,
        source_actor_id: String = "",
        is_critical: bool = false
    ) -> DamageEvent:
        var e := DamageEvent.new()
        e.target_actor_id = target_actor_id
        e.damage = damage
        e.damage_type = damage_type
        e.source_actor_id = source_actor_id
        e.is_critical = is_critical
        return e
    
    func to_dict() -> Dictionary:
        var d := {
            "kind": kind,
            "targetActorId": target_actor_id,
            "damage": damage,
            "damageType": BattleEvents._damage_type_to_string(damage_type),
            "isCritical": is_critical,
        }
        if source_actor_id != "":
            d["sourceActorId"] = source_actor_id
        return d
    
    static func from_dict(d: Dictionary) -> DamageEvent:
        var e := DamageEvent.new()
        e.target_actor_id = d.get("targetActorId", "")
        e.damage = d.get("damage", 0.0)
        e.damage_type = BattleEvents.string_to_damage_type(d.get("damageType", "physical"))
        e.source_actor_id = d.get("sourceActorId", "")
        e.is_critical = d.get("isCritical", false)
        return e
    
    static func is_match(d: Dictionary) -> bool:
        return d.get("kind") == "damage"

# 枚举序列化辅助函数
static func _damage_type_to_string(damage_type: DamageType) -> String:
    match damage_type:
        DamageType.PHYSICAL: return "physical"
        DamageType.MAGICAL: return "magical"
        DamageType.PURE: return "pure"
        _: return "unknown"

static func string_to_damage_type(s: String) -> DamageType:
    match s:
        "physical": return DamageType.PHYSICAL
        "magical": return DamageType.MAGICAL
        "pure": return DamageType.PURE
        _: return DamageType.PHYSICAL
```

### 序列化约定 🔧

#### Dictionary Keys vs Class Properties

- **Dictionary keys**（JSON）：使用 **camelCase**
  - 原因：JSON 标准约定，便于与前端/网络通信
  - 示例：`"targetActorId"`, `"damageType"`, `"isCritical"`

- **Class properties**（GDScript）：使用 **snake_case**
  - 原因：GDScript 官方代码风格
  - 示例：`target_actor_id`, `damage_type`, `is_critical`

```gdscript
# ✅ 正确示例
class DamageEvent:
    var target_actor_id: String = ""  # snake_case property
    
    func to_dict() -> Dictionary:
        return {
            "targetActorId": target_actor_id,  # camelCase key
        }
```

#### 枚举序列化

枚举值序列化为 **小写字符串**，便于人类阅读和调试：

```gdscript
enum DamageType { PHYSICAL, MAGICAL, PURE }

# 序列化：DamageType.PHYSICAL → "physical"
# 反序列化："physical" → DamageType.PHYSICAL
```

### 为什么使用强类型？ 💪

相比传统的 Dictionary 事件，强类型事件类提供：

1. **编译时类型检查**
   ```gdscript
   # ❌ Dictionary：运行时才发现拼写错误
   var damage = event.get("damge", 0.0)  # 拼写错误！
   
   # ✅ 强类型：编译时报错
   var e := DamageEvent.from_dict(event)
   var damage = e.damge  # LSP 立即提示错误
   ```

2. **IDE 自动补全**
   - 输入 `e.` 后自动显示所有可用属性
   - 减少查文档次数，提高开发效率

3. **重构安全**
   - 重命名属性时，IDE 可自动更新所有引用
   - 避免遗漏导致的运行时错误

4. **文档即代码**
   - 类定义即完整的事件结构文档
   - 类型标注清晰表达数据含义

### 使用示例 🎮

#### 逻辑层：产生事件

```gdscript
# hex-atb-battle/actions/damage_action.gd
class_name HexBattleDamageAction
extends Action.BaseAction

func execute(ctx: ExecutionContext) -> ActionResult:
    var target := _resolve_target(ctx)
    var final_damage := _calculate_damage(target)
    var is_critical := _roll_critical()
    
    # 创建强类型事件
    var event := BattleEvents.DamageEvent.create(
        target.id,
        final_damage,
        _damage_type,
        ctx.source_actor_id,
        is_critical
    )
    
    # 推送到事件收集器
    ctx.event_collector.push(event.to_dict())
    
    return ActionResult.success()
```

#### 表演层：消费事件

```gdscript
# hex-atb-battle-frontend/visualizers/damage_visualizer.gd
class_name DamageVisualizer
extends BaseVisualizer

func can_handle(event: Dictionary) -> bool:
    return BattleEvents.DamageEvent.is_match(event)

func visualize(event: Dictionary, context: Dictionary) -> void:
    # 反序列化为强类型
    var e := BattleEvents.DamageEvent.from_dict(event)
    
    # 类型安全访问
    var target_node := _get_actor_node(e.target_actor_id)
    var damage_text := str(int(e.damage))
    
    if e.is_critical:
        _show_critical_damage(target_node, damage_text)
    else:
        _show_normal_damage(target_node, damage_text)
```

## 版本历史

- **v0.3.0** - 重命名 `gameplay_state` → `game_state_provider`，添加 GameStateUtils 最佳实践
- **v0.2.0** - Action 构造函数重构：Dictionary → 类型化参数
- **v0.1.0** - 初始版本，从 TypeScript 迁移
