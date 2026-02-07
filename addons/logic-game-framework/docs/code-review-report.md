# Logic Game Framework 代码审查报告

> 审查日期: 2026-02-07
> 审查范围: `addons/logic-game-framework/` 全部 ~100 个 GDScript 文件
> 审查依据: 项目根目录 `AGENTS.md` 编码规范 + 框架 `AGENTS.md` 使用规范

---

## 目录

1. [审查摘要](#审查摘要)
2. [编码规范合规性](#编码规范合规性)
   - [类型标注缺失](#1-类型标注缺失variant-返回值未显式标注)
   - [未类型化 Array](#2-未类型化-array)
   - [其他规范问题](#3-其他规范问题)
3. [设计缺陷](#设计缺陷)
   - [严重 Bug](#1-严重-bugmoba_collision_detectorget_target-不存在)
   - [全局依赖耦合](#2-全局依赖耦合gameworld-硬依赖)
   - [类型安全问题](#3-类型安全问题)
   - [架构设计问题](#4-架构设计问题)
4. [积极发现](#积极发现)
5. [优先级建议](#优先级建议)

---

## 审查摘要

| 类别 | 数量 | 严重度 |
|------|------|--------|
| 类型标注缺失 (Variant 返回值) | ~25 处 | 中 |
| 未类型化 Array | ~10 处 | 低-中 |
| 严重 Bug | 1 处 | **严重** |
| 全局依赖耦合 | 6 处 | 高 |
| 类型安全问题 | 3 处 | 中 |
| 架构设计关注 | 5 处 | 中 |

**总体评价**: 框架整体代码质量**较高**，架构设计清晰（逻辑-表现分离、事件驱动、组件化）。主要问题集中在两方面：(1) 对 `Dictionary.get()` / `Object.get()` 等返回 Variant 的方法缺乏显式类型标注；(2) 多处核心逻辑硬依赖 `GameWorld` Autoload，影响可测试性。

---

## 编码规范合规性

### 1. 类型标注缺失（Variant 返回值未显式标注）

> AGENTS.md 规定: "load() / get() 等返回 Variant 的方法需要显式类型"

#### mutable_event.gd

| 行号 | 代码 | 修复建议 |
|------|------|----------|
| 37 | `var original_value = original.get(field, null)` | `var original_value: Variant = original.get(field, null)` |
| 69 | `var original_value = original.get(field, null)` | 同上 |
| 106 | `var record = get_field_computation_steps(str(field))` | `var record: Array[Dictionary] = ...` |
| 112 | `var record = get_field_computation_steps(field)` | 同上 |

#### tag_action.gd

| 行号 | 代码 | 修复建议 |
|------|------|----------|
| 10 | `var actor = GameWorld.get_actor(target.id)` | `var actor: Actor = GameWorld.get_actor(target.id)` |
| 14 | `var event = ctx.get_current_event()` | `var event: Dictionary = ctx.get_current_event()` |
| 44 | `var targets = get_targets(ctx)` | `var targets: Array[TargetSelector.TargetRef] = get_targets(ctx)` |
| 48 | `var ability_set = TagAction._get_ability_set_for_target(ctx, target)` | `var ability_set: AbilitySet = ...` |
| 79 | `var targets = get_targets(ctx)` | 同上 |
| 82 | `var ability_set = ...` | 同上 |
| 123 | `var targets = get_targets(ctx)` | 同上 |
| 126 | `var ability_set = ...` | 同上 |
| 130 | `var actions = then_actions if has_tag else else_actions` | `var actions: Array[Action.BaseAction] = ...` |

#### projectile_actor.gd

| 行号 | 代码 | 修复建议 |
|------|------|----------|
| 141 | `var max_pierce = config.get(...)` | `var max_pierce: int = int(config.get(...))` |

#### launch_projectile_action.gd

| 行号 | 代码 | 修复建议 |
|------|------|----------|
| 78 | `var target = targets[0]` | `var target: TargetSelector.TargetRef = targets[0]` |
| 103 | `var launched_event = ...` | `var launched_event: Dictionary = ...` |
| 163 | `var actor_ref = actor_ref_resolver.call(ctx)` | `var actor_ref: Variant = actor_ref_resolver.call(ctx)` |

#### battle_recorder.gd

| 行号 | 代码 | 修复建议 |
|------|------|----------|
| 78 | `var record = stop_recording(result)` | `var record: ReplayData = stop_recording(result)` |
| 112 | `var subscription = actor_subscriptions.get(actor_id)` | `var subscription: Variant = actor_subscriptions.get(actor_id)` |

#### replay_log_printer.gd

| 行号 | 代码 | 修复建议 |
|------|------|----------|
| 5-7 | `var xxx = record.get(...)` (多处) | 添加显式类型标注 |

#### raw_attribute_set.gd

| 行号 | 代码 | 修复建议 |
|------|------|----------|
| 65 | `var hook_result = _invoke_pre_hook(...)` | `var hook_result: Variant = _invoke_pre_hook(...)` |
| 104 | `var constraint = _constraints.get(name, null)` | `var constraint: Variant = _constraints.get(name, null)` |
| 335 | `var hook = attr_hooks[hook_name]` | `var hook: Variant = attr_hooks[hook_name]` |
| 337 | `var result = hook.call(event)` | `var result: Variant = hook.call(event)` |
| 342 | `var global_hook = _global_hooks[hook_name]` | `var global_hook: Variant = _global_hooks[hook_name]` |
| 344 | `var result = global_hook.call(event)` | `var result: Variant = global_hook.call(event)` |
| 364 | `var raw_array = _modifiers.get(name, [])` | `var raw_array: Variant = _modifiers.get(name, [])` |

#### cost.gd / condition.gd (共享模式)

| 行号 | 文件 | 代码 | 修复建议 |
|------|------|------|----------|
| 39 | cost.gd | `var value = get(prop_name)` | `var value: Variant = get(prop_name)` |
| 38 | condition.gd | `var value = get(prop_name)` | `var value: Variant = get(prop_name)` |

#### attribute_set_generator_script.gd

| 行号 | 代码 | 修复建议 |
|------|------|----------|
| 183 | `var left = cfg["left"]` | `var left: Variant = cfg["left"]` |
| 184 | `var right = cfg["right"]` | `var right: Variant = cfg["right"]` |

---

### 2. 未类型化 Array

> AGENTS.md 规定: "Array 如果元素类型相同，必须类型化"

| 文件 | 行号 | 代码 | 修复建议 |
|------|------|------|----------|
| mutable_event.gd | 77 | `var steps := []` | `var steps: Array[Dictionary] = []` |
| ability.gd | 162 | `var serialized_components := []` | `var serialized_components: Array[Dictionary] = []` |
| ability.gd | 168 | `var serialized_instances := []` | `var serialized_instances: Array[Dictionary] = []` |
| ability_set.gd | 87 | `var to_revoke := []` | `var to_revoke: Array[Ability] = []` |
| ability_set.gd | 96 | `var to_revoke := []` | `var to_revoke: Array[Ability] = []` |
| ability_set.gd | 177 | `var abilities := []` | `var abilities: Array[Dictionary] = []` |
| tag_container.gd | 157 | `var tag_list := []` | `var tag_list: Array[String] = []` |
| tag_container.gd | 183 | `var tag_list := []` | `var tag_list: Array[String] = []` |
| battle_recorder.gd | 141 | `var unsubscribes: Array = ...` | `var unsubscribes: Array[Callable] = ...` |
| tests/world_test.gd | 22 | `func tick(_actors: Array, ...)` | `func tick(_actors: Array[Actor], ...)` |

---

### 3. 其他规范问题

#### 函数参数类型缺失

| 文件 | 行号 | 代码 | 修复建议 |
|------|------|------|----------|
| tests/pre_event_component_test.gd | 34 | `func _build_context(state, event:...)` | `func _build_context(state: Variant, event:...)` |

#### bg_9f095ab9 代理补充：函数返回类型缺失

bg_9f095ab9 后台代理报告了大量函数缺少返回类型标注（`-> void` / `-> Type`），涉及以下文件的大部分方法：

- `ability_component.gd` — `get_state()`, `initialize()`, `is_active()`, `mark_expired()`, `is_expired()`, `get_ability()`, `on_tick()`, `on_event()`, `on_apply()`, `on_remove()`, `serialize()`, `match_triggers()`, `match_single_trigger()` 等 13 个方法
- `ability.gd` — `get_state()`, `is_granted()`, `is_expired()`, `get_expire_reason()`, `get_all_components()`, `tick()`, `tick_executions()`, `get_executing_instances()`, `cancel_all_executions()`, `receive_event()`, `add_triggered_listener()`, `apply_effects()`, `remove_effects()`, `expire()`, `has_ability_tag()`, `serialize()` 等 21 个方法
- `System.gd` — `get_enabled()`, `set_enabled()`, `on_register()`, `on_unregister()`, `tick()`, `get_logic_time()`, `filter_actors_by_type()` 等 7 个方法
- `Actor.gd` — `get_id()`, `is_id_valid()`, `set_id()`, `get_team()`, `set_team()`, `on_spawn()`, `on_despawn()`, `to_ref()`, `serialize_base()`, `setup_recording()` 等 20+ 方法
- `projectile_actor.gd` — `get_projectile_state()`, `is_flying()`, `launch()`, `update()`, `update_position()`, `hit()`, `miss()`, `despawn()`, `serialize()` 等 15 个方法
- `projectile_system.gd` — `tick()`, `_update_projectile()`, `_process_hitscan()`, `_process_hit()`, `_filter_valid_targets()`, `_emit_hit_event()`, `_emit_miss_event()`, `get_active_projectiles()`, `force_hit()`, `force_miss()` 等 15 个方法
- `game_event.gd` — 多个内部类的 `create()`, `from_dict()`, `to_dict()` 方法

**注意**: 这些方法缺少 `-> void` / `-> Type` 返回类型标注。AGENTS.md 规定 "函数参数和返回值必须显式标注类型"，其中 "void 类型可省略"。因此**只有非 void 返回值的函数**需要修复。上述列表中的纯 void 方法（如 `on_tick()`, `on_apply()` 等）如果省略 `-> void` 是**合规的**。

需要修复的是**有返回值但缺少返回类型标注的方法**，如 `get_state() -> String`, `is_granted() -> bool`, `serialize() -> Dictionary` 等。

---

## 设计缺陷

### 1. 严重 Bug：`moba_collision_detector.get_target()` 不存在

**文件**: `stdlib/systems/moba_collision_detector.gd` L8

```gdscript
var target_id: String = projectile.get_target()
```

**问题**: `ProjectileActor` 类**没有** `get_target()` 方法。该类有 `target_actor_id` 属性和 `get_target_actor_id()` getter，但没有 `get_target()`。

**影响**: 运行时调用会导致错误。这可能是：
- 重命名 API 后的遗留代码
- 未被测试覆盖的死代码路径

**修复建议**:
```gdscript
var target_id: String = projectile.get_target_actor_id()
# 或
var target_id: String = projectile.target_actor_id
```

**严重度**: 🔴 **严重** — 会在运行时崩溃

---

### 2. 全局依赖耦合（GameWorld 硬依赖）

框架内多处直接引用 `GameWorld` Autoload，破坏了框架的可测试性和可移植性。

| 文件 | 行号 | 引用 | 影响 |
|------|------|------|------|
| event_processor.gd | 238 | `GameWorld.get_actor()` | 事件处理器无法脱离 GameWorld 单元测试 |
| ability_ref.gd | 80 | `GameWorld.get_actor(owner_actor_id)` | 技能引用解析依赖全局状态 |
| ability_set.gd | 22 | `GameWorld.event_processor` | AbilitySet 无法独立测试 |
| ability_execution_instance.gd | 131 | `GameWorld.event_collector` | 技能执行依赖全局事件收集器 |
| no_instance_component.gd | 55 | `GameWorld.event_collector` | 组件依赖全局事件收集器 |
| tag_action.gd | 10 | `GameWorld.get_actor(target.id)` | Action 依赖全局状态 |

**影响**:
- 单元测试必须启动完整 GameWorld
- 框架无法在非 Autoload 环境中复用
- 隐式依赖使代码难以推理

**改进建议**: 考虑依赖注入模式 — 通过 `ExecutionContext` 或 `AbilityLifecycleContext` 传入需要的服务引用，而非直接访问全局单例。这是一个**架构级改进**，优先级不高但长期有价值。

**严重度**: 🟠 **高** — 影响可测试性，但不影响运行时正确性

---

### 3. 类型安全问题

#### 3.1 Vector3 truthy 检查不安全

**文件**: `stdlib/systems/distance_collision_detector.gd` L10

```gdscript
if not projectile.position:
    return []
```

**问题**: `Vector3.ZERO` 是 falsy，这意味着位于原点 `(0,0,0)` 的投射物会被错误跳过。

**修复建议**:
```gdscript
if projectile.position == null:
    return []
# 或者完全移除此检查（position 通常不会为 null）
```

#### 3.2 typeof 检查冗余

**文件**: `stdlib/systems/distance_collision_detector.gd` L13-14

```gdscript
if typeof(projectile.position) != TYPE_VECTOR3:
    return []
```

**问题**: 如果 `position` 已经是 `Vector3` 类型属性，此检查永远为 true，是多余的防御性代码。

#### 3.3 Dictionary.get() 返回 Variant 未转换

**文件**: `stdlib/systems/projectile_system.gd` L85

```gdscript
collision.get("hitPosition")  # 返回 Variant，赋值给期望 Vector3 的变量
```

**修复建议**: 使用 `as Vector3` 显式转换。

**严重度**: 🟡 **中** — 可能导致隐蔽的运行时错误

---

### 4. 架构设计问题

#### 4.1 ProjectileSystem 直接修改传入数组

**文件**: `stdlib/systems/projectile_system.gd` L122-128

`_process_pending_removal()` 方法直接在传入的 `actors` 数组上调用 `remove_at()`，修改了调用方的数据。

**影响**: 调用方可能不期望传入的数组被修改，产生副作用 Bug。

**修复建议**: 返回新数组或使用明确的移除回调。

#### 4.2 Ability 类职责偏多

**文件**: `core/abilities/core/ability.gd` (220 行)

Ability 同时管理：状态管理、组件生命周期、执行实例管理、事件接收分发、回调注册、序列化。

**评价**: 行数不算过多（220行），职责虽多但围绕 "技能" 这一核心概念展开，当前可接受。如果后续功能增长，建议拆分状态管理和执行实例管理。

#### 4.3 缺少 class_name 的 Autoload

**文件**: `core/world/game_world.gd`, `core/timeline/timeline.gd`

作为 Autoload 节点不定义 `class_name` 是 Godot 常见做法，但会导致无法在类型系统中静态引用这些类。

**评价**: 这是 Godot Autoload 的惯用模式，**不视为缺陷**，仅作记录。

#### 4.4 事件系统大量使用 Dictionary

框架的事件系统核心使用 `Dictionary` 传递事件数据（如 `GameEvent.create_xxx()` 返回 `Dictionary`）。

**优点**: 灵活，支持录像系统序列化，对框架用户无侵入。

**缺点**: 运行时无类型检查，字段名拼写错误只在运行时暴露。

**评价**: 这是框架 "逻辑-表现分离 + 录像系统" 的**核心设计决策**，Dictionary 事件是序列化友好的。权衡合理，**不视为缺陷**。

#### 4.5 AbilityComponent 基类返回类型宽泛

`AbilityComponent` 的虚方法（如 `get_state()`, `serialize()`）在基类中缺少返回类型标注，子类需要"猜测"正确的返回类型。

**修复建议**: 为基类虚方法添加明确的返回类型标注（`-> Dictionary`, `-> String` 等），作为子类实现的契约。

---

## 积极发现

以下方面代码质量**优秀**，值得肯定：

1. **接口模式规范** — `IAbilitySetOwner`, `IGameStateProvider` 完全遵循 AGENTS.md 的 `I*` 静态工具类模式
2. **无状态约束机制** — Action/Condition/Cost 通过 `_freeze()` + `_verify_unchanged()` 在 Debug 模式下校验无状态约束，设计精巧
3. **属性系统类型安全** — `AttributeModifier` 使用 enum Type 替代字符串常量，`AttributeBreakdown` 替代 Dictionary，类型安全
4. **`AttributeCalculator` 纯静态工具类** — 无 `extends`，完全符合 AGENTS.md 规范
5. **`TimelineTags` 常量类** — 无 `extends`，纯常量定义，符合规范
6. **Lambda 捕获处理** — `RecordingUtils` 中正确使用字典包装可变状态
7. **类型化 Array 广泛使用** — `Array[Actor]`, `Array[AttributeModifier]`, `Array[Condition]`, `Array[Action.BaseAction]` 等
8. **Builder 模式** — `AbilityConfig.builder()` 链式调用 API 设计清晰
9. **构造函数参数命名** — 使用 `_value` 后缀或 `p_` 前缀避免与成员变量同名混淆
10. **事件驱动架构** — EventProcessor + MutableEvent + Intent + Modification 构成完整的事件拦截-修改管道

---

## 优先级建议

### P0 - 立即修复（影响运行时正确性）

| 问题 | 文件 | 说明 |
|------|------|------|
| `get_target()` 方法不存在 | moba_collision_detector.gd:8 | 运行时崩溃，改为 `get_target_actor_id()` |
| Vector3 truthy 检查 | distance_collision_detector.gd:10 | `Vector3.ZERO` 被误判为 falsy |

### P1 - 短期修复（编码规范合规）

| 问题 | 范围 | 工作量 |
|------|------|--------|
| Variant 返回值显式标注 | ~25 处 | 低 |
| 未类型化 Array | ~10 处 | 低 |
| 基类虚方法添加返回类型 | ability_component.gd, Actor.gd, System.gd | 中 |

### P2 - 中期改进（代码质量提升）

| 问题 | 范围 | 工作量 |
|------|------|--------|
| 有返回值的函数添加返回类型标注 | ~80+ 个方法 | 中-高 |
| `_process_pending_removal` 副作用 | projectile_system.gd | 低 |
| Dictionary.get() Variant 转换 | projectile_system.gd:85 | 低 |

### P3 - 长期架构改进（可选）

| 问题 | 范围 | 工作量 |
|------|------|--------|
| GameWorld 硬依赖注入化 | 6 处核心文件 | 高 |
| Ability 类职责拆分 | ability.gd | 高 |

---

*审查工具: 人工代码审查 + 自动化 AST 分析*
*审查覆盖: core/ (67文件) + stdlib/ (16文件) + tests/ (19文件) + example/ (20+文件)*
