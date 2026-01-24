# Logic Game Framework 文档

本框架是一个用于构建回合制/ATB 战斗系统的 GDScript 框架，从 TypeScript 版本迁移而来。

## 快速开始

### 核心概念

- **Action**: 技能效果的最小执行单元（伤害、治疗、移动等）
- **Ability**: 技能配置，包含触发条件、消耗、Timeline 和 Actions
- **Timeline**: 定义技能执行的时间轴和关键帧（tags）
- **TargetSelector**: 目标选择器，决定 Action 作用于哪些目标
- **ExecutionContext**: 执行上下文，包含当前事件、Ability、GameplayState 等

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

## 项目结构

```
addons/logic-game-framework/
├── core/                    # 框架核心
│   ├── actions/            # Action 基类、TargetSelector
│   ├── ability/            # Ability 系统
│   ├── events/             # 事件系统
│   └── timeline/           # Timeline 系统
├── stdlib/                  # 标准库
│   └── actions/            # 通用 Action（StageCueAction 等）
├── example/                 # 示例项目
│   └── hex-atb-battle/     # 六边形 ATB 战斗示例
│       ├── actions/        # 游戏特定 Action
│       ├── skills/         # 技能配置
│       └── docs/           # 示例文档
└── docs/                    # 框架文档
    ├── README.md           # 本文件
    └── reference/          # 详细参考文档
```

## 版本历史

- **v0.2.0** - Action 构造函数重构：Dictionary → 类型化参数
- **v0.1.0** - 初始版本，从 TypeScript 迁移
