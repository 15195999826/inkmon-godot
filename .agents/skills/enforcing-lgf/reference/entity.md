# Entity & World API

## Contents
- [Actor](#actor-extends-refcounted)
- [BattleActor](#battleactor-extends-actor)
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
- `team: int` — **Read-only** BattleRecorder-compat int view, produced by `_get_team_int()`. `Actor`'s default parses the string `_team` (unparseable → `0`); `BattleActor` overrides it to return `team_id` (unassigned → `-1`). Use `get_team() -> String` / `set_team(value: String) -> void` for the real team identifier (Actor.gd:62-66)
- `position: Vector3` — Read-only; override `_get_position() -> Vector3` in subclasses (default `Vector3.ZERO`)

**Lifecycle:**
- `is_pre_event_responsive() -> bool` — Default `true`; override so an actor in an unresponsive state (dead/silenced/stunned) opts out of PreEvent handler dispatch for this instant. Other dispatch paths (POST event / tick / receive_event) are unaffected (Actor.gd:58-59)
- `on_spawn() -> void` — Empty virtual hook called at the end of `add_actor()`; override in subclasses
- `on_despawn() -> void` — Called when actor is removed
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

## BattleActor (extends Actor)

`core/entity/battle_actor.gd`. Opt-in skeleton for actors that take part in the combat
pipeline. `Actor` stays neutral; anything holding an `AbilitySet` extends this instead.

The base class deliberately declares **no** `ability_set` / `attribute_set` field — subclasses
keep their own strongly typed fields and override the two virtuals with covariant returns, so
project code can still write `actor.attribute_set.atk` without the base shadowing it.

**Virtuals (default `null` — a plain data actor just inherits them):**
- `get_ability_set() -> AbilitySet`
- `get_attribute_set() -> BaseGeneratedAttributeSet`

**Death latch:**
- `_hp_source() -> RawAttributeSet` — Virtual. The set that actually holds hp, or `null` when there is none. Override it when hp lives somewhere other than `get_attribute_set()`'s raw
- `has_hp() -> bool` — Whether a readable `hp` attribute exists (`HP_ATTRIBUTE := "hp"`); keeps "no health bar" distinct from "health bar at 0"
- `get_current_hp() -> float` — `0.0` when there is no hp attribute. Override this **together with** `has_hp()` to use a different attribute name — `check_death()` reads hp only through those two virtuals
- `check_death() -> bool` — Latches once when hp reaches 0; returns `true` only the first time. Never latches an actor without hp
- `mark_dead() -> bool` — Explicit latch (damage settled outside the hp read); returns whether it was the first time
- `set_death_latch(value: bool) -> void` — The **only** way to unlatch. "Revive from hp" / "rebuild downed state on load" are project rules core does not define — but the project shouldn't have to poke the base class's private field either (inkmon's `sync_downed_state()` calls this)
- `is_dead() -> bool`
- `is_pre_event_responsive() -> bool` — `not _is_dead`; still a project-overridable hook (a death-rattle passive that must fire after death overrides it back to `true`)

**Team:** `team_id: int` (-1 = unassigned), `set_team_id(id)` (also syncs the string `_team`),
`get_team_id()`, and `_get_team_int() -> team_id` for recording. A BattleActor that never calls
`set_team_id` therefore records `-1`, not `Actor`'s `0` — an actor that wants `0` (hex's
`EnvironmentActor`, which has no side) says so with its own `_get_team_int()` override.

**Defaults inherited by every subclass:** `_on_id_assigned()` (binds the id into ability_set +
attribute_set), `get_attribute_snapshot()` (all attributes), `get_ability_snapshot()`,
`get_tag_snapshot()`, `setup_recording()` (attribute + ability_set + lifecycle subscriptions),
`serialize()` (`serialize_base()` + attribute raw + `is_dead`; position stays project-side).
Every one of them takes a real null branch rather than an assertion — `Log.assert_crash` only
aborts its own frame in debug builds, so a half-built object would sail straight past it.

**Protocol query:**
- `static ability_set_of(actor: Actor) -> AbilitySet` — `null` for a non-BattleActor or a data-only one. Framework code holding an `Actor` reference uses this instead of `has_method` probing

---

## System (extends RefCounted)

Base class for game logic systems (ECS-style). Registered on GameplayInstance, ticked each frame.

**Constants:**
- `SystemPriority` — `HIGHEST=0`, `HIGH=100`, `NORMAL=500`, `LOW=900`, `LOWEST=1000`

**Properties:**
- `type: String` — System type identifier
- `priority: int` — Tick order (lower = earlier)
- `_registration_seq: int` — Tie-breaker inside one priority band, stamped by the owning instance at `add_system()` time (`-1` = not registered). Not serialized and never emitted into the event stream — it is a runtime ordering contract, not save semantics. Do not set it yourself

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

Instance registry: registers, looks up and ends gameplay instances, and reverse-resolves full actor ids. It owns no event infrastructure — each `GameplayInstance` carries its own `event_processor` / `event_collector`.

**Lifecycle:**
- `shutdown() -> void` — Ends every registered instance and clears the registry. The only lifecycle verb (there is no `init` / `destroy`); idempotent, so scenes and tests call it at both ends to get a clean registry

**Instance Management:**
- `create_instance(instance: GameplayInstance) -> GameplayInstance` — Registers the instance and returns it (a duplicate id logs a warning and returns the already-registered one). Construct → register → `start()` / `add_actor` / grants: contexts resolve their instance by owner id through the registry and see `null` before registration
- `get_instance_by_id(id_value: String) -> GameplayInstance`
- `get_instances_by_type(type_value: String) -> Array[GameplayInstance]`
- `destroy_instance(id_value: String) -> bool`
- `destroy_all_instances() -> void`
- `tick_all(dt: float) -> void`
- `get_instance_count() -> int`
- `has_running_instances() -> bool`
- `get_debug_info() -> Dictionary` — `{ instanceCount, instances: [{id, type, state, actorCount}] }`
- `get_actor(actor_id: String) -> Actor` — Global actor lookup by full ID
- `get_instance_of_actor(actor_id: String) -> GameplayInstance` — Reverse lookup from a full actor ID to its owning instance (same "id describes ownership" mechanism as `Actor.get_owner_gameplay_instance()`, without needing the Actor)

---

## GameplayInstance (extends RefCounted)

Individual gameplay session containing actors and systems.

**Properties:**
- `id: String`
- `type: String` — Instance type (default "instance")
- `event_processor: EventProcessor` — This instance's pre-handler registry, recursion depth and traces
- `event_collector: EventCollector` — This instance's recording queue; actions push through `ctx.event_collector`, the battle procedure flushes it once per frame

**Construction:**
- `_init(id_value: String = "", processor_config: EventProcessorConfig = null)` — `id_value` defaults to `IdGenerator.generate("instance")`; builds the processor (from `processor_config`) and collector. They are per instance, so two instances never see each other's handlers or events, and neither refers back to the instance (instance → processor / collector is the only edge)

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
- `add_system(system: System) -> void` — Rejects a duplicate `type` with a warning (no replace). Stamps `system._registration_seq` from the instance's counter, then re-sorts the table by the **two-key order `(priority, _registration_seq)`**, then calls `system.on_register(self)`
- `remove_system(system_type: String) -> bool`
- `get_system(system_type: String) -> System`
- `get_systems() -> Array[System]`

**Tick order is a declared fact, not luck** (`core/world/gameplay_instance.gd:136-169`): `sort_custom` is unstable, so under a single `priority` key the relative order inside one band had no contract and any mid-flight `add_system` (e.g. hanging a BattleSystem on at battle start) could reshuffle the whole table — a determinism hazard. The two keys form a total order: "systems in the same band must not depend on each other" is still the design contract, but a bug that violates it now reproduces deterministically instead of flapping. Every table change logs one `Log.info` line with the full tick order (`type(priority)` list) — debug logging only, it never reaches the event stream / recording / save.

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
- `_init(id_value: String = "", processor_config: EventProcessorConfig = null) -> void` — `id_value` defaults to `IdGenerator.generate("world")`; sets `type = "world"`; `processor_config` goes to `GameplayInstance` (inkmon's `InkMonWorldGI` passes `EventProcessorConfig.new(20)`)

**Mutation API** (fires the signals above):
- `add_actor(actor: Actor, after_id_assigned: Callable = Callable()) -> Actor` — `after_id_assigned` runs after ID assignment but before `actor_added` fires, so spawn code can init position/team/abilities before observers can snapshot the actor
- `remove_actor(actor_id: String) -> bool`
- `configure_grid(config: GridMapConfig) -> void` — Override to plug in a concrete grid backend (e.g. `UGridMap` autoload); subclasses must emit `grid_configured` last

**Battle Scheduling:**
- `start_battle(participants: Array[Actor]) -> BattleProcedure` — Asserts no battle already active (MVP: one battle at a time); delegates construction to `_create_battle_procedure()`
- `_create_battle_procedure(participants: Array[Actor]) -> BattleProcedure` — Factory hook; override to return a concrete subclass (e.g. `HexBattleProcedure`)
- `has_active_battle() -> bool` / `get_active_battle() -> BattleProcedure` — The procedure releases the slot itself in `finish()` / `abort()` (`_release_battle`, only while the slot still points at it), so a caller driving `finish()` directly (dota2) leaves no stale battle behind
- `end() -> void` — Overrides the base `end()`: a battle still active is aborted (`_active_battle.abort()`, which releases the slot; the world asserts it did) before `super.end()` despawns actors (no `battle_finished`, no record). With recording on, the recorder's subscription closures and every recorded actor hold each other strongly, so skipping this leaks the recorder together with all recorded actors (bystanders and mid-battle spawns included). It sits in `end()` rather than the `on_end()` hook so a subclass overriding `on_end()` can't drop it by forgetting `super`

**Replay Snapshot (world side produces, recorder only receives):**
- `capture_world_snapshot() -> PlaybackData.WorldSnapshot` — The opening state playback starts from: recordable registry actors + `grid.to_config_dict()` + `_get_position_formats()`
- `get_recordable_actors() -> Array[Actor]` — Registry actors filtered by `should_record_actor()`; same set feeds snapshot and change subscriptions
- `should_record_actor(actor: Actor) -> bool` — Recording-scope hook, default `true`. Persistent-world subclasses override to exclude non-battle registry residents (e.g. inkmon excludes overworld player/NPC actors, otherwise the 2D replay would build battle avatars for them)
- `_get_position_formats() -> Dictionary` — Coordinate-format declaration hook for replay consumers (e.g. hex returns `{KIND_CHARACTER: "hex", KIND_ENVIRONMENT: "hex"}`); base returns `{}`

**Tick:**
- `tick(dt: float) -> void` — With no active battle, delegates to `base_tick()`. With an active battle, this frame is spent exclusively on `_active_battle.tick_once()` (world systems do NOT tick) up to `BATTLE_TICKS_PER_WORLD_FRAME` times or until `should_end()`; on end, `finish()` has already released the slot when `battle_finished` emits (the world asserts it and clears as a fallback — subclass `finish()` overrides must call `super.finish()`), so a handler may safely call `start_battle()` again re-entrantly. If the slot was released during that `tick_once()` (the world was ended and aborted the battle, or the procedure called `finish()` itself), the world stops advancing it with no wrap-up and no signal — the rest of that `tick_once()` still runs; procedures end a battle with `mark_finished()`

---

## BattleProcedure (extends RefCounted)

A battle is a *procedure*, not an *instance*. `WorldGameplayInstance` holds one transiently (`_active_battle`) and releases it when the battle ends. The procedure borrows actors that live in the world and mutates them directly during `tick_once()` — there is no separate battle-owned actor copy; once the battle ends, the world is already in its final state (battle_procedure.gd:1-8).

The base class provides only the skeleton (participant tracking, `in_combat` tag hook, recorder lifecycle). Concrete ATB/turn-based pacing and win/loss determination are subclass responsibilities via `tick_once()` / `should_end()` overrides.

**Constants:**
- `DEFAULT_TICK_INTERVAL: float = 100.0`

**Construction:**
- `_init(world: WorldGameplayInstance, participants: Array[Actor])` — Stores `world` as a `WeakRef`; snapshots participant IDs

**Lifecycle:**
- `start() -> void` — Tags participants `in_combat`; when `_recording_enabled` (base-class field, subclasses set it from opts in `_init`), calls `_start_recorder()`
- `_start_recorder() -> void` — Base implementation is the standard path: constructs the `BattleRecorder` with the world's `event_collector` injected, asks the world for `capture_world_snapshot()` + `get_recordable_actors()`, injects both into `recorder.start_recording()`, and connects `world.actor_added` so mid-battle spawns auto-register into the recording (the handler re-checks `world.should_record_actor()`, and `register_actor` de-dupes internally). The connection is dropped in `finish()` / `abort()` — procedures are short-lived while worlds persist, so leaving it attached would accumulate stale listeners across battles and keep dead procedures alive
- `tick_once() -> void` — Virtual; base only advances `_current_tick` and calls `record_current_frame_events()`. Subclasses override for ATB/timeline advancement, typically calling `super.tick_once()` or `record_current_frame_events()` themselves
- `should_end() -> bool` — Virtual; base returns `_finished`. Subclasses override with win/loss conditions
- `finish(result: String = "battle_complete") -> Dictionary` — Disconnects the `actor_added` hookup, releases the world's battle slot, un-tags `in_combat`, stops the recorder, returns the timeline
- `abort() -> void` — Tear-down for a battle still running when its world ends (called by `WorldGameplayInstance.end`): disconnects `actor_added`, releases the world's battle slot, aborts the recording (`recorder.abort_recording()` unsubscribes every closure and produces no record), marks finished. Unlike `finish()` it doesn't un-tag `in_combat`, emit signals, or run subclass wrap-up (logs / replay writes / mission state) — the world is going away. No-op on a battle that already finished

**Query:**
- `get_participant_ids() -> Array[String]`
- `get_current_tick() -> int`
- `get_logic_time() -> float` — `current_tick * tick_interval`
- `get_recorder() -> BattleRecorder`
- `get_tick_interval() -> float`

**Protected Utilities:**
- `record_current_frame_events() -> void` — Flushes the world's `event_collector` into the recorder for the current tick (flushes even without a recorder so events never pile up across frames; no-op once the world is gone)
- `mark_finished() -> void` — Subclasses call after determining a winner, so `should_end()` returns `true`

**Virtual Hooks:**
- `_mark_in_combat(actor_id: String, active: bool) -> void` — No-op in base (plain `Actor` has no tag container); override per actor's actual tag API
- `_get_world() -> WorldGameplayInstance` — Resolves the `WeakRef`; `null` if world was freed. Subclasses that need the concrete world type override it covariantly (`func _get_world() -> MyWorld: return super._get_world() as MyWorld`) and never store the world in a field: `world._active_battle` holds the procedure strongly while the battle runs, so a strong back-reference is a cycle for that whole span, and any exit that skips `finish()` / `abort()` leaks the whole world. Objects the procedure holds (controllers, loggers) take `world` as a call argument instead of storing it or the procedure
- `_get_actor(actor_id: String) -> Actor` — `null` if world is gone or actor not found

---

## ActorId (static utility)

Formats/parses the Actor ID convention `"{instance_id}:{local_id}"` (e.g. `"battle_001:hero_001"`) (actor_id.gd:1-11).

- `static format(instance_id: String, local_id: String) -> String`
- `static parse(actor_id: String) -> Dictionary` — `{ instance_id, local_id }`; no separator → `{ instance_id: "", local_id: actor_id }` (a bare id belongs to no instance, so instance lookup returns `null`)
- `static is_valid(actor_id: String) -> bool` — Requires a separator that isn't at the very start/end (both parts non-empty)
- `static extract_instance_id(actor_id: String) -> String` / `static extract_local_id(actor_id: String) -> String` — The two halves via `find` + `substr`, without building a Dictionary (instance lookup by owner id calls `extract_instance_id` on every dispatch); `parse()` is built from them
