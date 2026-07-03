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
- [Supporting Classes](#supporting-classes) (TriggerConfig, Condition, Cost, IAbilitySetOwner)

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
- `apply_effects(context: AbilityLifecycleContext) -> void`
- `remove_effects() -> void`
- `expire(reason: String) -> void`

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

**Execution:**
- `activate_new_execution_instance(...) -> AbilityExecutionInstance`
- `get_executing_instances() -> Array[AbilityExecutionInstance]`
- `get_all_execution_instances() -> Array[AbilityExecutionInstance]`
- `cancel_all_executions() -> void`
- `tick_executions(dt: float, game_state_provider: Variant) -> Array[String]`

**Events:**
- `receive_event(event_dict: Dictionary, context: AbilityLifecycleContext, game_state_provider: Variant) -> void`
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

---

## AbilitySet (extends RefCounted)

Container for Abilities with tag management and grant/revoke operations.

**Revoke Reasons:** `REVOKE_REASON_EXPIRED`, `REVOKE_REASON_DISPELLED`, `REVOKE_REASON_REPLACED`, `REVOKE_REASON_MANUAL`

**Properties:**
- `owner_actor_id: String`
- `tag_container: TagContainer`

**Factory:**
- `static create(p_owner_actor_id: String, p_attribute_set: BaseGeneratedAttributeSet = null) -> AbilitySet`

**Grant/Revoke:**
- `grant_ability(ability: Ability, game_state_provider: Variant = null) -> void` — Passing a non-null `game_state_provider` synchronously broadcasts `AbilityGranted` to this ability_set's own abilities after grant (not the global event processor), so `TriggerConfig.GRANTED_SELF` can fire self-activating buffs
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

**Tags (delegates to TagContainer):**
- `add_loose_tag(tag: String, stacks: int = 1) -> void`
- `remove_loose_tag(tag: String, stacks: int = -1) -> bool`
- `add_auto_duration_tag(tag: String, duration: float) -> void`
- `has_tag(tag: String) -> bool` / `get_tag_stacks(tag: String) -> int`
- `get_all_tags() -> Dictionary`
- `has_loose_tag(tag: String) -> bool` / `get_loose_tag_stacks(tag: String) -> int`

**Tick & Events:**
- `tick(dt: float, logic_time: float = -1.0) -> void`
- `tick_executions(dt: float, game_state_provider: Variant) -> Array[String]`
- `receive_event(event_dict: Dictionary, game_state_provider: Variant) -> void`
- `get_event_processor() -> EventProcessor`
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
- `on_event(event_dict: Dictionary, context: AbilityLifecycleContext, game_state_provider: Variant) -> bool`
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

Context passed through ability lifecycle methods.

**Properties:**
- `owner_actor_id: String`
- `attribute_set: BaseGeneratedAttributeSet`
- `ability: Ability`
- `ability_set: AbilitySet`
- `event_processor: EventProcessor`

---

## AbilityExecutionInstance (extends RefCounted)

Timeline-based execution instance for ability effects.

**States:** `STATE_EXECUTING`, `STATE_COMPLETED`, `STATE_CANCELLED`

**Properties:**
- `id: String` / `timeline_id: String`

**Methods:**
- `get_elapsed() -> float` / `get_state() -> String`
- `is_executing() -> bool` / `is_completed() -> bool` / `is_cancelled() -> bool`
- `get_trigger_event() -> Dictionary`
- `tick(dt: float) -> Array[String]` — Returns completed tag names
- `cancel() -> void`

---

## Core Components

### ActiveUseConfig (extends AbilityComponentConfig)

Active skill with triggers, conditions, costs, and timeline execution.

```gdscript
ActiveUseConfig.builder()
    .timeline_id("slash_timeline")       # required
    .trigger(TriggerConfig.ABILITY_ACTIVATE)
    .on_timeline_start([StageCueAction.new(...)])
    .on_tag(TimelineTags.HIT, [DamageAction.new(...)])
    .on_timeline_end([...])
    .condition(my_condition)
    .cost(my_cost)
    .build()
```

**`on_timeline_start`/`on_timeline_end` vs `on_tag`** (`core/abilities/components/active_use_config.gd`): `on_tag` actions fire *asynchronously*, ticked at their timeline `tag_time`. `on_timeline_start`/`on_timeline_end` actions fire *synchronously*, inline with the `activate`/`tick` call chain — `on_timeline_start` the instant the execution instance activates (or a loop restarts), `on_timeline_end` when a timeline round completes. Use them where an effect needs an atomic/immediate guarantee (e.g. `grid.reserve_tile`, `StageCueAction`). In loop mode both fire on every iteration. `ActivateInstanceConfig` exposes the same two builder methods.

### ActivateInstanceConfig (extends AbilityComponentConfig)

Timeline execution without conditions/costs (for passive triggers).

```gdscript
ActivateInstanceConfig.builder()
    .timeline_id("counter_timeline")     # required
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

- `check(_ctx: AbilityLifecycleContext, _event_dict: Dictionary, _game_state: Variant) -> bool`
- `get_fail_reason(_ctx: AbilityLifecycleContext, _event_dict: Dictionary, _game_state: Variant) -> String`
- `get_condition_type() -> String` — Returns `"condition"` by default; built-ins override it for debug labeling (e.g. `HexBattleCooldownSystem.CooldownCondition` returns `"cooldown_ready"`)

**Built-in:** `HasTagCondition`, `NoTagCondition`, `TagStacksCondition`, `AllConditions`, `AnyCondition`

### Cost (extends RefCounted)

Shared objects — MUST NOT store mutable state. See conventions §3.

**Properties:**
- `type: String` — Cost type identifier, default `"cost"`

**Methods:**
- `can_pay(_ctx: AbilityLifecycleContext, _event_dict: Dictionary, _game_state: Variant) -> bool`
- `pay(_ctx: AbilityLifecycleContext, _event_dict: Dictionary, _game_state: Variant) -> void`
- `get_fail_reason(_ctx: AbilityLifecycleContext, _event_dict: Dictionary, _game_state: Variant) -> String`

**Built-in:** `ConsumeTagCost`, `RemoveTagCost`, `AddTagCost`

### IAbilitySetOwner (static utility)

- `static get_ability_set(owner: Object) -> AbilitySet`
- `static is_implemented(owner: Object) -> bool`
