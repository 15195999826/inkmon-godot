# Abilities API

## Contents
- [Ability](#ability-extends-refcounted)
- [AbilityConfig](#abilityconfig-extends-refcounted)
- [AbilitySet](#abilityset-extends-refcounted)
- [AbilityComponent](#abilitycomponent-extends-refcounted)
- [AbilityComponentConfig](#abilitycomponentconfig-extends-refcounted)
- [AbilityLifecycleContext](#abilitylifecyclecontext-extends-refcounted)
- [AbilityExecutionInstance](#abilityexecutioninstance-extends-refcounted)
- [Core Components](#core-components) (ActiveUseConfig, ActivateInstanceConfig, NoInstanceConfig, PreEventConfig, TagComponent)
- [Supporting Classes](#supporting-classes) (TriggerConfig, Condition, Cost, AbilityActivationQuery)

## Ability (extends RefCounted)

Runtime ability instance with lifecycle management and component execution.

**States:** `STATE_PENDING`, `STATE_GRANTED`, `STATE_EXPIRED`

**Stack Overflow Policies:** `OVERFLOW_CAP` (clamp to `max_stacks`), `OVERFLOW_REFRESH` (clamp to `max_stacks`, then broadcast `on_ability_stack_refreshed()` on all components — lets a duration component reset its timer atomically with the stack refresh), `OVERFLOW_REJECT` (reject the add entirely, `stacks` unchanged). See `core/abilities/core/ability.gd:8-15`.

**Properties:**
- `id: String` — Unique instance ID
- `config_id: String` — Reference to AbilityConfig
- `source_actor_id: String` — Actor that granted this ability
- `owner_actor_id: String` — Actor that owns this ability
- `display_name: String` / `description: String` / `icon: String`
- `ability_tags: Array[String]` — Tags for categorization
- `metadata: Dictionary` — Custom metadata
- `stacks: int` — Current stack count (default `1`)
- `max_stacks: int` — Stack cap (default `1` = non-stacking; `add_stacks` on a non-stacking ability just stays capped at 1)
- `overflow_policy: int` — One of the Stack Overflow Policies above (default `OVERFLOW_CAP`)

**State:**
- `get_state() -> String` / `is_granted() -> bool` / `is_expired() -> bool`
- `get_expire_reason() -> String`
- `has_ability_tag(tag: String) -> bool`
- `get_meta_int(key: String, default: int = 0) -> int`

**Components:**
- `get_all_components() -> Array[AbilityComponent]`
- `tick(dt: float) -> void`
- `apply_effects(context: AbilityLifecycleContext) -> void` — Runs every component's `on_apply`, then registers one post handler per kind its components declare (`get_post_event_kinds()`, directed-delivery kinds excluded) on `context.event_processor`, owned by `context.owner_actor_id` (the AbilitySet's owner, same as `PreEventComponent`); no processor (owner not registered) → nothing is registered. An `on_apply` that expires the ability stops it there: later components don't apply and nothing is registered
- `remove_effects() -> void` — Unregisters those post handlers first, then runs `on_remove` with a context from `AbilityLifecycleContext.for_ability(self)`
- `expire(reason: String) -> void` — Idempotent (a second call on an already-expired ability returns early); order is `cancel_all_executions()` → `remove_effects()` → state becomes `STATE_EXPIRED`, so a revoked/expired buff's in-flight executions still run their `on_cancel` cleanup

**Stacks** (`core/abilities/core/ability.gd:285-341`):
- `get_stacks() -> int`
- `is_stacks_full() -> bool` — `stacks >= max_stacks`
- `add_stacks(count: int) -> int` — Adds per `overflow_policy`, returns the actual delta applied; fires `component.on_stacks_changed()` on every component if `stacks` actually changed
- `remove_stacks(count: int) -> int` — Returns the actual delta removed; reaching 0 does **not** auto-expire the ability, cleanup is the caller's responsibility
- `set_stacks(count: int) -> void` — Force-set, clamped to `[0, max_stacks]`

**Break (passive disable)** (`core/abilities/core/ability.gd:175-226`, Phase B2):
- `is_disabled() -> bool` — True while at least one disabled source is registered
- `add_disabled_source(source_id: String) -> void` — Reference-counted by `source_id`; idempotent re-add. The first add (empty → non-empty) fires `on_passive_disabled()` on all components
- `remove_disabled_source(source_id: String) -> void` — The last remove (non-empty → empty) fires `on_passive_enabled()`; unknown `source_id` is a no-op
- `get_disabled_source_count() -> int`

While disabled, `receive_event()` and `tick_executions()` short-circuit at the top of `Ability` — `NoInstanceComponent`/`ActivateInstanceComponent` must **not** implement `on_passive_disabled`/`on_passive_enabled` themselves (event dispatch and timeline ticking already stop above them). Only externally-registered components (`StatModifierComponent`, `DynamicStatModifierComponent`) implement the two hooks, to retract/rebuild attribute modifiers.

**Activation gate query** (`core/abilities/core/ability.gd:190`):
- `can_activate(context: AbilityLifecycleContext, event_dict: Dictionary = {}) -> Dictionary` — Zero-side-effect dry run of the activation gate. Mirrors `receive_event`'s top-level short-circuits first (not `STATE_GRANTED` → denied `FAILED_ABILITY`; `is_disabled()` → denied `FAILED_ABILITY`), then evaluates every active `ActiveUseComponent`'s gate and returns the first failure. An ability with no `ActiveUseComponent` passes vacuously — the query answers "will the gate stop me", not "is this a castable skill" (that stays a declarative `metadata` question, see [cast-eligibility-vs-condition.md](cast-eligibility-vs-condition.md)). Result shape: [`AbilityActivationQuery`](#abilityactivationquery-static-utility). Normally reached through `AbilitySet.can_activate`, which builds the lifecycle context

**Execution:**
- `activate_new_execution_instance(p_timeline: TimelineData, p_tag_actions, p_on_timeline_start_actions, p_on_timeline_end_actions, p_trigger_event_dict, p_on_cancel_actions: Array[Action.BaseAction] = []) -> AbilityExecutionInstance` — timeline is passed by reference (no registry lookup). The execution holds no instance reference: every `ExecutionContext` it builds (tags, start/end, and `on_cancel` when revoke/expire cancels it) looks the owner's instance up by id. An `on_execution_activated` listener may cancel the instance synchronously; the `on_timeline_start` actions are then skipped
- `get_executing_instances() -> Array[AbilityExecutionInstance]`
- `has_executing_instance() -> bool` — Same answer as `get_executing_instances().size() > 0` without building the intermediate array (the battle loop asks once per actor per tick)
- `get_all_execution_instances() -> Array[AbilityExecutionInstance]`
- `cancel_all_executions() -> void` — Cancels every instance (running their `on_cancel` actions) and clears the list
- `tick_executions(dt: float) -> Array[String]`

**Events:**
- `receive_event(event_dict: Dictionary, context: AbilityLifecycleContext) -> bool` — Hands the event to every active component and returns whether any triggered. Reached from the ability's own post handlers (post dispatch) and from `AbilitySet.receive_event` (directed delivery)
- `add_triggered_listener(callback: Callable) -> Callable`
- `add_execution_activated_listener(callback: Callable) -> Callable`

---

## AbilityConfig (extends RefCounted)

Declarative ability definition using Builder pattern.

**Properties:**
- `config_id: String` — Required identifier
- `display_name: String` / `description: String` / `icon: String`
- `ability_tags: Array[String]`
- `active_use_components: Array[ActiveUseConfig]`
- `components: Array[AbilityComponentConfig]`
- `metadata: Dictionary`
- `initial_stacks: int` — Default `1`
- `max_stacks: int` — Default `1` (non-stacking)
- `overflow_policy: int` — `Ability.OVERFLOW_*`, default `OVERFLOW_CAP`

**Builder:**
```gdscript
AbilityConfig.builder()
    .config_id("slash")
    .display_name("Slash")
    .ability_tags(["melee", "physical"])
    .active_use(active_use_config)
    .component_config(stat_modifier_config)
    .meta("cooldown", 5.0)
    .stacks(1, 5, Ability.OVERFLOW_REFRESH)   # optional: initial, max, overflow policy
    .build()
```

`.stacks(initial, max_val, policy = Ability.OVERFLOW_CAP)` — Not calling it leaves the ability at the safe non-stacking default (1/1/CAP). See `core/abilities/core/ability_config.gd:146-154`.

**Methods:**
- `collect_timelines() -> Array[TimelineData]` — Every `TimelineData` carried by this config tree (each `ActiveUseConfig.timeline_data` + each `ActivateInstanceConfig.timeline_data`). **Static-check entry point only** — the runtime never goes through it (components hand their timeline straight to `AbilityExecutionInstance`). Its one consumer is hex `smoke_manifest_lint` assertion 1

---

## AbilitySet (extends RefCounted)

Container for Abilities with tag management and grant/revoke operations.

**Revoke Reasons:** `REVOKE_REASON_EXPIRED`, `REVOKE_REASON_DISPELLED`, `REVOKE_REASON_REPLACED`, `REVOKE_REASON_MANUAL`

**Properties:**
- `owner_actor_id: String`
- `tag_container: TagContainer`

**Factory:**
- `static create(p_owner_actor_id: String, p_attribute_set: BaseGeneratedAttributeSet = null) -> AbilitySet`

**Owner binding:**
- `bind_owner(actor_id: String) -> void` — Sets `owner_actor_id` **and** `tag_container.owner_id` together. The AbilitySet is built before the actor has an id, so both copies start out empty and must be re-pointed at once or they drift. (`tag_container.owner_id` currently has no readers — it is the container's own record of whose it is, not a bug this method fixes.) `BattleActor._on_id_assigned()` calls it

**Grant/Revoke:**
- `grant_ability(ability: Ability) -> void` — Always delivers `AbilityGranted` synchronously to this ability_set's own abilities after grant (a directed delivery, `EventProcessor.DIRECT_DELIVERY_KINDS` — never through `process_post_event`). Whether anything self-activates is declared by the ability's own triggers (`TriggerConfig.GRANTED_SELF`), never by the call site
- `revoke_ability(ability_id: String, reason: String = REVOKE_REASON_MANUAL, expire_reason: String = "") -> bool`
- `revoke_abilities_by_config_id(config_id: String, reason: String = REVOKE_REASON_MANUAL) -> int`
- `revoke_abilities_by_ability_tag(tag: String, reason: String = REVOKE_REASON_MANUAL) -> int`

**Query:**
- `get_abilities() -> Array[Ability]`
- `find_ability_by_id(ability_id: String) -> Ability`
- `find_ability_by_config_id(config_id: String) -> Ability`
- `find_abilities_by_config_id(config_id: String) -> Array[Ability]`
- `find_abilities_by_ability_tag(tag: String) -> Array[Ability]`
- `has_ability(config_id: String) -> bool`
- `get_ability_count() -> int`
- `can_activate(ability: Ability, event_dict: Dictionary = {}) -> Dictionary` — The entry point UI / AI / tooltip should use for "can this be cast right now": builds the same lifecycle context `receive_event` dispatch uses, then delegates to `Ability.can_activate`. `ability` must belong to this AbilitySet (a cross-set query would lie about the owner — it crashes instead). `event_dict` is only a simulated input forwarded to `Condition.check` / `Cost.can_pay` (e.g. a preset `target_actor_id`); pass `{}` when there is no target context

**Tags (delegates to TagContainer):**
- `add_loose_tag(tag: String, stacks: int = 1) -> void`
- `remove_loose_tag(tag: String, stacks: int = -1) -> bool`
- `add_auto_duration_tag(tag: String, duration: float) -> void`
- `has_tag(tag: String) -> bool` / `get_tag_stacks(tag: String) -> int`
- `get_all_tags() -> Dictionary`
- `has_loose_tag(tag: String) -> bool` / `get_loose_tag_stacks(tag: String) -> int`

**Tick & Events:**
- `tick_runtime(dt: float, logic_time: float) -> bool` — One frame of ability runtime, and the shape every turn/ATB battle loop should use: `tick` → compute blocking → `tick_executions` (skipped when nothing is executing). Returns whether a blocking execution occupied this frame. **Blocking is computed before `tick_executions` on purpose**: an execution that finishes inside this frame still owned it, and asking afterwards would let an actor both cast and charge ATB on its recovery frame. A real-time example that sequences its own phases (dota2) skips it and calls `has_executing_instances()` + `tick_executions()` directly
- `has_executing_instances() -> bool` — Any ability currently executing (blocking or not)
- `_is_blocking_execution(ability: Ability) -> bool` — Virtual, default `true` (everything blocks). Projects override it to express "always-on abilities don't freeze action" (both `BattleAbilitySet` and `InkMonBattleAbilitySet` use `not ability.has_ability_tag("intrinsic")`)
- `tick(dt: float, logic_time: float = -1.0) -> void`
- `tick_executions(dt: float) -> Array[String]`
- `receive_event(event_dict: Dictionary) -> void` — **Directed delivery** to every ability in this set (activation requests, the grant's `AbilityGranted`); it doesn't ask `is_event_responsive`, and cross-actor reactions go through `EventProcessor.process_post_event` instead. One lifecycle context per ability; the owner instance is looked up once per call. Like `tick` / `tick_executions` it walks a snapshot of the abilities: a revoke inside the pass doesn't skip the next ability, and an ability granted inside it is processed from the next pass on
- `get_owner_instance() -> GameplayInstance` — `GameWorld.get_instance_of_actor(owner_actor_id)`, re-resolved on every call (`null` when the owner isn't registered). Deliberately not cached or bound: the set is built before the actor has an id and projects rebuild it wholesale (inkmon `reset_battle_runtime`), so a bind-once reference would be missed on those paths
- `get_logic_time() -> float`

**Listeners:**
- `on_ability_granted(callback: Callable) -> Callable`
- `on_ability_revoked(callback: Callable) -> Callable`

---

## AbilityComponent (extends RefCounted)

Base class for all ability components with lifecycle hooks.

**Properties:**
- `type: String` — Component type identifier

**Lifecycle (override these):**
- `on_apply(context: AbilityLifecycleContext) -> void`
- `on_remove(context: AbilityLifecycleContext) -> void`
- `on_tick(dt: float) -> void`
- `on_event(event_dict: Dictionary, context: AbilityLifecycleContext) -> bool`
- `get_post_event_kinds() -> Array[String]` — Kinds this component wants from post dispatch (default `[]`; `NoInstanceComponent` / `ActivateInstanceComponent` return their triggers' kinds, deduped by `static trigger_event_kinds(triggers)`). A component that overrides `on_event` without declaring kinds only receives directed deliveries
- `on_stacks_changed(context: AbilityLifecycleContext, old_stacks: int, new_stacks: int) -> void` — Fires after `Ability.add_stacks`/`remove_stacks`/`set_stacks` actually changes `stacks` (no-op call if clamped to the same value). Must not call those methods again from inside the hook — `Ability` asserts against re-entrant nesting.
- `on_ability_stack_refreshed() -> void` — Fires when `OVERFLOW_REFRESH` caps a stack add; duration-based components use it to reset their remaining time atomically with the stack refresh
- `on_passive_disabled(context: AbilityLifecycleContext) -> void` — Phase B2 Break: fires once when the ability transitions into disabled (its first `add_disabled_source`). Only externally-registered components implement this (e.g. `StatModifierComponent` retracts its attribute modifiers); `NoInstanceComponent`/`ActivateInstanceComponent` must not, since `Ability` already short-circuits their dispatch
- `on_passive_enabled(context: AbilityLifecycleContext) -> void` — Phase B2 Break: fires once when the last disabled source is removed; rebuilds state from the ability's current stacks/scale, does not backfill missed ticks

**State:**
- `get_state() -> String` / `is_active() -> bool` / `is_expired() -> bool`
- `mark_expired() -> void`
- `get_ability() -> Ability`

---

## AbilityComponentConfig (extends RefCounted)

Base config class. Must implement `create_component() -> AbilityComponent`.

---

## AbilityLifecycleContext (extends RefCounted)

Context passed through ability lifecycle methods. **Stack-scoped**: never store it (or its `instance`) in a Component / Ability field — `instance` is a strong reference, so caching it closes an instance → actor → ability → component → context cycle.

**Properties:**
- `owner_actor_id: String`
- `attribute_set: BaseGeneratedAttributeSet`
- `ability: Ability`
- `ability_set: AbilitySet`
- `instance: GameplayInstance` — The owner's instance, looked up by `owner_actor_id` (5th and last constructor argument); `null` when the owner isn't registered in `GameWorld`
- `event_processor: EventProcessor` — Derived read-only: `instance.event_processor`, `null` when `instance` is `null`; assigning to it asserts. Every construction point (directed delivery, grant, `can_activate`, on_remove / stacks / Break hooks, pre / post handler rebuild) therefore gets the same processor

**Live count:** `static get_live_count() -> int` — Live instances, counted in every build (`_init` increments, `NOTIFICATION_PREDELETE` decrements). Contexts are stack-scoped, so tests assert the count is back to its baseline once the call returns (release test per case, hex `smoke_skill_scenarios` and inkmon `smoke_m1_battle` at the end)

**Factories** (registry lookups by owner id; `AbilitySet` builds its own contexts directly — it is the set, so only the instance is looked up):
- `static rebuild_for_handler(owner_id: String, ability_id: String, event_dict: Dictionary, phase: String) -> AbilityLifecycleContext` — Pre / post handler rebuild: instance → actor → `actor.is_event_responsive(event_dict, phase)` → AbilitySet → ability (not expired); `null` if any step fails, and the handler skips
- `static for_ability(ability: Ability) -> AbilityLifecycleContext` — on_remove / stacks / Break hooks: never `null`; `instance` is `null` when the owner id resolves to no registered instance, `attribute_set` / `ability_set` are `null` when the owner isn't in that instance or isn't a `BattleActor`

---

## AbilityExecutionInstance (extends RefCounted)

Timeline-based execution instance for ability effects.

**States:** `STATE_EXECUTING`, `STATE_COMPLETED`, `STATE_CANCELLED`

**Properties:**
- `id: String` / `timeline_id: String` (derived from the `TimelineData` passed at construction; read by playback/events)

**Methods:**
- `get_elapsed() -> float` / `get_state() -> String`
- `is_executing() -> bool` / `is_completed() -> bool` / `is_cancelled() -> bool`
- `get_trigger_event() -> Dictionary`
- `tick(dt: float) -> Array[String]` — Returns completed tag names
- `cancel() -> void` — No-op unless still `STATE_EXECUTING`; sets `STATE_CANCELLED`, then synchronously runs the config's `on_cancel` actions. Like every context this execution builds, the cancel context's `instance` is looked up from the ability owner's id, so revoke/expire cleanup resolves the world without anyone passing it in

**Timeline behaviour** (`core/abilities/core/ability_execution_instance.gd`):
- **Same-timestamp tags fire in definition order** — tags due in one tick are sorted by `(tag_time, definition index in TimelineData.tags)`. `Array.sort_custom` is unstable, so without the tie-break the execution order of same-instant tags depended on the sort implementation and broke replay determinism. Author order = execution order
- **Loop timelines carry the overflow across cycles** — when `_elapsed` passes `total_duration`, the remainder becomes the next round's starting `_elapsed` instead of being zeroed, and the carried window `(0, carry]` is re-scanned in the *same* tick so tags inside it are not skipped by the next tick's window start. The final round (once `max_loops` is reached) does not carry over. Zeroing used to stretch every cycle to the tick boundary, making DOT/HOT cadence drift with the caller's `dt`
- Loop mode asserts `dt <= total_duration` (a single tick may not straddle a whole cycle)

---

## Core Components

### ActiveUseConfig (extends AbilityComponentConfig)

Active skill with triggers, conditions, costs, and timeline execution.

```gdscript
ActiveUseConfig.builder()
    .timeline(SLASH_TIMELINE)            # required: a static TimelineData; tags frozen on declaration
    .trigger(TriggerConfig.ABILITY_ACTIVATE)
    .on_timeline_start([StageCueAction.new(...)])
    .on_tag(TimelineTags.HIT, [DamageAction.new(...)])
    .on_timeline_end([...])
    .on_cancel([ReleaseReservationAction.new(...)])   # cleanup that MUST run if the execution is cancelled
    .condition(my_condition)
    .cost(my_cost)
    .build()
```

`.timeline(data)` asserts `data != null and data.id != ""` and calls `data.tags.make_read_only()` (idempotent — shared standard timelines pass through it many times); `build()` asserts a timeline was bound, so a missing timeline is a **build-time crash**, not a runtime surprise.

**`.on_cancel(actions)`** (`core/abilities/components/active_use_config.gd`): actions that run synchronously when the execution is *cancelled* — not the same as finishing. Cancellation happens on stun/interrupt (hex `HexBattleCancelActiveExecutionsAction`), on `Ability.expire()` (revoke/dispel), and on `Ability.cancel_all_executions()`. Put resource releases here — the canonical case is hex `move.gd`'s `.on_cancel([HexBattleCancelMoveAction.new(...)])`, releasing the destination tile reserved by phase 1. `ActivateInstanceConfig` exposes the same builder method.

**`on_timeline_start`/`on_timeline_end` vs `on_tag`** (`core/abilities/components/active_use_config.gd`): `on_tag` actions fire *asynchronously*, ticked at their timeline `tag_time`. `on_timeline_start`/`on_timeline_end` actions fire *synchronously*, inline with the `activate`/`tick` call chain — `on_timeline_start` the instant the execution instance activates (or a loop restarts), `on_timeline_end` when a timeline round completes. Use them where an effect needs an atomic/immediate guarantee (e.g. `grid.reserve_tile`, `StageCueAction`). In loop mode both fire on every iteration. `ActivateInstanceConfig` exposes the same two builder methods.

### ActivateInstanceConfig (extends AbilityComponentConfig)

Timeline execution without conditions/costs (for passive triggers).

```gdscript
ActivateInstanceConfig.builder()
    .timeline(COUNTER_TIMELINE)          # required: a static TimelineData; tags frozen on declaration
    .trigger(TriggerConfig.new("damage", filter_fn))
    .on_tag("hit", [CounterAction.new(...)])
    .build()
```

### NoInstanceConfig (extends AbilityComponentConfig)

Direct action execution without timeline (immediate effects).

```gdscript
NoInstanceConfig.builder()
    .trigger(TriggerConfig.new("damage", filter_fn))
    .action(HealAction.new(...))
    .build()
```

**Lifecycle actions** (`core/abilities/components/no_instance_config.gd`, §0.6): `.on_apply_actions(acts)` runs when the ability grants, `.on_remove_actions(acts)` runs when it's removed (expire/revoke). These need no `trigger` — a builder configured with only lifecycle actions is valid on its own (`trigger + action` still requires `trigger` to be non-empty if `action(...)` is used).

```gdscript
NoInstanceConfig.builder() \
    .on_apply_actions([LooseTagAction.Apply.new(...)])
    .on_remove_actions([LooseTagAction.Remove.new(...)])
    .build()
```

### PreEventConfig (extends AbilityComponentConfig)

Pre-event handler for modifying/cancelling events before execution.

**Properties:**
- `event_kind: String` — Event type to listen for
- `handler: Callable` — `func(MutableEvent, AbilityLifecycleContext) -> Intent`
- `filter: Callable` — Optional `func(Dictionary, AbilityLifecycleContext) -> bool`
- `name: String` — Display name for debugging

### TagComponentConfig / TagComponent (extends AbilityComponentConfig / AbilityComponent)

Grants a fixed set of tags to the owner's `AbilitySet` when the ability applies (via `_add_component_tags`), removes them on removal — the tags are tied to the ability instance's own lifecycle instead of manual add/remove bookkeeping. Not for stance switching (that's loose tags) or for stacking action-locks (component tags on separate ability instances don't clobber each other the way loose-tag remove can).

```gdscript
TagComponentConfig.builder()
    .tag("action_locked")
    .tag("cant_act")
    .optional_tag(reason_tag)   # no-op if reason_tag is ""
    .build()
```

See `core/abilities/components/tag_component_config.gd`.

---

## Supporting Classes

### TriggerConfig (extends RefCounted)

Event trigger configuration.

- `event_kind: String` — Event type to match
- `filter: Callable` — Optional filter function
- `static ABILITY_ACTIVATE: TriggerConfig` — Default trigger for active skills
- `static GRANTED_SELF: TriggerConfig` — Fires when this exact ability instance is granted to its owner (matches by instance id, not config_id, so sibling instances of the same config don't cross-activate). Typical use: a buff pairs `ActivateInstanceConfig` + this trigger + a loop timeline to self-activate a DOT the moment it's granted. See `core/abilities/shared/trigger_config.gd:24-42`.

### Condition (extends AbilityComponent)

Shared objects — MUST NOT store mutable state. See conventions §3.

- `check(_ctx: AbilityLifecycleContext, _event_dict: Dictionary) -> bool`
- `get_fail_reason(_ctx: AbilityLifecycleContext, _event_dict: Dictionary) -> String`
- `get_condition_type() -> String` — Returns `"condition"` by default; built-ins override it for debug labeling (e.g. `HexBattleCooldownSystem.CooldownCondition` returns `"cooldown_ready"`)

**Built-in:** `HasTagCondition`, `NoTagCondition`, `TagStacksCondition`, `AllConditions`, `AnyCondition`

### Cost (extends RefCounted)

Shared objects — MUST NOT store mutable state. See conventions §3.

**Properties:**
- `type: String` — Cost type identifier, default `"cost"`

**Methods:**
- `can_pay(_ctx: AbilityLifecycleContext, _event_dict: Dictionary) -> bool`
- `pay(_ctx: AbilityLifecycleContext, _event_dict: Dictionary) -> void`
- `get_fail_reason(_ctx: AbilityLifecycleContext, _event_dict: Dictionary) -> String`

**Built-in:** `ConsumeTagCost`, `RemoveTagCost`, `AddTagCost`

### AbilityActivationQuery (static utility)

`core/abilities/shared/ability_activation_query.gd` — the single source for the result shape shared by `AbilitySet.can_activate` / `Ability.can_activate` / `ActiveUseComponent.can_activate`. An in-process `Dictionary` (not a serialization boundary), so the keys are snake_case.

**Result keys:** `KEY_ALLOWED` = `"allowed"` (bool) / `KEY_REASON` = `"reason"` (String) / `KEY_FAILED_COMPONENT_TYPE` = `"failed_component_type"` (String)

**`failed_component_type` values:** `FAILED_ABILITY` = `"ability"` (ability-level short-circuit: not granted / disabled) · `FAILED_CONDITION` = `"condition"` (a `Condition.check` said no) · `FAILED_COST` = `"cost"` (a `Cost.can_pay` said no). The last two use the same vocabulary as `GameEvent.AbilityActivateFailed`, so the query and the real activation path attribute the same failure the same way.

**Builders:** `static allowed() -> Dictionary` / `static denied(reason: String, failed_component_type: String) -> Dictionary` / `static is_allowed(result: Dictionary) -> bool`

`ActiveUseComponent.can_activate(context, event_dict = {})` evaluates the gate in the same order the activation path does — all `Condition.check` first, then all `Cost.can_pay` — returning on the first failure with `get_fail_reason()` as `reason` (falling back to `condition.get_condition_type()` / `cost.type` when the reason is empty). It deliberately does **not** match triggers: a trigger says *when to dispatch an event to this component*, and a pre-cast query has no event to match; `event_dict` is only a simulated input. It pays nothing, pushes no `AbilityActivateFailed`, creates no execution, and is re-entrant.

### Getting an AbilitySet from an Actor

Use `BattleActor.ability_set_of(actor) -> AbilitySet` (see [entity.md](entity.md#battleactor-extends-actor)).
Returns `null` for a non-BattleActor or a data-only one.
