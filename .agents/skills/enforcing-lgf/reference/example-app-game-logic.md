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
- [Skill Declaration Conventions](#skill-declaration-conventions)
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
      buffs/                    # Buff configs: stun_buff.gd, silence_buff.gd, shield_buffs.gd, buff_tags.gd
      passives/                 # Passive impls: thorn.gd, vitality.gd, general_passive.gd, ...
      shared/                   # cooldown_system.gd, skill_helpers.gd, skill_tags.gd, std_timelines.gd,
                                #   skill_presets.gd, all_skills.gd (single manifest)
    actions/                    # damage_action.gd, heal_action.gd, start/apply_move_action.gd, push_action.gd,
                                #   cancel_move_action.gd (move execution on_cancel cleanup), ...
    ai/                         # ai_strategy.gd (base) + melee/ranged_attack/ranged_support strategies
    attributes/                 # attributes_config.gd + generated/ (example-local AttributeSets)
    components/                 # shield_component.gd (AbilityComponent subclass)
    config/                     # class_config.gd, skill_config.gd, skill_meta_keys.gd, hex_battle_cues.gd
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
    battle/smoke_manifest_lint.gd  # Four manifest assertions, on the required hex/regression group
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

#### Derived Data: Compute Once Into `execution_state`

When several downstream pieces (a predicate, a selector, a handful of resolvers) all need the same derived fact, compute it **once** at the head of the tag's action list, write it into `ExecutionContext.execution_state` under a namespaced key, and let everyone else read it. `chain_lightning` (`logic/abilities/active/chain_lightning.gd`) does exactly that: an `on_hit` chain-head action writes `execution_state["chain_lightning.next"]`, and the predicate/selector/resolvers downstream are read-only. Before, the "next hop" was recomputed six times (each an O(whole battlefield) scan) and correctness rested on the implicit invariant that the world does not change across those six calls. `shadow_step`'s `"shadow_step.teleport_success"` is the same pattern.

Remember the key must be namespaced with a `.` (`set_execution_state` asserts), and the written value must be deterministic — no wall clock, no randomness, no mutable singleton (playback re-derives it by re-executing, the event stream does not record `execution_state`).

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
        .timeline(TIMELINE)
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
        .timeline(CAST_TIMELINE)                     # ② separate cast timeline (static TimelineData)
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
        .timeline(HIT_TIMELINE)                       # its own hit timeline
        .on_timeline_start([HexBattleDamageAction.new(...)])   # ④ actual damage happens here
        .build()
    )
    .build()
)
```

The real damage happens only in step ④, triggered by the projectile's own `PROJECTILE_HIT_EVENT`, once it lands.

### Skill Declaration Conventions

The July 2026 convergence pass turned four classes of "silently wrong" declaration into single sources plus a lint gate. Follow these when adding or editing a skill/buff/passive.

#### `ability_tags` — two orthogonal axes, two constant files

- **Carrier axis (mutually exclusive, exactly one required)**: `skill` (+ `active`) / `passive` / `buff` / `intrinsic` / `status` / `lifetime`. `buff` means specifically **a grantable state instance** (shows in the buff bar, cleanse can act on it, SkillPreview's picker excludes it). A passive is *never* `buff` — "beneficial passive" is expressed on the polarity axis.
- **Polarity axis (orthogonal, any carrier; a buff instance must carry one)**: `negative` / `positive`. "Is this beneficial?" is always answered by the polarity tag, never by the carrier (demon_form = `passive` + `positive`, a shield = `buff` + `positive`, poison = `buff` + `negative`).
- `control` (hard CC: stun/silence/break) and `passive_break` are cleanse-priority tags.

| Constants file | Class | Holds |
|---|---|---|
| `logic/abilities/shared/skill_tags.gd` | `HexBattleSkillTags` | Carrier: `TAG_SKILL` / `TAG_ACTIVE` / `TAG_PASSIVE` / `TAG_INTRINSIC` / `TAG_STATUS` / `TAG_LIFETIME`; targeting legality: `TAG_ENEMY` / `TAG_ALLY` / `TAG_SELF`; AI branch: `TAG_HEAL`; descriptive-only `TAG_CONE` |
| `logic/abilities/buffs/buff_tags.gd` | `HexBattleBuffTags` | `TAG_BUFF` / `TAG_NEGATIVE` / `TAG_POSITIVE` / `TAG_CONTROL` / `TAG_PASSIVE_BREAK` |

**Rule: a tag with a code consumer gets a const** — declaring side and consuming side reference the same symbol, so a typo becomes a compile error. Purely descriptive tags (`melee` / `ranged` / `magic` / `aoe` / `line` / flavour words) stay string literals and are covered by lint assertion 4's vocabulary list instead.

#### `HexBattleCues` — the official cue menu

`logic/config/hex_battle_cues.gd`. The frontend **silently skips** an unregistered cue id (no error, no visual), which is exactly why the menu exists: both the declaring side (`StageCueAction`, and the few direct `GameEvent.StageCue.create` call sites) and the frontend registry (`stage_cue_visualizer`) must reference these constants. Wanting a new cue means adding a line here first, so the change is visible. Groups are annotated as *has visuals* / *deliberately no visuals* (carried by the projectile animation) / *no visuals yet* (logic emits, art not wired — mirrored in the lint exemption list).

#### `HexBattleStdTimelines` — shared standard rhythms

`logic/abilities/shared/std_timelines.gd` — `MELEE_500` (HIT@300 / END@500), `CAST_LAUNCH_600` (CAST@200 / LAUNCH@400 / END@600), `HIT_RESPONSE_100` (END@100). "500ms with HIT at 300" is a global convention, not a per-skill personality, so it is one shared `static var TimelineData`; skills with genuine rhythm personality (charge-up, multi-hit, two-phase displacement, summon, buff tick, `precise_shot`) keep custom timelines.

Sharing is safe because `TimelineData` is pure data with no write points after construction (the execution cursor lives in `AbilityExecutionInstance`, new per cast) and `.timeline(data)` freezes `tags` at declaration. **Replay note:** the recorded `timeline_id` then reads `std_*` rather than a skill name — identify the skill through the event's ability `config_id`.

#### `HexBattleSkillPresets.buff_applier(...)` — the zero-difference family

`logic/abilities/shared/skill_presets.gd`. Eight "pick a target → apply a buff/shield" skills (stun / silence / break / expose / ward / both shields / surge) had byte-identical skeletons with ~8 informative lines each, so they collapsed into one preset:

```gdscript
static func buff_applier(
    config_id: String, display_name: String, description: String,
    ability_tags: Array[String], skill_range: int, targeting: String, cooldown_ms: float,
    buff_config: AbilityConfig, cue_id: String = "",
    use_shield_action: bool = false, extra_meta: Dictionary = {},
) -> AbilityConfig
```

It builds `apply_standard_active_gating` + `MELEE_500` + an optional `on_timeline_start` StageCue + `on_tag(HIT, [ApplyBuff | ApplyShield])`, and asserts `targeting` is `ACTOR` or `SELF`. **`poison.gd` deliberately stays fully explicit** as the family's teaching sample — read it to see what the preset expands into. Boundary: presets only absorb zero-variation boilerplate; anything with its own mechanic (execute's conditional damage, shadow_step's displacement, lifesteal's `on_hit` callback) keeps an explicit builder chain.

#### `TARGETING` — the cast-input protocol

`HexBattleSkillMetaKeys.TARGETING` is **required on every active skill** (lint assertion 4), with values `TARGETING_ACTOR` (`"actor"`) / `TARGETING_COORD` (`"coord"`) / `TARGETING_SELF` (`"self"`). It is what AI reads to decide whether the activate event carries `target_actor_id` or `target_coord` — the old heuristic of sniffing for a `"cone"` tag is gone.

Two legality entry points on `HexWorldGameplayInstance`, and they do **not** overlap:
- `can_use_skill_on(actor, skill, target) -> bool` — ACTOR/SELF only; a `COORD` skill returns `false` here immediately (letting it through would bypass the coord path's `grid.has_tile` check)
- `can_use_skill_at(actor, skill, coord) -> bool` — COORD only; requires a valid coord, `grid.has_tile(coord)`, and distance ≤ `RANGE`

Targeting splits into three layers, and mixing them is the mistake to avoid: **legality → metadata** (queryable without running anything) · **shape geometry → shared static pure functions** (AI preview and execution must share the same function) · **execution-time resolution → `TargetSelector`**. Regression coverage: `tests/battle/smoke_targeting_protocol.tscn` (`hex/skills` group).

#### Manifest lint (`tests/battle/smoke_manifest_lint.gd`)

Walks `HexBattleAllSkills.all_abilities()` and makes four assertions, one per silent-failure class. It is on the required `hex/regression` group.

| # | Assertion | The silent failure it replaces |
|---|---|---|
| 1 | Every timeline reachable via `AbilityConfig.collect_timelines()` has an empty `validate()`, has **frozen** `tags` (`tags.is_read_only()`, i.e. it went through `builder.timeline(data)`), and **the same id always means the same instance** across the whole manifest | Two places declaring same-named timelines that clobber each other, or a factory doing an inline `TimelineData.new()` |
| 2 | Every `config_id` carrying `HexBattleBuffTags.TAG_BUFF` is in `FrontendBuffVisualizer.BUFF_REGISTRY` (or the explicitly-reasoned exemption list) | A buff with no head-icon entry simply never displays, with no error |
| 3 | Every statically declared cue (top-level actions plus a generic DFS through `Action.get_child_actions()`, so FlowAction branches and DamageAction callback chains are covered) is in `FrontendStageCueVisualizer`'s registries ∪ the two exemption lists | `stage_cue_visualizer` silently skips an unknown cue |
| 4 | Every tag is in the vocabulary (the two constant classes + the descriptive word list), and every config with an `active_use` component declares `RANGE` plus a `TARGETING` that is one of the three legal values | A tag typo silently drops behaviour; a missing `RANGE` is silently read as `1` (the `stance` bug) |

Direct `GameEvent.StageCue.create` call sites (demon_form / totem_attack) cannot be collected statically — they are covered by the convention that they must reference `HexBattleCues` constants.

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
- **Shared skill helpers** (`logic/abilities/shared/skill_helpers.gd`, `class_name HexBattleSkillHelpers`): pass `ability_activate_filter` / `projectile_hit_filter` as **function references** (no parentheses) to `TriggerConfig`; **call** `target_coord_from_event()` / `owner_position_resolver()` / `target_position_resolver()` / `caster_atk_damage(mult)` (each returns a fresh Resolver). `caster(ctx) -> CharacterActor` replaces the five-line "owner_id → null check → get_actor → is CharacterActor → cast" boilerplate that used to be copied into every resolver/action — note it deliberately does **not** check `is_dead()`, since some call sites only want the coordinate

### Config / Data Organization

| File | Pattern | Content |
|------|---------|---------|
| `config/class_config.gd` | `class_name HexBattleClassConfig`, enum + per-class `ClassConfigItem{name, stats}` | 7 character classes (Priest/Warrior/Archer/Mage/Berserker/Assassin/Totem) → base stats |
| `config/skill_config.gd` | `class_name HexBattleSkillConfig`, `get_class_skill(char_class) -> AbilityConfig` | Which class gets which skill — returns the `AbilityConfig` directly, no enum indirection |
| `config/skill_meta_keys.gd` | `class_name HexBattleSkillMetaKeys`, string constants | `RANGE` (int, cast distance), `ALLOWED_TARGET_KINDS` (Array[String], default `["Character"]`), `TARGETING` (String, required on active skills; `TARGETING_ACTOR` / `TARGETING_COORD` / `TARGETING_SELF`) |
| `config/hex_battle_cues.gd` | `class_name HexBattleCues`, string constants | The official StageCue menu — see [Skill Declaration Conventions](#skill-declaration-conventions) |
| `abilities/shared/skill_tags.gd` + `abilities/buffs/buff_tags.gd` | `HexBattleSkillTags` / `HexBattleBuffTags` | Load-bearing `ability_tags` constants, two-axis model — same section |
| `abilities/shared/std_timelines.gd` | `class_name HexBattleStdTimelines`, `static var TimelineData` | `MELEE_500` / `CAST_LAUNCH_600` / `HIT_RESPONSE_100` shared rhythms |
| `abilities/shared/skill_presets.gd` | `class_name HexBattleSkillPresets`, static factories | `buff_applier(...)` — the 8-skill zero-difference family skeleton |
| `abilities/shared/all_skills.gd` | `class_name HexBattleAllSkills`, single manifest | One `AbilityConfig` entry per skill/passive/buff feeds `all_abilities()` (SkillPreview / tools / `smoke_manifest_lint`, which asserts every carried timeline is valid, frozen and unique per id) — adding a skill means one new line here; timelines ride on the config tree via `.timeline(data)`, nothing to register |
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
