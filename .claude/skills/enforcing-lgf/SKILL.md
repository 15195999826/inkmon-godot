---
name: enforcing-lgf
description: Enforces Logic Game Framework conventions for inkmon-godot GDScript code. Covers Actor lifecycle, shared Action/Condition/Cost statelessness, AbilitySet/AttributeSet access, PreEventConfig Intent returns, Resolvers, and event system patterns. Use when writing or modifying GDScript that touches Actor, AbilitySet, Action, Condition, Cost, Resolver, PreEventConfig, or the event system.
---

# Logic Game Framework Conventions

> 本文件与 addon `addons/logic-game-framework/CLAUDE.md` 是仅有的两个规则之家；API 细节看源码，不另写参考文档。

## Contents
- [When to use](#when-to-use)
- [Reference](#reference)
- [Coding Conventions](#coding-conventions)
  - [1. Attribute Access](#1-attribute-access)
  - [2. Actor Creation & Registration](#2-actor-creation--registration)
  - [3. Shared Object Statelessness (CRITICAL)](#3-shared-object-statelessness-critical)
  - [4. GameplayInstance Context](#4-gameplayinstance-context)
  - [5. Resolvers](#5-resolvers)
  - [6. PreEventConfig Handlers](#6-preeventconfig-handlers)
  - [7. GameWorld Dependency](#7-gameworld-dependency)
  - [8. Action Placement (two kinds)](#8-action-placement-two-kinds)
- [Standard Workflow](#standard-workflow)
- [Validation Checklist](#validation-checklist)

## When to use

Apply when writing or modifying GDScript that touches the Logic Game Framework: Actor creation, AbilitySet/AttributeSet access, Action/Condition/Cost implementation, PreEventConfig handlers, Resolvers, or the event system.

## Reference

- **Conventions (detailed)**: See [reference/conventions-detail.md](reference/conventions-detail.md) — Full examples, reference chain diagrams, architecture
- **Cast eligibility vs Condition**: See [reference/cast-eligibility-vs-condition.md](reference/cast-eligibility-vs-condition.md) — Where to put "can this skill be cast" config (metadata, NOT Condition). Read before adding any new cast-time filter (range / target kinds / faction / LOS).
- **Architecture & design rules**: `addons/logic-game-framework/CLAUDE.md` (module dependencies, World owns Battle, 设计铁律).

**Where to look** (no API reference docs — read the source header comments and the tests; paths are relative to `addons/logic-game-framework/`):

| Topic | Source | Tests |
|---|---|---|
| Entity & World (Actor / BattleActor / System / GameplayInstance / WorldGameplayInstance / GridWorldGameplayInstance / BattleProcedure / GameWorld) | `core/entity/Actor.gd`, `core/entity/battle_actor.gd`, `core/entity/System.gd`, `core/world/gameplay_instance.gd`, `core/entity/world_gameplay_instance.gd`, `stdlib/grid/grid_world_gameplay_instance.gd`, `stdlib/grid/i_grid_occupant.gd`, `core/entity/battle_procedure.gd`, `core/world/game_world.gd` | `tests/core/entity/battle_actor_test.gd`, `tests/core/world/world_test.gd`, `tests/core/world/refcount_release_test.gd`, `tests/stdlib/grid/grid_world_gameplay_instance_test.gd`, `tests/core/abilities/instance_context_test.gd` |
| Abilities (Ability / AbilitySet / AbilityConfig builder / ExecutionInstance / LifecycleContext / components / triggers / Condition / Cost / `can_activate`) | `core/abilities/core/ability.gd`, `core/abilities/core/ability_set.gd`, `core/abilities/core/ability_config.gd`, `core/abilities/core/ability_execution_instance.gd`, `core/abilities/core/ability_lifecycle_context.gd`, `core/abilities/core/ability_component.gd`, `core/abilities/components/`, `core/abilities/shared/trigger_config.gd`, `core/abilities/shared/condition.gd`, `core/abilities/shared/cost.gd`, `core/abilities/shared/ability_activation_query.gd` | `tests/core/abilities/` |
| Actions & Resolvers (BaseAction / SkillLocalAction / ExecutionContext / ActionResult / TargetSelector / FlowAction / LooseTagAction / Resolvers) | `core/actions/Action.gd`, `core/actions/execution_context.gd`, `core/actions/action_result.gd`, `core/actions/target_selector.gd`, `core/actions/flow_action.gd`, `core/actions/loose_tag_action.gd`, `core/actions/ability_ref.gd`, `core/resolvers/resolvers.gd` | `tests/core/actions/`, `tests/core/resolvers/resolvers_test.gd` |
| Events (EventProcessor / EventCollector / MutableEvent / Intent / Modification / HandlerContext / pre & post registrations / GameEvent) | `core/events/event_processor.gd`, `core/events/event_collector.gd`, `core/events/event_phase.gd`, `core/events/mutable_event.gd`, `core/events/intent.gd`, `core/events/modification.gd`, `core/events/handler_context.gd`, `core/events/pre_handler_registration.gd`, `core/events/post_handler_registration.gd`, `core/events/game_event.gd` | `tests/core/events/` |
| Attributes & Tags (RawAttributeSet / generated sets / AttributeModifier / Calculator / TagContainer) | `core/attributes/raw_attribute_set.gd`, `core/attributes/base_generated_attribute_set.gd`, `core/attributes/attribute_modifier.gd`, `core/attributes/attribute_calculator.gd`, `core/tags/tag_container.gd`, generator `scripts/generate_attribute_sets.gd` | `tests/core/attributes/` |
| Timeline & Playback (TimelineData / BattleRecorder / PlaybackData / recording utils) | `core/timeline/timeline_data.gd`, `core/playback/battle_recorder.gd`, `core/playback/playback_data.gd`, `core/playback/recording_context.gd`, `core/playback/recording_utils.gd` | `tests/core/timeline/` |
| Stdlib (StatModifier / DynamicStatModifier / TimeDuration components, StageCue / LaunchProjectile actions, projectile system) | `stdlib/components/`, `stdlib/actions/`, `stdlib/projectile/` | `tests/stdlib/components/stat_modifier_component_test.gd` |
| AI Decision (DecisionSnapshot / DecisionOption / OptionProvider / Reasoner / DecisionPipeline / GoalBacktrackReasoner) — the contracts (options sorted by id, `provide()` allocates fresh options, a Reasoner never returns null) are in the file headers | `core/ai_decision/` | `tests/core/ai_decision/decision_pipeline_test.gd` |
| Example app (hex three-layer wiring, procedure, reactive world view, animator, skill scenarios) | `example/hex-atb-battle/README.md`, `example/hex-atb-battle/core/README.md`, `example/hex-atb-battle/frontend/README.md`, `example/hex-atb-battle/logic/hex_world_gameplay_instance.gd`, `example/hex-atb-battle/logic/hex_battle_procedure.gd`, `example/hex-atb-battle/frontend/world_view.gd`, `example/hex-atb-battle/frontend/battle_animator.gd` | `example/hex-atb-battle/tests/battle/skill_scenarios/` |

---

## Coding Conventions

### 1. Attribute Access

Direct access for reads, no getter/setter wrappers. Methods with business logic are fine.

`hp` is a **resource** (`"kind": "resource"` in the attribute config): write it with `set_hp` / `add_hp` — there is no `set_hp_base`, the value is clamped to `[minValue, max_hp]` on write, and reads are capped by the current `max_hp` without touching the stored value (a transient `max_hp` drop — re-equip, Break — lowers `hp` only while it lasts). Stat attributes keep `set_*_base` + modifiers. The generated properties are read-only projections: `attribute_set.hp = x` is silently dropped.

```gdscript
# DO
var hp := actor.attribute_set.hp
actor.attribute_set.add_hp(-damage)      # resource write
actor.attribute_set.set_atk_base(value)  # stat write

# DON'T
actor.attribute_set.hp -= damage         # read-only projection, write is lost
func get_hp() -> float:
    return attribute_set.hp

# OK - has logic beyond simple access
func is_alive() -> bool:
    return attribute_set.hp > 0
```

---

### 2. Actor Creation & Registration

Two-step: **construct** then **register**.

```gdscript
var actor := CharacterActor.new(char_class)
instance.add_actor(actor)  # Framework assigns ID, calls _on_id_assigned()
```

| Phase | Actor._id | Notes |
|-------|-----------|-------|
| After `.new()` | Empty string | Do NOT generate ID in `_init` |
| After `add_actor()` | `{instance_id}:{local_id}` | Auto-generated, triggers `_on_id_assigned()` |

Override `_on_id_assigned()` when components created in `_init` need the actor ID:

```gdscript
func _on_id_assigned() -> void:
    ability_set.owner_actor_id = get_id()
    attribute_set.actor_id = get_id()
```

`get_owner_gameplay_instance()` uses stored `_instance_id` + `GameWorld.get_instance_by_id()` to avoid RefCounted circular references.

A world that needs a hex board extends stdlib `GridWorldGameplayInstance` (`grid`, `configure_grid` / `configure_grid_model`, `clear_grid_footprint`; its `remove_actor` clears the board before leaving the registry) — core `WorldGameplayInstance` has no grid, `_get_map_config()` is its only map hook, and a world without a board (dota2) extends it directly. An actor stands on the board by declaring `hex_position: HexCoord` (`IGridOccupant`); a dead actor that stays in the world only leaves the board (`clear_grid_footprint`), never the registry.

---

### 3. Shared Object Statelessness (CRITICAL)

| Type | Ownership | Mutable State? |
|------|-----------|----------------|
| Ability / AbilityComponent | Per character | YES |
| **Action / Condition / Cost / TriggerConfig** | **SHARED via `static var`** | **NO** |

`static var` configs run `.new()` once at class load. All characters share the same Action/Condition/Cost instances by reference.

**RULE: `execute()` / `check()` / `pay()` MUST NOT modify `self`**

```gdscript
# WRONG: mutable state in shared Action
class BadAction extends Action.BaseAction:
    var _count := 0
    func execute(ctx: ExecutionContext) -> void:
        _count += 1  # FORBIDDEN - pollutes other characters

# CORRECT: state in external storage
class GoodAction extends Action.BaseAction:
    func execute(ctx: ExecutionContext) -> void:
        var ability_set := _get_owner_ability_set(ctx)
        var count: int = ability_set.tag_container.get_stacks("my_counter")
        ability_set.tag_container.apply_tag("my_counter", -1.0, count + 1)
```

**State Storage:**

| Scope | Location |
|-------|----------|
| Cross-ability | `AbilitySet.tag_container` |
| Single-ability cross-cast | `AbilitySet.tag_container` (Tag + Stacks) |
| Single-cast | Local variables in `execute()` |

Debug: `logic_game_framework/debug/action_state_check = true` in Project Settings.

---

### 4. GameplayInstance Context

`ExecutionContext.instance` and `AbilityLifecycleContext.instance` are typed `GameplayInstance`. There is exactly one way the framework finds it: reverse lookup by the owner's actor id (`GameWorld.get_instance_of_actor`). No provider is threaded through call chains (`IGameStateProvider` and every trailing `game_state_provider` parameter are gone); an unregistered owner yields `null` — including grants made before `GameWorld.create_instance(instance)` has registered the instance, so construct → register → `start()` / grants.

- **Narrow in project code**: reads that require a world go through the project's `world(ctx)` helper (`as` + `Log.assert_crash` on mismatch, e.g. `HexBattleGameStateUtils.world`; a project adds one with its first must-have-world read — inkmon and dota2 have none yet). Lifecycle-context reads (Condition / Cost / trigger filter / PreEvent handler get an `AbilityLifecycleContext`, which the helper doesn't take) typed-assign and null-check, asserting in the null branch when the world is required. Reads that may legitimately run without a world use `var battle: HexWorldGameplayInstance = ctx.instance` and null-check (that implicit downcast is type-checked only in debug builds).
- **Contexts are stack-scoped**: never store a context (or `context.instance`) in a Component / Ability / Action / ExecutionInstance field, and never put an instance or actor into `execution_state`. `instance` is a strong reference — caching it closes a cycle RefCounted can't collect.
- **Self-activation is declared, not passed**: `grant_ability(ability)` always delivers `AbilityGranted` to the owner's set; whether an ability self-activates is decided by its own trigger (`TriggerConfig.GRANTED_SELF`).
- **Event infrastructure lives on the instance**: `instance.event_processor` / `instance.event_collector`; `ctx.event_collector` and `context.event_processor` are read-only views derived from `instance`. `GameWorld` is only the instance registry (no `event_processor` / `event_collector` / `init` / `destroy`; its single lifecycle verb is the idempotent `shutdown()`).
- **Post events are subscriptions**: `process_post_event(event_dict)` takes no audience. An ability subscribes in `apply_effects` for every kind its components' triggers name (`get_post_event_kinds()`) and unsubscribes in `remove_effects`; a component that overrides `on_event` without declaring kinds only gets directed deliveries. Whether a dead / stunned owner still reacts is the actor's `is_event_responsive(event_dict, phase)` (pre and post), never a list the caller builds. `ability_activate` / `ability_granted` are directed (`EventProcessor.DIRECT_DELIVERY_KINDS`): deliver them with `ability_set.receive_event`, never `process_post_event`.
- **Event dict keys and kind literals are snake_case**: every key an event `to_dict()` / factory emits (`GameEvent`, `ProjectileEvents`, `PlaybackData`, the `RawAttributeSet` listener dict, ability / component `serialize()`) and every `kind` string matches `^[a-z0-9_]+$` — read them through the constants and `from_dict()`, never a camelCase spelling; `tests/core/events/event_key_casing_test.gd` gates it.

---

### 5. Resolvers

Type-safe delayed evaluation for shared objects. Create via `Resolvers` factory, evaluate via `resolve(ctx)`.

| Resolver | Fixed | Dynamic |
|----------|-------|---------|
| `FloatResolver` | `Resolvers.float_val(v)` | `Resolvers.float_fn(fn)` |
| `IntResolver` | `Resolvers.int_val(v)` | `Resolvers.int_fn(fn)` |
| `StringResolver` | `Resolvers.str_val(v)` | `Resolvers.str_fn(fn)` |
| `DictResolver` | `Resolvers.dict_val(v)` | `Resolvers.dict_fn(fn)` |
| `Vector3Resolver` | `Resolvers.vec3_val(v)` | `Resolvers.vec3_fn(fn)` |

`ParamResolver.resolve_param(resolver: Variant, ctx)` accepting Variant is intentional. Prefer typed Resolvers in new code.

---

### 6. PreEventConfig Handlers

Signature: `func(MutableEvent, AbilityLifecycleContext) -> Intent`

**Every code path MUST return an Intent.** Missing return = null = runtime assertion failure.

| Intent | Factory | Use Case |
|--------|---------|----------|
| Pass through | `EventPhase.pass_intent()` | Condition not met |
| Modify | `EventPhase.modify_intent(id, [Modification])` | Damage reduction |
| Cancel | `EventPhase.cancel_intent(id, reason)` | Immunity, block |

```gdscript
# Correct: all branches return Intent
func(mutable: MutableEvent, ctx: AbilityLifecycleContext) -> Intent:
    if some_condition:
        return EventPhase.cancel_intent(ctx.ability.id, "immune")
    return EventPhase.pass_intent()

# WRONG: forgot return
func(mutable: MutableEvent, ctx: AbilityLifecycleContext) -> Intent:
    EventPhase.modify_intent(ctx.ability.id, [...])
    # Missing return!
```

Optional filter: `func(Dictionary, AbilityLifecycleContext) -> bool` — return `true` to process event.

---

### 7. GameWorld Dependency

Framework directly references `GameWorld` Autoload. This is intentional — do not attempt to decouple. Instance lookup is part of that contract: contexts resolve `instance` through `GameWorld.get_instance_of_actor(owner_actor_id)`.

---

### 8. Action Placement (two kinds)

Which kind an Action is decides where it lives:

| Kind | Base | Where | `class_name` |
|---|---|---|---|
| **Public primitive** — a generic building block (damage / heal / apply buff / launch projectile / loose tag / stage cue …) that knows no specific skill | `Action.BaseAction` | a public action directory: `core/actions/`, `stdlib/actions/`, `example/*/logic/actions/` | yes |
| **Skill-local** — a step that serves exactly one ability | `Action.SkillLocalAction`, constructed with the owner `config_id` (`execute()` asserts the running ability matches it; mismatch is `Log.assert_crash`, never a silent skip) | nested inside that skill's file as `class _XxxAction extends Action.SkillLocalAction` | **never** — and never placed in a public action directory |

Don't add a public primitive for one skill's sake: a complex skill expresses its own process as skill-local actions that compose primitives and `FlowAction.if_`. Public action directories only hold generic primitives.

Rules for both kinds:
- `_init` calls `super._init(target_selector)`; targets come from the selector via `get_targets(ctx)` — never hard-code actor ids in an Action.
- Child actions run through `Action.execute_child(parent, child, ctx)` (freeze / verify can't be skipped); a parent exposes its children via `get_child_actions()`.
- `execution_state` keys carry a namespace (`<skill>.<field>`, via `ctx.set_execution_state` / `ctx.get_execution_state`); values are plain serializable data — no Actor / Resource / instance references. Long-lived state stays in `AbilitySet.tag_container` (§3).
- Cross-time responses (projectile hit, summon, delayed hit) stay event-driven — no parallel callback system on Action.

---

## Standard Workflow

When implementing new game logic that touches the framework, follow these steps:

1. **Identify scope** → Is this an Actor, Ability, Action, PreEvent, or System?
   - **New Actor**: Follow §2 (construct → register → `_on_id_assigned`)
   - **New Ability**: Use `AbilityConfig.builder()` (`core/abilities/core/ability_config.gd`); copy a real one such as `example/hex-atb-battle/logic/abilities/active/poison.gd`
     - `AbilityConfig` keeps one `components` list: `.active_use(cfg)` entries always sort ahead of `.component_config(cfg)` entries regardless of call order (component order is the dispatch order inside the ability). `ActiveUseConfig` **is an** `ActivateInstanceConfig` — a type switch on `is ActivateInstanceConfig` also matches active-use configs; use `get_active_use_configs()` when you mean only those.
   - **New Action**: pick the kind and location per §8, ensure statelessness (§3)
   - **New PreEvent handler**: Follow §6 (every path returns Intent)
2. **Check shared vs owned** → Refer to §3 ownership table. If shared (`static var`), MUST NOT store mutable state in `self`.
3. **Use Resolvers for dynamic params** → If an Action needs runtime values, use `Resolvers` factory (§5) instead of storing state.
4. **Implement** → Write the code following conventions above.
5. **Validate** → Run the checklist below.

## Validation Checklist

Before considering implementation complete, verify:

- [ ] Actor IDs: NOT generated in `_init`; `_on_id_assigned()` syncs ID to components
- [ ] Shared objects (Action/Condition/Cost/TriggerConfig): `execute()`/`check()`/`pay()` do NOT modify `self`
- [ ] State storage: cross-ability → `tag_container`; single-cast → local variables
- [ ] Attribute access: direct `actor.attribute_set.x`, no trivial getter/setter wrappers
- [ ] PreEventConfig handlers: EVERY code path returns an `Intent` (pass/modify/cancel)
- [ ] Resolvers: dynamic values use `Resolvers.float_fn()` etc., not instance fields
- [ ] No attempts to decouple `GameWorld` Autoload dependency
- [ ] `ctx.instance` narrowed through the project's `world(ctx)` for `ExecutionContext` must-have reads (lifecycle contexts and may-be-absent reads: typed assign + null check); no context / `instance` cached in fields or `execution_state`
- [ ] Self-activation on grant is declared with `TriggerConfig.GRANTED_SELF`, not by how `grant_ability` is called
- [ ] Post events go through `process_post_event(event_dict)` with no audience list; death policy lives in the actor's `is_event_responsive`; activation requests go through `ability_set.receive_event`
- [ ] New Action is placed per §8: public primitive with `class_name` in an action directory, or skill-local `_XxxAction extends Action.SkillLocalAction` nested in the skill file without `class_name`
