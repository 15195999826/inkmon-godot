# sim-nav-map Public API Hardening Progress

## Status

Complete.

## Checklist

- [x] Confirm root and `addons` worktrees started clean.
- [x] Run `./tools/run_tests.ps1 -List`.
- [x] Audit existing docs and `class_name` / non-underscore function boundary.
- [x] Identify public API smoke gap around constructor/default and queued request
  cloning contracts.
- [x] Add or tighten `simnav/smoke` contract coverage.
- [x] Update public API and usage docs to match actual entry points.
- [x] Run `git diff --check`.
- [x] Run `./tools/run_tests.ps1 simnav/smoke rtslab/smoke`.
- [x] Final audit scope and ensure `0ad-source/` is not staged.
- [x] Commit `addons` submodule and root pointer/goal docs.

## Notes

- `./tools/run_tests.ps1 -List` passed at goal start and reported
  `simnav/smoke` plus `rtslab/smoke`.
- After adding `smoke_sim_nav_public_api_contract.tscn`,
  `./tools/run_tests.ps1 -List` reports `simnav/smoke` with 14 scenes.
- Existing `public-api.md` already separated core addon, adapter, lab, and
  game-specific movement policy. The main gap was function-level boundary and
  a missing `SimNavObstructionShape` base return-type note.
- `./tools/run_tests.ps1 simnav/smoke` passed 14/14 after fixing one incorrect
  new smoke assertion around zero-size static obstruction center containment.
- `git -C addons diff --check` and root `git diff --check` passed.
- `./tools/run_tests.ps1 simnav/smoke rtslab/smoke` passed 16/16.
- Final scope audit only listed `addons/sim-nav-map/**`,
  `.codex-goal/sim-nav-map-api-hardening/**`, and the root `addons` submodule
  pointer.
- `git -C addons status --short -- sim-nav-map/docs/references/0ad-source`
  returned empty.
- `addons` commit created: `592a4f8 test: harden sim nav public API contract`.
