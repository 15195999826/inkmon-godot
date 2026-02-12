---
description: Review GDScript files against coding conventions
---

# Review GDScript Coding Conventions

Review all `.gd` files under the specified path for compliance with the project's GDScript coding conventions.

**Target path**: `$ARGUMENTS`

## Instructions

Load the `gdscript-coding` skill, then review every `.gd` file under the target path.

For each file, check ALL of the following rules:

1. **Variable shadowing** — No base class property/method names used as variable names. Verify against actual inheritance chain before flagging.
2. **Global class preload** — `class_name` classes used directly, not via `preload()`.
3. **Branch variable confusion** — No same-name variables across branches in one function.
4. **Function signature types** — All parameters and return types explicitly annotated (void may be omitted).
5. **Variable type inference** — `:=` for literals and typed method returns. Explicit type for `load()`, `get()`, `.new()` on dynamic scripts.
6. **Typed Arrays** — `Array[T]` when element type is uniform.
7. **Variant avoidance** — No `-> Variant` returns unless truly necessary. Use `as` cast when unavoidable.
8. **Interface pattern** — Inheritance preferred over `has_method`. `I*` utility classes only for cross-module/protocol scenarios.
9. **Unused param prefix** — `_` prefix on unused function parameters.
10. **Lambda capture** — Mutable state wrapped in Dictionary, not bare variables.
11. **Assertions** — `Log.assert_crash()` only, no bare `assert()`.
12. **Autoload extends Node** — Autoload scripts must `extends Node`.
13. **Static-only classes** — No `extends RefCounted` on classes that are never instantiated.
14. **Value-type null** — `Dictionary`/`Array` returns use `{}`/`[]` instead of `null`.

## Output Format

For each violation found, report:

```
## <file_path>

### [Rule N] <Rule Name>
- **Line**: <line number>
- **Issue**: <what's wrong>
- **Fix**: <suggested correction>
```

If a file has no violations, skip it (don't list clean files).

At the end, provide a summary:

```
## Summary

- Files scanned: N
- Files with violations: N
- Total violations: N
- By rule: Rule 1: N, Rule 5: N, ...
```
