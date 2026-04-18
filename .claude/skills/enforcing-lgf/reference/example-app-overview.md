# Example App — Overview & Core Events

Complete framework application reference covering three layers: **Core Events** → **Game Logic** → **Presentation**.

Source: `addons/logic-game-framework/example/`

## Contents
- [Three-Layer Architecture](#three-layer-architecture)
- [Layer 1: Core Events](#layer-1-core-events-hex-atb-battle-core)
- [Cross-Layer Data Flow](#cross-layer-data-flow)
- [Design Pattern Summary](#design-pattern-summary)

**Other layers:**
- **Game Logic**: See [example-app-game-logic.md](example-app-game-logic.md)
- **Presentation**: See [example-app-presentation.md](example-app-presentation.md)

---

## Three-Layer Architecture

```
┌─────────────────────────────────────────────────────────┐
│              Presentation Layer (frontend)               │
│   Replay-driven declarative animation pipeline           │
│   Visualizer → Scheduler → RenderWorld → Scene (3D)      │
└────────────────────┬────────────────────────────────────┘
                     │ subscribes to events / consumes replay
┌────────────────────▼────────────────────────────────────┐
│              Game Logic Layer (hex-atb-battle)            │
│   ATB system, Actor management, AI, Ability execution    │
│   Actions, PreEvents, Projectiles, Recording             │
└────────────────────┬────────────────────────────────────┘
                     │ references shared data structures
┌────────────────────▼────────────────────────────────────┐
│           Core Events Layer (hex-atb-battle-core)        │
│   Strongly-typed event definitions, shared enums         │
│   Serializable, replay-safe, no logic                    │
└─────────────────────────────────────────────────────────┘
```

**Dependency rule**: Presentation → Logic → Core. Never reverse.

---

## Layer 1: Core Events (`hex-atb-battle-core`)

### Purpose

Pure data layer. Defines the **event contract** between logic and presentation. No game logic, no Node references. Both layers import these types.

### Directory Structure

```
hex-atb-battle-core/
  events/
    battle_events.gd    # All event type definitions
  README.md
```

### Event Definition Pattern

Every event follows this template:

```gdscript
class XEvent extends GameEvent.Base:
    # 1. Typed fields with defaults
    var target_actor_id: String = ""
    var amount: float = 0.0

    func _init() -> void:
        kind = "event_kind"           # 2. Lowercase, past-tense identifier

    static func create(               # 3. Factory method
        p_target_actor_id: String,
        p_amount: float
    ) -> XEvent:
        var e := XEvent.new()
        e.target_actor_id = p_target_actor_id
        e.amount = p_amount
        return e

    func to_dict() -> Dictionary:     # 4. Serialization (optional fields conditional)
        var d := {"kind": kind, "target_actor_id": target_actor_id, "amount": amount}
        return d

    static func from_dict(d: Dictionary) -> XEvent:  # 5. Deserialization with safe defaults
        var e := XEvent.new()
        e.target_actor_id = d.get("target_actor_id", "") as String
        e.amount = d.get("amount", 0.0) as float
        return e

    static func is_match(d: Dictionary) -> bool:     # 6. Pattern matcher for filtering
        return d.get("kind") == "event_kind"
```

### Event Catalog

| Event | Kind | Key Fields | Notes |
|-------|------|-----------|-------|
| `DamageEvent` | `"damage"` | `target_actor_id`, `damage`, `damage_type`, `source_actor_id`, `is_critical`, `is_reflected` | `DamageType` enum: PHYSICAL, MAGICAL, PURE |
| `HealEvent` | `"heal"` | `target_actor_id`, `heal_amount`, `source_actor_id` | `source_actor_id` omitted from dict if empty |
| `MoveStartEvent` | `"move_start"` | `actor_id`, `from_hex`, `to_hex` | Hex as `Dictionary { "q": int, "r": int }` |
| `MoveCompleteEvent` | `"move_complete"` | `actor_id`, `from_hex`, `to_hex` | Paired with MoveStartEvent |
| `DeathEvent` | `"death"` | `actor_id`, `killer_actor_id` | `killer_actor_id` optional |

### Conventions

- **Event kind**: lowercase, past-tense (`"damage"`, `"death"`, not `"on_damage"`, `"Damage"`)
- **Actor references**: always `actor_id: String`, never Actor objects
- **Hex coordinates**: always `Dictionary { "q": int, "r": int }`
- **Optional fields**: conditionally included in `to_dict()`, safe-defaulted in `from_dict()`
- **Enum serialization**: convert to lowercase string for dict, parse back with fallback default

---

## Cross-Layer Data Flow

### Logic → Core → Presentation (Complete Path)

```
[Logic Layer]                     [Core Events]                    [Presentation]
     │                                 │                                │
     │ DamageAction.execute()          │                                │
     │  → push DamageEvent ──────────→ │                                │
     │  → deduct HP                    │                                │
     │  → broadcast post_damage        │                                │
     │                                 │                                │
     │ BattleRecorder.record() ──────→ │ ── ReplayData ──────────────→ │
     │                                 │                                │ Director.load_replay()
     │                                 │                                │ DamageVisualizer.translate()
     │                                 │                                │  → FloatingText + HitFlash + UpdateHP
     │                                 │                                │ Scheduler.tick()
     │                                 │                                │ RenderWorld.apply_actions()
     │                                 │                                │ Scene updates 3D nodes
```

### Key Integration Points

| Integration | Mechanism | Notes |
|-------------|-----------|-------|
| Logic → Recording | `BattleRecorder` + `EventCollector` | Events serialized via `to_dict()` |
| Recording → Presentation | `ReplayData.BattleRecord` | Passed to `Director.load_replay()` |
| Event → Visual | `Visualizer.translate()` | Maps event kind to VisualAction[] |
| Visual → 3D | `RenderWorld` signals → Scene | One-directional, Scene is replaceable |

### Design Pattern Summary

| Pattern | Where | Purpose |
|---------|-------|---------|
| **Stateless shared instances** | Actions, AI strategies, TargetSelectors | Memory efficiency, thread safety |
| **Builder API** | AbilityConfig | Readable, composable configuration |
| **Tag-based state** | Cooldowns, buffs, stacks | Unified temporal state management |
| **Two-phase operations** | Movement (reserve → apply) | Concurrent safety |
| **PreEvent interception** | Damage/heal modification | Passive ability hooks |
| **Callback chains** | on_hit/on_critical/on_kill | Composable action responses |
| **Pure function translation** | Visualizers | Testable, replay-safe |
| **Pure data actions** | VisualActions | Serializable, no side effects |
| **One-directional signals** | RenderWorld → Scene | Loose coupling |
| **Event contract layer** | Core events | Decouples logic from presentation |
