# Player UI Correction Handoff

Status: ready for implementation after user confirms file/system scope.

Date: 2026-05-31

## Inputs

Claude consults:

- `consults/claude-player-ui-round-1.md`
- `consults/claude-player-ui-round-2.md`

Selected mockup:

- `ui-mockups/inkmon-l2-3d-overworld-player-ui-v1.png`

## UI Direction

The 3D playfield remains the primary surface. Persistent UI is corner-only and compact. Dense information lives in one shared right drawer, not multiple stacked windows.

## Planned Control Structure

`InkMonAppRoot`

- `World3DViewport` / `InkMonOverworldView3D`: full-screen 3D hex scene.
- `HUDLayer`:
  - top-left player status pill: avatar placeholder, rank, gold.
  - top-left party strip: up to six roster slots with level and compact HP/progress bars.
  - top-right tool buttons: Party, Bag, Journal, Menu.
  - bottom-left low-opacity hotkey hint.
  - world-positioned context prompt for nearby NPC interaction.
- `RightDrawerLayer`:
  - scrim that blocks field input while open.
  - drawer panel at the right edge.
  - tab bar for Party / Bag / Journal when player panels are open.
  - NPC mode reuses the same drawer slot and hides the tab bar.
- `ModalLayer`:
  - save/load/system modal opened from Menu or `Esc`.

## Data Binding

All player-facing UI reads from real runtime state, not DevAgent dumps.

- Gold: `session.player_state.gold`
- Rank/guild/cultivation: `session.player_state.progression`
- Party/roster: `session.player_state.roster`
- Bag: `ItemSystem` through the session bag container.
- Save/load: existing `InkMonAppRoot.save_game()` / `load_game()`.
- Last battle/progression feedback: `last_battle_result` and player state after battle completion.

Refresh can initially be explicit from `InkMonAppRoot._refresh_ui()` after state-changing actions. If a stable local signal emerges, use it; do not introduce a broad new state bus for this correction.

## Default Behavior

- First load: HUD visible, drawer closed, 3D movement enabled.
- Moving: HUD remains visible, drawer closed, movement continues.
- Near NPC: floating prompt appears; drawer does not auto-open.
- Prompt/E on NPC: right drawer opens in NPC mode and blocks field input through the scrim.
- Party/Bag/Journal button: right drawer opens in tabbed player mode.
- Menu/Esc: drawer closes first; if drawer is closed, save/load modal opens.
- Battle reward: HUD values update; Journal may show new result summary, but no panel opens automatically.

## Rejected UI Shapes

- Always-on dense dashboard.
- Center or bottom-center persistent overlays.
- Multiple side sheets or draggable windows.
- Save/load as a casual drawer tab without confirmation.
- Any UI path that requires DevAgent state output to understand the game.
- Left-click movement ambiguity; right-click remains movement.

## Implementation Notes

The mockup uses detailed creature portraits/icons as visual direction only. M1 correction may use placeholders, KayKit assets, or simple generated textures if needed, but layout and information hierarchy should match the selected mockup. Any visual deviation must be recorded in `Progress.md`.
