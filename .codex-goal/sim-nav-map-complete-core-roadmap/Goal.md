# sim-nav-map complete core roadmap

## Objective

Complete the remaining `addons/sim-nav-map` core roadmap features 6, 7, and 8
with local 0 A.D. source-audited contracts, implementation, smoke coverage, and
documentation.

## Source References

- Local 0 A.D. source reference:
  `addons/sim-nav-map/docs/references/0ad-source/`
- Feature 6/7/8 source audit:
  `addons/sim-nav-map/docs/roadmap-refs/0ad-navigation-source-map.md`
- Core roadmap:
  `addons/sim-nav-map/docs/feature-roadmap.md`
- Public contract docs:
  `addons/sim-nav-map/docs/public-api.md`
- Smoke matrix:
  `addons/sim-nav-map/docs/smoke-matrix.md`

## Scope

- Feature 6: filtered short query, obstruction filter protocol,
  movement-line validation, and unit-only line validation.
- Feature 7: long/short request queue ticket lifecycle, clone, cancel, budget
  processing, worker/batch result, stale result, and diagnostics contract.
- Feature 8: core navigation diagnostics, scale/perf scenarios, connectivity
  read-only exports, and dirtiness read-only exports.
- Update facade/public API/queue touchpoints, core smoke, lab smoke,
  `public-api.md`, `smoke-matrix.md`, `feature-roadmap.md`, and necessary
  roadmap refs.
- Keep `rts-pathfinding-lab` as an adapter consumer / playable regression that
  can expose metadata or call core primitives without owning core policy.

## Non-Scope

- Formation, push/yield, stuck/deadlock, retry cadence, arrival, speed,
  acceleration, steering, or gameplay movement policy in core.
- Lab `_move_unit()` / `_resolve_separation()` refactors.
- Full RTS movement system, UnitAI, combat, resource, selection, command queue,
  or HUD policy.
- Optional `rts-pathfinding-lab-formation-validation`.
- Committing `addons/sim-nav-map/docs/references/0ad-source/`.
- Copying GPL source implementation from 0 A.D.

## Acceptance

- Feature 6/7/8 all have refreshed local 0 A.D. source audit basis.
- Docs and implementation agree.
- Core smoke covers filter contract, movement-line validation, unit-line
  validation, queue lifecycle/budget/cancel/worker result, and
  diagnostics/export contract.
- Lab smoke proves adapter consumption of new primitive/result metadata without
  moving gameplay movement policy into core.
- Feature 6/7/8 boundaries are complete and optional formation validation is not
  included.
- Required verification passes:
  `./tools/run_tests.ps1 simnav/smoke rtslab/smoke`,
  `git -C addons diff --check`, and
  `git -C addons status --short -- sim-nav-map/docs/references/0ad-source`.
