# Completion Rejection Gaps

Status: corrected implementation completed and validated.

Date: 2026-05-31

## Why The Previous Closeout Is Invalid

The previous closeout proved a data-flow loop, but it did not prove the intended L2 main-game experience. It is superseded by this document.

Missing requirements:

1. The main game must be a 3D game in the same broad presentation family as `hex-atb-battle`, not a flat 2D placeholder overworld.
2. Player movement must use right-click-on-tile commands and pathfind to the clicked grid cell. Keyboard step movement is only acceptable as a debug shortcut, not as the primary v1 control path.
3. Player-facing UI is incomplete. NPC panels alone are insufficient. The slice needs enough self-service UI for the player to understand and operate the game without DevAgent state dumps.

## Corrected Acceptance

The vertical slice is not complete until all of the following are implemented and validated:

- 3D overworld scene using project-local L2 code.
- 3D hex map rendering path based on existing `GridMapRenderer3D` / KayKit preview / hex-atb frontend patterns.
- Player avatar visible on the 3D grid.
- Mouse right-click raycast to hex tile.
- Right-click issues a move command, computes a path, and moves the player along the path.
- Movement reference is `hex-atb-battle`'s `Move` ability pipeline, not `sim-nav-map` / RTS pathfinding:
  - `HexBattleMove`
  - `HexBattleStartMoveAction`
  - `HexBattleApplyMoveAction`
  - grid reservation / occupant updates / `MoveStartEvent` / `MoveCompleteEvent`
- Overworld right-click movement may add multi-step path planning, but each committed step should preserve the same hex grid mutation semantics as the move skill pipeline.
- NPC interaction works after path movement, not only after direct coordinate mutation.
- Player UI includes, at minimum:
  - player status/resource strip
  - party/roster status
  - bag/inventory panel backed by `ItemSystem`
  - progression summary
  - save/load access or a clearly documented v1 save/load UI affordance
- The above has a `claude -p` architecture/UI discussion recorded under `consults/`.
- A new imagegen mockup is generated for the corrected 3D overworld + player UI surface before Godot UI implementation.
- DevAgent validation uses real input for right-click movement and relevant UI clicks.

## Existing Work That Remains Valid

- M1 battle core and headless smoke.
- Session/player-state/inventory serialization spine.
- Six NPC handlers and minimal data effects.
- Save/load data API.
- Lab content contract validator.

These are necessary foundation pieces, but they are not sufficient completion criteria.

## Correction Gate Decisions

Architecture/UI gate outputs are now recorded:

- `consults/claude-3d-overworld-round-1.md`
- `consults/claude-3d-overworld-round-2.md`
- `consults/claude-player-ui-round-1.md`
- `consults/claude-player-ui-round-2.md`
- `3D-Overworld-Correction-Handoff.md`
- `Player-UI-Correction-Handoff.md`
- `ui-mockups/inkmon-l2-3d-overworld-player-ui-v1.png`

## Corrected Closeout Evidence

The rejection gaps are now closed by the corrected 3D/UI slice:

- 3D main scene: `scenes/inkmon-main/InkMonMain.tscn` now instantiates project-local `InkMonOverworldView3D`.
- Right-click hex movement: `InkMonAppRoot._input()` routes secondary mouse clicks through tile picking and `InkMonOverworldMoveController`.
- Move semantics: each path step reserves the target tile, updates grid occupants, emits start/apply/complete events, and clears reservations.
- Player UI: HUD, roster strip, Party drawer, Bag drawer backed by `ItemSystem`, Journal/progression drawer, NPC drawer, and save/load modal are present.
- Validation: `git diff --check` PASS and `./tools/run_tests.ps1 inkmon/content inkmon/app-root inkmon/session inkmon/m1 inkmon/overworld-3d` PASS.
- Runtime evidence: DevAgent session `inkmon-main-3d-correction-20260531112918` proved real right-click movement, NPC interaction, buy, battle reward, cultivation progression, player panels, save, and load.
