---
name: gdscript-coding
description: GDScript coding conventions for this Godot project. Enforces type safety, variable shadowing checks, I* interface pattern, naming conventions (_ prefix for unused params), Log.assert_crash usage, and value-type null avoidance. Use when writing, reviewing, or refactoring GDScript code (.gd files).
---

# GDScript Coding Conventions

## Contents
- [1. Variable Shadowing](#1-variable-shadowing)
- [2. Type Annotations](#2-type-annotations)
- [3. Interface Pattern](#3-interface-pattern)
- [4. Naming & Style](#4-naming--style)
- [5. Misc Rules](#5-misc-rules)
- [Troubleshooting](#troubleshooting)

---

## 1. Variable Shadowing

**Do NOT use base class method/property names as variable names.**

```gdscript
# BAD
var set := RawAttributeSet.new()

# GOOD
var attr_set := RawAttributeSet.new()
```

**Check inheritance chain before flagging shadowing.** `var type` is fine in `RefCounted` subclasses (no `type` property). `var name` shadows only in `Node` subclasses.

**Global classes: use directly, never preload.**

```gdscript
# BAD: shadows global class
const TestFramework = preload("res://tests/test_framework.gd")

# GOOD: use class_name directly
TestFramework.register_test("test", _test)
```

**Avoid same-name variables across branches in one function:**

```gdscript
# BAD
if condition:
    var base_value := 1.0
    return base_value
var base_value := 2.0  # confusing

# GOOD
if condition:
    var fallback_base := 1.0
    return fallback_base
var base_value := 2.0
```

---

## 2. Type Annotations

### Function signatures: ALWAYS explicit types

```gdscript
# BAD
func get_tile(coord) -> GridTileData:

# GOOD
func get_tile(coord: HexCoord) -> GridTileData:
```

Void return type may be omitted.

### Variables: use `:=` for inference

```gdscript
# Literals and method returns: use :=
var count := 0
var collision := detector.detect(projectile, targets)

# Exception: Variant-returning methods need explicit type
var script: GDScript = load("res://my_script.gd") as GDScript
var value: float = dict.get("key", 0.0) as float

# Dynamic load().new() needs explicit type
var instance: RefCounted = script.new()
```

### Typed Arrays: REQUIRED when element type is uniform

```gdscript
# BAD
var targets: Array

# GOOD
var targets: Array[Actor]
var callbacks: Array[Callable] = []
```

### Avoid Variant returns. Use `as` cast when unavoidable

```gdscript
var failures: int = framework.run() as int
```

---

## 3. Interface Pattern

**Default: use inheritance + typed arrays. Avoid `has_method` duck typing.**

```gdscript
var _conditions: Array[Condition] = []

func _check_conditions(ctx: Dictionary) -> bool:
    for condition in _conditions:
        if not condition.check(ctx):
            return false
    return true
```

### When to use `I*` static utility classes

| Scenario | Use `I*`? |
|----------|-----------|
| Common base class exists | NO — use base type directly |
| Cross-module, no shared base | YES |
| Framework must accept user classes | YES |
| Pure protocol ("has method X?") | YES |

### Pattern

```gdscript
class_name IAbilitySetOwner
## Protocol: get_ability_set() -> AbilitySet

static func get_ability_set(owner: Object) -> AbilitySet:
    if owner == null or not owner.has_method("get_ability_set"):
        return null
    return owner.get_ability_set()

static func is_implemented(owner: Object) -> bool:
    return owner != null and owner.has_method("get_ability_set")
```

Usage:

```gdscript
# BAD: scattered has_method
if actor.has_method("get_ability_set"):
    var ability_set = actor.get_ability_set()

# GOOD: centralized via utility class
var ability_set := IAbilitySetOwner.get_ability_set(actor)
if ability_set != null:
    ability_set.apply_tag(...)
```

**Naming**: `I` + protocol name (e.g. `IAbilitySetOwner`). No `extends RefCounted` — static-only classes omit `extends`.

---

## 4. Naming & Style

### Unused parameters: `_` prefix

```gdscript
# Used params: no prefix. Unused: _ prefix.
func check(ctx: AbilityLifecycleContext, _event_dict: Dictionary, _game_state: Variant) -> bool:
    return ctx.ability_set.has_tag(tag)
```

### Lambda capture: wrap mutable state in Dictionary

```gdscript
# BAD: lambda can't modify outer simple types
var hit := false
var callback := func(): hit = true  # won't work

# GOOD
var state := { "hit": false }
var callback := func(): state["hit"] = true
```

---

## 5. Misc Rules

| Rule | Detail |
|------|--------|
| Assertions | Use `Log.assert_crash(condition, module, message)`. Never bare `assert()`. |
| Autoload scripts | MUST `extends Node`. |
| Static-only utility classes | Omit `extends RefCounted` (it's the default and implies instantiation). |
| Value-type "no result" | Return `{}` or `[]`, not `null`. Avoids `-> Variant`. |

Value-type example:

```gdscript
# BAD: forced Variant return
func get_current_event() -> Variant:
    if event_chain.is_empty(): return null
    return event_chain.back()

# GOOD: empty dict preserves type safety
func get_current_event() -> Dictionary:
    if event_chain.is_empty(): return {}
    return event_chain.back()
```

Reference types (`RefCounted`, `Node`, etc.) still return `null` normally.

---

## Troubleshooting

Common GDScript errors and solutions: See [reference/troubleshooting.md](reference/troubleshooting.md)
