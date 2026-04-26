# Example App — Presentation Layer (`hex-atb-battle-frontend`)

> Part of the Example App reference. See also: [Overview & Core Events](example-app-overview.md) | [Game Logic](example-app-game-logic.md)

Replay-driven declarative animation pipeline for visualizing battle events as 3D animations.

**Full documentation**: See `addons/logic-game-framework/example/hex-atb-battle-frontend/README.md` for flow diagrams and data format specs.

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

The Director's `_tick(delta_ms)` drives the pipeline each frame. **Any presentation layer built on this framework MUST follow this 6-step sequence:**

```
Director._tick(delta_ms)
  │
  │  STEP 1: Advance logic frames (accumulator pattern)
  │  ════════════════════════════════════════════════════
  │  _logic_accumulator += delta_ms
  │
  │  while _logic_accumulator >= TICK_INTERVAL:
  │      _logic_accumulator -= TICK_INTERVAL
  │      _current_frame++
  │
  │      if frame has events:
  │          context = _world.as_context()       ← read-only snapshot
  │          actions = _registry.translate(event, context)
  │          _scheduler.enqueue(actions)
  │
  │      emit frame_changed(current, total)
  │
  │  STEP 2: Advance world time
  │  ════════════════════════════════════════════════════
  │  _world.advance_time(delta_ms)
  │
  │  STEP 3: Tick scheduler (advance all animation progress)
  │  ════════════════════════════════════════════════════
  │  result = _scheduler.tick(delta_ms)
  │
  │    Per active action:
  │      elapsed += delta_ms
  │      if elapsed < delay → still waiting
  │      progress = min(1.0, (elapsed - delay) / duration)
  │      if progress >= 1.0 → mark completed
  │
  │    → TickResult { active_actions, completed_this_tick, has_changes }
  │
  │  STEP 4: Apply actions to world state (if has_changes)
  │  ════════════════════════════════════════════════════
  │  _world.apply_actions(result.active_actions)
  │  _world.apply_actions(result.completed_this_tick)
  │
  │    match action.type → update actor state + mark dirty
  │
  │  _world.cleanup(world_time)  → remove expired effects
  │
  │  STEP 5: Batch flush dirty actor signals
  │  ════════════════════════════════════════════════════
  │  _world.flush_dirty_actors()
  │    → emit actor_state_changed(id, state) per dirty actor
  │    → clear dirty set
  │
  │  STEP 6: End detection
  │  ════════════════════════════════════════════════════
  │  if current_frame >= total_frames
  │     AND scheduler.action_count == 0:
  │      → emit playback_ended()
  │
  │  NOTE: Playback does NOT end when logic frames finish.
  │  It continues ticking until all animations complete.
```

**Key design points:**
- **Accumulator pattern** separates logic frame rate from render frame rate
- **Step 1 may process 0, 1, or N logic frames** per render frame depending on speed
- **Steps 3-5 always run** even after all logic frames are consumed — animations play to completion
- **Dirty batching** (Step 5) avoids per-action signal spam; Views receive one update per actor per frame

---

### End-to-End Example: Damage Event Lifecycle

Shows how a single event flows through all 4 layers:

**Input:** Logic layer produces a damage event in frame 10:
```
{ kind: "damage", target_actor_id: "actor_2", damage: 25, is_critical: false }
```

**Step 1 — Translate** (Visualizer layer, pure function):
```
DamageVisualizer.translate() produces 3 VisualActions:
  [0] FloatingTextAction  { text: "-25", color: WHITE, duration: 1000ms }
  [1] ProceduralVFXAction { effect: HIT_FLASH, duration: 300ms }
  [2] UpdateHPAction      { from: 80, to: 55, duration: 300ms, delay: 200ms }
```

**Step 2 — Schedule** (all 3 actions enqueued, run in parallel):
```
  t=0ms    FloatingText p=0.0   HitFlash p=0.0   HP [waiting delay]
  t=100ms  FloatingText p=0.1   HitFlash p=0.33  HP [waiting delay]
  t=200ms  FloatingText p=0.2   HitFlash p=0.67  HP p=0.0  ← delay ends
  t=300ms  FloatingText p=0.3   HitFlash p=1.0✓  HP p=0.33
  t=500ms  FloatingText p=0.5                     HP p=1.0✓
  t=1000ms FloatingText p=1.0✓
```

**Step 3 — Apply** (RenderWorld updates state per progress):
```
  FloatingText: first frame → emit floating_text_created → Scene spawns View
  HitFlash:     actor.flash_progress 0→1→0 → mark dirty → View lerps material white
  UpdateHP:     actor.visual_hp 80→55 interpolated → mark dirty → View scales HP bar
```

**Step 4 — Cleanup**: FloatingText removed from tracking after 1000ms.

**Output:** Scene renders floating "-25" text, white flash on hit, and smooth HP bar decrease — all from a single event dict.

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

```gdscript
class_name FrontendMyEffectVisualizer
extends FrontendBaseVisualizer

func _init() -> void:
    visualizer_name = "MyEffectVisualizer"

func can_handle(event: Dictionary) -> bool:
    return get_event_kind(event) == "my_effect"

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

Orchestrates replay playback. Forwards all RenderWorld signals.

**Signals:** `playback_state_changed`, `frame_changed`, `playback_ended`, `actor_state_changed`, `floating_text_created`, `actor_died`, `attack_vfx_created/updated/removed`, `projectile_created/updated/removed`

**Methods:**
- `load_replay(record: ReplayData.BattleRecord) → void`
- `play()` / `pause()` / `toggle()` / `reset()`
- `set_speed(speed: float)` / `get_speed() → float`
- `get_current_frame() → int` / `get_total_frames() → int`
- `is_playing() → bool` / `is_ended() → bool`
- `get_actors_snapshot() → Dictionary` — actor_id → FrontendActorRenderState
- `get_actor_world_position(actor_id: String) → Vector3`
- `get_screen_shake_offset() → Vector2`

#### FrontendActionScheduler (extends RefCounted)

Manages action lifecycle: delay → progress (0→1) → complete.

**Inner Classes:**
- `ActiveAction` — `id`, `action`, `elapsed`, `progress`, `is_delaying`
- `TickResult` — `active_actions[]`, `completed_this_tick[]`, `has_changes`

**Methods:**
- `enqueue(actions: Array[FrontendVisualAction]) → void`
- `tick(delta_ms: float) → TickResult`
- `get_action_count() → int` / `cancel_all() → void`

#### FrontendRenderWorld (extends RefCounted)

Single source of truth for render state. Applies actions, emits signals.

**Methods:**
- `initialize_from_replay(record) → void` / `reset_to(record) → void`
- `apply_actions(active_actions: Array[FrontendActionScheduler.ActiveAction]) → void`
- `as_context() → FrontendVisualizerContext` — Read-only snapshot for Visualizers
- `flush_dirty_actors() → void` — Batch emit `actor_state_changed`
- `advance_time(delta_ms: int) → void`
- `get_actor_world_position(actor_id) → Vector3`

#### FrontendVisualizerRegistry (extends RefCounted)

**Methods:**
- `register(visualizer) → self` (fluent) / `register_all(visualizers) → self`
- `translate(event, context) → Array[FrontendVisualAction]`
- `translate_all(events, context) → Array[FrontendVisualAction]`
- `has_visualizer_for(event_kind) → bool`

#### FrontendVisualizerContext (extends RefCounted)

Read-only query interface passed to `translate()`.

**Actor queries:** `get_actor_position()`, `get_actor_hp()`, `get_actor_max_hp()`, `is_actor_alive()`, `get_actor_hex_position()`, `get_actor_team()`, `get_all_actor_ids()`, `get_actor_display_name()`

**Config:** `get_animation_config() → FrontendAnimationConfig`, `get_layout() → GridLayout`, `hex_to_world(hex) → Vector3`

### Action Types

| ActionType | Class | Key Properties |
|-----------|-------|---------------|
| `MOVE` | `FrontendMoveAction` | `from_hex`, `to_hex`, `easing` |
| `APPLY_HP_DELTA` | `FrontendApplyHPDeltaAction` | `delta` (瞬时指令,state path,见 design-note 2026-04-26-presentation-event-vs-state「血条迁移到 state」) |
| `FLOATING_TEXT` | `FrontendFloatingTextAction` | `text`, `color`, `position`, `style` |
| `PROCEDURAL_VFX` | `FrontendProceduralVFXAction` | `effect` (HIT_FLASH/SHAKE/COLOR_TINT), `intensity` |
| `DEATH` | `FrontendDeathAction` | `killer_id` |
| `ATTACK_VFX` | `FrontendAttackVFXAction` | `source_actor_id`, `target_actor_id`, `vfx_type` |
| `PROJECTILE` | `FrontendProjectileAction` | `projectile_id`, `start_position`, `target_position` |

All extend `FrontendVisualAction` (base: `type`, `actor_id`, `duration`, `delay`).

### Built-in Visualizers

| Visualizer | Handles | Produces |
|-----------|---------|----------|
| `MoveVisualizer` | `move_start` | MoveAction |
| `DamageVisualizer` | `damage` | FloatingText + HitFlash + UpdateHP |
| `HealVisualizer` | `heal` | FloatingText + UpdateHP |
| `DeathVisualizer` | `death` | DeathAction |
| `ProjectileVisualizer` | `projectileHit` | AttackVFX + FloatingText + HitFlash + UpdateHP |
| `StageCueVisualizer` | `stageCue` | AttackVFX / MeleeStrike |

One event can trigger multiple Visualizers (many-to-many).

### Data Types

#### FrontendActorRenderState (extends RefCounted)

Actor visual state managed by RenderWorld:

- `id`, `type`, `display_name`, `team`
- `position: HexCoord`
- `visual_hp: float`, `max_hp: float`, `is_alive: bool`
- `flash_progress: float`, `tint_color: Color`, `death_progress: float`

#### FrontendRenderData (inner classes)

Signal payload types: `FloatingText`, `AttackVfx`, `Projectile`, `ProceduralEffect`, `ScreenShake`

#### FrontendAnimationConfig

Timing constants (all in ms): `move_duration`, `damage_hp_bar_duration`, `damage_hp_bar_delay`, `damage_hit_vfx_duration`, `heal_hp_bar_duration`, `death_duration`, `attack_vfx_duration`, etc.

Factory: `FrontendAnimationConfig.create_default()`
