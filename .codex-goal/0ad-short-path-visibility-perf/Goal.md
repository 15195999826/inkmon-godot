# 0AD Short Path Visibility Performance Goal

## Objective

Optimize `addons/sim-nav-map/examples/0ad-rts-pathfinding-lab` short-path
visibility graph performance against the local 0 A.D. `VertexPathfinder` /
`CCmpUnitMotion` reference.

The work must use current 0AD lab repro, smoke, and exploration data as the
source of truth. Legacy `examples/rts-pathfinding-lab` and `docs/issues/LAB-*`
are not issue sources for this goal.

## Deliverables

- `SimNavVertexPathfinder` short-path construction uses local explicit static
  and dynamic obstruction range queries before graph construction.
- Terrain passability is represented as local boundary candidates when needed,
  not as a dense global obstacle set.
- Visibility graph diagnostics expose structural counters:
  explicit static/unit counts, terrain edges/vertices, vertex count,
  visibility checks, and A* expansions.
- Slow frame / path request profiles include per-request `compute_usec` and
  short-path graph diagnostics.
- 0AD lab smoke locks:
  - `fully_blocked_path` static short request `< 8000us`
  - `partial_wall_with_gap` arrives and static short request `< 8000us`
  - fully blocked recovery remains bounded
- `addons/sim-nav-map/examples/0ad-rts-pathfinding-lab/docs/short-path-visibility-optimization-goals.md`
  records 0 A.D. source references, strategy, current metrics, and remaining
  dynamic blocker follow-up.

## Non-goals

- Do not use async worker migration as the first-stage fix.
- Do not hide cost by changing motion cooldowns, search range, or movement
  thresholds.
- Do not make long path consider dense dynamic units as global blockers.
- Do not claim dynamic blocker thrash is solved by the static optimization.

## Required Verification

- `./tools/run_tests.ps1 zeroadlab/smoke simnav/smoke`
- 0AD lab exploration playthrough with recorded `avg_step_usec`,
  `max_step_usec`, and `max_short_compute_usec`.

