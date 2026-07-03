# Example App — Overview & Core Events

Complete framework application reference covering three layers: **Core Events** → **Game Logic** → **Presentation**.

Source: `addons/logic-game-framework/example/`

Two examples live under `example/`: **hex-atb-battle** (turn-based ATB + hex grid, Timeline-driven skills — this doc set's worked example) and **dota2-auto-battle** (real-time fixed-tick 30Hz, controller-intent model, sim-nav movement adapter). This reference documents hex-atb-battle in depth; dota2-auto-battle follows the same three-layer dependency rule but uses fixed-tick + `attack_cooldown` instead of Timeline scheduling.

## Contents
- [Three-Layer Architecture](#three-layer-architecture)
- [Layer 1: Core Events](#layer-1-core-events-hex-atb-battlecore)
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
│           Core Events Layer (hex-atb-battle/core)        │
│   Strongly-typed event definitions, shared enums         │
│   Serializable, replay-safe, no logic                    │
└─────────────────────────────────────────────────────────┘
```

**Dependency rule**: Presentation → Logic → Core. Never reverse.

---

## Layer 1: Core Events (`hex-atb-battle/core`)

### Purpose

Pure data layer. Defines the **event contract** between logic and presentation. No game logic, no Node references. Both layers import these types.

### Directory Structure

```
hex-atb-battle/core/
  events/
    battle_events.gd    # All event type definitions
  README.md
```

### Event Definition Pattern

Every event follows this template — real example: `HealEvent` (`core/events/battle_events.gd`):

```gdscript
const HEAL_EVENT := "heal"            # 1. kind constant — the ONLY source of truth for this kind

class HealEvent extends GameEvent.Base:
    # 2. Typed fields with defaults
    var target_actor_id: String = ""
    var heal_amount: float = 0.0
    var source_actor_id: String = ""

    func _init() -> void:
        kind = HEAL_EVENT             # 3. Named constant — NEVER a literal string like kind = "heal"

    static func create(               # 4. Factory method
        p_target_actor_id: String, p_heal_amount: float, p_source_actor_id: String = ""
    ) -> HealEvent:
        var e := HealEvent.new()
        e.target_actor_id = p_target_actor_id
        e.heal_amount = p_heal_amount
        e.source_actor_id = p_source_actor_id
        return e

    func to_dict() -> Dictionary:     # 5. Serialization (optional fields conditional)
        var d := {"kind": kind, "target_actor_id": target_actor_id, "heal_amount": heal_amount}
        if source_actor_id != "":
            d["source_actor_id"] = source_actor_id
        return d

    static func from_dict(d: Dictionary) -> HealEvent:  # 6. Deserialization with safe defaults
        var e := HealEvent.new()
        e.target_actor_id = d.get("target_actor_id", "") as String
        e.heal_amount = d.get("heal_amount", 0.0) as float
        e.source_actor_id = d.get("source_actor_id", "") as String
        return e

    static func is_match(d: Dictionary) -> bool:     # 7. Pattern matcher for filtering
        return d.get("kind") == HEAL_EVENT
```

### Event Catalog

All 11 kinds are defined in `BattleEvents` (`core/events/battle_events.gd`):

| Event | Kind | Key Fields | Notes |
|-------|------|-----------|-------|
| `DamageEvent` | `DAMAGE_EVENT` (`"damage"`) | `target_actor_id`, `damage`, `damage_type`, `source_actor_id`, `is_critical`, `is_reflected`, `shield_absorbed`, `actual_life_damage`, `consumption_records` | `damage` = post-mitigation total; `actual_life_damage` = post-shield HP loss, filled in by `HexBattleDamageUtils.apply_damage()` |
| `BasicAttackLandedEvent` | `BASIC_ATTACK_LANDED_EVENT` | `attacker_actor_id`, `target_actor_id`, `source_ability_id`/`source_ability_config_id`, `actual_life_damage`, `damage_event` | Basic-attack-only (Strike), emitted via the `on_hit` callback — not fired by Fireball/DOT/reflect |
| `ShieldBrokenEvent` | `SHIELD_BROKEN_EVENT` | `target_actor_id`, `attacker_actor_id`, `shield_ability_id`/`shield_config_id`, `damage_type`, `absorbed_amount` | Fired before the death check so `on_break` callbacks still see live owner context |
| `RegenerationEvent` | `REGENERATION_EVENT` | `target_actor_id`, `resource`, `amount`, `actual_amount`, `source` | NOT a heal — doesn't go through `HealAction`, doesn't trigger heal-related passives |
| `HealEvent` | `HEAL_EVENT` (`"heal"`) | `target_actor_id`, `heal_amount`, `source_actor_id` | `source_actor_id` omitted from dict if empty |
| `MoveStartEvent` | `MOVE_START_EVENT` | `actor_id`, `from_hex`, `to_hex` | Hex as `Dictionary { "q": int, "r": int }` |
| `MoveCompleteEvent` | `MOVE_COMPLETE_EVENT` | `actor_id`, `from_hex`, `to_hex` | Paired with `MoveStartEvent` |
| `DeathEvent` | `DEATH_EVENT` | `actor_id`, `killer_actor_id` | `killer_actor_id` optional |
| `ActorDisplacedEvent` | `ACTOR_DISPLACED_EVENT` | `actor_id`, `from_hex`, `to_hex`, `displacement_kind`, `source_actor_id`, `actual_distance`, `swap_id` | Forced movement (knockback/swap); only pushed if the actor actually moved (else see `PushBlockedEvent`) |
| `ActorFacingChangedEvent` | `ACTOR_FACING_CHANGED_EVENT` | `actor_id`, `old_direction`, `new_direction`, `reason` | `reason` from `HexFacing.REASON_*`; directions are 0-5 (`HexCoord.DIRECTIONS`) |
| `PushBlockedEvent` | `PUSH_BLOCKED_EVENT` | `actor_id`, `stopped_at_hex`, `attempted_to_hex`, `blocked_by`, `blocker_actor_id`, `source_actor_id` | Complements `ActorDisplacedEvent` for the "hit a wall/actor" case |

`DamageType` enum: `PHYSICAL`, `MAGICAL`, `PURE` — serialized via `BattleEvents._damage_type_to_string()` / `string_to_damage_type()`.

### Conventions

- **Event kind**: lowercase, past-tense (`"damage"`, `"death"`, not `"on_damage"`, `"Damage"`) — declared once as a named constant (`const HEAL_EVENT := "heal"`) and assigned via `kind = HEAL_EVENT` in `_init()`; never a literal string (`kind = "heal"`), so `is_match()` callers can't typo-drift from the producer
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
     │ HexBattleDamageAction.execute() │                                │
     │  → PreDamageEvent (mutable)     │                                │
     │  → shield resolve (absorb)      │                                │
     │  → push DamageEvent ──────────→ │                                │
     │  → deduct actual_life_damage    │                                │
     │  → on_hit/on_critical/on_kill   │                                │
     │  → broadcast_post_damage()      │                                │
     │                                 │                                │
     │ BattleRecorder                  │                                │
     │  .record_frame(frame, events) ─→│ ── PlaybackData ──────────────→ │
     │                                 │                                │ FrontendBattleDirector.load_playback()
     │                                 │                                │ FrontendDamageVisualizer.translate()
     │                                 │                                │  → FloatingText + HitFlash + ApplyHPDeltaAction
     │                                 │                                │ FrontendActionScheduler.tick()
     │                                 │                                │ FrontendRenderWorld.apply_event_side_effects()
     │                                 │                                │ Scene updates 3D nodes
```

### Key Integration Points

| Integration | Mechanism | Notes |
|-------------|-----------|-------|
| Logic → Recording | `BattleRecorder` + `EventCollector` | Events serialized via `to_dict()`; recorded via `record_frame(frame, events)` |
| Recording → Presentation | `PlaybackData.BattleRecord` | Passed to `FrontendBattleDirector.load_playback()` |
| Event → Visual | `FrontendBaseVisualizer.translate()` | Pure function: maps one event dict to `Array[FrontendVisualAction]` |
| Visual → Schedule | `FrontendActionScheduler` | Buffers/sequences `FrontendVisualAction`s, drives timing |
| Visual → 3D | `FrontendRenderWorld` signals → Scene | One-directional, Scene is replaceable |

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
