# Overworld UI Handoff

Status: UI gate complete for the first player-facing surface.

Consult evidence:

- `consults/claude-ui-overworld-round-1.md`
- `consults/claude-ui-overworld-round-2.md`

Selected mockup:

- `ui-mockups/overworld-shop-v2.png`

Draft kept for traceability:

- `ui-mockups/overworld-shop-v1.png`

`overworld-shop-v1.png` had the right direction but generated five roster chips. V2 is selected because the first implementation must bind roster chips to the actual `player_state.roster.size()` and the current new-game roster has four entries.

## 1. Surface

First surface: L2 overworld + NPC interaction shell, shown in the `Shop` opened state.

This is not a landing page, menu-only screen, or dashboard. The hex overworld remains the primary viewport. The HUD and panel are supporting chrome.

## 2. Visual Direction

- Ink-and-parchment fantasy map.
- Warm parchment playfield.
- Low-chrome semi-transparent ink panels.
- Amber gold accent, small elemental color dots on roster chips.
- Motion tone: quiet, minimal, no constant animation. Prompt can pulse subtly later.

Godot implementation should use simple `Node2D`/`Control` shapes first. The mockup is a direction reference, not a requirement to ship detailed illustration assets in this slice.

## 3. Must-Have Visible Elements

1. `WorldLayer`: hex map, player token, and NPC markers.
2. Two emphasized NPC markers: `Shop` and `Trainer`.
3. Top-left gold display from `session.player_state.gold`.
4. Trainer rank `R1` from `session.player_state.progression.trainer_rank`.
5. Roster chip row bound to `session.player_state.roster.size()`.
6. Top-right settings icon placeholder.
7. Near-NPC prompt bubble with `Enter`.
8. NPC side sheet shell with header, close, and dim overlay.
9. Shop rows for `Training Sword` and `Minor Rune`.
10. Trainer CTA `Start Training Battle` in the same shell later, not a separate UI framework.

## 4. Data Decisions

The mockup displays `Training Sword 30` and `Minor Rune 10`. Current `InkMonItemCatalog` does not yet have price data. The v1 implementation should add a `price` field to the project-local catalog for these two items:

- `Training Sword`: 30
- `Minor Rune`: 10

If future economy design moves prices into Shop NPC config, that should be a focused migration. Do not duplicate price truth in both places during this slice.

## 5. Godot Layering

Recommended scene children under `InkMonMain`:

- `WorldLayer` (`Node2D`): hex grid, player marker, NPC markers.
- `HUDLayer` (`CanvasLayer` / `Control`): gold, rank, roster chips, settings icon.
- `PromptLayer` (`CanvasLayer` / `Control`): near-NPC `Enter` bubble.
- `PanelLayer` (`CanvasLayer` / `Control`): dim overlay and NPC side sheet.

`InkMonAppRoot` remains the state owner. UI reads from `session.player_state` and calls normal AppRoot methods for state transitions.

## 6. DevAgent Boundary

Direct scene ops remain valid for data flow:

- `state`
- `reset_session`
- `run_training_battle`

New player-facing UI paths must use real input through DevAgent raw ops:

- move player to trigger near-NPC prompt
- click `Enter` to open `NPC_MENU`
- click Shop `Buy`
- click Trainer `Start Training Battle`
- click panel close
- click roster chip expansion when implemented

Post-click assertions should use structured scene state. The click itself must not be replaced with `pressed.emit()` or a direct scene op.

## 7. Implementation Scope

The next implementation slice may build:

- static hex overworld shell
- player token movement between a small set of hex cells
- near-NPC prompt for Shop/Trainer
- Shop side sheet
- real-input `Buy` flow: deduct gold and create item through `ItemSystem`
- DevAgent state/layout ops for verification

It should not build:

- full overworld art production
- all six NPC panels at full depth
- mobile responsive layout
- battle presentation UI
- final save slot UI
