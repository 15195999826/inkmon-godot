# Progress

## 2026-05-06

- Created active Codex goal for Feature 3+4 dirty lifecycle and reachability
  queries.
- Feature 2 handoff commits provided by user:
  - root commit `bb146cb`
  - addons commit `058d299`
- Initial target docs were missing; created `Goal.md` and this `Progress.md`.
- Baseline before runtime edits:
  - `git status --short` -> no output.
  - `git -C addons status --short` -> no output.
  - `./tools/run_tests.ps1 simnav/smoke rtslab/smoke` -> PASS 19 / FAIL 0 /
    TIMEOUT 0.
- Architecture KB check:
  - Direct `Authorization: Basic $env:LOMO_KB_AUTH` returned 401.
  - `curl -u "$env:LOMO_KB_AUTH"` timed out.
  - Proceeded with existing addon boundary and minimal result DTO; no remote KB
    principle was applied.
- Scope confirmed before `.gd` edits:
  - `addons/sim-nav-map/pathfinding/sim_nav_path_goal.gd`
  - `addons/sim-nav-map/pathfinding/sim_nav_reachability_result.gd`
  - `addons/sim-nav-map/pathfinding/sim_nav_hierarchical_pathfinder.gd`
  - `addons/sim-nav-map/pathfinding/sim_nav_pathfinder_facade.gd`
  - `addons/sim-nav-map/examples/rts-pathfinding-lab/logic/rts_pathfinding_lab_pathfinder.gd`

## Feature 3 Implementation

- Added `SimNavPathfinderFacade.recompute_dirty(passability_masks,
  clear_dirty_navcells := true)`.
- The lifecycle order is:
  - `SimNavMap.rasterize_dirty_obstructions()`
  - `SimNavHierarchicalPathfinder.recompute_dirty()`
  - `SimNavLongPathfinder.invalidate_jump_point_cache()`
  - `SimNavMap.clear_dirty_navcells()` by default
- Updated `smoke_sim_nav_dirty_lifecycle.tscn/.gd` to cover:
  - terrain edit dirty recompute
  - static obstruction add/remove dirty rasterization
  - region split/reconnect after dirty recompute
  - long-path cache invalidation before dirty cleanup
- Feature 3 gate:
  - `./tools/run_tests.ps1 simnav/smoke` -> PASS 15 / FAIL 0 / TIMEOUT 0.

## Feature 4 Implementation

- Added `SimNavReachabilityResult`.
- Added `SimNavPathGoal.clone()` and `copy_from()` so reachability/facade code can
  clone or mutate goals without duplicating field lists.
- Added `SimNavHierarchicalPathfinder.query_goal_reachability()`.
- Added `SimNavPathfinderFacade.query_reachability()`.
- Updated `SimNavPathfinderFacade.compute_path_immediate()` to reuse the explicit
  reachability query before long-path search.
- Updated `rts-pathfinding-lab` adapter reporting to consume reachability
  metadata and canonical goals without promoting movement/selection/command/
  formation policy into core.
- Added `smoke_sim_nav_reachability_query.tscn/.gd` and registered it in
  `simnav/smoke`.
- Coverage includes:
  - `POINT`
  - `CIRCLE`
  - `SQUARE`
  - inverted circle goal
  - passability class/mask echo
  - dirty recompute changing canonical target
- Failure root cause during implementation:
  - First `simnav/smoke` run timed out on the new reachability smoke because the
    Godot class cache had not registered the new `SimNavReachabilityResult`
    `class_name` and new facade method.
  - Fix: ran `godot_console.exe --headless --path . --import`.
- Feature 4 gate:
  - `./tools/run_tests.ps1 simnav/smoke` -> PASS 16 / FAIL 0 / TIMEOUT 0.
  - `./tools/run_tests.ps1 rtslab/smoke` -> PASS 4 / FAIL 0 / TIMEOUT 0.

## Docs

- Updated `public-api.md` with `SimNavReachabilityResult`,
  `SimNavPathfinderFacade.recompute_dirty()`, `query_reachability()`, and
  canonicalization metadata.
- Updated `usage.md` with dirty lifecycle and explicit reachability query usage.
- Updated `smoke-matrix.md` with Feature 3 and Feature 4 smoke contracts and
  Feature 5 entry boundary.
- Updated `feature-roadmap.md` with Feature 3/4 completion records and Feature 5
  entry conditions.

## Final Verification

- Final required commands:
  - `./tools/run_tests.ps1 simnav/smoke rtslab/smoke` -> PASS 20 / FAIL 0 /
    TIMEOUT 0.
  - `git -C addons diff --check` -> PASS.
  - `git -C addons status --short -- sim-nav-map/docs/references/0ad-source`
    -> no output.
- Editor/manual verification:
  - No Godot frontend/playable scene behavior or editor workflow was changed.
  - New/changed `.tscn` coverage is headless smoke only, so no editor-side manual
    verification is required for this goal.

## 2026-05-06 Manual Lab Perf Follow-Up

- User manually verified the documented `rts-pathfinding-lab` behavior and found
  severe frame stutter when targeting inside a building, with max frame around
  1500 ms.
- Added lab smoke perf guards for blocked target canonicalization:
  - single `plan_path()` to an unreachable static target must stay below 100 ms.
  - group unreachable target max `world.step()` must stay below 100 ms.
- Reproduced the failure before the fix:
  - `./tools/run_tests.ps1 rtslab/smoke` -> FAIL.
  - single blocked target plan was `1143187` usec.
  - unreachable target max step was `1295620` usec.
- Root cause:
  - `SimNavHierarchicalPathfinder._find_nearest_goal_navcell()` treated `POINT`
    goals like area goals and scanned up to `_MAX_NEAREST_RADIUS` rings looking
    for a reachable goal cell, even though a point goal can only match its exact
    navcell. When that navcell was blocked by a building, the scan did useless
    full-radius work before falling back to nearest reachable region.
- Fix:
  - `POINT` goal reachability now checks only the point's anchor navcell.
  - Area goal scan radius is bounded by goal geometry.
  - Area scan checks `goal.navcell_contains_goal()` before global region lookup.
- Verification after the fix:
  - `./tools/run_tests.ps1 rtslab/smoke` -> PASS 4 / FAIL 0 / TIMEOUT 0.
  - `./tools/run_tests.ps1 simnav/smoke rtslab/smoke` -> PASS 20 / FAIL 0 /
    TIMEOUT 0.

## 2026-05-06 Manual Lab Dynamic Edit Stress Follow-Up

- User manually tested the documented dynamic static-obstacle edit workflow and
  observed one frame with `world.step` max around `158 ms`.
- Added a deterministic lab stress regression:
  - 10 rounds of all six mobile units moving between left/right sides of the
    building cluster.
  - Each round adds and removes static obstacles at the upper/lower gap
    positions while the units are moving.
  - The smoke records `max_step_usec`, `max_edit_usec`, active obstacle
    violations, overlap, replan budget, and static context cache counts.
- First stress run did not reproduce the `158 ms` spike:
  - max `world.step` was `67268` usec.
  - max edit operation was `25332` usec.
- The stress did expose a geometry stability bug:
  - a unit could remain inside an active static obstacle when a newly added
    obstacle's inflated rect overlapped an existing building's inflated rect.
  - after the first fix, active obstacle violations dropped to 0, but residual
    overlap peaked at about `1.54 px`.
- Root cause:
  - `_push_out_static_obstacles()` pushed against individual inflated rectangles
    in sequence, so overlapping static rectangles could push a unit back into a
    rectangle that had already been processed.
  - static push-out happened after unit overlap resolution, so push-out could
    create a small residual unit overlap in the same frame.
- Fix:
  - Lab world now merges connected inflated static obstacle rectangles before
    pushing a unit out.
  - Lab world now runs static push-out and unit overlap separation as a small
    same-frame stabilization loop.
- Verification after the fix:
  - `./tools/run_tests.ps1 rtslab/smoke` -> PASS 4 / FAIL 0 / TIMEOUT 0.
  - `./tools/run_tests.ps1 simnav/smoke rtslab/smoke` -> PASS 20 / FAIL 0 /
    TIMEOUT 0.
  - latest stress metrics from the full run:
    - `rounds=10`, `steps=640`
    - `max_step_usec=54269`
    - `avg_step_usec=2451.309375`
    - `max_edit_usec=28929`
    - `max_active_obstacle_violations=0`
    - `max_overlap=0.0`
    - `max_replans_per_tick=1`

## 2026-05-06 Manual Lab Export Log Follow-Up

- User requested a way to export a lab log after manually hitting an abnormal
  frame/pathing result.
- Added an `Export log` button to the playable lab scene.
- Export behavior:
  - writes structured JSON under `user://rts_pathfinding_lab_logs/`;
  - prints `RTS_PATHFINDING_LAB_EXPORT_LOG: <global path>` to Godot output;
  - includes selected ids, current target, metrics, perf counters,
    pathfinder `last_report`, obstacles, unit position/target/path/recent trace,
    recent actions, and slow-frame events above `50000 usec`.
- Added scene-load smoke coverage that instantiates the real lab scene, verifies
  the button exists, calls `export_debug_log()`, reads the JSON back, and checks
  schema/world/unit/event content.
- Verification:
  - `./tools/run_tests.ps1 rtslab/smoke` -> PASS 4 / FAIL 0 / TIMEOUT 0.
  - `./tools/run_tests.ps1 simnav/smoke rtslab/smoke` -> PASS 20 / FAIL 0 /
    TIMEOUT 0.

## 2026-05-06 Manual Lab Exported Log Side-Crossing Follow-Up

- User exported:
  - `C:/Users/37065/AppData/Roaming/Godot/app_userdata/Inkmon/rts_pathfinding_lab_logs/rts_pathfinding_lab_2026-05-06T01-08-11_tick_1557.json`
- Log findings:
  - The export still did not contain a slow-frame event.
  - `max_step_usec` was `4429`.
  - Several units jumped from the left edge of the right-side obstacle chain to
    the right side, for example `blue_5` from about `(396.1, 141.6)` to
    `(495.4, 134.3)`.
- Added a regression for side-preserving static push-out:
  - a unit whose latest static-safe trace point is left of the containing
    obstacle rect must not be pushed to the obstacle's right side.
- Reproduced before the fix:
  - `./tools/run_tests.ps1 rtslab/smoke` -> FAIL.
  - test unit moved to `(495.5, 144.25)`.
- Root cause:
  - The nearest-exit fix still chose only from sparse side/corner candidates.
  - When the same-y left candidate was covered by a connected building rect,
    the right edge could remain the nearest valid candidate, so the unit crossed
    the obstacle component.
- Fix:
  - static push-out now samples candidate exits along rectangle perimeters.
  - when the latest nearby static-safe trace point clearly lies on one side of
    the containing rect, push-out prefers valid exits preserving that side;
    otherwise it falls back to the nearest current-position exit.
- Verification:
  - `./tools/run_tests.ps1 rtslab/smoke` -> PASS 4 / FAIL 0 / TIMEOUT 0.
  - `./tools/run_tests.ps1 simnav/smoke rtslab/smoke` -> PASS 20 / FAIL 0 /
    TIMEOUT 0.
  - latest stress metrics after the fix:
    - `dynamic_edit_stress.max_step_usec=55264`
    - `dynamic_edit_stress.max_active_obstacle_violations=0`
    - `dynamic_edit_stress.max_overlap=0.0`

## 2026-05-06 Manual Lab Exported Log Flicker Follow-Up

- User exported:
  - `C:/Users/37065/AppData/Roaming/Godot/app_userdata/Inkmon/rts_pathfinding_lab_logs/rts_pathfinding_lab_2026-05-06T01-02-55_tick_1546.json`
- Log findings:
  - The export did not contain a slow-frame event.
  - `max_step_usec` was `4374`.
  - `blue_0`, `blue_3`, and `blue_5` trace tails showed about `70-100 px`
    horizontal jumps near the upper building/obstacle cluster.
- Added a regression for connected static obstacle push-out:
  - a unit inside a bridge obstacle connected to existing building inflated
    rects must exit through the nearest valid real rectangle edge;
  - it must not be pushed across the whole connected component bounding box.
- Reproduced before the fix:
  - `./tools/run_tests.ps1 rtslab/smoke` -> FAIL.
  - test unit moved from `(365.0, 136.0)` to `(468.0884, 123.5826)`, about
    `103.83 px`.
- Root cause:
  - the previous stability fix merged connected static obstacle inflated rects
    into one large bounding `Rect2` and pushed units out of that bounding rect.
  - for non-rectangular connected obstacle components, that bounding rect covers
    playable empty space and can cause visible position jumps.
- Fix:
  - static push-out now collects the connected inflated-rect component but
    evaluates candidate exits on each real component rectangle edge.
  - it chooses the nearest candidate that is outside the whole component and
    outside all static inflated obstacles.
  - the old bounding-rect push remains only as a fallback if no valid candidate
    exists.
- Verification:
  - `./tools/run_tests.ps1 rtslab/smoke` -> PASS 4 / FAIL 0 / TIMEOUT 0.
  - `./tools/run_tests.ps1 simnav/smoke rtslab/smoke` -> PASS 20 / FAIL 0 /
    TIMEOUT 0.
  - `git -C addons diff --check` -> PASS.
  - `git -C addons status --short -- sim-nav-map/docs/references/0ad-source`
    -> no output.

## 2026-05-06 Manual Lab Boundary Follow-Up

- User manually tested "place static obstacle while units are moving, then
  replan around the new obstruction" and found units/trace lines routing below
  the playable bottom boundary after closing the middle, upper, and lower routes.
- Added lab smoke regressions for:
  - a vertical obstacle that blocks all safe in-map center positions but still
    leaves the `ceil(map_size / cell_size)` navcell overhang row outside the
    visible map;
  - static-obstacle push-out near the bottom edge moving a unit center outside
    the map by clamping to `map_size.y` instead of `map_size.y - radius`.
- Reproduced the first failure before the fix:
  - `./tools/run_tests.ps1 rtslab/smoke` -> FAIL.
  - returned path contained waypoints at `y=431.1479` on a `420 px` tall map.
- Reproduced the second failure before the fix:
  - unit push-out moved a center to `(340.0, 420.0)` with radius `11.0`.
- Root causes:
  - Lab nav context uses `ceil(map_size / cell_size)`, so the final navcell row
    can have centers outside the visible/playable rectangle.
  - Lab vertex path candidates can be generated from obstacle corners outside
    playable bounds.
  - Lab world clamped mobile unit centers to raw map bounds instead of
    radius-safe bounds.
- Fix:
  - Lab adapter now projects out-of-playable navcells into each passability mask
    as blocked.
  - Lab adapter rejects vertex/long smoothed paths whose segments leave
    radius-safe playable bounds.
  - Lab world now clamps mobile unit center movement, overlap resolution, static
    obstacle push-out, and command targets with `radius` margins.
- Verification after the fix:
  - `./tools/run_tests.ps1 rtslab/smoke` -> PASS 4 / FAIL 0 / TIMEOUT 0.
  - `./tools/run_tests.ps1 simnav/smoke rtslab/smoke` -> PASS 20 / FAIL 0 /
    TIMEOUT 0.
  - `git -C addons diff --check` -> PASS.
  - `git diff --check` -> PASS.
  - `git -C addons status --short -- sim-nav-map/docs/references/0ad-source`
    -> no output.

## 2026-05-06 Manual Lab Single-Unit Target Follow-Up

- User manually tested single-unit selection and found a clear, unobstructed
  command target was not used as the unit's exact movement target.
- Added a lab smoke regression:
  - selecting exactly one mobile unit and calling `set_units_target()` must
    preserve the command target center exactly.
- Reproduced the failure before the fix:
  - `./tools/run_tests.ps1 rtslab/smoke` -> FAIL.
  - command target `(180.0, 80.0)` became unit target `(150.0, 65.0)`.
- Root cause:
  - Lab formation offsets were applied even when only one unit was selected.
  - `_formation_offsets(1)` returned `(-30.0, -15.0)` because it reused the
    3-column group formation layout.
- Fix:
  - `_formation_offsets(1)` now returns `Vector2.ZERO`.
  - Multi-unit group movement still uses the existing formation offsets.
- Verification after the fix:
  - `./tools/run_tests.ps1 rtslab/smoke` -> PASS 4 / FAIL 0 / TIMEOUT 0.
  - `./tools/run_tests.ps1 simnav/smoke rtslab/smoke` -> PASS 20 / FAIL 0 /
    TIMEOUT 0.
