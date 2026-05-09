# 0AD Short Path Visibility Performance Progress

## 2026-05-09

### Baseline

Ran current 0AD lab exploration before the final optimization pass:

| Phase | avg_step_usec | max_step_usec | max short compute |
|---|---:|---:|---:|
| `1_baseline_open_movement` | 700.64 | 9412 | 0 |
| `4_fully_blocked_path` | 1062.06 | 32687 | 31659 |
| `9_partial_wall_with_gap` | 927.41 | 25908 | 24883 |
| `8_rapid_obstacle_thrash` | 21313.80 | 317562 | 158538 |

### Implemented

- Added static and dynamic obstruction range-query APIs on `SimNavMap`.
- Changed `SimNavVertexPathfinder` to collect explicit static/unit
  obstructions through local range queries.
- Added structural short-path diagnostics:
  `explicit_static_obstruction_count`, `explicit_unit_obstruction_count`,
  `terrain_edge_count`, `terrain_vertex_count`, `vertex_count`,
  `visibility_check_count`, and `astar_expansion_count`.
- Added the diagnostics to `SimNavShortPathResult`, path request queue
  per-request profiles, and 0AD lab short-path reports.
- Changed terrain extraction from dense navcell obstacle spans to local terrain
  boundary vertices used only as fallback after explicit obstruction vertices.
- Added nearest-neighbor visibility pruning for lazy A* graph expansion.
- Added request-level `static_vertex_extra_outset`; the 0AD lab applies half a
  navcell so explicit static corners clear its rasterized passability margin
  without changing the core default OBB-corner contract.
- Tightened 0AD budget smoke static short-path threshold to `8000us`.
- Added a `partial_wall_with_gap` smoke assertion for arrival plus short-path
  `compute_usec < 8000`.
- Added `max_short_compute_usec` and `max_short_profile` to the 0AD exploration
  playthrough output.

### Current Exploration Result

After optimization:

| Phase | avg_step_usec | max_step_usec | max_short_compute_usec | Notes |
|---|---:|---:|---:|---|
| `1_baseline_open_movement` | 717.46 | 9666 | 0 | Average remains in the same practical range as before this pass. |
| `4_fully_blocked_path` | 782.20 | 22589 | 1922 | Static short spike removed; slowest frame is long-path setup. |
| `9_partial_wall_with_gap` | 724.11 | 24641 | 936 | Arrived `6/6`; static short spike removed. |
| `8_rapid_obstacle_thrash` | 4624.46 | 45484 | 27803 | Still dynamic blocker thrash / runaway; tracked separately. |

### 0 A.D. Source Re-read

- `addons/sim-nav-map/docs/references/0ad-source/source/simulation2/helpers/VertexPathfinder.cpp`
  - `VertexPathfinder::ComputeShortPath()`
  - `AddTerrainEdges()`
  - `CheckVisibility*()`
  - `SplitAAEdges()`
- `addons/sim-nav-map/docs/references/0ad-source/source/simulation2/helpers/VertexPathfinder.h`
- `addons/sim-nav-map/docs/references/0ad-source/source/simulation2/helpers/Pathfinding.h`
- `addons/sim-nav-map/docs/references/0ad-source/source/simulation2/components/ICmpObstructionManager.h`
- `addons/sim-nav-map/docs/references/0ad-source/source/simulation2/components/CCmpObstructionManager.cpp`
  - `GetStaticObstructionsInRange()`
  - `GetUnitObstructionsInRange()`
  - `TestLine()`
  - `TestUnitLine()`
- `addons/sim-nav-map/docs/references/0ad-source/source/simulation2/components/CCmpPathfinder.cpp`
  - `CheckMovement()`
- `addons/sim-nav-map/docs/references/0ad-source/source/simulation2/components/CCmpUnitMotion.h`
  - `RequestShortPath()`
  - `ShouldCollideWithMovingUnits()`
  - `TryGoingStraightToTarget()`

### Final Verification

- `godot_console --headless --path . addons/sim-nav-map/tests/repro/repro_core_001_vertex_obb_outset.tscn`: PASS.
- `godot_console --headless --path . addons/sim-nav-map/examples/0ad-rts-pathfinding-lab/tests/smoke/smoke_zero_ad_rts_lab_0ad_budget.tscn`: PASS.
- `./tools/run_tests.ps1 zeroadlab/smoke simnav/smoke`: PASS 28 / FAIL 0 / TIMEOUT 0.
- Final exploration log: `.claude/tmp/0ad-short-path-exploration-final.log`.

### Remaining

- Keep dynamic blocker thrash as a separate follow-up; do not mark it solved by
  this static short-path optimization.
