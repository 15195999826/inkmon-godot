# Entity & World API

## Contents
- [Actor](#actor-extends-refcounted)
- [System](#system-extends-refcounted)
- [GameWorld — Autoload](#gameworld-extends-node--autoload)
- [GameplayInstance](#gameplayinstance-extends-refcounted)
- [WorldGameplayInstance](#worldgameplayinstance-extends-gameplayinstance)
- [BattleProcedure](#battleprocedure-extends-refcounted)
- [ActorId](#actorid-static-utility)

## Actor (extends RefCounted)

Base entity class. All game entities extend Actor.

**Properties:**
- `type: String` — Actor type identifier (default "actor")
- `id: String` — Assigned by framework after `add_actor()`
- `config_id: String` — Read-only; override `_get_config_id() -> String` in subclasses (default returns `type`)
- `display_name: String` — Get: `_display_name` if set, else auto `"%s_%s" % [type, get_id()]`; set via `set_display_name()`
- `team: int` — **Read-only** BattleRecorder-compat int view of `_team` (via `_get_team_int()`); use `get_team() -> String` / `set_team(value: String) -> void` for the real team identifier (Actor.gd:62-66)
- `position: Vector3` — Read-only; override `_get_position() -> Vector3` in subclasses (default `Vector3.ZERO`)

**Lifecycle:**
- `is_pre_event_responsive() -> bool` — Default `true`; override so an actor in an unresponsive state (dead/silenced/stunned) opts out of PreEvent handler dispatch for this instant. Other dispatch paths (POST event / tick / receive_event) are unaffected (Actor.gd:58-59)
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
- `get_debug_info() -> Dictionary` — `{ initialized, instanceCount, instances: [{id, type, state, actorCount}] }` (game_world.gd:95-108)
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
- `base_tick(dt: float) -> void` — Ticks registered systems only (gameplay_instance.gd:30-36). Does NOT tick abilities — `ability_set.tick()` / `tick_executions()` are called per-actor by example-layer `BattleProcedure` subclasses (e.g. `HexBattleProcedure`), not by this base class
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

---

## WorldGameplayInstance (extends GameplayInstance)

World-owns-Battle architecture: the long-lived world instance that owns the actor registry, grid, and systems. Battles are short-lived `BattleProcedure` objects it creates and holds transiently — not separate instances. Signals fire only during non-battle periods (actor enter/exit world, NPC movement, buff expiry); during battle, frontend consumes `event_timeline` replay via BattleAnimator instead (world_gameplay_instance.gd:1-8).

**Constants:**
- `BATTLE_TICKS_PER_WORLD_FRAME: int` — Battle ticks advanced per world tick (default `INT_MAX`: battle runs to completion within one world tick; lower to spread a long battle across multiple world frames)

**Signals** (non-battle periods only — during battle, frontend consumes `event_timeline` replay instead):
- `actor_added(actor_id: String)` / `actor_removed(actor_id: String)`
- `actor_position_changed(actor_id: String, old_coord: HexCoord, new_coord: HexCoord)`
- `grid_configured(config: GridMapConfig)` / `grid_cell_changed(coord: HexCoord, change_type: String)`
- `battle_finished(timeline: Dictionary)`

**Properties:**
- `grid: GridMapModel`

**Construction:**
- `_init(id_value: String = "") -> void` — `id_value` defaults to `IdGenerator.generate("world")`; sets `type = "world"`

**Mutation API** (fires the signals above):
- `add_actor(actor: Actor, after_id_assigned: Callable = Callable()) -> Actor` — `after_id_assigned` runs after ID assignment but before `actor_added` fires, so spawn code can init position/team/abilities before observers can snapshot the actor
- `remove_actor(actor_id: String) -> bool`
- `configure_grid(config: GridMapConfig) -> void` — Override to plug in a concrete grid backend (e.g. `UGridMap` autoload); subclasses must emit `grid_configured` last

**Battle Scheduling:**
- `start_battle(participants: Array[Actor]) -> BattleProcedure` — Asserts no battle already active (MVP: one battle at a time); delegates construction to `_create_battle_procedure()`
- `_create_battle_procedure(participants: Array[Actor]) -> BattleProcedure` — Factory hook; override to return a concrete subclass (e.g. `HexBattleProcedure`)
- `has_active_battle() -> bool` / `get_active_battle() -> BattleProcedure`

**Tick:**
- `tick(dt: float) -> void` — With no active battle, delegates to `base_tick()`. With an active battle, this frame is spent exclusively on `_active_battle.tick_once()` (world systems do NOT tick) up to `BATTLE_TICKS_PER_WORLD_FRAME` times or until `should_end()`; on end, `_active_battle` is nulled *before* `battle_finished` emits, so a handler may safely call `start_battle()` again re-entrantly (world_gameplay_instance.gd:106-119)

---

## BattleProcedure (extends RefCounted)

A battle is a *procedure*, not an *instance*. `WorldGameplayInstance` holds one transiently (`_active_battle`) and releases it when the battle ends. The procedure borrows actors that live in the world and mutates them directly during `tick_once()` — there is no separate battle-owned actor copy; once the battle ends, the world is already in its final state (battle_procedure.gd:1-8).

The base class provides only the skeleton (participant tracking, `in_combat` tag hook, recorder lifecycle). Concrete ATB/turn-based pacing and win/loss determination are subclass responsibilities via `tick_once()` / `should_end()` overrides.

**Constants:**
- `DEFAULT_TICK_INTERVAL: float = 100.0`

**Construction:**
- `_init(world: WorldGameplayInstance, participants: Array[Actor])` — Stores `world` as a `WeakRef`; snapshots participant IDs

**Lifecycle:**
- `start() -> void` — Tags participants `in_combat`, constructs a `BattleRecorder`, calls `_start_recorder()`
- `_start_recorder() -> void` — Virtual hook; default calls `start_recording_events_only()` (no initial-actor snapshot). Override to use the legacy `start_recording(actors, configs, map_config)` path
- `tick_once() -> void` — Virtual; base only advances `_current_tick` and calls `record_current_frame_events()`. Subclasses override for ATB/timeline advancement, typically calling `super.tick_once()` or `record_current_frame_events()` themselves
- `should_end() -> bool` — Virtual; base returns `_finished`. Subclasses override with win/loss conditions
- `finish(result: String = "battle_complete") -> Dictionary` — Un-tags `in_combat`, stops the recorder, returns the timeline

**Query:**
- `get_participant_ids() -> Array[String]`
- `get_current_tick() -> int`
- `get_logic_time() -> float` — `current_tick * tick_interval`
- `get_recorder() -> BattleRecorder`
- `get_tick_interval() -> float`

**Protected Utilities:**
- `record_current_frame_events() -> void` — Flushes `GameWorld.event_collector` into the recorder for the current tick
- `mark_finished() -> void` — Subclasses call after determining a winner, so `should_end()` returns `true`

**Virtual Hooks:**
- `_mark_in_combat(actor_id: String, active: bool) -> void` — No-op in base (plain `Actor` has no tag container); override per actor's actual tag API
- `_get_world() -> WorldGameplayInstance` — Resolves the `WeakRef`; `null` if world was freed
- `_get_actor(actor_id: String) -> Actor` — `null` if world is gone or actor not found

---

## ActorId (static utility)

Formats/parses the Actor ID convention `"{instance_id}:{local_id}"` (e.g. `"battle_001:hero_001"`) (actor_id.gd:1-11).

- `static format(instance_id: String, local_id: String) -> String`
- `static parse(actor_id: String) -> Dictionary` — `{ instance_id, local_id }`; no separator found → legacy-compat fallback `{ instance_id: "", local_id: actor_id }`
- `static is_valid(actor_id: String) -> bool` — Requires a separator that isn't at the very start/end (both parts non-empty)
- `static extract_instance_id(actor_id: String) -> String` / `static extract_local_id(actor_id: String) -> String` — Convenience wrappers over `parse()`
