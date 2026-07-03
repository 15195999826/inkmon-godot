# Actions API

## Contents
- [Action / BaseAction](#action-extends-refcounted) (layering contract: PrimitiveAction / FlowActionBase / SkillLocalAction)
- [ExecutionContext](#executioncontext-extends-refcounted)
- [ActionResult](#actionresult-extends-refcounted)
- [TargetSelector](#targetselector-extends-refcounted)
- [FlowAction](#flowaction-extends-refcounted)
- [LooseTagAction](#loosetagaction-extends-refcounted)
- [TagAction](#tagaction-extends-refcounted) (deprecated)
- [Resolvers](#resolvers)
- [Supporting Classes](#supporting-classes) (AbilityRef, AbilityExecutionInfo)

## Action (extends RefCounted)

Container class with inner classes for the action system.

**Layering contract** (`core/actions/Action.gd:4-16` header comment; enforced by `tests/core/actions/action_architecture_validator_test.gd`): new Actions must extend a concrete semantic base below, not `Action.BaseAction` directly — historical exceptions are grandfathered via an allowlist.

| Layer | Base class | Timeline-eligible | Purpose |
|---|---|---|---|
| Util | (not an Action subclass) | No | Lowest-level resolution / side-effect functions |
| Primitive Action | `Action.PrimitiveAction` | Yes | Public domain-primitive adapter |
| FlowAction | `Action.FlowActionBase` | Yes | Flow combinator — only organizes child actions |
| SkillLocalAction | `Action.SkillLocalAction` | Yes | Skill-private procedure, asserts owner at runtime |

### Action.BaseAction (extends RefCounted)

Base class for all actions. **SHARED across characters — MUST NOT modify `self`.**

**Properties:**
- `type: String` — Action type identifier

**Methods:**
- `execute(_ctx: ExecutionContext) -> ActionResult` — Override to implement action logic
- `get_targets(ctx: ExecutionContext) -> Array[String]` — Resolve target actor IDs via TargetSelector
- `get_child_actions() -> Array[BaseAction]` — Override when the action holds child actions (e.g. `FlowActionBase` subclasses); default empty. `_freeze()` walks this to freeze children too.

### Action.PrimitiveAction (extends BaseAction)

Thin adapter over a target selector / resolver / util, with no specific-skill knowledge. Must be registered in the public primitive allowlist. Examples: `DamageAction`, `LaunchProjectileAction`, `LooseTagAction.Apply`/`.Remove`.

### Action.FlowActionBase (extends BaseAction)

Flow combinator base — only organizes child actions, carries no business semantics. Currently the only approved subclass is `FlowAction.if_`'s `IfAction`. Subclasses must override `get_child_actions()` to return every child reference so they participate in `_freeze()`/`_verify_unchanged()`.

### Action.SkillLocalAction (extends BaseAction)

Serves exactly one Ability; `execute()` asserts at runtime that the currently-executing ability's `config_id` matches `owner_config_id`, then delegates to `_execute_local()`. Must not use `class_name` (validator-enforced) — write it as a class nested inside the skill/buff file.

- `owner_config_id: String`
- `_init(target_selector: TargetSelector, p_owner_config_id: String)`
- `_execute_local(_ctx: ExecutionContext) -> ActionResult` — Override in subclasses

### Action.NoopAction (extends BaseAction)

Empty action returning success with no events.

### Action.execute_child (static)

- `static execute_child(_parent_action: BaseAction, child_action: BaseAction, ctx: ExecutionContext) -> ActionResult` — Mandatory entry point for running a child action: calls `child.execute(ctx)`, then `child._verify_unchanged()`, and normalizes a null result to an empty success result. Never hand-roll `child.execute()` elsewhere — that skips the verify step. Used by `FlowAction.IfAction` and any other composite.

---

## ExecutionContext (extends RefCounted)

Runtime context passed to `Action.execute()`.

**Properties:**
- `event_dict_chain: Array[Dictionary]` — Trigger event chain
- `game_state_provider: Variant` — Game state access
- `event_collector: EventCollector` — For recording events
- `ability_ref: AbilityRef` — Reference to owning ability
- `execution_info: AbilityExecutionInfo` — Timeline execution metadata
- `execution_state: Dictionary` — §0.4 transient scratchpad shared by every `ExecutionContext` created for the same `AbilityExecutionInstance` (e.g. CAST-tag write, HIT-tag read). `ExecutionContext` doesn't own it, only holds the reference; `create_callback_context` carries the same reference forward.

**Methods:**
- `get_current_event() -> Dictionary` — Last event in chain (most recent trigger)
- `get_original_event() -> Dictionary` — First event in chain (root trigger)
- `push_event(event_dict: Dictionary) -> Dictionary` — Forwards straight to `event_collector.push(event_dict)`; no pre/post processing happens here (that already ran earlier, in `EventProcessor`)
- `set_execution_state(key: String, value: Variant) -> void` — Writes to `execution_state`; `key` must be namespaced with a `"."` (asserts otherwise, e.g. `"shadow_step.teleport_success"`)
- `get_execution_state(key: String, fallback: Variant = null) -> Variant` — Reads from `execution_state`; same namespace requirement

**Factory:**
- `static create(...) -> ExecutionContext`
- `static create_callback_context(ctx: ExecutionContext, callback_event_dict: Dictionary) -> ExecutionContext`

---

## ActionResult (extends RefCounted)

Outcome of action execution.

**Properties:**
- `success: bool`
- `event_dicts: Array[Dictionary]`
- `failure_reason: String`
- `data: Dictionary`

**Factory:**
- `static create_success_result(p_event_dicts, p_data = {}) -> ActionResult`
- `static create_failure_result(reason, p_event_dicts = []) -> ActionResult`

---

## TargetSelector (extends RefCounted)

Resolves target actor IDs for actions.

**Methods:**
- `select(_ctx: ExecutionContext) -> Array[String]` — Override in subclasses
- `filtered(filter_fn: Callable) -> TargetSelector` — Returns filtered wrapper

---

## FlowAction (extends RefCounted)

General-purpose Action flow combinator. Only `FlowAction.if_(predicate, then_actions, else_actions := [])` is approved — no sequence/DSL/VM (`core/actions/flow_action.gd`).

- `static if_(predicate: Callable, then_actions: Array[Action.BaseAction], else_actions: Array[Action.BaseAction] = []) -> Action.BaseAction`

Contract: `predicate` must be `func(ctx: ExecutionContext) -> bool` (asserts if it returns non-bool). Only the selected branch runs, its children execute in array order via `Action.execute_child`; a failing child stops the branch early and returns a failure result with whatever `event_dicts` were collected so far. `ActionResult.data` carries `{ "branch": "then" | "else" }`.

```gdscript
FlowAction.if_(
    func(ctx: ExecutionContext) -> bool: return ctx.get_execution_state("shadow_step.teleport_success", false),
    [DamageAction.new(...)],
    [MissAction.new(...)]
)
```

---

## LooseTagAction (extends RefCounted)

Loose-tag-only mutation actions — the replacement for `TagAction`'s `ApplyTagAction`/`RemoveTagAction`. Never touches auto-duration tags (buff/duration ability territory) or component tags (`TagComponentConfig`/`TagComponent` territory). See `core/actions/loose_tag_action.gd`.

**Constants:**
- `REMOVE_ALL_STACKS := -1`

**Inner Classes** (both extend `Action.PrimitiveAction`):
- `Apply(target_selector, tag_name: String, stacks_count: IntResolver = 1)` — Adds loose tag stacks
- `Remove(target_selector, tag_name: String, stacks_count: IntResolver = REMOVE_ALL_STACKS)` — Removes loose tag stacks

```gdscript
LooseTagAction.Apply.new(target_selector, "stance:wrath")
LooseTagAction.Remove.new(target_selector, "stance:wrath")
```

Tag-presence *queries* still go through `Condition.HasTagCondition`/`NoTagCondition` (active-skill condition slot) or a `FlowAction.if_` predicate — not through an Action.

---

## TagAction (extends RefCounted) — deprecated

**@deprecated** — use `LooseTagAction.Apply`/`LooseTagAction.Remove` instead (`core/actions/tag_action.gd:1-11`). The original file mixed three unrelated concerns: `ApplyTagAction`/`RemoveTagAction` only ever touched loose tags, while `HasTagAction` reads the aggregate tag state. `HasTagAction` call sites should migrate to `FlowAction.if_` + `Condition.HasTagCondition`/`NoTagCondition`. Existing call sites are grandfathered (validator allowlist); do not add new uses.

Built-in actions for tag manipulation.

**Constants:**
- `PERMANENT_DURATION := -1.0`
- `REMOVE_ALL_STACKS := -1`

**Inner Classes:**
- `ApplyTagAction(target_selector, tag_name, stacks_count, tag_duration)` — Apply tag with stacks and duration
- `RemoveTagAction(target_selector, tag_name, stacks_count)` — Remove tag stacks
- `HasTagAction(target_selector, tag_name, then_actions, else_actions)` — Conditional branch on tag presence

---

## Resolvers

Type-safe delayed evaluation for shared Action parameters. Create via `Resolvers` factory, evaluate via `resolve(ctx: ExecutionContext)`.

### Resolvers (static factory)

| Method | Returns |
|--------|---------|
| `Resolvers.float_val(v)` / `Resolvers.float_fn(fn)` | `FloatResolver` |
| `Resolvers.int_val(v)` / `Resolvers.int_fn(fn)` | `IntResolver` |
| `Resolvers.str_val(v)` / `Resolvers.str_fn(fn)` | `StringResolver` |
| `Resolvers.dict_val(v)` / `Resolvers.dict_fn(fn)` | `DictResolver` |
| `Resolvers.vec3_val(v)` / `Resolvers.vec3_fn(fn)` | `Vector3Resolver` |

Each resolver has: `resolve(ctx: ExecutionContext) -> T`

Dynamic resolvers accept `Callable` with signature `func(ctx: ExecutionContext) -> T`.

### ParamResolver (static utility)

- `static resolve_param(resolver: Variant, ctx: ExecutionContext) -> Variant` — If resolver is Callable, calls it with ctx; otherwise returns as-is
- `static resolve_optional_param(resolver: Variant, default_value: Variant, ctx: ExecutionContext) -> Variant` — Returns default_value if resolver is null

---

## Supporting Classes

### AbilityRef (extends RefCounted)

Lightweight reference to an Ability for use in ExecutionContext.

**Properties:**
- `id: String` / `config_id: String` / `owner_actor_id: String` / `source_actor_id: String`

**Methods:**
- `static from_ability(in_ability: Ability) -> AbilityRef`
- `static create(p_id: String, p_config_id: String, p_owner_actor_id: String, p_source_actor_id: String = "") -> AbilityRef` — If `source_actor_id` empty, defaults to `owner_actor_id`
- `resolve() -> Ability` — Resolves to full Ability instance via GameWorld
- `is_valid() -> bool`
- `to_dict() -> Dictionary` / `static from_dict(d: Dictionary) -> AbilityRef`

### AbilityExecutionInfo (extends RefCounted)

Timeline execution metadata.

**Properties:**
- `id: String` / `timeline_id: String` / `elapsed: float` / `current_tag: String`

**Methods:**
- `static create(p_id: String, p_timeline_id: String, p_elapsed: float, p_current_tag: String) -> AbilityExecutionInfo`
- `to_dict() -> Dictionary` / `static from_dict(d: Dictionary) -> AbilityExecutionInfo`
