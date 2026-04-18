# Example App — Game Logic Layer (`hex-atb-battle`)

> Part of the Example App reference. See also: [Overview & Core Events](example-app-overview.md) | [Presentation](example-app-presentation.md)

## Contents
- [Directory Structure](#directory-structure)
- [Actor Subclass Pattern](#actor-subclass-pattern)
- [GameplayInstance Pattern](#gameplayinstance-pattern)
- [AbilitySet Extension](#abilityset-extension)
- [Action Implementation Patterns](#action-implementation-patterns)
- [PreEvent Pattern](#preevent-pattern)
- [Ability Configuration Patterns](#ability-configuration-patterns)
- [AI Strategy Pattern](#ai-strategy-pattern)
- [Target Selectors](#target-selectors)
- [Utility Patterns](#utility-patterns)
- [Config / Data Organization](#config--data-organization)
- [Logging](#logging)

---

### Directory Structure

```
hex-atb-battle/
  actions/           # Action implementations (stateless, shared)
  ai/                # AI strategy pattern
  buffs/             # Buff configurations
  config/            # Static data (class stats, skill mappings)
  docs/              # Architecture documentation
  logger/            # Battle logging system
  skills/            # Ability configurations (active, passive, cooldown, timelines)
  utils/             # Shared utility functions
  battle_ability_set.gd   # Extended AbilitySet with cooldown
  character_actor.gd      # Actor subclass
  hex_battle.gd           # GameplayInstance subclass (main controller)
  hex_battle_pre_events.gd # PreEvent definitions
  main.gd                 # Entry point
  target_selectors.gd     # Project-specific TargetSelectors
```

### Actor Subclass Pattern

`CharacterActor extends Actor` — the entity that participates in battle.

**Component ownership:**

```gdscript
class_name CharacterActor extends Actor

var attribute_set: HexBattleCharacterAttributeSet  # Generated type-safe attributes
var ability_set: BattleAbilitySet                   # Extended with cooldown support
var ai_strategy: AIStrategy                         # Shared stateless instance
var hex_position: HexCoord                          # Grid position
```

**Lifecycle:**

| Phase | What happens |
|-------|-------------|
| `_init(class_type)` | Create attribute_set, ability_set. NO ID yet |
| `add_actor()` called | Framework assigns ID, triggers `_on_id_assigned()` |
| `_on_id_assigned()` | Sync ID to ability_set and attribute_set |
| `equip_abilities()` | Register move skill + class skill + passives |
| `setup_recording()` | Attach attribute change listeners for replay |

**Key rules:**
- Override `_get_position()` to return hex coordinate for framework queries
- Implement `get_ability_set()` protocol for `IAbilitySetOwner` compatibility
- Never generate ID in `_init` — wait for `_on_id_assigned()`

### GameplayInstance Pattern

`HexBattle extends GameplayInstance` — the battle controller.

**Lifecycle:**

```gdscript
func start() -> void:
    # Initialize: logger, recorder, map, teams, projectile system
    # Register actors via add_actor()

func tick(delta_ms: int) -> void:
    # 1. Accumulate ATB for all actors
    # 2. Check who can act (ATB full)
    # 3. AI decision → create ABILITY_ACTIVATE_EVENT
    # 4. Execute abilities (tick instances)
    # 5. Process projectile events
    # 6. Collect events for replay
    # 7. Check win/lose conditions

func end() -> void:
    # Save logs and replay data
```

**Design decisions:**
- **Atomic state sync**: Action internally does push + apply + post as one unit
- **EventCollector is read-only**: only for replay/presentation, not logic state
- **ATB freezes during execution**: classic ATB — no accumulation while casting
- **Serial decision-making**: one actor acts at a time, `tick(0)` ensures reservations take effect

### AbilitySet Extension

`BattleAbilitySet extends AbilitySet` — adds tag-based cooldown system.

```gdscript
# Cooldown tag format: "cooldown:{ability_config_id}"
func start_cooldown(ability_config_id: String, duration_ms: float) -> void:
    var tag := "cooldown:" + ability_config_id
    tag_container.add_auto_duration_tag(tag, duration_ms)

func is_on_cooldown(ability_config_id: String) -> bool:
    return tag_container.has_tag("cooldown:" + ability_config_id)

func get_cooldown_remaining(ability_config_id: String) -> float:
    return tag_container.get_auto_duration_remaining("cooldown:" + ability_config_id)
```

Paired with `CooldownCondition` (check) and `TimedCooldownCost` (pay) in `cooldown_system.gd`.

### Action Implementation Patterns

All Actions are **stateless shared instances** (via `static var`). State lives in `ExecutionContext`.

#### Damage Action Flow

```
execute(ctx) →
  1. Create PreDamageEvent, process through pre_event system
  2. If cancelled → skip
  3. Read modified damage from MutableEvent
  4. Roll critical hit (random, uses ctx)
  5. apply_damage() — atomic: push event + deduct HP + check death
  6. Fire callbacks: on_hit → on_critical → on_kill
  7. broadcast_post_damage() — triggers passive responses
```

#### Callback Chain Pattern

```gdscript
# Builder-style callback registration
HexBattleDamageAction.new(
    Resolvers.float_fn(func(ctx): return ctx.owner_actor.attribute_set.atk),
    BattleEvents.DamageType.PHYSICAL,
    HexBattleTargetSelectors.current_target()
).on_hit(
    HexBattleDamageAction.new(...)  # Bonus damage on hit
).on_critical(
    HexBattleDamageAction.new(...)  # Extra damage on crit
).on_kill(
    HexBattleHealAction.new(...)    # Lifesteal on kill
)
```

#### Two-Phase Movement

```
StartMoveAction → reserve_tile() + MoveStartEvent
  ↓ (next timeline tag)
ApplyMoveAction → move_occupant() + cancel reservation + MoveCompleteEvent
```

Reservation prevents concurrent actors from targeting the same tile.

#### Reflect Damage (Infinite Loop Prevention)

```gdscript
# ReflectDamageAction sets is_reflected: true on the DamageEvent
# Thorns passive filter EXCLUDES events where is_reflected == true
# → No infinite reflect chains
```

### PreEvent Pattern

Modify or cancel effects **before** they apply.

```gdscript
# Definition (hex_battle_pre_events.gd)
class PreDamageEvent extends PreExecuteEvent:
    var damage: float
    var damage_type: BattleEvents.DamageType

# Usage in Action
var pre_event := PreDamageEvent.create(source_id, target_id, damage, damage_type)
var mutable := instance.process_pre_event(pre_event)
if mutable.cancelled:
    return  # Effect blocked by a passive
var final_damage: float = mutable.get_value("damage")
```

PreEvent handlers registered via `PreEventConfig` on passive abilities. Every code path MUST return an Intent.

### Ability Configuration Patterns

#### Active Skill (Builder API)

```gdscript
static var slash_config := AbilityConfig.builder("slash", "Slash") \
    .set_meta(SkillMetaKeys.RANGE, 1) \
    .add_component(ActiveUseConfig.new(
        SkillTimelines.melee_timeline,
        {
            TimelineTags.START: [StageCueAction.new(...)],
            TimelineTags.EXECUTE: [HexBattleDamageAction.new(...)],
        }
    )) \
    .add_condition(CooldownCondition.new()) \
    .add_cost(TimedCooldownCost.new(3000.0)) \
    .build()
```

#### Passive Skill (NoInstanceComponent)

```gdscript
static var thorns_config := AbilityConfig.builder("thorns", "Thorns") \
    .add_component(NoInstanceConfig.new(
        TriggerConfig.new(
            GameEvent.POST_DAMAGE,
            func(event, ctx): return _is_damage_to_owner(event, ctx),  # filter
            func(event, ctx):                                           # handler
                var reflect := HexBattleReflectDamageAction.new(...)
                reflect.execute(ctx.create_execution_context(event))
        )
    )) \
    .build()
```

#### Projectile Skill (Two-Phase)

```gdscript
# Phase 1: Launch (ActiveUseConfig)
TimelineTags.EXECUTE: [LaunchProjectileAction.new(
    Resolvers.vec3_fn(func(ctx): return hex_to_world(ctx.target_position)),
    projectile_config
)]

# Phase 2: Hit response (ActivateInstanceConfig)
.add_component(ActivateInstanceConfig.new(
    TriggerConfig.new(
        ProjectileEvents.PROJECTILE_HIT,
        _projectile_hit_filter,
        hit_handler
    ),
    SkillTimelines.projectile_hit_timeline,
    { TimelineTags.EXECUTE: [HexBattleDamageAction.new(...)] }
))
```

### AI Strategy Pattern

**Stateless shared instances** — factory returns same object for same class.

```gdscript
# Base class provides shared utilities
class_name AIStrategy extends RefCounted
func decide(actor: CharacterActor, battle: HexBattle) -> Dictionary:
    return {"type": "skip"}  # Override in subclass

# Shared helpers: _get_enemies(), _get_allies(), _select_lowest_hp(),
#   _select_nearest(), _move_toward(), _move_away_from(), _is_tile_available()
```

**Decision format:** `{"type": "skill/move/skip", "target_id": ..., "hex": ...}`

| Strategy | Priority | Behavior |
|----------|----------|----------|
| MeleeAttack | Skill → Move → Skip | Attack lowest HP in range, else move toward nearest |
| RangedAttack | Skill → Move toward → Kite → Skip | Attack in range, approach if far, retreat if too close |
| RangedSupport | Heal → Move → Skip | Heal lowest HP% wounded ally, move toward most injured |

### Target Selectors

Project-specific selectors in `target_selectors.gd`:

| Selector | Source | Use Case |
|----------|--------|----------|
| `current_target()` | Event's `target_actor_id` or `target_actor_ids` | Default for most actions |
| `ability_owner()` | Ability's owner actor | Self-targeting (heals, buffs) |
| `event_source()` | Event's `source_actor_id` | Reflect damage back to attacker |
| `all_enemies()` | All alive actors on opposing team | AoE effects |
| `fixed(id)` | Hardcoded actor ID | Testing only |

### Utility Patterns

- **Shared flow extraction**: `HexBattleDamageUtils` extracts the push → deduct → log → death-check flow shared by DamageAction and ReflectDamageAction
- **Separated broadcast**: `broadcast_post_damage()` is a separate call so the caller controls timing (after callbacks)
- **Type-safe state access**: `HexBattleGameStateUtils` wraps `IGameStateProvider` with typed methods

### Config / Data Organization

| File | Pattern | Content |
|------|---------|---------|
| `class_config.gd` | Enum + Dictionary mapping | Character classes → base stats |
| `skill_config.gd` | Enum + class-to-skill mapping | Which class gets which skill |
| `skill_meta_keys.gd` | String constants | Standardized metadata keys (e.g., RANGE) |
| `attributes_config.gd` | Dictionary config | Attribute base values and constraints |

### Logging

`BattleLogger` — multi-output battle logging:
- Console + file output (`user://Logs/battle_timestamp_id/`)
- Per-actor log files (`actors/*.log`)
- Execution tracking (start/tag/end per ability instance)
- Frame-based organization (`tick()` starts new frame)
