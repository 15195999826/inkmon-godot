# Stdlib API

Only [Components](#components) and [Systems](#systems) genuinely live under `stdlib/`. [Replay](#replay), [Timeline](#timeline), [Interfaces](#interfaces), and [Utils](#utils) are `core/` classes kept in this doc for lookup convenience — each section below has a `Location:` note with the real path.

## Contents
- [Components](#components) (StatModifier, TimeDuration, DynamicStatModifier)
- [Systems](#systems) (ProjectileSystem, CollisionDetector)
- [Replay](#replay) (BattleRecorder, PlaybackData, RecordingUtils)
- [Timeline](#timeline) (Timeline Autoload, TimelineData)
- [Interfaces](#interfaces) (IAbilitySetOwner, IGameStateProvider)
- [Utils](#utils) (Log, IdGenerator, StateCheck)

## Components

*Location: `stdlib/components/`.*

### StatModifierComponent (extends AbilityComponent)

Applies static attribute modifiers when ability is granted, removes on revoke.

**Properties:**
- `configs: Array[StatModifierConfig.ModifierEntry]`
- `applied_modifiers: Array[AttributeModifier]`
- `current_scale: float`
- `scales_by_stacks: bool` — When true, modifier value = `config.value * ability.stacks`, kept in sync via `on_stacks_changed`

**Methods:**
- `on_apply(context: AbilityLifecycleContext) -> void` / `on_remove(context: AbilityLifecycleContext) -> void`
- `get_modifiers() -> Array[AttributeModifier]` / `get_modifier_ids() -> Array[String]`
- `set_scale(scale: float) -> void` — Sets `current_scale` only (`current_scale = scale`); does not retroactively update modifiers already applied to `RawAttributeSet` — those pick up the new scale next time modifiers are rebuilt (e.g. `on_passive_enabled`), not immediately
- `scale_by_stacks(stacks: int) -> void` — Convenience wrapper: `set_scale(float(stacks))`
- `on_stacks_changed(context: AbilityLifecycleContext, old_stacks: int, new_stacks: int) -> void` — No-op unless `scales_by_stacks`; otherwise recomputes `current_scale` from `new_stacks` and atomically updates every applied modifier via `RawAttributeSet.update_modifier` (not remove+add, avoids breakdown flicker)
- `on_passive_disabled(context: AbilityLifecycleContext) -> void` — Break hook (see abilities.md): removes all modifiers by source, keeps `configs`/`current_scale` so `on_passive_enabled` can rebuild
- `on_passive_enabled(context: AbilityLifecycleContext) -> void` — Break hook: rebuilds modifiers; if `scales_by_stacks`, re-reads `context.ability.get_stacks()` first since stacks may have changed while disabled

**Config:** `StatModifierConfig.builder()` with `ModifierEntry` inner class; `.scale_by_stacks()` enables the stacks-scaled mode (`stdlib/components/stat_modifier_config.gd`).

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

### ~~StackComponent~~ — removed

`StackComponent` no longer exists (no file under `stdlib/components/` defines it). Stacking is now a first-class field group directly on `Ability` itself — `stacks` / `max_stacks` / `overflow_policy`, with `OVERFLOW_CAP` / `OVERFLOW_REFRESH` / `OVERFLOW_REJECT` policies — not a component. See the "Stacks" and "Stack Overflow Policies" sections in [`abilities.md`](abilities.md).

### DynamicStatModifierComponent (extends AbilityComponent)

Modifier that dynamically tracks another attribute value.

**Config:** `DynamicStatModifierConfig` with `source_attribute`, `target_attribute`, `modifier_type`, `coefficient`.

---

## Systems

*Location: `stdlib/projectile/`.*

### ProjectileSystem (extends System)

Projectile simulation with pluggable collision detection.

**Properties:**
- `collision_detector: CollisionDetector`
- `event_collector: EventCollector`
- `pending_removal: Dictionary` — Projectile ids marked for removal this tick; flushed (actors removed from the instance) at the end of `tick()` when `auto_remove` is true
- `auto_remove: bool`

**Methods:**
- `set_event_collector(collector: EventCollector) -> void`
- `tick(actors: Array[Actor], dt: float) -> void`
- `get_active_projectiles(actors: Array[Actor]) -> Array[ProjectileActor]`
- `get_pending_removal_ids() -> Dictionary` — Duplicate of `pending_removal`
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

*Location: `core/playback/` (not `stdlib/`).*

### BattleRecorder (extends RefCounted)

Records battle events for replay.

**Properties:** `is_recording: bool` / `current_frame: int`

**Methods:**
- `start_recording(world_snapshot: PlaybackData.WorldSnapshot, actors: Array[Actor]) -> void` — The single recording path. `world_snapshot` (the opening state playback starts from) is produced by the world side (`WorldGameplayInstance.capture_world_snapshot()`) and injected — the recorder never captures it itself. `actors` = the actors to subscribe change callbacks on (normally `world.get_recordable_actors()`); subscriptions turn attribute/tag/ability changes into events for replay consumers
- `record_frame(frame: int, events: Array[Dictionary]) -> void`
- `stop_recording(result = "") -> Dictionary`
- `export_json(result = "", pretty = true) -> String`
- `get_timeline() -> Array[Dictionary]` — Returns frames recorded so far (`FrameData.to_dict()` each), without stopping the recording
- `register_actor(actor: Actor) -> void` / `unregister_actor(actor_id, reason = "") -> void` — Mid-battle spawns/despawns; pushes `ActorSpawned`/`ActorDestroyed` events and (de)subscribes

### PlaybackData

Data structures with serialization. Record shape: `{meta, world_snapshot, timeline}` — **no `version` field** (single architecture, replays are short-lived data; guard rails are required-key asserts in `BattleRecord.from_dict`, which crashes on a dict missing `world_snapshot`/`timeline`).

**Inner Classes:**
- `BattleRecord` — `meta`, `world_snapshot`, `timeline`
- `WorldSnapshot` — `actors: Array[ActorInitData]`, `map_config`, `position_formats`; the world-side opening state, produced by `WorldGameplayInstance.capture_world_snapshot()`
- `BattleMeta` — `battle_id`, `recorded_at`, `tick_interval`, `total_frames`, `result`
- `FrameData` — `frame`, `events`
- `ActorInitData` — `id`, `type`, `config_id`, `display_name`, `team`, `position`, `attributes` (playback never rebuilds the logic layer, so only visual-avatar fields are carried)

Each has `to_dict()` and `static from_dict()`.

### RecordingUtils (static utility)

- `static record_attribute_changes(attr_set, ctx) -> Array[Callable]`
- `static record_ability_set_changes(ability_set, ctx) -> Array[Callable]`
- `static record_tag_changes(tag_container, ctx) -> Callable`
- `static record_actor_lifecycle(actor, ctx) -> Array[Callable]`

---

## Timeline

*Location: `core/timeline/` (not `stdlib/`).*

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

*Location: `core/interfaces/` (not `stdlib/`).*

### IAbilitySetOwner (static utility)

- `static get_ability_set(owner: Object) -> AbilitySet`
- `static is_implemented(owner: Object) -> bool`

### IGameStateProvider (static utility)

- `static get_logic_time(provider: Variant) -> float`
- `static is_implemented(provider: Variant) -> bool`

---

## Utils

*Location: `core/utils/` (Log, IdGenerator) and `core/` (StateCheck) — not `stdlib/`.*

### Log (extends Node) — Autoload

**Levels:** `DEBUG`, `INFO`, `WARNING`, `ERROR`, `NONE`

- `debug(module, message)` / `info(module, message)` / `warning(module, message)` / `error(module, message)`
- `set_level(level)` / `set_enabled(value)` / `set_production_mode()` / `set_debug_mode()`

### IdGenerator (extends Node)

- `static generate_id(prefix: String) -> String` — Formats `"<prefix>_<counter>"` off a shared static counter, then increments it
- `static generate(prefix = "") -> String` — Alias for `generate_id(prefix)`
- `static reset_id_counter() -> void` — Resets the shared static counter to 0 (test isolation)
- `_init(prefix: String = "") -> void` / `generate_with_prefix() -> String` — Instance form: bind a prefix once via `_init`, then call `generate_with_prefix()` repeatedly instead of passing `prefix` to the static method each time

### StateCheck (static utility)

Debug tool for validating shared instance immutability.

- `static is_enabled() -> bool`
- `static freeze(obj: Object) -> int` — Returns hash
- `static verify(obj: Object, frozen_hash: int, label: String) -> void` — Asserts unchanged
