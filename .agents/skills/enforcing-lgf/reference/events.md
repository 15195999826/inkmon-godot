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
- [Supporting Classes](#supporting-classes) (PreHandlerRegistration, PostHandlerRegistration, HandlerContext, EventProcessorConfig)

## EventProcessor (extends RefCounted)

Dual-phase event processing: Pre (modify/cancel) and Post (subscription dispatch). **Owned per instance**: `GameplayInstance._init(id, processor_config)` builds one (`instance.event_processor`), so pre / post handler registrations, recursion depth and traces are instance-scoped — handlers registered on one instance never see another instance's events. It holds no reference to the instance, abilities or components (handler closures capture ids only). Reach it through the instance (`battle.event_processor`) or a lifecycle context (`context.event_processor`, derived from `context.instance`); `GameWorld` has no processor.

**Constructor:**
- `_init(config: EventProcessorConfig = null)` — Normally called for you by `GameplayInstance._init`; construct one directly only in isolated unit tests

**Pre-Event (modify/cancel before execution):**
- `register_pre_handler(registration: PreHandlerRegistration) -> Callable` — Returns an unsubscribe closure (removes by id, idempotent). It is built in a static function and captures only the registration table, kind and id — never the processor or the registration — so callers may keep it as long as the ability lives
- `process_pre_event(event_dict: Dictionary) -> MutableEvent` — Iterates a snapshot of the kind's handlers: registering or unregistering inside a handler doesn't change who sees the event in flight

**Post-Event (subscription dispatch after execution):**
- `process_post_event(event_dict: Dictionary) -> void` — No audience parameter. Calls every handler registered for the event's kind in owner registry order → registration (grant) order; iterates a snapshot, like the pre side. Passing a `DIRECT_DELIVERY_KINDS` kind asserts
- `register_post_handler(registration: PostHandlerRegistration) -> Callable` — Normally called by `Ability.apply_effects` (one registration per kind its components declare via `get_post_event_kinds()`); inserts in dispatch order and returns the same kind of unsubscribe closure as the pre side. A `DIRECT_DELIVERY_KINDS` kind asserts
- `const DIRECT_DELIVERY_KINDS: Array[String]` — `abilityActivate` / `abilityGranted`: directed deliveries that only go through `AbilitySet.receive_event`; they are never registered, so nothing can receive them twice
- Liveness: an Ability's post handler rebuilds its context by id (`AbilityLifecycleContext.rebuild_for_handler`), which first asks the owner `is_event_responsive(event_dict, "post")` — `false` skips it, and so does an ability that has since left the owner's AbilitySet or expired. The audience is decided by registration, liveness by the actor

**Registry & cleanup:**
- `note_actor_added(actor_id: String) -> void` / `note_actor_removed(actor_id: String) -> void` — Called by `GameplayInstance.add_actor` / `remove_actor`: the first records the owner's dispatch order, the second drops the owner's pre / post handlers and its order slot
- `remove_handlers_by_ability_id(ability_id: String) -> void` / `remove_handlers_by_owner_id(owner_id: String) -> void` — Both tables. inkmon's `reset_battle_runtime` uses the owner form before swapping in a fresh AbilitySet (abilities dropped wholesale never run `remove_effects`)
- `remove_all_handlers() -> void` — Clears both tables (`GameplayInstance.end()`)

**Tracing:**
- `set_trace_level(level: int) -> void` — Switches this processor's trace level at runtime (the recursion-depth error's "no trace available" hint points here)
- `get_traces() -> Array[Dictionary]` / `clear_traces() -> void`
- `get_current_depth() -> int` / `get_current_trace_id() -> String`
- `export_trace_log() -> String` — At trace_level ≥ 2, pre traces list each handler's intent and post traces list each handler and whether it triggered

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

Collects events during action execution. **Owned per instance** (`instance.event_collector`): actions push through `ctx.event_collector` (derived from `ctx.instance`), recording callbacks through the same collector injected into `BattleRecorder` / `RecordingContext`, and the battle procedure flushes it once per frame — one queue, so the recorded order is the real call-stack order.

- `push(event_dict: Dictionary) -> Dictionary` — Stores a **deep copy** (`duplicate(true)`) in the buffer and returns the **original** dict. The copy is what recording keeps, so a post-listener mutating the event it received can no longer retroactively rewrite the replay; the returned original is still the live object the pushing Action keeps working with
- `collect() -> Array[Dictionary]` — Returns a deep copy, does not clear
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
- `handler_context: HandlerContext` — Built from the ids at construction and reused by every dispatch

**Dispatch:**
- `get_display_name() -> String` — `handler_name` if set, else `config_id`, else `id`
- `passes_filter(event_dict: Dictionary) -> bool` — `true` if `filter` unset, else `filter.call(event_dict)`
- `call_handler(mutable: MutableEvent) -> Intent` — Calls `handler` with `handler_context`; falls back to `Intent.pass_through()` if `handler` is invalid or doesn't return an `Intent`

### PostHandlerRegistration (extends RefCounted)

`core/events/post_handler_registration.gd`. One per (ability, kind): `Ability.apply_effects` registers it, `remove_effects` unregisters it. **No filter** — `TriggerConfig.filter` is still evaluated inside `AbilityComponent.match_triggers`.

- `id: String` (`"<ability_id>_post_<kind>"` for abilities) / `event_kind: String` / `owner_id: String` / `ability_id: String` / `config_id: String`
- `handler: Callable` — `func(Dictionary, HandlerContext) -> bool`; `true` = at least one component triggered (trace only). The processor holds it strongly, so it must capture ids only: `Ability._make_post_handler` builds it in a static function (no `self` to capture) and gets the ability back through `AbilityLifecycleContext.rebuild_for_handler`
- `handler_name: String` / `handler_context: HandlerContext`
- `owner_seq: int` — The owner's registry order, assigned by `register_post_handler`; one kind's registrations dispatch in this order, same-owner registrations in registration order
- `get_display_name() -> String` / `call_handler(event_dict: Dictionary) -> bool` — An invalid handler, or one that returns a non-bool, counts as not triggered

### HandlerContext (extends RefCounted)

- `owner_id: String` / `ability_id: String` / `config_id: String` — ids only, no instance or processor. Built once per registration and reused by every dispatch, so handlers must not mutate it. `PreEventConfig` user handlers and Ability post handlers get an `AbilityLifecycleContext` rebuilt per dispatch (which carries `instance`); a raw handler that needs the world looks it up by `owner_id`

### EventProcessorConfig (extends RefCounted)

- `max_depth: int` (default 10) — Max recursion depth
- `trace_level: int` (default 0) — 0=none (traces are not accumulated), 1=basic, 2=detailed. The config is handed to the instance at construction (`GameplayInstance._init(id, config)`); to debug an existing instance call `instance.event_processor.set_trace_level(1)` instead
