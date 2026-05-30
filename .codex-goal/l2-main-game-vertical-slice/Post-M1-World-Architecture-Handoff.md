# Post-M1 World Architecture Handoff

Status: consensus reached.

Evidence:

- `consults/claude-post-m1-architecture-round-1.md`
- `consults/claude-post-m1-architecture-round-2.md`
- `consults/claude-post-m1-architecture-round-3.md`
- `consults/claude-post-m1-architecture-round-4.md`

The final round signed off after correcting the battle snapshot injection boundary. This handoff is the architecture gate for L2 work after M1 and before overworld, NPC, economy, PlayerState, save/load, or UI implementation.

## 0. Ground Rules

1. L2 remains project-level game code in this repository. Do not create a new addon example or a new repository.
2. `addons/logic-game-framework/example/hex-atb-battle/` remains reference-only. L2 code must not call or type against hex-atb example classes, actions, utilities, AI, skills, world classes, or procedures.
3. Reuse LGF core/framework services: `GameWorld`, `GameplayInstance`, `WorldGameplayInstance`, `EventProcessor`, `AbilitySet`, `AttributeSet`, `UGridMap`, `ItemSystem`, Godot `Node`, signals, and existing autoloads.
4. Do not create a parallel item/inventory system. L2 inventory persistence composes `ItemSystem` capabilities.
5. Do not store persistent player data on a `GameplayInstance`. Instances are runtime simulation objects and may be ended/destroyed.
6. UI/player-facing surfaces are gated separately: `claude -p` UI discussion, `imagegen` mockup saved under this goal folder, Godot implementation, and DevAgent runtime validation.

## 1. Ownership Model

### 1.1 Session-Owned Player State

Final decision: do not make `PlayerState` a new autoload.

Use:

- `InkMonAppRoot extends Node`: scene/root controller for L2 runtime flow.
- `InkMonGameSession extends RefCounted` or `Node`: persistent runtime owner created by `InkMonAppRoot`.
- `InkMonPlayerState`: pure serializable data root held by `InkMonGameSession`.

`ItemSystem` remains an existing autoload/framework service. `InkMonGameSession` owns the player-facing view of inventory state, especially logical container names mapped to runtime `ItemSystem` container ids.

Reasoning:

- Tests can instantiate `InkMonGameSession` directly without global player-state reset hazards.
- Scene/UI dependencies stay explicit through `InkMonAppRoot.session`.
- Godot autoload remains reserved for framework/global services already shaped that way.

### 1.2 Entry Strategy

Add a new independent L2 entry scene:

- `scenes/inkmon-main/InkMonMain.tscn`
- `scenes/inkmon-main/app_root.gd`

During the vertical slice, do not change `project.godot` `run/main_scene`. Keep `Simulation.tscn` and `SimulationManager.gd` web/preview bridge intact until a final entrypoint switch is intentionally designed and validated.

### 1.3 Instance Topology

`InkMonAppRoot` owns the flow state machine and decides which runtime instance is active.

Use sibling LGF instances:

- `InkMonOverworldInstance`: persistent while the player is in the world.
- `InkMonBattleWorldGI`: current M1 battle instance, semantically one battle session.

Battle is not an overworld-internal procedure for the L2 vertical slice. `InkMonAppRoot` transitions into battle by creating a separate battle instance, ticking that active battle instance, consuming its result, destroying/ending it, and returning to the overworld instance.

Only one active instance should be ticked at a time.

### 1.4 Battle Class Naming Boundary

`InkMonBattleWorldGI` may keep its M1 class/file name for now. It must be documented as:

> This class represents one battle session instance. It is team-keyed and ends after battle completion. It is not the persistent overworld.

Optional later cleanup: a rename-only commit may rename it to `InkMonBattleSessionInstance` after overworld instance work makes the naming debt painful. This rename is not a Post-M1 prerequisite.

## 2. Data Model And Projection

### 2.1 `InkMonGameSession`

Responsibilities:

- create/reset `InkMonPlayerState`
- configure and reset session-facing `ItemSystem` state
- own logical inventory container mapping
- serialize/deserialize session/player/inventory persistent state
- apply battle and NPC system results back into player state

Sketch:

```gdscript
class_name InkMonGameSession
extends RefCounted

var player_state: InkMonPlayerState
var inventory_map: Dictionary # logical_name:String -> runtime container id:int

func begin() -> void
func end() -> void
func to_dict() -> Dictionary
func from_dict(data: Dictionary) -> void
```

### 2.2 `InkMonPlayerState`

Persistent save root. It must not hold live `Node`, `Actor`, `GameplayInstance`, or replay objects.

Minimum fields:

```gdscript
{
    "gold": int,
    "roster": Array[Dictionary],
    "overworld": {
        "player_coord": Dictionary,
        "visited_flags": Dictionary,
        "npc_states": Dictionary
    },
    "progression": Dictionary
}
```

### 2.3 `InkMonRosterEntry`

Persistent representation of one owned InkMon. It is not a battle actor.

Minimum fields:

```gdscript
{
    "entry_id": int,
    "species": StringName,
    "stage": int,
    "role": StringName,
    "elements": Array[StringName],
    "level": int,
    "exp": int,
    "persistent_stats": {
        "max_hp": int,
        "ad": int,
        "ap": int,
        "armor": int,
        "mr": int,
        "speed": int
    },
    "learned_skill_id": StringName,
    "equipment_container": String,
    "medals": Array[StringName]
}
```

`equipment_container` is a logical name such as `equip:<entry_id>`, not a raw runtime container id.

### 2.4 `InkMonBattleUnitSnapshot`

Projection product. It is pure value data and replay-safe.

Minimum fields:

```gdscript
{
    "source_entry_id": int,
    "species": StringName,
    "role": StringName,
    "elements": Array[StringName],
    "learned_skill_id": StringName,
    "battle_stats": {
        "max_hp": int,
        "ad": int,
        "ap": int,
        "armor": int,
        "mr": int,
        "speed": int
    }
}
```

`battle_stats` equals persistent stats plus equipment fold plus static medal fold. The battle runtime does not know progression, equipment, or medal systems. New battle actor `hp` starts at `battle_stats.max_hp`; `hp` is not persisted in the snapshot unless a future carry-over-health feature is explicitly designed.

### 2.5 `InkMonBattleConfig`

Battle instance input:

```gdscript
{
    "seed": int,
    "left_roster_snapshots": Array[Dictionary],
    "right_roster_snapshots": Array[Dictionary],
    "rules": Dictionary
}
```

The existing M1 default path remains valid:

```gdscript
{
    "left_roster": Array[String],
    "right_roster": Array[String]
}
```

## 3. Corrected Battle Injection Boundary

The M1 implementation currently uses a fallback path:

- `left_roster`/`right_roster` contain unit-key strings.
- `_create_team_actor(unit_key, team_id)` constructs `InkMonUnitActor.new(unit_key)`.
- `InkMonUnitActor` pulls stats from `InkMonUnitConfig`.

Post-M1 adds a parallel snapshot path. It must not silently replace or break the M1 path.

Rules:

1. `_setup_teams(config)` prefers `left_roster_snapshots`/`right_roster_snapshots` when present.
2. If snapshots are absent, `_setup_teams(config)` falls back to existing `left_roster`/`right_roster` unit-key lists.
3. `_create_team_actor` gains an explicit snapshot branch.
4. The snapshot branch uses project-local initialization such as `InkMonUnitActor.from_battle_snapshot(snapshot)` or `setup_from_snapshot(snapshot)`.
5. Snapshot-provided stat fields must bypass `InkMonUnitConfig`.
6. Missing required snapshot fields should crash fast during implementation unless an explicit fallback rule is designed.
7. Acceptance must include a non-default stat smoke proving the actor used snapshot stats, plus an M1 fallback regression proving default unit-key rosters still pass.

Do not borrow projection, stats, or adapter utilities from `hex-atb-battle`.

## 4. Inventory And Save/Load

`ItemSystem` is the only item service. L2 writes `InkMonInventorySerializer` as a thin serializer around these capabilities:

1. register/configure the item domain and catalog
2. reset session item state
3. create an item in a container
4. enumerate item ids in a container
5. read one item snapshot
6. rebuild one item from a snapshot

Do not assume `ItemSystem` has whole-database `to_dict`/`serialize`.

Persistent inventory save data should be keyed by logical container name, not raw runtime container id. On load:

1. reset `ItemSystem` session state
2. recreate logical containers in deterministic order
3. refill `inventory_map`
4. rebuild items from item snapshots

Save root:

- `InkMonGameSession.to_dict()`
- `InkMonGameSession.from_dict(data)`

V1 does not save battle mid-state or replay. Save only persistent session/player state from overworld/NPC safe points.

## 5. NPC System Boundary

All six v1 NPC systems must share one handler contract and must have at least one headless-assertable state change by final vertical-slice closeout. No pure placeholder NPC remains at final.

Sketch:

```gdscript
class_name InkMonNpcHandler
extends RefCounted

func on_interact(session: InkMonGameSession) -> InkMonNpcSession:
    return null
```

Required v1 floor:

| NPC | V1 depth | Required behavior |
| --- | --- | --- |
| Trainer Advancement | full | starts battle flow, consumes battle result, awards gold/exp/progression |
| Shop | full | spends gold and creates at least one item through `ItemSystem` |
| Release/Adopt | lite | removes/adds at least one roster entry |
| Training | lite | spends gold and changes one roster entry stat/exp/progression field |
| Guild | minimal-real | reads/writes at least one `PlayerState` flag, for example `guild_joined` |
| Cultivation | minimal-real | spends gold or progression and writes one cultivation/progression state |

UI can be simple, but handler behavior cannot be a text-only stub at final.

## 6. Medal And Team Passive Gap

V1 does not add an LGF player/team-level attribute owner.

Use static projection fold:

- roster entry persistent stats
- equipment modifiers
- static medal modifiers
- result becomes `battle_stats`

Reactive team-wide passives are out of v1 unless separately designed. If a later milestone needs them before LGF has a player/team owner, the least invasive fallback is per-actor passive copies, not a new shared owner hidden inside battle code.

## 7. Known Debts

1. `InkMonBattleWorldGI` naming debt. Current class is battle-session semantics with world-instance scaffolding.
2. `RtsRng` autoload currently points at an RTS example path. V1 accepts this existing project boundary debt and does not fix it inside this slice.
3. `project.godot` main scene remains `Simulation.tscn` during vertical-slice development. The final entrypoint decision is a separate closeout task.
4. Battle mid-state save/load is out of v1. Save points are overworld/NPC safe points.

## 8. Implementation Order

1. Add `InkMonGameSession` and `InkMonPlayerState` pure data with `to_dict`/`from_dict` round trip. Do not touch UI or `ItemSystem` yet.
2. Add `InkMonInventorySerializer` and logical container mapping around `ItemSystem` capabilities.
3. Add `InkMonRosterEntry` and deterministic `project_to_battle_snapshot()`.
4. Add snapshot battle injection path while preserving M1 unit-key fallback.
5. Add battle result shape and `PlayerState.apply_battle_result()`.
6. Add `InkMonAppRoot` and `InkMonMain.tscn` independent entry with one active instance ticked at a time. Add DevAgent adapter before relying on runtime scene verification.
7. Add six NPC handlers as data-layer contracts with headless assertions.
8. For player-facing UI surfaces, run the UI gate before Godot UI implementation: `claude -p` discussion, `imagegen` mockup, implementation, DevAgent runtime validation.

## 9. Hard Acceptance Criteria

1. Projection determinism: the same roster entry projected twice produces identical `battle_stats`.
2. Snapshot injection proof: a battle started with deliberately non-default snapshot stats gives actors those exact attributes.
3. HP start rule: a snapshot-created actor starts with `hp == battle_stats.max_hp`.
4. M1 fallback regression: `./tools/run_tests.ps1 inkmon/m1` still passes without snapshot input.
5. Save/load idempotence: `session.to_dict() -> from_dict() -> to_dict()` deep-equals for player state and inventory logical contents.
6. No persisted raw runtime container ids: save data uses logical container names.
7. Battle result can map all `source_entry_id` values back to roster entries.
8. Instance topology: only one active instance is ticked; battle end does not destroy session/player state.
9. NPC floor: each of the six NPC handlers mutates at least one assertable state surface.
10. UI/runtime gate: new L2 scenes and player-facing UI are verified through DevAgent, not only headless tests.

## 10. Next Slice Boundary

The next implementation slice should stop before player-facing UI:

- session/player-state data
- save/load round trip
- roster projection
- battle snapshot injection
- battle-result application

This slice can be validated headlessly. Overworld scene/UI/NPC panel implementation must pause for the UI and DevAgent gates before pixels are built.
