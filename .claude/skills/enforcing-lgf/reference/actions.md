# Actions API

## Contents
- [Action / BaseAction](#action-extends-refcounted)
- [ExecutionContext](#executioncontext-extends-refcounted)
- [ActionResult](#actionresult-extends-refcounted)
- [TargetSelector](#targetselector-extends-refcounted)
- [TagAction](#tagaction-extends-refcounted)
- [Resolvers](#resolvers)
- [Supporting Classes](#supporting-classes) (AbilityRef, AbilityExecutionInfo)

## Action (extends RefCounted)

Container class with inner classes for the action system.

### Action.BaseAction (extends RefCounted)

Base class for all actions. **SHARED across characters — MUST NOT modify `self`.**

**Properties:**
- `type: String` — Action type identifier

**Methods:**
- `execute(_ctx: ExecutionContext) -> ActionResult` — Override to implement action logic
- `get_targets(ctx: ExecutionContext) -> Array[String]` — Resolve target actor IDs via TargetSelector

### Action.NoopAction (extends BaseAction)

Empty action returning success with no events.

---

## ExecutionContext (extends RefCounted)

Runtime context passed to `Action.execute()`.

**Properties:**
- `event_dict_chain: Array[Dictionary]` — Trigger event chain
- `game_state_provider: Variant` — Game state access
- `event_collector: EventCollector` — For recording events
- `ability_ref: AbilityRef` — Reference to owning ability
- `execution_info: AbilityExecutionInfo` — Timeline execution metadata

**Methods:**
- `get_current_event() -> Dictionary` — Last event in chain (most recent trigger)
- `get_original_event() -> Dictionary` — First event in chain (root trigger)
- `push_event(event_dict: Dictionary) -> Dictionary` — Push event through pre/post processing

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

## TagAction (extends RefCounted)

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
