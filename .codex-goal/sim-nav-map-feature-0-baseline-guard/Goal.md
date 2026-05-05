# sim-nav-map Feature 0 Baseline Guard Goal

## Objective

Complete the Feature 0 baseline guard for `addons/sim-nav-map` in
`D:\GodotProjects\inkmon\inkmon-godot`.

## Scope

Allowed write scope:

- `addons/sim-nav-map/docs/**`
- `addons/sim-nav-map/tests/**` only if an existing baseline smoke contract needs
  registration or wording alignment
- `addons/sim-nav-map/examples/rts-pathfinding-lab/{README.md,tests/**}` only if
  the lab baseline contract needs registration or wording alignment
- `.codex-goal/sim-nav-map-feature-0-baseline-guard/**`

Runtime code under `addons/sim-nav-map/{core,model,obstruction,pathfinding}/` or
`examples/rts-pathfinding-lab/{logic,frontend}/` is out of scope unless a failing
baseline smoke proves a real regression and the affected files are confirmed
before editing.

## Deliverables

- Pin the V1 regression baseline after the `sim-nav-map-v1.0.0` tag.
- Make the Feature 0 gate explicit: the baseline is documentation and smoke
  consistency, not a new navigation capability.
- Clarify the boundary between core addon baseline verification and
  `examples/rts-pathfinding-lab` adapter/playable regression verification.
- Keep Feature 1 entry conditions clear so terrain-derived passability work can
  start from a known-good baseline.

## Constraints

- Do not implement terrain-derived passability, clearance rasterization, dirty
  cache lifecycle changes, long path result expansion, short path filters, or
  other Feature 1+ capabilities.
- Do not move game-specific movement policy into core `sim-nav-map`.
- Do not commit `addons/sim-nav-map/docs/references/0ad-source/`.

## Validation

```powershell
./tools/run_tests.ps1 simnav/smoke rtslab/smoke
git -C addons diff --check
```

## Completion Gate

- Feature 0 baseline automatic validation passes.
- `Progress.md` records the exact validation commands and results.
- The next Feature 1 entry conditions are documented.
