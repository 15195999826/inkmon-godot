# sim-nav-map path result contract

## Objective

Complete Feature 5 for `addons/sim-nav-map`: make long-path query/result
contracts explicit, source-audited, documented, and covered by core plus lab
smoke tests.

## Source References

- Local 0 A.D. source reference:
  `addons/sim-nav-map/docs/references/0ad-source/`
- Feature 5 audit:
  `addons/sim-nav-map/docs/roadmap-refs/0ad-navigation-source-map.md`
- Public contract docs:
  `addons/sim-nav-map/docs/public-api.md`
- Smoke matrix:
  `addons/sim-nav-map/docs/smoke-matrix.md`

## Scope

- Add long-path query/result DTOs for status, metadata, path cost/length,
  raw navcell path, and refined waypoint path.
- Support request-scoped inputs: passability mask/class name, goal, excluded
  regions, waypoint spacing, and post-processing preference.
- Update long-path, facade, queue, public API docs, smoke matrix, roadmap docs,
  core smoke, and lab adapter smoke.
- Keep `rts-pathfinding-lab` as adapter consumer / playable regression only.

## Non-Scope

- Feature 6 short-path filters, movement-line validation, and unit-line
  validation.
- Feature 7 request queue budget / worker expansion.
- Feature 8 scale diagnostics.
- Lab `_move_unit()` / `_resolve_separation()` refactor.
- Formation, push/yield, stuck/deadlock, retry cadence, or gameplay movement
  policy in core.
- Committing `addons/sim-nav-map/docs/references/0ad-source/`.

## Acceptance

- Feature 5 contract has local 0 A.D. source audit basis.
- Docs and implementation agree.
- Core smoke covers status, canonicalization metadata, raw/refined boundary, max
  spacing, and excluded-region query isolation.
- Lab smoke proves adapter consumption of result metadata without promoting
  movement policy.
- Required verification passes:
  `./tools/run_tests.ps1 simnav/smoke rtslab/smoke`,
  `git -C addons diff --check`, and
  `git -C addons status --short -- sim-nav-map/docs/references/0ad-source`.
