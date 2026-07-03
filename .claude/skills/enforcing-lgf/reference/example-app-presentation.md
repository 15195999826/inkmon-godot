# Example App — Presentation Layer (`hex-atb-battle/frontend`)

> Part of the Example App reference. See also: [Overview & Core Events](example-app-overview.md) | [Game Logic](example-app-game-logic.md)

Replay-driven declarative animation pipeline for visualizing battle events as 3D animations.

**Full documentation**: See `addons/logic-game-framework/example/hex-atb-battle/frontend/README.md` for flow diagrams and data format specs.

## Contents
- [4-Layer Pipeline](#4-layer-pipeline)
- [Design Constraints (MUST follow)](#design-constraints-must-follow)
- [Runtime Tick Protocol](#runtime-tick-protocol)
- [End-to-End Example: Damage Event Lifecycle](#end-to-end-example-damage-event-lifecycle)
- [Extension Guide: Adding a New Visual Effect](#extension-guide-adding-a-new-visual-effect)
- [Core API Quick Reference](#core-api-quick-reference)
- [Action Types](#action-types)
- [Built-in Visualizers](#built-in-visualizers)
- [Data Types](#data-types)

---

### 4-Layer Pipeline

```
Replay Data → Visualizer (translate) → Scheduler (timing) → RenderWorld (state) → Scene (3D)
```

| Layer | Class | Responsibility | Stateful? |
|-------|-------|---------------|-----------|
| **Translate** | `FrontendBaseVisualizer` | Event → VisualAction[] (pure function) | NO |
| **Schedule** | `FrontendActionScheduler` | Manage delay/duration/progress | YES |
| **State** | `FrontendRenderWorld` | Apply actions to actor state, emit signals | YES |
| **Render** | `FrontendWorldView` (unit lifecycle) + `FrontendBattleAnimator` (VFX/floating-text overlay) | Reactive view from world signals + animator subscribes director state changes | YES |

Scene composition: `FrontendWorldView` (`frontend/world_view.gd`) owns one `FrontendUnitView` (`frontend/scene/unit_view.gd`) per actor, each compositing focused sub-views (`hp_bar_view.gd`, `shield_bar_view.gd`, `buff_row_view.gd`, `name_label_view.gd`, `facing_indicator_view.gd`). `FrontendBattleAnimator` (`frontend/battle_animator.gd`) owns a `FrontendBattleDirector` internally and overlays transient VFX views (`floating_text_view.gd`, `attack_vfx_view.gd`, `projectile_view.gd`, `cone_debug_overlay_view.gd`) onto the base unit views during battle playback.

**Key design decisions:**
- VisualAction = pure data, no Node references → serializable, replay-safe
- All actions run in parallel, timing via `delay` field → simple scheduler
- Director → Scene via signals → loose coupling, Scene is replaceable
- RenderWorld is single source of truth → Views are read-only consumers

### Design Constraints (MUST follow)

#### Visualizers MUST be pure functions

```gdscript
# CORRECT: read-only context, return data
func translate(event: Dictionary, context: FrontendVisualizerContext) -> Array[FrontendVisualAction]:
    return [FrontendApplyHPDeltaAction.new(actor_id, -damage, config.damage_hp_bar_delay)]

# WRONG: modifying state in visualizer
func translate(event: Dictionary, context: FrontendVisualizerContext) -> Array[FrontendVisualAction]:
    render_world.set_actor_hp(actor_id, new_hp)  # FORBIDDEN
```

#### VisualActions MUST be pure data objects

No Node references, no Callable, no side effects. Only describe "what" not "how".

#### Signal flow is one-directional

```
RenderWorld → (signals) → Director → (signals) → Scene/Views
```

Views NEVER write back to RenderWorld. State changes only happen through action application.

### Runtime Tick Protocol

`FrontendBattleDirector._tick(delta_ms)` (`frontend/core/battle_director.gd`) drives the pipeline every frame — from `_process(delta)` during normal playback, or directly from `step(delta_ms)` for deterministic manual advance (see Core API below). **The real sequence is 7 steps:**

```
Director._tick(delta_ms)
  │
  │  STEP 1: Advance logic frames (accumulator pattern)
  │  ════════════════════════════════════════════════════
  │  _logic_accumulator += delta_ms
  │
  │  while _logic_accumulator >= LOGIC_TICK_MS:   # LOGIC_TICK_MS = 100.0
  │      _logic_accumulator -= LOGIC_TICK_MS
  │      _current_frame++
  │
  │      if frame has events:
  │          for event in events:
  │              _world.apply_event_side_effects(event)   ← FIRST: actorSpawned/
  │                                                           actorDestroyed/attribute_changed
  │                                                           land in render-state before translate
  │              context = _world.as_context()             ← read-only snapshot (sees the update above)
  │              actions = _registry.translate(event, context)
  │              _scheduler.enqueue(actions)
  │
  │      emit frame_changed(current, total)
  │
  │  STEP 2: Advance world time (every _tick() call, not just on frame boundaries)
  │  ════════════════════════════════════════════════════
  │  _world.advance_time(int(delta_ms))
  │
  │  STEP 3: Tick scheduler (advance all animation progress)
  │  ════════════════════════════════════════════════════
  │  result = _scheduler.tick(delta_ms)
  │
  │    Per active action:
  │      elapsed += delta_ms
  │      if elapsed < delay → is_delaying = true, progress = 0.0
  │      else: effective_elapsed = elapsed - delay
  │            progress = 1.0 if duration <= 0.0 else min(1.0, effective_elapsed / duration)
  │            if effective_elapsed >= duration → completed_this_tick
  │
  │    → TickResult { active_actions, completed_this_tick, has_changes }
  │
  │  STEP 4: Apply actions to world state (only if result.has_changes)
  │  ════════════════════════════════════════════════════
  │  _world.apply_actions(result.active_actions)
  │  _world.apply_actions(result.completed_this_tick)
  │
  │    match action.type → update actor state + mark dirty
  │
  │  _world.cleanup(_world.get_world_time())  → purge expired floating texts / procedural effects
  │
  │  STEP 5: HP lerp convergence (UNCONDITIONAL — runs every tick, even with no active actions)
  │  ════════════════════════════════════════════════════
  │  _world.tick_hp_lerp(delta_ms)
  │    → per actor: visual_hp exponentially chases target_hp (rate = hp_lerp_rate, default 8.0/s)
  │    → decoupled from the action/scheduler system entirely — see End-to-End Example below
  │
  │  STEP 6: Batch flush dirty actor signals
  │  ════════════════════════════════════════════════════
  │  _world.flush_dirty_actors()
  │    → emit actor_state_changed(id, state) per dirty actor
  │    → clear dirty set
  │
  │  STEP 7: End detection
  │  ════════════════════════════════════════════════════
  │  if _current_frame >= _total_frames
  │     AND _scheduler.get_action_count() == 0:
  │      → _is_playing = false
  │      → emit playback_state_changed(false)
  │      → emit playback_ended()
  │
  │  NOTE: Playback does NOT end when logic frames finish.
  │  It continues ticking (Steps 2-6) until all scheduled actions complete.
```

**Key design points:**
- **Accumulator pattern** separates logic frame rate (`LOGIC_TICK_MS` = 100ms) from render frame rate
- **Step 1 may process 0, 1, or N logic frames** per render frame depending on speed; `apply_event_side_effects` always runs before `translate()` for the same event, never after
- **Steps 2-6 always run**, even after all logic frames are consumed — animations and HP-bar convergence play to completion
- **HP lerp (Step 5) is a *state* mechanism, not an *action*** — it runs unconditionally every tick, decoupled from whether any `FrontendVisualAction` is active
- **Dirty batching** (Step 6) avoids per-action signal spam; Views receive one update per actor per frame

---

### End-to-End Example: Damage Event Lifecycle

Shows how a single event flows through all 4 layers — real behavior from `FrontendDamageVisualizer` (`frontend/visualizers/damage_visualizer.gd`) and `FrontendRenderWorld` (`frontend/core/render_world.gd`):

**Input:** Logic layer produces a damage event in frame 10 (full `BattleEvents.DamageEvent` shape, see [Overview: Event Catalog](example-app-overview.md#event-catalog)):
```
{ kind: "damage", target_actor_id: "actor_2", damage: 25, damage_type: "physical",
  is_critical: false, is_reflected: false, shield_absorbed: 0.0, actual_life_damage: 25.0 }
```

**Step 1 — Translate** (Visualizer layer, pure function):
```
DamageVisualizer.translate() produces 3 VisualActions (actual_life_damage > 0, shield_absorbed == 0):
  [0] FloatingTextAction  { text: "-25", color: WHITE, duration: damage_floating_text_duration=1000ms }
  [1] ProceduralVFXAction { effect: HIT_FLASH, duration: damage_hit_vfx_duration=300ms }
  [2] ApplyHPDeltaAction  { delta: -25, duration: 0ms, delay: damage_hp_bar_delay=200ms }
```
(A `shield_absorbed > 0` hit additionally produces a "护盾 -N" FloatingTextAction; a fully-absorbed hit skips HitFlash and the HP delta entirely.)

**Step 2 — Schedule** (all 3 actions enqueued, run in parallel):
```
  t=0ms    FloatingText p=0.0   HitFlash p=0.0    HPDelta [waiting, elapsed < delay]
  t=100ms  FloatingText p=0.1   HitFlash p=0.33   HPDelta [waiting]
  t=200ms  FloatingText p=0.2   HitFlash p=0.67   HPDelta p=1.0 ✓ (duration=0 → completes the instant delay elapses)
  t=300ms  FloatingText p=0.3   HitFlash p=1.0 ✓
  t=1000ms FloatingText p=1.0 ✓
```

**Step 3 — Apply** (`RenderWorld._apply_action()` dispatch, plus the unconditional `tick_hp_lerp` state path):
```
  FloatingText: first frame → emit floating_text_created → Scene spawns FloatingTextView
  HitFlash:     actor.flash_progress 0→1→0 over 300ms → mark dirty → UnitView lerps material white
  HPDelta:      at t=200ms, actor.target_hp -= 25 — instant, atomic, NOT itself lerped
  tick_hp_lerp: every tick from t=200ms onward, actor.visual_hp exponentially chases target_hp
                (rate = hp_lerp_rate, default 8.0/s ⇒ ~63% converged per ~125ms); this runs on
                every Director tick regardless of scheduler state — see Runtime Tick Protocol Step 5
```

**Step 4 — Cleanup**: FloatingText and HitFlash purged by `RenderWorld.cleanup(world_time)` once `now - start_time >= duration` (t=1000ms and t=300ms respectively).

**Output:** floating "-25" text, a white hit-flash, and a smoothly draining HP bar — all from one event dict. The HP-bar smoothing is a **state** concern (`tick_hp_lerp`, decoupled from actions), not an **action** concern — there is no `UpdateHPAction { from, to, duration }` in real source.

---

### Extension Guide: Adding a New Visual Effect

#### Step 1: Create Action class

```gdscript
class_name FrontendMyEffectAction
extends FrontendVisualAction

var target_id: String
var intensity: float

func _init(p_target_id: String, p_intensity: float, p_duration: float) -> void:
    super._init(ActionType.MY_EFFECT, p_duration)  # Add to ActionType enum first
    target_id = p_target_id
    intensity = p_intensity
```

#### Step 2: Create Visualizer

Real visualizers never compare against a literal string — they check a named kind constant, same convention as [Core Events: Event Definition Pattern](example-app-overview.md#event-definition-pattern). Real example (`FrontendMoveVisualizer`, `frontend/visualizers/move_visualizer.gd`):

```gdscript
func can_handle(event: Dictionary) -> bool:
    return get_event_kind(event) == BattleEvents.MOVE_START_EVENT
```

Applied to a new "my_effect" event (define `const MY_EFFECT_EVENT := "my_effect"` alongside your event class, per the Core Events convention):

```gdscript
class_name FrontendMyEffectVisualizer
extends FrontendBaseVisualizer

func _init() -> void:
    visualizer_name = "MyEffectVisualizer"

func can_handle(event: Dictionary) -> bool:
    return get_event_kind(event) == MY_EFFECT_EVENT   # never a literal "my_effect" string

func translate(event: Dictionary, context: FrontendVisualizerContext) -> Array[FrontendVisualAction]:
    var config := context.get_animation_config()
    var action := FrontendMyEffectAction.new(
        get_string_field(event, "target_actor_id"),
        get_float_field(event, "intensity", 1.0),
        500.0  # duration ms
    )
    return [action]
```

#### Step 3: Add RenderWorld handler

In `render_world.gd`, add a match branch in `_apply_action()`:

```gdscript
FrontendVisualAction.ActionType.MY_EFFECT:
    var effect_action := action as FrontendMyEffectAction
    # Update actor state...
    _mark_dirty(effect_action.target_id)
```

#### Step 4: Register

In `default_registry.gd` → `create()`:

```gdscript
registry.register(FrontendMyEffectVisualizer.new())
```

No changes needed to Director or Scheduler.

### Core API Quick Reference

#### FrontendBattleDirector (extends Node)

Orchestrates replay playback (`frontend/core/battle_director.gd`). Forwards all RenderWorld signals. `LOGIC_TICK_MS = 100.0` is the fixed logic-frame interval (see Runtime Tick Protocol).

**Signals:** `playback_state_changed(is_playing)`, `frame_changed(current, total)`, `playback_ended`, `actor_state_changed(actor_id, state)`, `actor_spawned(actor_id, state)`, `floating_text_created`, `actor_died`, `attack_vfx_created/updated/removed`, `projectile_created/updated/removed`, `cone_debug_overlay_created`

**Methods:**
- `load_playback(record: PlaybackData.BattleRecord) → void`
- `play()` / `pause()` / `toggle()` / `reset()`
- `step(delta_ms: float) → void` — deterministic manual advance: bypasses `_process`/`_is_playing`, runs the same `_tick()` path as normal playback. Used by DevAgent/tests to pause then step to an exact frame and capture transient VFX.
- `set_speed(speed: float)` / `get_speed() → float`
- `get_current_frame() → int` / `get_total_frames() → int`
- `is_playing() → bool` / `is_ended() → bool`
- `get_actors_snapshot() → Dictionary` — actor_id → FrontendActorRenderState
- `get_actor_world_position(actor_id: String) → Vector3`
- `get_screen_shake_offset() → Vector2`

#### FrontendActionScheduler (extends RefCounted)

Manages action lifecycle: delay → progress (0→1) → complete (`frontend/core/action_scheduler.gd`). All actions run in parallel — no queueing/blocking between them.

**Inner Classes:**
- `ActiveAction` — `id`, `action`, `elapsed`, `progress`, `is_delaying`
- `TickResult` — `active_actions[]`, `completed_this_tick[]`, `has_changes`

**Methods:**
- `enqueue(actions: Array[FrontendVisualAction]) → void`
- `tick(delta_ms: float) → TickResult`
- `get_active_actions() → Array[ActiveAction]`
- `get_action_count() → int` / `cancel_all() → void`

#### FrontendRenderWorld (extends RefCounted)

Single source of truth for render state (`frontend/core/render_world.gd`). Applies actions, emits signals. "职责分离: ActionScheduler 管理时序, RenderWorld 管理状态" (source header).

**Methods:**
- `initialize_from_replay(record) → void` / `reset_to(record) → void`
- `apply_event_side_effects(event: Dictionary) → void` — pre-translate render-state lifecycle (`ACTOR_SPAWNED_EVENT`/`ACTOR_DESTROYED_EVENT`/`ATTRIBUTE_CHANGED_EVENT`); Director calls this before `as_context()` so Visualizers see up-to-date state
- `apply_actions(active_actions: Array[FrontendActionScheduler.ActiveAction]) → void`
- `tick_hp_lerp(delta_ms: float) → void` — unconditional per-tick `visual_hp → target_hp` exponential convergence (rate = `hp_lerp_rate`), independent of the scheduler
- `as_context() → FrontendVisualizerContext` — Read-only snapshot for Visualizers
- `cleanup(now_ms: int) → void` — purge expired floating texts / procedural effects
- `flush_dirty_actors() → void` — Batch emit `actor_state_changed`
- `advance_time(delta_ms: int) → void` / `get_world_time() → int`
- `get_actors_snapshot() → Dictionary` — deep-copied actor_id → FrontendActorRenderState
- `get_actor_world_position(actor_id) → Vector3` / `get_screen_shake_offset() → Vector2`
- `set_actor_hp/set_actor_position/set_actor_dead(...)` — direct state writes bypassing lerp/animation (non-replay callers)

#### FrontendVisualizerRegistry (extends RefCounted)

`frontend/core/visualizer_registry.gd`. Collects results from *all* matching visualizers per event (many-to-many by design — e.g. a future screen-shake visualizer could co-handle `damage` alongside `DamageVisualizer`).

**Methods:**
- `register(visualizer) → self` (fluent) / `register_all(visualizers) → self`
- `set_debug_mode(enabled: bool) → self` — logs each event → visualizer → action-count mapping via `Log.debug`
- `translate(event, context) → Array[FrontendVisualAction]`
- `translate_all(events, context) → Array[FrontendVisualAction]`
- `has_visualizer_for(event_kind) → bool`
- `get_visualizers_for(event_kind) → Array[String]` — names of visualizers that can handle a kind
- `get_count() → int` / `get_registered_names() → Array[String]`

#### FrontendVisualizerContext (extends RefCounted)

Read-only query interface passed to `translate()`.

**Actor queries:** `get_actor_position()`, `get_actor_hp()`, `get_actor_max_hp()`, `is_actor_alive()`, `get_actor_hex_position()`, `get_actor_team()`, `get_all_actor_ids()`, `get_actor_display_name()`

**Config:** `get_animation_config() → FrontendAnimationConfig`, `get_layout() → GridLayout`, `hex_to_world(hex) → Vector3`

### Action Types

`FrontendVisualAction.ActionType` enum has 13 values (`frontend/actions/visual_action.gd`):

| ActionType | Class | Key Properties |
|-----------|-------|---------------|
| `MOVE` | `FrontendMoveAction` | `from_hex`, `to_hex`, `easing` |
| `APPLY_HP_DELTA` | `FrontendApplyHPDeltaAction` | `delta` — instant (`duration=0`); RenderWorld separately lerps `visual_hp → target_hp` every tick (see `README.md#event-vs-state`) |
| `FLOATING_TEXT` | `FrontendFloatingTextAction` | `text`, `color`, `position`, `style` |
| `PROCEDURAL_VFX` | `FrontendProceduralVFXAction` | `effect` (HIT_FLASH/SHAKE/COLOR_TINT), `intensity` |
| `DEATH` | `FrontendDeathAction` | `killer_id` |
| `ATTACK_VFX` | `FrontendAttackVFXAction` | `source_actor_id`, `target_actor_id`, `vfx_type` |
| `PROJECTILE` | `FrontendProjectileAction` | `projectile_id`, `start_position`, `target_position` |
| `APPLY_BUFF_STATE` | `FrontendApplyBuffStateAction` | `op` (ADD/UPDATE/REMOVE), `buff_id`, `summary: FrontendBuffSummary` |
| `APPLY_SHIELD_STATE` | `FrontendApplyShieldStateAction` | `op` (ADD/UPDATE/REMOVE), `shield_id`, `summary: FrontendShieldSummary` |
| `BUMP` | `FrontendBumpAction` | `direction`, `max_offset`, `squish_enabled` — world-space offset/squish only, `hex_position` never moves |
| `APPLY_FACING_STATE` | `FrontendApplyFacingStateAction` | `new_direction` (`HexFacing.DIR_*`, 0-5), instant, no turn-speed/lerp |
| `CONE_DEBUG_OVERLAY` | `FrontendConeDebugOverlayAction` | `cue_id`, `cell_polygons`, `boundary_segments`, `fill_color`, `boundary_color` |

All extend `FrontendVisualAction` (base: `type`, `actor_id`, `duration`, `delay`). (`MELEE_STRIKE` is declared in the enum but no visualizer currently produces it — treat as reserved/unused, not a documented pattern.)

### Built-in Visualizers

12 concrete visualizers registered by `FrontendDefaultRegistry.create()` (`frontend/visualizers/default_registry.gd`), all extending `FrontendBaseVisualizer`:

| Visualizer | Handles | Produces |
|-----------|---------|----------|
| `MoveVisualizer` | `move_start` | `MoveAction` |
| `DamageVisualizer` | `damage` | FloatingText (`-N`, + "护盾 -N" text if `shield_absorbed>0`) + HitFlash (only if `actual_life_damage>0`) + `ApplyHPDeltaAction` |
| `HealVisualizer` | `heal` | FloatingText (`+N`) + `ApplyHPDeltaAction` |
| `DeathVisualizer` | `death` | `DeathAction` |
| `ProjectileVisualizer` | `projectileLaunched` / `projectileHit` / `projectileMiss` | Launched → `ProjectileAction`; Hit → HitFlash; Miss → none |
| `StageCueVisualizer` | `stageCue` | Cue-dependent: melee cues → `AttackVFXAction`; heal cue → `AttackVFXAction` (green); `execute_kill` → scaled `AttackVFXAction` + FloatingText; control cues (`control_stunned`/`_silenced`/`_broken`/...) → FloatingText; `*_cone_cast` → `ConeDebugOverlayAction` |
| `BuffVisualizer` | `AbilityGranted`/`AbilityStacksChanged`/`AbilityRemoved`/`damage` (via `consumption_records`) | `ApplyBuffStateAction` (ADD/UPDATE/REMOVE), whitelisted via `BUFF_REGISTRY` |
| `ShieldBarVisualizer` | `AbilityGranted`/`AbilityRemoved`/`damage` (via `consumption_records`) | `ApplyShieldStateAction` (ADD/UPDATE/REMOVE), whitelisted via `SHIELD_REGISTRY` |
| `DisplacementVisualizer` | `actor_displaced` | `MoveAction` (duration from event's `action_lock_duration_ms`) |
| `PushBlockedVisualizer` | `push_blocked` | `BumpAction` ("冲出→撞击→弹回" offset+squish curve) |
| `RegenerationVisualizer` | `regeneration` | FloatingText (`+N`, HEAL style) + `ApplyHPDeltaAction` — NOT routed through `HealVisualizer` |
| `ActorFacingChangedVisualizer` | `actor_facing_changed` | `ApplyFacingStateAction` |

One event can trigger multiple Visualizers (many-to-many) — e.g. a `damage` event is independently picked up by `DamageVisualizer`, `BuffVisualizer` (shield consumption), and `ShieldBarVisualizer`.

### Data Types

#### FrontendActorRenderState (extends RefCounted)

Actor visual state managed by RenderWorld (`frontend/core/actor_render_state.gd`), replacing what used to be a raw Dictionary:

- `id`, `type`, `config_id`, `display_name`, `team`
- `position: HexCoord`
- `visual_hp: float` (rendered value, lerps toward `target_hp`), `target_hp: float` (set instantly by `ApplyHPDeltaAction`), `max_hp: float`, `is_alive: bool`
- `flash_progress: float`, `tint_color: Color`, `death_progress: float`
- `bump_offset: Vector3`, `bump_squish: Vector3` — world-space-only, `position` (hex) never moves
- `facing_direction: int` (`HexFacing.DIR_*`, 0-5)
- `buffs: Array[FrontendBuffSummary]` — maintained by `BuffVisualizer` via `ApplyBuffStateAction`, order = first-ADD order
- `shields: Array[FrontendShieldSummary]` — maintained by `ShieldBarVisualizer` via `ApplyShieldStateAction`, parallel to `buffs`
- `duplicate() → FrontendActorRenderState` — deep copy, used by `get_actors_snapshot()`

#### FrontendRenderData (inner classes)

Signal payload types (`frontend/core/render_data.gd`): `FloatingText`, `AttackVfx`, `Projectile`, `ConeDebugOverlay`, `ProceduralEffect`, `ScreenShake`

#### FrontendAnimationConfig

`frontend/core/animation_config.gd`. Timing constants (all in ms unless noted):

- Move: `move_duration` (500.0), `move_easing`
- Damage: `damage_floating_text_duration` (1000.0), `damage_hp_bar_delay` (200.0 — **not** `damage_hp_bar_duration`, that field does not exist), `damage_hit_vfx_duration` (300.0)
- Heal: `heal_floating_text_duration` (1000.0) — **no** `heal_hp_bar_duration` field; heal HP changes go through the same `hp_lerp_rate` convergence as damage
- HP lerp (state path, not tied to any action): `hp_lerp_rate` (8.0, unit = 1/sec — exponential-decay rate for `visual_hp → target_hp`)
- Death: `death_duration` (1000.0)
- Skill: `skill_basic_attack_duration` (1000.0), `skill_basic_attack_hit_frame` (500.0)
- Attack VFX: `attack_vfx_duration` (300.0)
- Projectile: `projectile_size` (0.15), `projectile_hit_vfx_duration` (200.0), `projectile_default_speed` (20.0 units/sec)

Factory: `FrontendAnimationConfig.create_default()` / `FrontendAnimationConfig.from_dict(data)`
