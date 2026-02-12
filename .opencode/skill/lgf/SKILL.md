---
name: lgf
description: Use when writing or modifying GDScript code that uses Logic Game Framework - Actor creation/registration, AbilitySet/AttributeSet access, Action/Condition/Cost implementation (statelessness rules), PreEventConfig handlers (Intent returns), Resolvers, or event system. Required for any gameplay logic in inkmon-godot.
---

# Logic Game Framework - Coding Conventions

This skill contains the coding rules for the Logic Game Framework used in the inkmon-godot project. Subagents MUST follow these conventions when writing GDScript code that interacts with the framework.

---

## 1. Attribute Access

Direct access `actor.attribute_set`, no getter/setter wrappers.

```gdscript
# DO
var hp := actor.attribute_set.hp
actor.attribute_set.hp -= damage

# DON'T
func get_hp() -> float:
    return attribute_set.hp
```

**Exception**: Methods with business logic are fine:

```gdscript
class_name CharacterActor extends Node

var attribute_set: AttributeSet  # public

# OK - has logic
func is_alive() -> bool:
    return attribute_set.hp > 0

func take_damage(amount: float) -> void:
    var old_hp := attribute_set.hp
    attribute_set.hp = max(0, attribute_set.hp - amount)
    if old_hp > 0 and attribute_set.hp <= 0:
        emit_signal("died")
```

---

## 2. Actor Creation & Registration

Two-step process: **construct** then **register**.

```gdscript
# Step 1: new()
var actor := CharacterActor.new(char_class)
# Step 2: register (framework assigns full ID)
instance.add_actor(actor)

# In Action: get instance via source actor
var source_actor := GameWorld.get_actor(source_actor_id)
var instance := source_actor.get_owner_gameplay_instance()
instance.add_actor(projectile)
```

### ID Assignment

| Phase | Actor._id | Notes |
|-------|-----------|-------|
| After `SomeActor.new()` | Empty string | Do NOT generate ID in `_init` |
| After `add_actor()` | `{instance_id}:{local_id}` | Framework auto-generates, calls `_on_id_assigned()` |

### `_on_id_assigned()` Callback

Override when components created in `_init` need the actor ID:

```gdscript
func _on_id_assigned() -> void:
    ability_set.owner_actor_id = get_id()
    attribute_set.actor_id = get_id()
```

### `get_owner_gameplay_instance()`

Like UE's `GetWorld()`. Uses stored `_instance_id` + `GameWorld.get_instance_by_id()` to avoid RefCounted circular references.

---

## 3. Instance Ownership & State Constraints (CRITICAL)

### Object Categories

| Type | Creation | Ownership | Mutable State? |
|------|----------|-----------|----------------|
| Ability | `AbilityConfig` -> per-character instance | Per character | YES |
| AbilityComponent | `ActiveUseComponent.new(cfg)` per Ability | Per Ability | YES |
| **Action** | `.new(...)` in `static var` | **SHARED across all characters** | **NO** |
| **Condition** | Same as Action | **SHARED** | **NO** |
| **Cost** | Same as Action | **SHARED** | **NO** |
| **TriggerConfig** | `.new(...)` in `static var` or Builder | **SHARED** | **NO** |

### Why Shared

Ability configs use `static var` - `.new()` runs once at class load:

```gdscript
static var SLASH_ABILITY := (
    AbilityConfig.builder()
    .active_use(
        ActiveUseConfig.builder()
        .on_tag(TimelineTags.HIT, [DamageAction.new(...)])  # Created ONCE!
        .build()
    )
    .build()
)
```

Although each character gets independent Ability and Component instances, the Action/Condition/Cost objects inside are **passed by reference** - all characters share the same instances.

### RULE: Action/Condition/Cost execute()/check()/pay() MUST NOT modify `self`

```gdscript
# WRONG: mutable state in shared Action
class BadAction extends Action.BaseAction:
    var _count := 0
    func execute(ctx: ExecutionContext) -> void:
        _count += 1  # FORBIDDEN - pollutes other characters

# CORRECT: state in external storage (tag_container)
class GoodAction extends Action.BaseAction:
    func execute(ctx: ExecutionContext) -> void:
        var ability_set := _get_owner_ability_set(ctx)
        var count: int = ability_set.tag_container.get_stacks("my_counter")
        ability_set.tag_container.apply_tag("my_counter", -1.0, count + 1)
```

### Where to Store State

| State Type | Location | Example |
|-----------|----------|---------|
| Cross-ability state | `AbilitySet.tag_container` | Buffs, global effects |
| Single-ability cross-cast state | `AbilitySet.tag_container` (Tag + Stacks) | Combo count, PRD |
| Single-cast state | Local variables in `execute()` | Bounce target list |

### Debug Detection

Enable in Project Settings:
```
logic_game_framework/debug/action_state_check = true
```

---

## 4. GameStateProvider Variant Design

`IGameStateProvider.get_game_state()` intentionally returns `Variant` - framework must not constrain game state type (could be Dictionary, RefCounted, Node).

**This is the ONLY acceptable Variant return in the framework.** Other functions using Variant are design errors.

---

## 5. Resolvers - Parameter Resolution

Type-safe delayed evaluation for shared objects (Actions etc.). Create via `Resolvers` factory, evaluate via `resolve(ctx: ExecutionContext)`.

| Resolver | Return Type | Fixed Value | Dynamic Value |
|----------|-------------|-------------|---------------|
| `FloatResolver` | `float` | `Resolvers.float_val(v)` | `Resolvers.float_fn(fn)` |
| `IntResolver` | `int` | `Resolvers.int_val(v)` | `Resolvers.int_fn(fn)` |
| `StringResolver` | `String` | `Resolvers.str_val(v)` | `Resolvers.str_fn(fn)` |
| `DictResolver` | `Dictionary` | `Resolvers.dict_val(v)` | `Resolvers.dict_fn(fn)` |
| `Vector3Resolver` | `Vector3` | `Resolvers.vec3_val(v)` | `Resolvers.vec3_fn(fn)` |

`ParamResolver.resolve_param(resolver: Variant, ctx)` accepting Variant is intentional - must handle all Resolver types + raw Callable. Prefer typed Resolvers in new code.

---

## 6. PreEventConfig Handler Convention

### Handler Signature

**MUST** be: `func(MutableEvent, AbilityLifecycleContext) -> Intent`

**Return value MUST be Intent. Never omit return.** Framework asserts at runtime. Missing return = null = assertion failure.

### Intent Options

| Return | Meaning | Use Case |
|--------|---------|----------|
| `EventPhase.pass_intent()` | Pass through, no modification | Condition not met, skip |
| `EventPhase.modify_intent(id, [Modification])` | Modify event fields | Damage reduction/amplification |
| `EventPhase.cancel_intent(id, reason)` | Cancel event | Immunity, block, invincible |

### Correct Examples

```gdscript
# Modify event
PreEventConfig.new(
    "pre_damage",
    func(mutable: MutableEvent, ctx: AbilityLifecycleContext) -> Intent:
        return EventPhase.modify_intent(ctx.ability.id, [
            Modification.multiply("damage", 0.7),
        ]),
    func(event: Dictionary, ctx: AbilityLifecycleContext) -> bool:
        return event.get("target_actor_id") == ctx.owner_actor_id,
    "30% damage reduction"
)

# Conditional with all branches returning Intent
PreEventConfig.new(
    "pre_damage",
    func(mutable: MutableEvent, ctx: AbilityLifecycleContext) -> Intent:
        if some_condition:
            return EventPhase.cancel_intent(ctx.ability.id, "immune")
        return EventPhase.pass_intent()
)
```

### Common Mistakes

```gdscript
# WRONG: forgot return -> null -> assertion failure
func(mutable: MutableEvent, ctx: AbilityLifecycleContext) -> Intent:
    EventPhase.modify_intent(ctx.ability.id, [...])
    # Missing return!

# WRONG: wrong return type
func(mutable: MutableEvent, ctx: AbilityLifecycleContext) -> Intent:
    return true  # bool is not Intent
```

### Filter (Optional)

Signature: `func(Dictionary, AbilityLifecycleContext) -> bool`

Filters events before handler. Return `true` = process this event. No filter = process all matching events.

---

## 7. GameWorld Hard Dependency

Framework directly references `GameWorld` Autoload in multiple places. This is an **intentional design tradeoff**, not a defect. Do not attempt to decouple it.
