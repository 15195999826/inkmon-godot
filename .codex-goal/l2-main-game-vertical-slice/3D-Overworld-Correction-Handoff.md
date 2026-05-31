# 3D Overworld Correction Handoff

Status: ready for implementation after user confirms file/system scope.

Date: 2026-05-31

## Inputs Read

- `.codex-goal/l2-main-game-vertical-slice/Goal.md`
- `.codex-goal/l2-main-game-vertical-slice/Progress.md`
- `.codex-goal/l2-main-game-vertical-slice/Completion-Rejection-Gaps.md`
- `scenes/KaykitPreview.gd`
- `addons/logic-game-framework/example/hex-atb-battle/frontend/world_view.gd`
- `addons/logic-game-framework/example/hex-atb-battle/logic/abilities/active/move.gd`
- `addons/logic-game-framework/example/hex-atb-battle/logic/actions/start_move_action.gd`
- `addons/logic-game-framework/example/hex-atb-battle/logic/actions/apply_move_action.gd`
- Current `scenes/inkmon-main/`

Claude consults:

- `consults/claude-3d-overworld-round-1.md`
- `consults/claude-3d-overworld-round-2.md`

## Chosen Architecture

Implement a project-local 3D overworld under `scenes/inkmon-main/`. The 3D view replaces the current 2D `InkMonOverworldView`, while `InkMonAppRoot` remains the single orchestrator for session state, NPC handlers, battle entry, save/load, and UI.

Movement uses a project-local lightweight two-phase controller, not `hex-atb-battle` classes and not battle `InkMonMove` classes. The controller preserves the required Move semantics:

1. Resolve target/path.
2. Reserve the next tile.
3. Emit move-start state.
4. Apply occupant movement.
5. Sync `session.player_state.overworld["player_coord"]`.
6. Release reservation.
7. Emit move-complete state.

Right-click movement pathing uses bounded axial-hex BFS over the overworld grid. This is not RTS navigation and does not use `addons/sim-nav-map`. Each path step commits through the same two-phase move semantics.

## Planned Project-Local Files

Likely new files:

- `scenes/inkmon-main/overworld/ink_mon_overworld_grid.gd`
- `scenes/inkmon-main/overworld/ink_mon_overworld_move_controller.gd`
- `scenes/inkmon-main/overworld/ink_mon_overworld_view_3d.gd`
- `scenes/inkmon-main/overworld/InkMonOverworldView3D.tscn` if the view is split into its own scene.
- `scenes/inkmon-main/tests/smoke_overworld_3d.gd`
- `scenes/inkmon-main/tests/smoke_overworld_3d.tscn`

Likely changed files:

- `scenes/inkmon-main/app_root.gd`
- `scenes/inkmon-main/InkMonMain.tscn`
- `scenes/inkmon-main/ink_mon_main_agent_ops.gd`
- `scenes/inkmon-main/DEV_AGENT.md`
- test launcher manifest for `inkmon/overworld-3d` if required by `tools/run_tests.ps1`.

No planned `addons/` edits.

## NPC Targeting Rule

NPC tiles are occupied/blocked. If the player right-clicks an NPC tile or any blocked tile, resolve the target to the reachable free neighbor of that tile with the shortest BFS distance from the player. Tie-break deterministically by axial `(q, r)`.

After movement completes, `InkMonAppRoot` refreshes existing NPC proximity. The 3D view never calls NPC handlers directly.

## Rejected Options

- Direct dependency on `addons/logic-game-framework/example/hex-atb-battle/`.
- Reusing battle `InkMonMove` or battle `InkMonBattleWorldGI` in overworld.
- `addons/sim-nav-map`, RTS pathfinding, steering, or navmesh movement.
- Single-step or straight-line-only movement as the primary right-click path.
- A new overworld LGF `GameplayInstance` solely for this slice.
- A separate NPC/UI orchestrator outside `InkMonAppRoot`.

## Validation Plan

Launcher:

- `git diff --check`
- `./tools/run_tests.ps1 inkmon/content inkmon/app-root inkmon/session inkmon/m1`
- `./tools/run_tests.ps1 inkmon/overworld-3d`

Smoke acceptance:

- Right-click-equivalent move computes a multi-step BFS path.
- Each path step records start/apply/complete semantics.
- Reservation set is empty after movement.
- Occupant count is conserved.
- Player never lands on blocked NPC tile.
- `session.player_state.overworld["player_coord"]` matches final visual position.
- Moving to an NPC-adjacent tile sets `near_npc_id` and allows NPC interaction.

DevAgent real-input acceptance:

- Capture/inspect confirms non-empty 3D scene, player avatar, NPC markers, and HUD.
- Real right-click on a hex tile moves the player to the target.
- Real right-click on or near NPC moves to an interaction tile and opens NPC UI through prompt/click.
- DevAgent scene op for `goto_tile` must route through the same move controller as right-click input, not a second movement implementation.
