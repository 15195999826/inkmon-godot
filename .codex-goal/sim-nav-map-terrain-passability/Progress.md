# Progress

## 2026-05-05

- Created active Codex goal for Feature 1 terrain-derived passability.
- Initial target docs were missing; created `Goal.md` and this `Progress.md`.
- Read `addons/sim-nav-map/docs/feature-roadmap.md`, current public API docs,
  smoke matrix, core terrain/map runtime, and lab adapter runtime.
- Current baseline validation before runtime edits:
  - `./tools/run_tests.ps1 simnav/smoke rtslab/smoke` -> PASS 16 / FAIL 0 / TIMEOUT 0.
  - `git -C addons diff --check` -> PASS.
  - `git -C addons status --short -- sim-nav-map/docs/references/0ad-source` -> no output.
- Key finding: `SimNavPassabilityClassConfig.terrain_mask` already exists and is
  documented, but `SimNavMap` currently stores terrain tile data only; terrain
  data is not derived into navcell passability. Existing
  `smoke_sim_nav_terrain_tile_map.gd` explicitly asserts that terrain data does
  not mutate navcell passability, which must change for Feature 1.
- Runtime scope is pending user confirmation before editing `.gd` files.

## 2026-05-05 Implementation

- User allowed direct modification after runtime scope was listed.
- Core implementation:
  - Added a separate terrain-derived navcell layer in
    `addons/sim-nav-map/model/sim_nav_map.gd`.
  - `SimNavMap.get_navcell_data()` now composes manual/base navcell data,
    terrain-derived passability, and static obstruction raster data.
  - `SimNavMap.set_terrain_tile_data()` now stores raw tile data, derives
    affected navcell passability from each class `terrain_mask`, and marks
    changed navcells dirty.
  - `SimNavMap.register_passability_class()` now rebuilds terrain-derived
    passability so terrain data set before class registration becomes active.
  - Added public `rebuild_terrain_passability()` for tools that edit the raw
    `SimNavTerrainTileMap` directly.
- Core smoke:
  - Updated `smoke_sim_nav_terrain_tile_map.gd` to cover terrain tile projection,
    class-specific terrain masks, dirty marking, same-value stability, clearing
    terrain data, manual navcell layer composition, and register-after-terrain
    rebuild.
  - Updated `smoke_sim_nav_public_api_contract.gd` to cover `terrain_mask`
    default, map-level terrain edit, and `rebuild_terrain_passability()`.
- Lab adapter smoke:
  - Added `RtsPathfindingLabPathfinder.build_terrain_nav_context()` and
    `plan_path_with_terrain_context()` as adapter-only terrain preset helpers.
  - Added `smoke_rts_pathfinding_lab_terrain_adapter.tscn/.gd`.
  - Registered the new smoke in
    `addons/sim-nav-map/examples/rts-pathfinding-lab/tests/test_groups.json`.
- Docs:
  - Updated `public-api.md`, `usage.md`, `smoke-matrix.md`, and
    `feature-roadmap.md` with Feature 1 API, smoke coverage, addon/lab boundary,
    and Feature 2 entry conditions.
- Scope intentionally not implemented:
  - No class-aware clearance rasterization, dirty cache lifecycle expansion,
    reachability/result DTO, long path result contract, short filter, line
    validation, queue expansion, scale diagnostics, ship gameplay, formation,
    HUD policy, or lab movement policy promotion.
- Validation after implementation:
  - `./tools/run_tests.ps1 simnav/smoke rtslab/smoke` -> PASS 17 / FAIL 0 /
    TIMEOUT 0.

## 2026-05-05 Final Verification

- Final required commands:
  - `./tools/run_tests.ps1 simnav/smoke rtslab/smoke` -> PASS 17 / FAIL 0 /
    TIMEOUT 0.
  - `git -C addons diff --check` -> PASS.
  - `git -C addons status --short -- sim-nav-map/docs/references/0ad-source`
    -> no output.
- Failure root causes:
  - No implementation-time test failure occurred after the runtime edits.
  - The pre-implementation contract gap was that terrain tile data existed only
    as raw storage; it did not derive into navcell passability despite
    `terrain_mask` already existing on passability class config.
- Editor/manual verification:
  - No playable frontend scene or visual/editor workflow was changed. The only
    `.tscn` addition is a headless smoke scene, so no editor-side manual check is
    required for this goal.
