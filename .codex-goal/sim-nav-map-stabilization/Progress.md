# sim-nav-map Stabilization Progress

## Status

Active.

## Checklist

- [x] Confirm root and `addons` worktrees started without uncommitted changes.
- [x] Inspect `addons/sim-nav-map` docs, tests, and `rts-pathfinding-lab` example.
- [x] Inspect old RTS private pathfinder fixture references in `rts-auto-battle`.
- [x] Document public API boundary.
- [x] Clarify core addon / adapter / example lab responsibilities.
- [x] Update smoke matrix docs around `simnav/smoke` and `rtslab/smoke`.
- [x] Archive old RTS private pathfinder fixture wording.
- [x] Run final audit.
- [x] Run `git diff --check`.
- [x] Run `./tools/run_tests.ps1 simnav/smoke rtslab/smoke`.
- [x] Confirm root and `addons` worktree status.

## Notes

- `.codex-goal/sim-nav-map-stabilization/` did not exist at goal start.
- `addons/sim-nav-map/docs/references/0ad-source/` exists locally, is ignored by `addons/sim-nav-map/.gitignore`, and is not tracked by `git -C addons ls-files`.
- `tools/run_tests.ps1` discovers `addons/sim-nav-map/tests/test_groups.json` and `addons/sim-nav-map/examples/*/tests/test_groups.json`.
- Added `addons/sim-nav-map/docs/public-api.md`, `docs/usage.md`, and `docs/smoke-matrix.md`.
- `./tools/run_tests.ps1 -List` reports `simnav/smoke` with 13 scenes and `rtslab/smoke` with 2 scenes.
- Markdown link audit passed for updated docs.
- `git diff --check` passed in root and `addons`.
- `./tools/run_tests.ps1 simnav/smoke rtslab/smoke` passed 15/15.
- `addons` commit created: `3e5a2ed docs: stabilize sim nav map boundaries`.
