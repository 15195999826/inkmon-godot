# Progress

## 2026-05-05

- Created active Codex goal for Feature 2 class-aware clearance rasterization.
- Feature 1 terrain-derived passability was committed first:
  - root commit `f680716 chore(sim-nav-map): record terrain passability goal`
  - addons commit `20f0163 feat(sim-nav-map): derive terrain passability`
- Initial target docs were missing; created `Goal.md` and this `Progress.md`.
- Read `feature-roadmap.md`, current public docs, manifests, `SimNavMap`, passability
  config/registry, terrain tile map, static obstruction shapes, and existing smoke.
- Current baseline before Feature 2 runtime edits:
  - `./tools/run_tests.ps1 simnav/smoke rtslab/smoke` -> PASS 17 / FAIL 0 /
    TIMEOUT 0.
  - `git -C addons diff --check` -> PASS.
  - `git -C addons status --short -- sim-nav-map/docs/references/0ad-source`
    -> no output.
- Scope confirmed before `.gd` edits:
  - `addons/sim-nav-map/model/sim_nav_map.gd`
  - `addons/sim-nav-map/examples/rts-pathfinding-lab/logic/rts_pathfinding_lab_pathfinder.gd`
    was allowed if needed, but the final implementation did not require runtime
    changes in the lab adapter.

## 2026-05-05 Implementation

- Core implementation:
  - Updated `SimNavMap` terrain-derived passability so each class's `clearance`
    expands terrain-blocked navcell rectangles for that class.
  - Updated terrain tile edit recompute scope so changing or clearing a terrain
    tile also recomputes surrounding navcells affected by registered class
    clearance.
  - Preserved existing static obstruction rasterization contract:
    `contains_point_with_clearance(point, config.clearance)` writes class-specific
    obstruction bits.
- Core smoke:
  - Added `smoke_sim_nav_clearance_rasterization.tscn/.gd`.
  - Registered it in `addons/sim-nav-map/tests/test_groups.json`.
  - Coverage includes class-specific terrain masks, class-specific static
    obstruction masks, dirty marking after clearing clearance-expanded terrain,
    and small/large long-path behavior through one-navcell terrain/static gaps.
- Lab adapter smoke:
  - Added `smoke_rts_pathfinding_lab_clearance_adapter.tscn/.gd`.
  - Registered it in
    `addons/sim-nav-map/examples/rts-pathfinding-lab/tests/test_groups.json`.
  - The smoke uses existing lab terrain context helpers; no lab movement,
    selection, command, formation, unit type, or HUD policy was promoted to core.
- Docs:
  - Updated `public-api.md`, `usage.md`, `smoke-matrix.md`, and
    `feature-roadmap.md` with Feature 2 API, smoke coverage, addon/lab boundary,
    and Feature 3 entry conditions.
- Scope intentionally not implemented:
  - No dirty cache lifecycle expansion, reachability result DTO, long path result
    contract, short filter, line validation, request queue expansion, scale
    diagnostics, ship gameplay, formation, push/yield, stuck/deadlock, HUD policy,
    or game-specific movement policy.
- Initial implementation verification:
  - `./tools/run_tests.ps1 simnav/smoke` -> PASS 15 / FAIL 0 / TIMEOUT 0.
  - `./tools/run_tests.ps1 rtslab/smoke` -> PASS 4 / FAIL 0 / TIMEOUT 0.

## 2026-05-05 Final Verification

- Final required commands:
  - `./tools/run_tests.ps1 simnav/smoke rtslab/smoke` -> PASS 19 / FAIL 0 /
    TIMEOUT 0.
  - `git -C addons diff --check` -> PASS.
  - `git -C addons status --short -- sim-nav-map/docs/references/0ad-source`
    -> no output.
- Failure root causes:
  - No implementation-time smoke failure occurred after the runtime edits.
  - The pre-implementation contract gap was that terrain-derived passability
    considered `terrain_mask` but did not expand terrain-blocked areas by each
    passability class `clearance`; static obstruction rasterization already had
    class-aware clearance behavior but lacked dedicated Feature 2 smoke/docs.
- Editor/manual verification:
  - No playable frontend scene or visual/editor workflow was changed. The only
    `.tscn` additions are headless smoke scenes, so no editor-side manual check
    is required for this goal.
