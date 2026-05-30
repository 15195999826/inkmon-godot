# Progress

## Current State

- Status: active
- Branch: `master`
- Workspace: `D:\GodotProjects\inkmon\inkmon-godot`
- Goal scope: full L2 playable vertical slice, with M1 as the first implementation phase.

## Checkpoints

- 2026-05-31 - Planning - User asked to keep this in planning first; initial docs were created before implementation work.
- 2026-05-31 - Planning - Added post-M1 world design gate: overworld/NPC/economy work requires `claude -p` multi-round architecture discussion and consensus before implementation.
- 2026-05-31 - Planning - Corrected goal scope from M1-only to full L2 vertical slice planning through M1/M2/M3/M4/M-lab.
- 2026-05-31 - Planning - Tightened M1 dependency boundary: `hex-atb-battle` lower-level actions/utils/classes are reference-only and cannot be directly called by L2 code.
- 2026-05-31 - Planning - Added runtime validation policy: use `dev-agent-scene-debug-mode` to add minimal adapters where needed, then use `run-dev-scene` for actual Godot scene testing of scene/UI/world/NPC gameplay flows. Headless launcher tests remain required for deterministic smoke/regression coverage.
- 2026-05-31 - Planning - Added UI/UX design gate: each major player-facing UI surface needs `claude -p` discussion, an `imagegen` visual mockup, implementation against the selected mockup, and DevAgent scene validation where applicable.
- 2026-05-31 - Planning - Added commit policy: no failing-test WIP commits, commit only meaningful validated slices, stage only owned files, use submodule-first commits for `addons/` changes, and record validation gaps before any risky commit.
- 2026-05-31 - Goal start - Re-read goal docs, L2 M1 brief, lab L2 design docs, repo/LGF rules, LGF skill guidance, and M1 hex-atb-battle reference paths. Architecture KB weak-relevant guidance checked: P119 supports reference-only example usage; P101 supports project-layer attribute config/generated output.
- 2026-05-31 - M1 start - Confirmed current repo has no `scenes/inkmon-battle/` yet and project attribute config only contains `Hero`/`Tower`. Starting M1 with the Day-1 `InkMonUnitAttributeSet` gate.
- 2026-05-31 - M1 implementation - Added project-local `InkMonUnitAttributeSet`, `scenes/inkmon-battle/` core/logic structure, `InkMonUnitActor`, project-local actions/utils/skills/AI/procedure/world, and `inkmon/m1` smoke. No L2 code directly calls or types against `hex-atb-battle` example classes.
- 2026-05-31 - M1 validation - `./tools/run_tests.ps1 inkmon/m1` PASS. Smoke result `left_win` at 159 ticks, losing side all dead, and logs include `InkMonDamageCalc ... base=34.00 final=22.97`, proving mitigation/element math changed final damage. `git diff --check` PASS. Strict project-local reference scan found no direct `HexBattle*` / `CharacterActor` / `HexWorldGameplayInstance` / `HexBattleProcedure` usage in L2 M1 code.
- 2026-05-31 - Post-M1 design gate - Ran four `claude -p` architecture rounds and reached consensus. Outputs are recorded in `.codex-goal/l2-main-game-vertical-slice/consults/`. Added `Post-M1-World-Architecture-Handoff.md`. Final decisions: `InkMonGameSession` owns `InkMonPlayerState` instead of a new autoload; `InkMonMain.tscn` is an independent L2 entry and `project.godot` stays unchanged during the slice; overworld and battle are sibling LGF instances ticked by `InkMonAppRoot`; battle snapshot injection is added alongside the M1 unit-key fallback; `ItemSystem` is reused through a thin L2 serializer; all six NPC handlers need assertable state changes by final; UI surfaces remain gated by `claude -p` UI discussion, `imagegen` mockup, Godot implementation, and DevAgent validation.
- 2026-05-31 - Post-M1 design validation - `git diff --check` PASS. `./tools/run_tests.ps1 inkmon/m1` PASS (`tests/smoke_m1_battle` 1.4s). No `addons/` changes in this checkpoint.
- 2026-05-31 - Session spine implementation - Added project-local `scenes/inkmon-main/` data spine: `InkMonGameSession`, `InkMonPlayerState`, `InkMonRosterEntry`, `InkMonInventorySerializer`, minimal InkMon item domain/catalog, and `smoke_session_spine`. Added battle snapshot injection beside the M1 unit-key fallback, plus `InkMonBattleWorldGI.get_result_summary()` for player-state reward application. No `project.godot`, UI, DevAgent, or `addons/` changes.
- 2026-05-31 - Session spine validation - `git diff --check` PASS. `./tools/run_tests.ps1 inkmon/session inkmon/m1` PASS (`tests/smoke_session_spine` 1.5s, `tests/smoke_m1_battle` 1.6s). Strict scan of `scenes/inkmon-main` and `scenes/inkmon-battle` found no `hex-atb-battle` / `HexBattle*` / `CharacterActor` / `HexWorldGameplayInstance` / `HexBattleProcedure` references.

## Blockers

- None
