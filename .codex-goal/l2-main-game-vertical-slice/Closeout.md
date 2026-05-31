# L2 Main Game Vertical Slice Closeout

Status: superseded. This closeout was rejected by product owner feedback on 2026-05-31.

See `Completion-Rejection-Gaps.md` for the corrected acceptance criteria. The validation below remains useful as evidence for the data-flow loop, but it no longer represents vertical-slice completion.

## Delivered

- M1 headless 4v4 hex ATB battle with dual-channel stats, element multiplier, role AI, project-local `InkMon*` implementation, and `inkmon/m1` smoke.
- M2 session/player-state spine with battle snapshot projection, inventory serialization through `ItemSystem`, and deterministic round-trip smoke.
- M3 independent `InkMonMain.tscn` runtime shell with DevAgent adapter, overworld hex shell, HUD, prompt, side sheet, Shop buy flow, and Training battle entry.
- M4 minimal playable system NPC flows: Shop, Training, Cultivation, Guild, Trainer Advancement, Release/Adopt, save/load, and expanded `inkmon/app-root` smoke.
- M-lab documented content import contract plus `InkMonL2ContentContract` validator and `inkmon/content` smoke. Runtime still uses project-local stubs until a lab export validates.

## Final Validation

Launcher:

```powershell
./tools/run_tests.ps1 inkmon/content inkmon/app-root inkmon/session inkmon/m1
```

Result: PASS 4/4.

DevAgent final loop:

- Session: `inkmon-main-final-loop-20260531063627`
- Real input moved to Shop, opened prompt, bought `minor_rune`: gold `100 -> 90`.
- Real input moved to Training, clicked CTA, completed battle: winner `left`, gold `90 -> 115`.
- Real input moved to Cultivation, clicked action: gold `115 -> 90`, `cultivation_points=1`, lead InkMon `Lv2`.
- `save_game` and `load_game` returned ok.
- Final state: `OVERWORLD`, gold `90`, bag contains `minor_rune`, lead level `2`.

Strict boundary scan:

```powershell
rg "hex-atb-battle|HexBattle|CharacterActor|HexWorldGameplayInstance|HexBattleProcedure|HexDemoWorldGameplayInstance" "scenes/inkmon-main" "scenes/inkmon-battle"
```

Result: no matches.

## Remaining Deferrals

- Canon lab data import is deliberately deferred until `inkmon-lab` emits a full `inkmon.l2.content.v1` export.
- Multi-slot kit AI, skill variance, evolution, engraving, and player-level medal ownership remain documented future work, not hidden runtime TODOs in this slice.
