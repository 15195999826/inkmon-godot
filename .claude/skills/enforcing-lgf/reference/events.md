# Events API

## Contents
- [EventProcessor](#eventprocessor-extends-refcounted)
- [EventPhase](#eventphase-static-utility)
- [MutableEvent](#mutableevent-extends-refcounted)
- [Intent](#intent-extends-refcounted)
- [Modification](#modification-extends-refcounted)
- [GameEvent](#gameevent-extends-refcounted)
- [ProjectileEvents](#projectileevents-static-utility)
- [EventCollector](#eventcollector-extends-refcounted)
- [Supporting Classes](#supporting-classes) (PreHandlerRegistration, HandlerContext, EventProcessorConfig)

## EventProcessor (extends RefCounted)

Dual-phase event processing: Pre (modify/cancel) and Post (broadcast).

**Constructor:**
- `_init(config: EventProcessorConfig = null)`

**Pre-Event (modify/cancel before execution):**
- `register_pre_handler(registration: PreHandlerRegistration) -> Callable` — Returns unsubscribe function
- `remove_handlers_by_ability_id(ability_id: String) -> void`
- `remove_handlers_by_owner_id(owner_id: String) -> void`
- `process_pre_event(event_dict: Dictionary, game_state_provider: Variant) -> MutableEvent`

**Post-Event (broadcast after execution):**
- `process_post_event(event_dict: Dictionary, actor_ids: Array[String], game_state_provider: Variant) -> void`
- `process_post_event_to_related(event_dict: Dictionary, actor_ids: Array[String], related_actor_ids: Dictionary, game_state_provider: Variant) -> void`

**Tracing:**
- `get_traces() -> Array[Dictionary]` / `clear_traces() -> void`
- `get_current_depth() -> int` / `get_current_trace_id() -> String`
- `export_trace_log() -> String`

---

## EventPhase (static utility)

Factory for Intent objects.

**Constants:**
- `PHASE_PRE := "pre"` / `PHASE_POST := "post"`
- `INTENT_PASS := "pass"` / `INTENT_CANCEL := "cancel"` / `INTENT_MODIFY := "modify"`

**Factory Methods:**
- `static pass_intent() -> Intent`
- `static cancel_intent(handler_id: String, reason: String) -> Intent`
- `static modify_intent(handler_id: String, modifications: Array[Modification]) -> Intent`

---

## MutableEvent (extends RefCounted)

Event wrapper that accumulates modifications during pre-event processing.

**Properties:**
- `original: Dictionary` — Original event data
- `phase: String` — Current phase
- `cancelled: bool` / `cancel_reason: String` / `cancelled_by: String`

**Methods:**
- `get_current_value(field: String) -> Variant` — Value after all modifications applied
- `to_final_event() -> Dictionary` — Original + all modifications applied
- `add_modification(modification: Modification) -> void`
- `add_modifications(modifications: Array[Modification]) -> void`
- `cancel(handler_id: String, reason: String) -> void`
- `get_modifications() -> Array[Modification]`
- `get_original_values() -> Dictionary` / `get_final_values() -> Dictionary`
- `get_field_computation_steps(field: String) -> Dictionary`
- `get_all_computation_steps() -> Array[Dictionary]`

---

## Intent (extends RefCounted)

Result of a pre-event handler.

**Enum:** `Type { PASS, CANCEL, MODIFY }`

**Properties:**
- `type: Type` / `handler_id: String` / `reason: String` / `modifications: Array[Modification]`

**Factory:**
- `static pass_through() -> Intent`
- `static cancel(p_handler_id: String, p_reason: String) -> Intent`
- `static modify(p_handler_id: String, p_modifications: Array[Modification]) -> Intent`

**Checks:** `is_pass()` / `is_cancel()` / `is_modify()`

---

## Modification (extends RefCounted)

Single field modification operation.

**Enum:** `Operation { SET, ADD, MULTIPLY }`

**Properties:**
- `field: String` / `operation: Operation` / `value: float`
- `source_id: String` / `source_name: String`

**Factory:**
- `static set_value(p_field: String, p_value: float, p_source_id: String = "", p_source_name: String = "") -> Modification`
- `static add(p_field: String, p_value: float, p_source_id: String = "", p_source_name: String = "") -> Modification`
- `static multiply(p_field: String, p_value: float, p_source_id: String = "", p_source_name: String = "") -> Modification`

---

## GameEvent (extends RefCounted)

Event type constants and inner class factories.

**Constants:**
`ABILITY_ACTIVATE_EVENT`, `ABILITY_ACTIVATE_FAILED_EVENT`, `ACTOR_SPAWNED_EVENT`, `ACTOR_DESTROYED_EVENT`, `ATTRIBUTE_CHANGED_EVENT`, `ABILITY_GRANTED_EVENT`, `ABILITY_REMOVED_EVENT`, `ABILITY_TRIGGERED_EVENT`, `ABILITY_STACKS_CHANGED_EVENT`, `EXECUTION_ACTIVATED_EVENT`, `TAG_CHANGED_EVENT`, `STAGE_CUE_EVENT`, `PROJECTILE_HIT_EVENT`

**Inner Classes** (each has `create()`, `to_dict()`, `from_dict()`, `is_match()`):
`ActorSpawned`, `ActorDestroyed`, `AttributeChanged`, `AbilityGranted`, `AbilityRemoved`, `AbilityTriggered`, `AbilityStacksChanged` (`actor_id`/`ability_instance_id`/`ability_config_id`/`old_stacks`/`new_stacks`; business code emits explicitly — core does not couple this into `add_stacks`/`remove_stacks`), `ExecutionActivated`, `TagChanged`, `StageCue`, `ProjectileHit`, `AbilityActivate` (self-activation request; carries `logic_time` / `target_actor_id` / `target_coord`), `AbilityActivateFailed` (`reason` / `failed_component_type`; pushed when `ActiveUseComponent` condition/cost checks reject an already-matched trigger — a trigger that never matched is a silent skip, not a failure)

---

## ProjectileEvents (static utility)

**Constants:** `PROJECTILE_LAUNCHED_EVENT`, `PROJECTILE_HIT_EVENT`, `PROJECTILE_MISS_EVENT`, `PROJECTILE_DESPAWN_EVENT`, `PROJECTILE_PIERCE_EVENT`

**Factory:** `create_projectile_hit_event(..., options: Dictionary = {})`, `create_projectile_launched_event(...)`, etc.
**Checks:** `is_projectile_hit_event(event)`, `is_projectile_launched_event(event)`, etc.

---

## EventCollector (extends RefCounted)

Collects events during action execution.

- `push(event_dict: Dictionary) -> Dictionary`
- `collect() -> Array[Dictionary]` — Returns copy, does not clear
- `flush() -> Array[Dictionary]` — Returns and clears
- `clear() -> void`
- `get_count() -> int` / `has_events() -> bool`
- `filter_by_kind(kind: String) -> Array[Dictionary]`
- `merge(other: EventCollector) -> void`

---

## Supporting Classes

### PreHandlerRegistration (extends RefCounted)

Registration data for pre-event handlers.

- `id: String` / `event_kind: String` / `owner_id: String` / `ability_id: String` / `config_id: String`
- `handler: Callable` — `func(MutableEvent, HandlerContext) -> Intent`
- `filter: Callable` — `func(Dictionary) -> bool`
- `handler_name: String`

**Dispatch:**
- `get_display_name() -> String` — `handler_name` if set, else `config_id`, else `id`
- `passes_filter(event_dict: Dictionary) -> bool` — `true` if `filter` unset, else `filter.call(event_dict)`
- `call_handler(mutable: MutableEvent, ctx: HandlerContext) -> Intent` — Calls `handler`; falls back to `Intent.pass_through()` if `handler` is invalid or doesn't return an `Intent`

### HandlerContext (extends RefCounted)

- `owner_id: String` / `ability_id: String` / `config_id: String` / `game_state: Variant`

### EventProcessorConfig (extends RefCounted)

- `max_depth: int` (default 10) — Max recursion depth
- `trace_level: int` (default 1) — 0=none, 1=basic, 2=detailed
