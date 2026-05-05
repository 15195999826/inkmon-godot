# sim-nav-map Feature 0 Baseline Guard Progress

## Status

Complete.

## Checklist

- [x] Create active Codex goal.
- [x] Inspect Feature 0 roadmap and current baseline docs.
- [x] Confirm existing `addons` worktree changes and keep them intact.
- [x] Confirm this pass can stay in docs / goal records unless validation fails.
- [x] Document V1 baseline guard and Feature 1 entry conditions.
- [x] Run `./tools/run_tests.ps1 simnav/smoke rtslab/smoke`.
- [x] Run `git -C addons diff --check`.
- [x] Confirm `addons/sim-nav-map/docs/references/0ad-source/` is not tracked or staged.

## Notes

- `addons` currently has pre-existing uncommitted work in
  `sim-nav-map/docs/feature-roadmap.md` and
  `sim-nav-map/docs/roadmap-refs/0ad-navigation-source-map.md`; this goal keeps
  those changes and does not revert them.
- `addons` HEAD is tagged `sim-nav-map-v1.0.0`, matching the roadmap's V1
  baseline anchor.
- Feature 0 is a regression guard only. No Feature 1+ navigation capability is
  being implemented in this pass.

## Validation Results

- `./tools/run_tests.ps1 simnav/smoke rtslab/smoke`: PASS 16 / FAIL 0 /
  TIMEOUT 0.
- `git -C addons diff --check`: passed.
- `git -C addons status --short -- sim-nav-map/docs/references/0ad-source`:
  empty output.
- `git -C addons ls-files sim-nav-map/docs/references/0ad-source`: empty
  output.

## Feature 1 Entry Condition

Feature 1 can start only from a green Feature 0 baseline:

- `simnav/smoke` and `rtslab/smoke` pass together.
- `git -C addons diff --check` passes.
- `docs/public-api.md`, `docs/smoke-matrix.md`, and
  `docs/feature-roadmap.md` still describe the same core addon /
  `rts-pathfinding-lab` boundary.
- `addons/sim-nav-map/docs/references/0ad-source/` remains untracked.
- The next scope is terrain-derived passability only; runtime code files must be
  named before editing if Feature 1 needs them.
