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

**Properties:**
- `id: String` — Unique instance ID
- `config_id: String` — Reference to AbilityConfig
- `source_actor_id: String` — Actor that granted this ability
- `owner_actor_id: String` — Actor that owns this ability
- `display_name: String` / `description: String` / `icon: String`
- `ability_tags: Array[String]` — Tags for categorization
- `metadata: Dictionary` — Custom metadata

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

**Execution:**
- `activate_new_execution_instance(...) -> AbilityExecutionInstance`
- `get_executing_instances() -> Array[AbilityExecutionInstance]`
- `get_all_execution_instances() -> Array[AbilityExecutionInstance]`
- `cancel_all_executions() -> void`
- `tick_executions(dt: float) -> Array[String]`

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

**Builder:**
```gdscript
AbilityConfig.builder()
    .config_id("slash")
    .display_name("Slash")
    .ability_tags(["melee", "physical"])
    .active_use(active_use_config)
    .component_config(stat_modifier_config)
    .meta("cooldown", 5.0)
    .build()
```

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
- `grant_ability(ability: Ability) -> void`
- `revoke_ability(ability_id: String, reason: String = REVOKE_REASON_MANUAL, expire_reason: String = "") -> bool`
- `revoke_abilities_by_config_id(config_id: String, reason: String) -> int`
- `revoke_abilities_by_ability_tag(tag: String, reason: String) -> int`

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
- `tick_executions(dt: float) -> Array[String]`
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
    .condition(my_condition)
    .cost(my_cost)
    .on_tag(TimelineTags.HIT, [DamageAction.new(...)])
    .build()
```

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

### PreEventConfig (extends AbilityComponentConfig)

Pre-event handler for modifying/cancelling events before execution.

**Properties:**
- `event_kind: String` — Event type to listen for
- `handler: Callable` — `func(MutableEvent, AbilityLifecycleContext) -> Intent`
- `filter: Callable` — Optional `func(Dictionary, AbilityLifecycleContext) -> bool`
- `name: String` — Display name for debugging

### TagComponent (extends AbilityComponent)

Grants tags to owner when ability is applied, removes on removal.

---

## Supporting Classes

### TriggerConfig (extends RefCounted)

Event trigger configuration.

- `event_kind: String` — Event type to match
- `filter: Callable` — Optional filter function
- `static ABILITY_ACTIVATE: TriggerConfig` — Default trigger for active skills

### Condition (extends AbilityComponent)

Shared objects — MUST NOT store mutable state. See conventions §3.

- `check(_ctx: AbilityLifecycleContext, _event_dict: Dictionary, _game_state: Variant) -> bool`
- `get_fail_reason(_ctx: AbilityLifecycleContext, _event_dict: Dictionary, _game_state: Variant) -> String`

**Built-in:** `HasTagCondition`, `NoTagCondition`, `TagStacksCondition`, `AllConditions`, `AnyCondition`

### Cost (extends RefCounted)

Shared objects — MUST NOT store mutable state. See conventions §3.

- `can_pay(_ctx: AbilityLifecycleContext, _event_dict: Dictionary, _game_state: Variant) -> bool`
- `pay(_ctx: AbilityLifecycleContext, _event_dict: Dictionary, _game_state: Variant) -> void`
- `get_fail_reason(_ctx: AbilityLifecycleContext, _event_dict: Dictionary, _game_state: Variant) -> String`

**Built-in:** `ConsumeTagCost`, `RemoveTagCost`, `AddTagCost`

### IAbilitySetOwner (static utility)

- `static get_ability_set(owner: Object) -> AbilitySet`
- `static is_implemented(owner: Object) -> bool`
