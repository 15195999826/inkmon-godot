# Stdlib API

## Contents
- [Components](#components) (StatModifier, TimeDuration, Stack, DynamicStatModifier)
- [Systems](#systems) (ProjectileSystem, CollisionDetector)
- [Replay](#replay) (BattleRecorder, ReplayData, RecordingUtils)
- [Timeline](#timeline) (Timeline Autoload, TimelineData)
- [Interfaces](#interfaces) (IAbilitySetOwner, IGameStateProvider)
- [Utils](#utils) (Log, IdGenerator, StateCheck)

## Components

### StatModifierComponent (extends AbilityComponent)

Applies static attribute modifiers when ability is granted, removes on revoke.

**Properties:**
- `configs: Array[StatModifierConfig.ModifierEntry]`
- `applied_modifiers: Array[AttributeModifier]`
- `current_scale: float`

**Methods:**
- `on_apply(context: AbilityLifecycleContext) -> void` / `on_remove(context: AbilityLifecycleContext) -> void`
- `get_modifiers() -> Array[AttributeModifier]` / `get_modifier_ids() -> Array[String]`
- `set_scale(scale: float) -> void` — Scale all modifier values
- `scale_by_stacks(stacks: int) -> void` — Scale = stacks count

**Config:** `StatModifierConfig.builder()` with `ModifierEntry` inner class.

### TimeDurationComponent (extends AbilityComponent)

Time-based ability expiration.

**Constants:** `EXPIRE_REASON_TIME_DURATION`

**Properties:** `initial_duration: float` / `remaining: float`

**Methods:**
- `on_tick(dt: float) -> void` — Decrements remaining, expires ability when 0
- `get_remaining() -> float` / `get_initial_duration() -> float` / `get_progress() -> float`
- `refresh() -> void` — Reset to initial duration
- `extend(amount_ms: float) -> void`

**Config:** `TimeDurationConfig.new(duration_ms)`

### StackComponent (extends AbilityComponent)

Stack count management with overflow policies.

**Enum:** `StackOverflowPolicy { CAP, REFRESH, REJECT }`

**Properties:** `stacks: int` / `max_stacks: int` / `overflow_policy: StackOverflowPolicy`

**Methods:**
- `get_stacks() -> int` / `get_max_stacks() -> int` / `is_full() -> bool`
- `add_stacks(count: int) -> int` — Returns actual added
- `remove_stacks(count: int) -> int` — Returns actual removed
- `set_stacks(count: int) -> void` / `reset() -> void`

### DynamicStatModifierComponent (extends AbilityComponent)

Modifier that dynamically tracks another attribute value.

**Config:** `DynamicStatModifierConfig` with `source_attribute`, `target_attribute`, `modifier_type`, `coefficient`.

---

## Systems

### ProjectileSystem (extends System)

Projectile simulation with pluggable collision detection.

**Properties:**
- `collision_detector: CollisionDetector`
- `event_collector: EventCollector`
- `auto_remove: bool`

**Methods:**
- `tick(actors: Array[Actor], dt: float) -> void`
- `get_active_projectiles(actors: Array[Actor]) -> Array[ProjectileActor]`
- `force_hit(projectile: ProjectileActor, target_actor_id: String, hit_position: Vector3) -> void`
- `force_miss(projectile: ProjectileActor, reason: String = "forced") -> void`

### CollisionDetector (extends RefCounted)

Base class for collision strategies.

- `detect(projectile: ProjectileActor, potential_targets: Array[Actor]) -> Dictionary`

**Implementations:**
- `DistanceCollisionDetector` — Distance-based (`hit_distance: float`)
- `MobaCollisionDetector` — Homing/tracking collision
- `CompositeCollisionDetector` — Combines multiple detectors via `add(detector) -> self`

---

## Replay

### BattleRecorder (extends RefCounted)

Records battle events for replay.

**Properties:** `is_recording: bool` / `current_frame: int`

**Methods:**
- `start_recording(actors: Array, configs_value: Dictionary = {}, map_config_value: Dictionary = {}) -> void`
- `record_frame(frame: int, events: Array[Dictionary]) -> void`
- `stop_recording(result = "") -> Dictionary`
- `export_json(result = "", pretty = true) -> String`
- `register_actor(actor: Actor) -> void` / `unregister_actor(actor_id, reason = "") -> void`

### ReplayData

Data structures with serialization.

**Inner Classes:**
- `BattleRecord` — `version`, `meta`, `configs`, `map_config`, `initial_actors`, `timeline`
- `BattleMeta` — `battle_id`, `recorded_at`, `tick_interval`, `total_frames`, `result`
- `FrameData` — `frame`, `events`
- `ActorInitData` — `id`, `type`, `config_id`, `display_name`, `team`, `position`, `attributes`, `abilities`, `tags`

Each has `to_dict()` and `static from_dict()`.

### RecordingUtils (static utility)

- `static record_attribute_changes(attr_set, ctx) -> Array[Callable]`
- `static record_ability_set_changes(ability_set, ctx) -> Array[Callable]`
- `static record_tag_changes(tag_container, ctx) -> Callable`
- `static record_actor_lifecycle(actor, ctx) -> Array[Callable]`

---

## Timeline

### Timeline (extends Node) — Autoload registry

- `register(timeline: TimelineData) -> void` / `register_all(timelines: Array[TimelineData]) -> void`
- `get_timeline(timeline_id: String) -> TimelineData` / `has(timeline_id: String) -> bool`
- `get_all_ids() -> Array[String]` / `reset() -> void`

### TimelineData (extends RefCounted)

**Properties:** `id: String` / `total_duration: float` / `tags: Dictionary`

**Methods:**
- `get_tag_time(tag_name: String) -> float`
- `get_tag_names() -> Array[String]`
- `get_sorted_tags() -> Array[Dictionary]`
- `validate() -> Array[String]`

---

## Interfaces

### IAbilitySetOwner (static utility)

- `static get_ability_set(owner: Object) -> AbilitySet`
- `static is_implemented(owner: Object) -> bool`

### IGameStateProvider (static utility)

- `static get_logic_time(provider: Variant) -> float`
- `static is_implemented(provider: Variant) -> bool`

---

## Utils

### Log (extends Node) — Autoload

**Levels:** `DEBUG`, `INFO`, `WARNING`, `ERROR`, `NONE`

- `debug(module, message)` / `info(module, message)` / `warning(module, message)` / `error(module, message)`
- `set_level(level)` / `set_enabled(value)` / `set_production_mode()` / `set_debug_mode()`

### IdGenerator (extends Node)

- `static generate_id(prefix: String) -> String`
- `static generate(prefix = "") -> String`

### StateCheck (static utility)

Debug tool for validating shared instance immutability.

- `static is_enabled() -> bool`
- `static freeze(obj: Object) -> int` — Returns hash
- `static verify(obj: Object, frozen_hash: int, label: String) -> void` — Asserts unchanged
