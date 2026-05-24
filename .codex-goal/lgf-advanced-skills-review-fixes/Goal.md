# LGF Advanced Skills Review Fixes

## Objective

Fix the Codex review findings from LGF advanced skills Phase 2+ so the new skills are correct in production, replay, and scenario paths.

## Deliverables

- Fix Fire Tile overlay cleanup so expiring/removing an overlay actor never clears a character occupant on the same hex.
- Fix production `HexBattleProcedure` mid-spawn actor recording so spawned totems/fire tiles have correct replay lifecycle and ability events.
- Fix spawn initialization ordering or registration timing so recorder/frontend snapshots see initialized team, position, attributes, and abilities.
- Resolve `Cleanse` self-target contract mismatch with `HexWorldGameplayInstance.can_use_skill_on`.
- Resolve Break semantics for passive abilities with `TimeDurationConfig`, especially `TotemLifetime` and `FireTileLifetime`.
- Add or tighten scenario/frontend/regression coverage for the fixed paths.

## Non-Goals

- Do not implement unrelated advanced skills beyond the review fixes.
- Do not do broad frontend VFX polish unless needed for a failing contract.
- Do not introduce the full `HexBattleActor.placement_mode` abstraction unless the minimal occupant-safe fix is insufficient.
- Do not include unrelated dirty or untracked files.

## Validation

- `./tools/run_tests.ps1 hex/skills`
- `./tools/run_tests.ps1 hex/regression`
- `./tools/run_tests.ps1 core/unit hex/skills hex/regression`
- Targeted production replay/smoke evidence for Summon Totem and Fire Tile mid-spawn actor lifecycle.
- If frontend scope is touched, run `./tools/run_tests.ps1 hex/frontend` and record any pre-existing timeout separately.

## Completion Gate

- All P1/P2 review findings above are either fixed with tests or explicitly documented as accepted follow-up with stronger evidence than the current review.
- Required validation commands pass, or any failure is root-caused and not caused by this goal.
