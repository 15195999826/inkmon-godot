# Progress

## Status

Complete pending final goal close.

## Implemented

- Added `SimNavLongPathQuery` and `SimNavLongPathResult`.
- Added `SimNavLongPathfinder.compute_path_result()`.
- Added `SimNavPathfinderFacade.compute_path_result()`.
- Added queue touchpoints `enqueue_long_path_query()` and
  `take_long_path_result()` while preserving path-only compatibility.
- Added request-scoped excluded regions and post-processing preferences:
  `raw`, `line_of_sight`, and `max_spacing`.
- Added metadata for status, failure reason, canonicalization, start recovery,
  raw navcell path, refined waypoint path, path cost, and path length.
- Updated `rts-pathfinding-lab` adapter reports to expose long-path metadata
  without modifying movement/separation policy.

## Smoke Coverage

- `smoke_sim_nav_long_pathfinder.tscn`: status, canonicalization metadata,
  start recovery, raw/refined boundary, max spacing, excluded-region isolation,
  path cost, and path length.
- `smoke_sim_nav_public_api_contract.tscn`: long query/result public DTO
  defaults and clone/snapshot behavior.
- `smoke_sim_nav_path_request_queue.tscn`: queued long query cloning and result
  metadata retrieval.
- `smoke_rts_pathfinding_lab_long_path_result_adapter.tscn`: lab adapter
  metadata consumption.

## Evidence

- `./tools/run_tests.ps1 simnav/smoke rtslab/smoke`
  - PASS 21 / FAIL 0 / TIMEOUT 0.
- `git -C addons diff --check`
  - PASS. Only line-ending warnings were reported.
- `git -C addons status --short -- sim-nav-map/docs/references/0ad-source`
  - PASS. No output; local 0 A.D. source reference is not included.

## Remaining Checks

- None for Feature 5.
