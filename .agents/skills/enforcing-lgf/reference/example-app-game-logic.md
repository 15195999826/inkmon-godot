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
- [Additional Subsystems](#additional-subsystems-pointers-only)

---

### Directory Structure

```
hex-atb-battle/
  core/
    events/
      battle_events.gd          # BattleEvents — 11 event kinds, shared logic<->presentation contract
    README.md
  logic/
    abilities/
      active/                   # Skill impls: strike.gd, fireball.gd, move.gd, holy_heal.gd, ... (~30 files)
      buffs/                    # Buff configs: stun_buff.gd, silence_buff.gd, shield_buffs.gd, ...
      passives/                 # Passive impls: thorn.gd, vitality.gd, general_passive.gd, ...
      shared/                   # cooldown_system.gd, skill_helpers.gd, all_skills.gd (single manifest)
    actions/                    # damage_action.gd, heal_action.gd, start/apply_move_action.gd, push_action.gd, ...
    ai/                         # ai_strategy.gd (base) + melee/ranged_attack/ranged_support strategies
    components/                 # shield_component.gd (AbilityComponent subclass)
    config/                     # class_config.gd, skill_config.gd, skill_meta_keys.gd
    docs/                       # logic-to-presentation-guide.md
    environment/                # Concrete EnvironmentActor kinds: stone_wall.gd, fire_tile.gd, collision_profile.gd
    item/                       # hex_item_domain.gd, hex_item_catalog.gd, hex_actor_equipment_container.gd, ...
    logger/
      battle_logger.gd          # class_name HexBattleLogger
    scenario/
      skill_scenario_harness.gd # DSL backing tests/battle/skill_scenarios/*.gd
    utils/                      # hex_battle_damage_utils.gd, hex_battle_shield_resolver.gd, hex_battle_game_state_utils.gd
    battle_ability_set.gd       # AbilitySet extension: cooldown tags
    character_actor.gd          # extends HexBattleActor
    environment_actor.gd        # extends HexBattleActor
    hex_battle_actor.gd         # shared base: Actor -> HexBattleActor -> {CharacterActor, EnvironmentActor}
    hex_battle_pre_events.gd    # PreDamageEvent / PreBasicAttackEvent / PreHealEvent
    hex_battle_procedure.gd     # extends BattleProcedure — ATB tick loop (ephemeral, one per battle)
    hex_facing.gd               # HexFacing static utility
    hex_world_gameplay_instance.gd  # extends WorldGameplayInstance — persistent world (grid + actor registry)
    target_selectors.gd         # HexBattleTargetSelectors
  frontend/                     # See example-app-presentation.md
  skill-preview/                # Editor skill-preview sandbox tool + presets/*.json
  tests/
    battle/skill_scenarios/     # Per-skill scenario contract tests (30+ files)
    frontend/                   # Frontend smoke tests
    skill-preview/              # Skill preview smoke tests
```

### Actor Subclass Pattern

Real hierarchy: `Actor` (LGF core) → `HexBattleActor` (`logic/hex_battle_actor.gd`, shared base) → `CharacterActor` (`logic/character_actor.gd`) and `EnvironmentActor` (`logic/environment_actor.gd`), siblings.

**`HexBattleActor`** holds shared battle-actor state — it does NOT hold `attribute_set` itself (each subclass keeps its own strongly-typed field, exposed generically through an abstract getter):

```gdscript
class_name HexBattleActor
extends Actor

const KIND_CHARACTER := "Character"
const KIND_ENVIRONMENT := "Environment"

var ability_set: BattleAbilitySet
var hex_position: HexCoord = HexCoord.invalid()
var collision_profile: CollisionProfile

# Abstract — every subclass must override this.
func get_attribute_set() -> HexBattleActorAttributeSet:
    push_error("HexBattleActor.get_attribute_set must be overridden by subclass")
    return null

func is_dead() -> bool:
    return get_attribute_set().hp <= 0
```

**`EnvironmentActor extends HexBattleActor`** (`logic/environment_actor.gd`) is the non-character sibling — walls, fire tiles, totems' terrain. Same base contract, no ATB/AI/facing; concrete kinds (`stone_wall.gd`, `fire_tile.gd`) live under `logic/environment/`:

```gdscript
class_name EnvironmentActor
extends HexBattleActor

var environment_kind: String = ""       # e.g. "stone_wall" — drives replay visuals
var attribute_set: HexBattleEnvironmentAttributeSet

func _init(p_environment_kind: String, p_collision_profile: CollisionProfile) -> void:
    environment_kind = p_environment_kind
    type = KIND_ENVIRONMENT
    attribute_set = HexBattleEnvironmentAttributeSet.new(get_id())
    collision_profile = p_collision_profile if p_collision_profile != null else CollisionProfile.new()
    ability_set = BattleAbilitySet.create_battle_ability_set(get_id(), attribute_set)

func get_attribute_set() -> HexBattleActorAttributeSet:
    return attribute_set
```

`CharacterActor extends HexBattleActor` (`logic/character_actor.gd`) adds ATB, AI, facing, and class-specific stats — see its own field list in [GameplayInstance Pattern](#gameplayinstance-pattern) usage below.

**Key rules:**
- `get_attribute_set()` is the only base-contract way to read `hp`/`max_hp` generically (used by `HexBattleDamageUtils`, AI helpers, death checks); subclass-specific stats (e.g. `atk`/`def`/`speed` on `CharacterActor`) are only reachable through the subclass's own strongly-typed field
- Isolation boundary (see `environment_actor.gd` header comment): AI / default enemy selector / heal / buff / shield default to character-only; the damage/death/PreEvent/PostEvent pipeline treats character and environment actors identically
- Never generate ID in `_init` — the framework assigns it and syncs it into `ability_set`/`attribute_set`

### GameplayInstance Pattern

The old `HexBattle` class doesn't exist. Real split: **`HexWorldGameplayInstance`** (`logic/hex_world_gameplay_instance.gd`, `extends WorldGameplayInstance`) is the **persistent world** — grid, actor registry, `can_use_skill_on()` — that outlives any one battle. **`HexBattleProcedure`** (`logic/hex_battle_procedure.gd`, `extends BattleProcedure`) is the **ephemeral ATB tick loop** for a single battle, created by the world via `start_battle` and released when the battle ends.

```gdscript
class_name HexBattleProcedure
extends BattleProcedure

const MAX_TICKS := 10000

func tick_once() -> void:
    _current_tick += 1
    world.base_tick(_tick_interval)
    world.broadcast_projectile_events()

    # ATB freezes during execution — classic ATB, no accumulation while casting.
    for actor in get_alive_characters():
        if HexBattleProcedure.tick_actor_ability_runtime(actor, _tick_interval, cur_logic_time, world):
            continue
        actor.accumulate_atb(_tick_interval)
        if actor.can_act():
            _start_actor_action(actor, cur_logic_time)

    record_current_frame_events()
    if _current_tick >= MAX_TICKS:
        _result = "timeout"
        mark_finished()
    else:
        _check_battle_end()
```

`world.get_actor(actor_id) -> HexBattleActor` is the shared entry point damage/death pipelines use (treats character + environment uniformly); `world.get_character_actor(actor_id) -> CharacterActor` is the character-only entry point AI/heal/buff code uses (returns `null` on an environment actor).

**Design decisions:**
- **Atomic state sync**: an Action does push-event + apply-state as one unit, no split phases
- **`EventCollector` is read-only**: only for replay/presentation, never drives logic state
- **ATB freezes during execution**: `tick_actor_ability_runtime()` returning `true` (a blocking, non-`"intrinsic"`-tagged execution in flight) skips ATB accumulation for that actor entirely that tick
- **Mid-battle spawns** (totems, fire tiles) are ticked in a second pass separate from the initial `left_team`/`right_team` roster, so periodic/lifetime timelines on spawned actors still fire
- **`battle_final_state_ready`** (debug-build only, on the world instance) fires right after `battle_finished` with a full actor snapshot for view-logic reconciliation tooling

### AbilitySet Extension

`BattleAbilitySet extends AbilitySet` (`logic/battle_ability_set.gd`) — adds tag-based cooldown on top of the base ability set. Note the real methods check/set the tag on `self` (the ability set), not on a separate `tag_container` field:

```gdscript
class_name BattleAbilitySet
extends AbilitySet

func is_on_cooldown(ability_config_id: String) -> bool:
    var cooldown_tag := _get_cooldown_tag(ability_config_id)
    return has_tag(cooldown_tag)

func start_cooldown(ability_config_id: String, duration: float) -> void:
    var cooldown_tag := _get_cooldown_tag(ability_config_id)
    add_auto_duration_tag(cooldown_tag, duration)

func reset_cooldown(ability_config_id: String) -> void:
    remove_tag(_get_cooldown_tag(ability_config_id))

func _get_cooldown_tag(ability_config_id: String) -> String:
    return "cooldown:%s" % ability_config_id
```

Paired with `CooldownCondition` (check) and `TimedCooldownCost` (pay) in `logic/abilities/shared/cooldown_system.gd` (`class_name HexBattleCooldownSystem` — **not** under `utils/`), which also exposes two ready-made gating bundles every active skill's builder chain uses:

- `apply_standard_active_gating(builder, cooldown_ms)` — no-cant-act tag + no-silence tag + cooldown condition + timed-cooldown cost. Used by all standard skills.
- `apply_basic_attack_gating(builder, cooldown_ms)` — same minus the silence check (MOBA convention: basic attacks stay usable while silenced). Used only by Strike.

### Action Implementation Patterns

All Actions are **stateless shared instances** — state lives in `ExecutionContext`, never on the Action object.

#### Damage Action Flow

`HexBattleDamageAction.execute()` (`logic/actions/damage_action.gd`), per target (skipping null/dead targets):

```
1. [only if .emit_pre_basic_attack() was set on this Action — Strike only] PreBasicAttackEvent
     → equipment/passives may rewrite attack_damage / is_critical
     → cancelled? skip this target
2. PreDamageEvent (generic to ALL damage, not just basic attacks)
     → cancelled? skip this target
3. HexBattleDamageUtils.apply_damage():
     a. shield resolve FIRST (HexBattleShieldResolver.resolve()) — writes
        shield_absorbed / actual_life_damage / consumption_records onto the event
     b. push DamageEvent
     c. deduct HP by actual_life_damage (not the raw damage value)
     d. log via battle.logger
     e. broken-shield callbacks (ShieldBrokenEvent + on_break + ability.expire) —
        BEFORE death check, so exploding-shield callbacks still see live owner context
     f. death check → DeathEvent → process_post_event → clear grid footprint
        (actor stays in world dead; "dead" != "removed", so death VFX can still play)
4. on_hit / on_critical / on_kill callbacks fire (see Callback Chain Pattern below)
5. HexBattleDamageUtils.broadcast_post_damage() — separate call so the caller
   controls timing relative to the callbacks in step 4
```

**There is no random crit roll.** `is_critical` is decided entirely by the PreBasicAttackEvent pipeline (step 1, basic-attack-only) and defaults to `false` for every other damage source (skills, DOTs, reflect, fire tile, totem) — straight from the source docstring:

```gdscript
## §Phase G 暴击规则: DamageAction 自身不再做 randf 暴击; is_critical 由本次的
## attack_pipeline 决定 —— 普攻路径由装备 grant 的 PreBasicAttackEvent handler 决定,
## 非普攻(技能伤害/DOT/反伤等) is_critical 恒为 false。
```

#### Callback Chain Pattern

Real usage from Strike (`logic/abilities/active/strike.gd`) — `on_hit` registers an Action that fires a `BasicAttackLandedEvent` for lifesteal/passive consumers:

```gdscript
HexBattleDamageAction.new(
    HexBattleTargetSelectors.current_target(),
    _CASTER_ATK_DAMAGE,
    BattleEvents.DamageType.PHYSICAL,
).emit_pre_basic_attack().on_hit(_EmitBasicAttackLandedAction.new())
```

`on_hit` always fires on a landed hit; `on_critical` only when `is_critical` ended up true; `on_kill` only when the target died from this hit.

#### Two-Phase Movement

`HexBattleStartMoveAction` (`logic/actions/start_move_action.gd`) reserves the tile, pushes `MoveStartEvent`, and (for `CharacterActor` targets) turns the mover to face the destination via `HexFacing.face_actor_toward()`. `HexBattleApplyMoveAction` (`logic/actions/apply_move_action.gd`), on a later timeline tag, performs the actual `grid.move_occupant()`, updates `actor.hex_position`, and pushes `MoveCompleteEvent` — no facing update here, it already happened in phase 1:

```
StartMoveAction → grid.reserve_tile() + MoveStartEvent + HexFacing.face_actor_toward()
  ↓ (next timeline tag)
ApplyMoveAction → grid.move_occupant() + actor.hex_position update + MoveCompleteEvent
```

Reservation prevents a second actor from being routed onto the same tile between the two phases.

#### Reflect Damage (Infinite Loop Prevention)

`HexBattleReflectDamageAction` (`logic/actions/reflect_damage_action.gd`) targets `HexBattleTargetSelectors.event_source()` (the original attacker) and marks the resulting `DamageEvent` with `is_reflected = true`. It calls `apply_damage()` + `broadcast_post_damage()` directly — no on_hit/on_critical/on_kill callback chain, unlike `DamageAction`. Thorn's own trigger filter (`logic/abilities/passives/thorn.gd`) excludes events with `is_reflected == true` (and requires `actual_life_damage > 0.0`, so a hit fully absorbed by shield doesn't trigger thorns) — that filter is what stops an infinite reflect chain, not a depth counter.

### PreEvent Pattern

Modify or cancel effects **before** they apply. Real definitions in `logic/hex_battle_pre_events.gd` (`class_name HexBattlePreEvents`, no `extends` — a plain namespace holding inner event classes). There are **three** pre-events, not one:

```gdscript
const PRE_DAMAGE_EVENT := "pre_damage"
const PRE_HEAL_EVENT := "pre_heal"
const PRE_BASIC_ATTACK_EVENT := "pre_basic_attack"   # basic-attack-only, see Damage Action Flow above

class PreDamageEvent extends PreExecuteEvent:
    var damage: float = 0.0
    var damage_type: String = "physical"    # String, not a BattleEvents.DamageType enum
    func _init() -> void:
        kind = PRE_DAMAGE_EVENT
```

Usage in an Action (from `damage_action.gd`):

```gdscript
var pre_event := HexBattlePreEvents.PreDamageEvent.create(
    source_actor_id, target_id, attack_damage,
    BattleEvents._damage_type_to_string(_damage_type)
)
var mutable: MutableEvent = event_processor.process_pre_event(pre_event.to_dict(), battle)
if mutable.cancelled:
    continue  # Effect blocked by a passive
var final_damage: float = mutable.get_current_value("damage")
```

PreEvent handlers are registered via `TriggerConfig`/`PreEventConfig` on passive abilities. Every code path MUST return an `ActionResult`.

### Ability Configuration Patterns

Real builder chain: `AbilityConfig.builder()` (no args) → `.config_id()` → `.display_name()` → `.description()` → `.ability_tags([...])` → `.meta(key, value)` (not `.set_meta()`) → `.active_use(...)` and/or `.component_config(...)` → `.build()`. There is no `.add_component()` / `.add_condition()` / `.add_cost()` on the top-level builder — conditions/costs live inside `ActiveUseConfig.builder()`.

#### Active Skill — real example: Strike (`logic/abilities/active/strike.gd`)

```gdscript
static var ABILITY := (
    AbilityConfig.builder()
    .config_id(CONFIG_ID)
    .display_name("普通攻击")
    .ability_tags(["skill", "active", "melee", "enemy"])
    .meta(HexBattleSkillMetaKeys.RANGE, 1)
    .active_use(
        HexBattleCooldownSystem.apply_basic_attack_gating(ActiveUseConfig.builder(), COOLDOWN_MS)
        .timeline_id(TIMELINE_ID)
        .on_timeline_start([StageCueAction.new(
            HexBattleTargetSelectors.current_target(), Resolvers.str_val("melee_slash")
        )])
        .on_tag(TimelineTags.HIT, [
            HexBattleDamageAction.new(
                HexBattleTargetSelectors.current_target(), _CASTER_ATK_DAMAGE, BattleEvents.DamageType.PHYSICAL
            ).emit_pre_basic_attack().on_hit(_EmitBasicAttackLandedAction.new()),
        ])
        .build()
    )
    .build()
)
```

#### Passive Skill — real example: Thorn (`logic/abilities/passives/thorn.gd`)

```gdscript
static var ABILITY := (
    AbilityConfig.builder()
    .config_id(CONFIG_ID)
    .display_name("荆棘")
    .ability_tags(["passive"])
    .component_config(
        NoInstanceConfig.builder()
        .trigger(TriggerConfig.new(BattleEvents.DAMAGE_EVENT, _thorn_filter()))
        .action(HexBattleReflectDamageAction.new(REFLECT_DAMAGE, BattleEvents.DamageType.PURE))
        .build()
    )
    .build()
)
```

`_thorn_filter()` returns a `Callable` checking "is target of this event, has a source, source isn't self, event isn't `is_reflected`, `actual_life_damage > 0.0`" — the last check stops a fully-shield-absorbed hit from still triggering thorns.

#### Projectile Skill — real example: Fireball (`logic/abilities/active/fireball.gd`), the "4-piece pattern"

A projectile damage skill is launch + hit split across **two** timelines and **two** config blocks — the projectile itself carries zero HP damage, only replay/VFX metadata:

```gdscript
static var ABILITY := (
    AbilityConfig.builder()
    .config_id(CONFIG_ID)
    .meta(HexBattleSkillMetaKeys.RANGE, 5)
    .active_use(                                    # ① launch: fires the projectile
        HexBattleCooldownSystem.apply_standard_active_gating(ActiveUseConfig.builder(), COOLDOWN_MS)
        .timeline_id(TIMELINE_ID_CAST)               # ② separate cast timeline
        .on_tag(TimelineTags.LAUNCH, [LaunchProjectileAction.new(
            HexBattleTargetSelectors.current_target(),
            Resolvers.dict_val({ ... }),              # ProjectileActor.CFG_* keys — VFX/replay metadata only
            owner_position_resolver, target_position_resolver,
        )])
        .build()
    )
    .component_config(                               # ③ separate hit-reaction component
        ActivateInstanceConfig.builder()
        .trigger(TriggerConfig.new(ProjectileEvents.PROJECTILE_HIT_EVENT, HexBattleSkillHelpers.projectile_hit_filter))
        .timeline_id(TIMELINE_ID_HIT)                 # its own hit timeline
        .on_timeline_start([HexBattleDamageAction.new(...)])   # ④ actual damage happens here
        .build()
    )
    .build()
)
```

The real damage happens only in step ④, triggered by the projectile's own `PROJECTILE_HIT_EVENT`, once it lands.

### AI Strategy Pattern

**Stateless shared instances** — `AIStrategyFactory` returns the same object for the same class; `decide()` must not mutate `self`.

```gdscript
class_name AIStrategy
# extends RefCounted implicitly (no explicit base)

func decide(actor: CharacterActor, battle: HexWorldGameplayInstance) -> Dictionary:
    return { "type": "skip" }  # Override in subclass

# Shared helpers (logic/ai/ai_strategy.gd): _get_enemies(), _get_allies(),
#   _get_valid_skill_targets() (uses battle.can_use_skill_on()), _select_lowest_hp(),
#   _select_lowest_hp_percent(), _select_nearest(), _make_skill_decision(),
#   _make_move_decision(), _move_toward() (must strictly reduce distance),
#   _move_away_from() (must strictly increase distance), _is_tile_available()
```

**Decision format:** `{"type": "skill/move/skip", "ability_instance_id": ..., "target_actor_id"/"target_coord": ...}` — real subclasses in `logic/ai/`: `MeleeAttackStrategy`, `RangedAttackStrategy`, `RangedSupportStrategy`, `RandomLoadoutStrategy`.

| Strategy | Priority | Behavior |
|----------|----------|----------|
| MeleeAttack | Skill → Move → Skip | Attack lowest HP in range, else move toward nearest |
| RangedAttack | Skill → Move toward → Kite → Skip | Attack in range, approach if far, retreat if too close |
| RangedSupport | Heal → Move → Skip | Heal lowest HP% wounded ally, move toward most injured |

### Target Selectors

Project-specific selectors in `logic/target_selectors.gd` (`class_name HexBattleTargetSelectors` — **not** under `utils/`):

| Selector | Source | Use Case |
|----------|--------|----------|
| `current_target()` | Event's `target_actor_id` | Default for most actions |
| `ability_owner()` | Ability's owner actor | Self-targeting (heals, buffs) |
| `event_source()` | Event's `source_actor_id` | Reflect damage back to attacker |
| `all_enemies()` | All alive actors on opposing team (owner must be a `CharacterActor`) | AoE effects |
| `fixed(targets: Array[String])` | Hardcoded actor ID list | Testing only — takes an `Array[String]`, not a single id |

### Utility Patterns

- **Shared flow extraction**: `HexBattleDamageUtils` (`logic/utils/hex_battle_damage_utils.gd`, all-static) extracts the shield-resolve → push → deduct-HP → log → broken-shield-callbacks → death-check flow shared by `DamageAction` and `ReflectDamageAction`
- **Separated broadcast**: `broadcast_post_damage()` is a separate static call so the caller controls timing — `DamageAction` needs on_hit/on_critical/on_kill callbacks to run *before* the post-damage broadcast; `ReflectDamageAction` posts immediately
- **Type-safe state access**: `HexBattleGameStateUtils` (`logic/utils/hex_battle_game_state_utils.gd`) wraps actor/display-name/death lookups with typed methods

### Config / Data Organization

| File | Pattern | Content |
|------|---------|---------|
| `config/class_config.gd` | `class_name HexBattleClassConfig`, enum + per-class `ClassConfigItem{name, stats}` | 7 character classes (Priest/Warrior/Archer/Mage/Berserker/Assassin/Totem) → base stats |
| `config/skill_config.gd` | `class_name HexBattleSkillConfig`, `get_class_skill(char_class) -> AbilityConfig` | Which class gets which skill — returns the `AbilityConfig` directly, no enum indirection |
| `config/skill_meta_keys.gd` | `class_name HexBattleSkillMetaKeys`, string constants | `RANGE` (int, cast distance), `ALLOWED_TARGET_KINDS` (Array[String], default `["Character"]`) |
| `abilities/shared/all_skills.gd` | `class_name HexBattleAllSkills`, single manifest | One entry (`AbilityConfig` + its Timeline data) per skill/passive/buff drives both `register_all_timelines()` and `all_abilities()` — adding a skill means one new line here |
| `attributes_config.gd` (`logic/attributes/`) | Dictionary config, example-local (auto-discovered by `AttributeSetGeneratorScript`, one per example; generated sets in sibling `generated/`) | Attribute base values and constraints |

### Logging

`HexBattleLogger` (`logic/logger/battle_logger.gd`, `class_name HexBattleLogger extends RefCounted` — **not** `BattleLogger`) — multi-output battle logging, constructed via `HexBattleLogger.new(world.id, {"console": bool, "file": bool})`:
- Console + file output (`user://Logs/battle_<timestamp>_<id>/`)
- Per-actor log files (`actors/*.log`)
- Execution tracking (`execution_start`/`tag_triggered`/`execution_complete`/`execution_cancel`)
- Frame-based organization (`tick()` starts a new frame; `damage_dealt()`, `heal_applied()`, `actor_died()`, `ai_decision()` log within it)

### Additional Subsystems (pointers only)

Brief orientation for subsystems this doc doesn't cover in depth — read the source file directly when you need to touch one.

- **PreBasicAttackEvent pipeline** (`logic/hex_battle_pre_events.gd`): a *third* pre-event, separate from `PreDamageEvent`, that only basic-attack Actions emit (via `.emit_pre_basic_attack()`, Strike-only). Lets equipment/passives (e.g. a critical-strike passive) rewrite `attack_damage` and set `is_critical` (numeric flag, `>= 0.5` → true) before the damage even reaches the generic `PreDamageEvent` stage. Skills/DOTs/reflect never emit it, so `is_critical` is `false` for all non-basic-attack damage.
- **Shield system** (`logic/utils/hex_battle_shield_resolver.gd` + `logic/components/shield_component.gd`): `HexBattleShieldComponent extends AbilityComponent` holds capacity/damage-type-filter/priority/stacking-policy/on_break. `HexBattleShieldResolver.resolve(actor, incoming_damage, damage_type)` picks which shields absorb (damage-type filter → priority DESC → grant-order LIFO → id tiebreak) and is always invoked by `HexBattleDamageUtils.apply_damage()` before HP is deducted.
- **HexFacing** (`logic/hex_facing.gd`): static-only utility owning the 6-direction facing enum (`DIR_EAST=0` .. `DIR_SOUTHEAST=5`) and the *sole* recommended setter `HexFacing.face_actor_toward(actor, target_hex, reason, event_collector)`, which updates the actor's facing and pushes `ActorFacingChangedEvent` in one call (no-ops if direction is unchanged). Forced displacement (push/knockback) intentionally does not change facing.
- **Item / equipment** (`logic/item/hex_item_domain.gd` + `hex_item_catalog.gd`/`hex_actor_equipment_container.gd`/`hex_equipment_ability_resolver.gd`): `HexItemDomain extends ItemDomain`, registered via `ItemSystem.configure_domain()`. Equipping an item is gated on `cfg.equipable` plus `HexEquipmentAbilityResolver` resolving every one of its granted abilities as already-registered — otherwise the move is rejected before any ability is granted (no partial-grant rollback).
- **Scenario harness** (`logic/scenario/skill_scenario_harness.gd`): a small DSL that `tests/battle/skill_scenarios/*.gd` files build on to set up a minimal battle, fire one skill, and assert on resulting events/attributes — the "unit test for one skill" pattern; consult an existing scenario file as the template before writing a new one.
- **`battle_final_state_ready` oracle** (`logic/hex_world_gameplay_instance.gd`): debug-build-only signal emitted right after `battle_finished`, carrying a full actor snapshot (`id`/`type`/`is_dead`/`hex_position`/`attribute`/`abilities`/`tags` per actor, dead actors included) for view-logic reconciliation tooling. Zero cost in release builds.
