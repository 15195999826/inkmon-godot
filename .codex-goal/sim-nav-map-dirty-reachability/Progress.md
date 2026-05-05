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

## 2026-05-06 Claude Review Follow-Up For Slow Separation

- Claude Code reviewed the uncommitted slow-frame diff and agreed that:
  - `_resolve_overlaps()` / `_push_out_static_obstacles()` returning `bool` plus
    `_resolve_separation()` early-out is a correct no-regret change;
  - the logged-cluster smoke regression should remain;
  - lowering `SEPARATION_STABILIZE_ITERATIONS` from 6 to 3 is too hack-like for
    the long term;
  - changing perimeter `sample_step` from 8 to 24 is a risky trade-off because
    it can miss candidates near a unit radius boundary.
- Applied the review direction:
  - restored `SEPARATION_STABILIZE_ITERATIONS` to 6;
  - restored perimeter `sample_step` to 8;
  - added stuck-break in `_push_out_static_obstacles()` when a push attempt does
    not move the unit.
- Result:
  - smoke still reproduced the slow frame at about `separation_usec=54472`, so
    stuck-break alone did not address this log's root cause.
- Final fix:
  - added step-local cache inside `_resolve_separation()` for static inflated
    rectangles and connected components keyed by unit radius;
  - removed a duplicate per-candidate component containment check because the
    global inflated-rect check already covers component membership.
- This keeps the safer 6 stabilization passes and 8 px perimeter sampling while
  removing the repeated static component work from each unit/iteration.
- Verification:
  - `./tools/run_tests.ps1 rtslab/smoke` -> PASS 4 / FAIL 0 / TIMEOUT 0.
  - `./tools/run_tests.ps1 simnav/smoke rtslab/smoke` -> PASS 20 / FAIL 0 /
    TIMEOUT 0.
  - latest dynamic stress metrics:
    - `dynamic_edit_stress.max_step_usec=50641`
    - `dynamic_edit_stress.max_active_obstacle_violations=0`
    - `dynamic_edit_stress.max_overlap=0.0`

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

## 2026-05-06 Manual Lab Slow-Frame Log Follow-Up

- User exported:
  - `C:/Users/37065/AppData/Roaming/Godot/app_userdata/Inkmon/rts_pathfinding_lab_logs/rts_pathfinding_lab_2026-05-06T01-18-56_tick_911.json`
- Log findings:
  - This was a real continuous slow-frame case, not a side-crossing-only case.
  - `last_step_usec=59538`, `max_step_usec=86837`, `avg_step_usec=6045.4006586169`.
  - Slow-frame events were recorded continuously from tick `844` through
    `911`.
  - The previous export schema could prove the slow frame was inside
    `_world.step()`, but could not split the cost between replan, movement,
    separation, and trace/settle phases.
- Logging improvement:
  - `RtsPathfindingLabWorld` now records `last_step_profile` with phase timing:
    `replan_usec`, `move_usec`, `separation_usec`, `settle_trace_usec`,
    `planned_count`, pending replans, and per-step plan reports.
  - `_plan_unit()` now records rolling `recent_plan_reports` with unit id,
    start/target before/after canonicalization, `plan_usec`, path size,
    static obstacle count, other unit count, and the pathfinder `last_report`.
  - The frontend now records `position_jump` events when a unit moves more than
    `24 px` in one `world.step()`.
  - `slow_step` events now include `world_step_profile` and recent plan reports.
  - Export JSON includes `world.last_step_profile` and
    `world.recent_plan_reports`.
- Verification:
  - `./tools/run_tests.ps1 rtslab/smoke` -> PASS 4 / FAIL 0 / TIMEOUT 0.
  - `./tools/run_tests.ps1 simnav/smoke rtslab/smoke` -> PASS 20 / FAIL 0 /
    TIMEOUT 0.

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

## 2026-05-06 Manual Lab Tick 1039 Export Follow-Up

- User exported:
  - `C:/Users/37065/AppData/Roaming/Godot/app_userdata/Inkmon/rts_pathfinding_lab_logs/rts_pathfinding_lab_2026-05-06T01-36-48_tick_1039.json`
- Log findings:
  - `world.metrics.active_move_orders=5`, `arrived_count=1`,
    `pending_replans=1`.
  - `perf.last_step_usec=21618`, `perf.max_step_usec=23478`.
  - `world.last_step_profile.replan_usec=794`,
    `separation_usec=20773`, so this was not a core path query spike.
  - The 22ms frame was not captured as a slow event because the playable lab
    threshold was still `50000 usec`.
- Failure root cause:
  - static push-out picked the nearest valid exit point without considering
    nearby units, so multiple active units could be pushed onto the same narrow
    obstacle edge/gap and then keep active direct-to-target orders alive.
  - The remaining cost was lab separation/settling around static obstacle
    edges, not `SimNavPathfinderFacade` reachability or dirty recompute.
- Fix:
  - lowered playable slow-step event threshold from `50000 usec` to
    `20000 usec`.
  - export JSON now includes `world.movement_debug` with per-unit target error,
    stalled tick counters, direct-target state, and static-constraint state.
  - `world.last_step_profile` now includes `stuck_settles`.
  - lab static push-out now scores exit candidates by severe unit overlap before
    distance, while preserving the previous-side preference.
  - lab separation now stabilizes in `static -> unit overlap -> static` order so
    static push-out does not leave same-frame unit overlap on obstacle edges.
  - active arrival after separation is gated by `ARRIVE_MAX_OVERLAP`; near-target
    stuck settle is lab-local and only applies to final direct targets near a
    static obstacle boundary.
- Regression coverage:
  - added a smoke scenario from the exported tick-1039 obstacle/unit layout.
  - it asserts active move orders settle, queued replans clear, no active
    obstacle violations occur, overlap stays bounded, and separation remains
    budgeted.
  - dynamic edit stress now records `max_overlap_detail` for future failures.
- Verification after the fix:
  - `./tools/run_tests.ps1 rtslab/smoke` -> PASS 4 / FAIL 0 / TIMEOUT 0.
  - `./tools/run_tests.ps1 simnav/smoke rtslab/smoke` -> PASS 20 / FAIL 0 /
    TIMEOUT 0.
  - `git -C addons diff --check` -> PASS.
  - `git -C addons status --short -- sim-nav-map/docs/references/0ad-source`
    -> no output.
- Editor/manual verification:
  - Headless scene-load/export smoke covers the script-level export contract.
  - The playable feel of placing obstacles while units are moving still needs
    editor-side/manual verification, because this changed the lab frontend log
    threshold and movement settling behavior.

## 2026-05-06 Manual Lab Tick 1254 Idle Crossing Follow-Up

- User exported:
  - `C:/Users/37065/AppData/Roaming/Godot/app_userdata/Inkmon/rts_pathfinding_lab_logs/rts_pathfinding_lab_2026-05-06T01-53-06_tick_1254.json`
- Log findings:
  - `perf.max_step_usec=3980`, so this was not a slow-frame bug.
  - `recent_events` contained multiple `position_jump` events with
    `arrived=true`, `has_move_order=false`, and `path_size=0`.
  - Example: `blue_1` jumped from about `(392.9, 143.9)` to `(396.5, 23.5)`,
    about `120 px`.
  - This was idle static separation, not path traversal or reachability.
- Reproduced before the fix:
  - added `idle-gap-push` smoke from the exported obstacle layout and the
    trace-tail positions before the jumps.
  - `./tools/run_tests.ps1 rtslab/smoke` -> FAIL.
  - first failure moved `blue_0` from `(392.93, 126.038)` to `(409.5, 231.5)`,
    `106.76 px`.
- Root cause:
  - idle mobile units clustered near a connected static component gap.
  - idle-idle overlap separation could push an already-arrived unit into a
    static inflated rect.
  - static push-out then chose a low-overlap exit on a far edge of the connected
    component, creating a visible cross-component teleport.
- Fix:
  - static push-out now treats the latest nearby static-safe trace point as a
    local exit candidate for idle units only.
  - local static exits are preferred for idle units within `24 px`; active units
    keep the overlap-aware candidate scoring from the tick-1039 fix.
  - idle-idle overlap resolution is skipped only when either idle unit is near a
    static boundary; ordinary open-area arrival still uses overlap resolution.
  - non-direct active stuck tracking now uses current-waypoint progress when the
    unit is static-constrained, avoiding a revived "active forever" case in the
    tick-1039 regression.
- Regression coverage:
  - `idle-gap-push` asserts no idle unit moves more than `24 px` and no active
    obstacle violation remains.
  - the tick-1039 active-order regression remains, with a longer 520-tick window
    to prove eventual settle instead of enforcing an arbitrary short arrival
    time.
- Verification after the fix:
  - `./tools/run_tests.ps1 rtslab/smoke` -> PASS 4 / FAIL 0 / TIMEOUT 0.
  - `./tools/run_tests.ps1 simnav/smoke rtslab/smoke` -> PASS 20 / FAIL 0 /
    TIMEOUT 0.
  - `git diff --check` -> PASS.
  - `git -C addons diff --check` -> PASS.
  - `git -C addons status --short -- sim-nav-map/docs/references/0ad-source`
    -> no output.

## 2026-05-06 Overnight Lab Stress And 10x Follow-Up

- User asked for broader self-testing before handoff:
  - repeat six units moving between building sides;
  - create/remove static obstacles and blockers mid-move;
  - cover edge targets, blocked building targets, group filter toggles, dynamic
    avoidance toggles, active/idle jump detection, out-of-bounds checks,
    overlap checks, active obstacle violations, and replan budget.
- Added `comprehensive_scripted_stress` to `rtslab/smoke`:
  - 10 deterministic cases, 960 total `world.step()` calls per smoke run.
  - Records `max_step_usec`, `max_edit_usec`, `max_any_jump`,
    `max_idle_jump`, `max_overlap_detail`, `max_out_of_bounds`,
    `max_active_obstacle_violations`, and per-case final metrics.
  - Tightened dynamic/comprehensive stress max-step budgets to `80000 usec`.
- Failure root causes found by the broader stress:
  - Far/edge lab queries could still run `SimNavVertexPathfinder` first and only
    then fall back to long grid pathing; slow frames were dominated by
    `vertex_usec`, not dirty recompute, reachability, or separation.
  - Canonicalized targets needed to persist as lab command state across later
    replans; otherwise a previously canonicalized reachable edge could be
    treated as an ordinary target on the next query.
  - Units whose active orders were already eligible for age-based settling still
    paid one final separation pass before `_update_active_move_settle()` stopped
    them.
- Fixes:
  - Lab pathfinder records reachability/vertex/grid timings and active/dynamic
    obstacle counts in `last_report`.
  - Lab pathfinder skips vertex for far canonical targets, crowded canonical
    targets, edited static long queries, and edge targets beyond `64 px`, using
    long grid fallback instead.
  - Long grid fallback string-pulls and validates against static obstacles only;
    dynamic unit avoidance remains a local/movement-policy concern in the lab.
  - Lab world tracks `_canonical_target_by_unit` so canonical target state
    survives subsequent replans until the move order settles or is retargeted.
  - Lab world now pre-settles expired active orders before separation, avoiding
    one extra expensive static/unit push pass for orders that are already known
    to stop in the same tick.
- Fix classification:
  - Logic-correctness fixes:
    - persistent canonical target state in the lab adapter;
    - static-only validation for long-grid fallback boundaries;
    - pre-separation settling for already-expired active orders.
  - Protective/performance fixes:
    - vertex skip policy for edge/far/crowded lab queries;
    - `80000 usec` stress budgets and richer failure metrics.
  - These remain lab adapter/playable-regression policy, not core Feature 5
    long-path result contract or game-specific movement policy promoted into
    `sim-nav-map`.
- Verification:
  - `./tools/run_tests.ps1 rtslab/smoke` -> PASS 4 / FAIL 0 / TIMEOUT 0.
  - `./tools/run_tests.ps1 simnav/smoke rtslab/smoke` -> PASS 20 / FAIL 0 /
    TIMEOUT 0.
  - 10 consecutive runs:
    - `./tools/run_tests.ps1 rtslab/smoke` repeated 10 times
    - `RTSLAB_SMOKE_10X_PASS: 10/10`
  - `git diff --check` -> PASS.
  - `git -C addons diff --check` -> PASS.
  - `git -C addons status --short -- sim-nav-map/docs/references/0ad-source`
    -> no output.
- Latest final-run metrics:
  - default world: `max_step_usec=1826`, `arrived_count=6/6`,
    `obstacle_violations=0`, `max_overlap=0.0`.
  - dynamic edit stress: `max_step_usec=42319`, `max_edit_usec=27807`,
    `max_active_obstacle_violations=0`, `max_overlap=0.0`,
    `max_replans_per_tick=1`.
  - comprehensive scripted stress: `max_step_usec=36403`,
    `max_edit_usec=22287`, `max_active_obstacle_violations=0`,
    `max_out_of_bounds=0`, `max_idle_jump=8.1138`,
    `max_replans_per_tick=1`.
