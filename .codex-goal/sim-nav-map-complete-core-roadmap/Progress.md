# Progress

## Status

Complete pending final goal close.

## Baseline

- Main repo status before implementation: `## master...origin/master [ahead 3]`
  with dirty `addons` pointer.
- Submodule status before implementation: `## master...origin/master [ahead 4]`
  with dirty docs:
  - `sim-nav-map/docs/lab-separation-design-discussion.md`
  - `sim-nav-map/docs/roadmap-refs/0ad-navigation-source-map.md`
- `lab-separation-design-discussion.md` is an existing dirty document and is not
  part of this goal unless directly needed.
- Architecture KB search for this core contract work had no strong relevant
  principle: top score `0.486`.

## Implemented

- Added `SimNavObstructionFilter` and wired it through filtered range queries,
  short-path queries, movement-line validation, and unit-only line validation.
- Added `SimNavShortPathResult` and `compute_short_path_result()` while keeping
  `compute_short_path_immediate()` path-only compatible.
- Added `SimNavMovementLineResult` plus
  `SimNavPathfinderFacade.validate_movement_line()` and `validate_unit_line()`.
- Expanded `SimNavPathRequestQueue` with short metadata results,
  `take_short_path_result()`, pending/result ticket exports, stale-result
  isolation, worker/batch diagnostics, and queue lifecycle diagnostics.
- Added read-only diagnostics/export primitives:
  `SimNavMap.get_dirtiness_snapshot()`, `SimNavMap.get_diagnostics()`,
  `SimNavHierarchicalPathfinder.export_connectivity()`,
  `SimNavHierarchicalPathfinder.get_diagnostics()`, and
  `SimNavPathfinderFacade.get_navigation_diagnostics()`.
- Added explicit `RtsPathfindingLabPathfinder.inspect_core_primitives()` adapter
  inspection for short-result, movement-line, and unit-line metadata outside the
  playable `plan_path()` hot path. `_move_unit()` and `_resolve_separation()`
  were not changed.
- Updated `public-api.md`, `smoke-matrix.md`, `feature-roadmap.md`, and the
  Feature 7 source audit note in `0ad-navigation-source-map.md`.

## Smoke Coverage

- `smoke_sim_nav_vertex_pathfinder.tscn`: filtered short query, ignored-tag
  filter snapshot, out-of-range short status, path-only compatibility.
- `smoke_sim_nav_line_validation.tscn`: filtered range query,
  movement-line passability/static obstruction blocking, unit-only line
  validation, control-group filtering.
- `smoke_sim_nav_path_request_queue.tscn`: queue tickets, budget, cancel,
  stale results, long/short metadata results, worker batch, filter clone, and
  diagnostics.
- `smoke_sim_nav_diagnostics_exports.tscn`: map dirtiness diagnostics,
  connectivity export shape, facade diagnostics, and scale/perf scenario shape.
- `smoke_sim_nav_public_api_contract.tscn`: constructor/default contract for
  new filter/result DTOs.
- `smoke_rts_pathfinding_lab_core_primitive_adapter.tscn`: lab adapter consumes
  short-result and line-validation metadata without owning core policy.

## Evidence

- 0 A.D. source audit sidecar check:
  - PASS. No Feature 6/7/8 source-audit conflicts found against local
    `addons/sim-nav-map/docs/references/0ad-source/`.
- `./tools/run_tests.ps1 simnav/smoke rtslab/smoke`
  - PASS 24 / FAIL 0 / TIMEOUT 0.
- Post-completion lab regression follow-up:
  - Removed line-validation metadata calls from playable `plan_path()` hot path;
    `smoke_rts_pathfinding_lab_core_primitive_adapter.tscn` now uses
    `inspect_core_primitives()`.
  - Restored `SimNavLineOfSight.segment_clear()` inner-loop inline checks while
    keeping `first_blocking_shape()` for diagnostics.
  - Restored `SimNavVertexPathfinder.compute_short_path_immediate()` as a
    path-only fast path; result DTO metadata remains on
    `compute_short_path_result()`.
  - Latest `rtslab/smoke` default metrics: `avg_step_usec ~= 477`,
    `max_step_usec ~= 1299`, `max_overlap = 0` in the default scenario. Stress
    still reports vertex spikes and a known lab separation overlap/jump case,
    which are application movement-policy issues outside Feature 6/7/8 core.
- `git -C addons diff --check`
  - PASS. Only line-ending warnings were reported.
- `git -C addons status --short -- sim-nav-map/docs/references/0ad-source`
  - PASS. No output; local 0 A.D. source reference is not included.

## Remaining Checks

- None for Feature 6/7/8 core roadmap.
