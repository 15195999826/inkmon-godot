# Entity & World API

## Contents
- [Actor](#actor-extends-refcounted)
- [System](#system-extends-refcounted)
- [GameWorld — Autoload](#gameworld-extends-node--autoload)
- [GameplayInstance](#gameplayinstance-extends-refcounted)

## Actor (extends RefCounted)

Base entity class. All game entities extend Actor.

**Properties:**
- `type: String` — Actor type identifier (default "actor")
- `id: String` — Assigned by framework after `add_actor()`
- `config_id: String` — Configuration identifier
- `display_name: String` — Human-readable name
- `team: int` — Team identifier
- `position: Vector3` — Current position

**Lifecycle:**
- `on_spawn() -> void` — Called when actor is added to instance
- `on_despawn() -> void` — Called when actor is removed
- `add_spawn_listener(callback: Callable) -> Callable` — Returns unsubscribe function
- `add_despawn_listener(callback: Callable) -> Callable` — Returns unsubscribe function

**ID & Instance:**
- `get_id() -> String`
- `is_id_valid() -> bool`
- `set_id(id_value: String) -> void`
- `get_gameplay_instance_id() -> String`
- `get_owner_gameplay_instance() -> GameplayInstance` — Uses stored `_instance_id` to avoid circular refs

**Recording:**
- `setup_recording(_ctx: RecordingContext) -> Array[Callable]`
- `get_attribute_snapshot() -> Dictionary`
- `get_ability_snapshot() -> Array[Dictionary]`
- `get_tag_snapshot() -> Dictionary`
- `get_position_snapshot() -> Array[float]`
- `serialize_base() -> Dictionary`

---

## System (extends RefCounted)

Base class for game logic systems (ECS-style). Registered on GameplayInstance, ticked each frame.

**Constants:**
- `SystemPriority` — `HIGHEST=0`, `HIGH=100`, `NORMAL=500`, `LOW=900`, `LOWEST=1000`

**Properties:**
- `type: String` — System type identifier
- `priority: int` — Tick order (lower = earlier)

**Lifecycle:**
- `on_register(instance: GameplayInstance) -> void`
- `on_unregister() -> void`
- `tick(_actors: Array[Actor], _dt: float) -> void` — Override for per-frame logic

**Utilities:**
- `get_enabled() -> bool` / `set_enabled(value: bool) -> void`
- `get_logic_time() -> float`
- `filter_actors_by_type(actors: Array[Actor], actor_type: String) -> Array[Actor]`

**Inner Class:** `NoopSystem` — Empty system placeholder

---

## GameWorld (extends Node) — Autoload

Global singleton managing all gameplay instances.

**Properties:**
- `event_processor: EventProcessor`
- `event_collector: EventCollector`

**Lifecycle:**
- `init(config: EventProcessorConfig = null) -> void`
- `destroy() -> void`

**Instance Management:**
- `create_instance(factory: Callable) -> GameplayInstance`
- `get_instance_by_id(id_value: String) -> GameplayInstance`
- `get_instances_by_type(type_value: String) -> Array[GameplayInstance]`
- `destroy_instance(id_value: String) -> bool`
- `destroy_all_instances() -> void`
- `tick_all(dt: float) -> void`
- `get_instance_count() -> int`
- `has_running_instances() -> bool`
- `get_actor(actor_id: String) -> Actor` — Global actor lookup by full ID

---

## GameplayInstance (extends RefCounted)

Individual gameplay session containing actors and systems.

**Properties:**
- `id: String`
- `type: String` — Instance type (default "instance")

**State:**
- `get_logic_time() -> float`
- `get_state() -> String`
- `is_running() -> bool`

**Lifecycle:**
- `start() -> void` / `pause() -> void` / `resume() -> void` / `end() -> void`
- `tick(_dt: float) -> void` — Override for custom tick logic
- `base_tick(dt: float) -> void` — Ticks systems and abilities
- `on_start()` / `on_pause()` / `on_resume()` / `on_end()` — Override hooks

**Actor Management:**
- `add_actor(actor: Actor) -> Actor`
- `remove_actor(actor_id: String) -> bool`
- `get_actor(actor_id: String) -> Actor`
- `get_actors() -> Array[Actor]`
- `get_actors_by_type(actor_type: String) -> Array[Actor]`
- `find_actors(predicate: Callable) -> Array[Actor]`
- `get_actor_count() -> int`

**System Management:**
- `add_system(system: System) -> void`
- `remove_system(system_type: String) -> bool`
- `get_system(system_type: String) -> System`
- `get_systems() -> Array[System]`
