# Tile Pipeline Seam Prototype Report

Date: 2026-06-17

Output root:

`blender/textures/_candidates/tile-pipeline-seam-prototype-20260617-01/`

## Best Preview

Best Godot preview:

`map_godot_seam_preview.png`

Comparison files:

- `map_no_seam_baseline.png`: Godot assembled map without seam overlay.
- `map_godot_seam_preview.png`: Godot assembled map with selected seam overlay.
- `map_seam_zoom_compare.png`: crop compare derived from the two Godot screenshots.
- `tile_contact_sheet.png`: baked tile asset contact sheet.

The final preview was rendered by Godot from:

`res://inkmon/tools/tile_pipeline/candidate_seam_preview/tile_pipeline_seam_candidate.tscn`

The candidate scene aligns with `inkmon/tools/tile_pipeline/tile_pipeline_scene.gd` for:

- manifest-driven `pitch_deg`, `yaw_deg`, and `px_per_hex_edge`;
- flat-top axial center calculation;
- `InkMonRender2DIsoProjection.ground_basis(pitch, yaw)`;
- projected painter order by ground center `y`, then `x`, then stable order;
- Sprite2D tile assembly in Godot.

## Baked Tile Assets

Candidate baked PNGs with alpha:

- `assets/baked_tiles/tile_01_grass_meadow_baked.png`
- `assets/baked_tiles/tile_02_cracked_dry_earth_baked.png`
- `assets/baked_tiles/tile_03_mossy_flagstone_baked.png`
- `assets/baked_tiles/tile_04_dirt_arena_baked.png`
- `assets/baked_tiles/tile_05_pale_limestone_baked.png`
- `assets/baked_tiles/tile_06_dark_forest_floor_baked.png`

All six were baked from the raw candidates through `blender/scripts/texgen/single_design_21_matrix.py`, using Blender only for single-tile bake output. The map preview does not use raw PNGs directly.

Selected bake variant per tile:

`baked/top_edge_clean_no_ink/original_both_faces_own_top_edge_clean_no_ink.png`

## Seam / Alpha / Edge Parameters

Selected final round: `round_04_final-narrow-seam`

Parameters:

```json
{
  "shadow_width_px": 6.6,
  "shadow_alpha": 0.24,
  "core_width_px": 1.8,
  "core_alpha": 0.44,
  "highlight_width_px": 1.05,
  "highlight_alpha": 0.12,
  "highlight_offset_px": 1.35,
  "endpoint_trim_px": 2.2
}
```

Implementation notes:

- Shared seam geometry is stored in `seam_geometry.json`.
- Seam lines are drawn in Godot after tile sprites, with `z_index = 20`.
- The seam is limited to shared top edges only.
- No extra shared-edge side wall is drawn.
- Existing baked tile side walls remain visible only where the tile asset exposes an outer wall.
- Highlight is intentionally low alpha and directional, so it reads as a small lit top lip instead of a white outline.

Alpha check from `logs/visual_metrics.json`:

- baked tile size: `512x512`;
- transparent ratio per tile: about `0.849541`;
- opaque ratio per tile: about `0.145504`.

## Iterations

1. `round_01_wide-dark-outline`
   - Observation: seam became easy to read but risked reading as a heavy outline.
   - Change: established wide shadow/core/highlight bounds.
   - Output: `iterations/round_01_wide-dark-outline_godot.png`
   - Result: closer than no seam, but too assertive.

2. `round_02_narrower-core`
   - Observation: less outline-like; still a bit dark around pale tiles.
   - Change: reduced core width/alpha and added endpoint trim.
   - Output: `iterations/round_02_narrower-core_godot.png`
   - Result: closer.

3. `round_03_subtle-catch-light`
   - Observation: clean and narrow, but under-read at full-map scale on dark tiles.
   - Change: reduced highlight and core further.
   - Output: `iterations/round_03_subtle-catch-light_godot.png`
   - Result: too subtle for the provided reference.

4. `round_04_final-narrow-seam`
   - Observation: restored enough dark recess while keeping the line narrow.
   - Change: slightly boosted shadow/core alpha and kept low highlight.
   - Output: `iterations/round_04_final-narrow-seam_godot.png`
   - Result: selected.

## Failed / Rejected Attempts

- Rejected Blender/PIL full-map compositing as acceptance path. It does not validate Godot assembly.
- Rejected raw PNG map assembly. Raw images were only single-tile bake inputs.
- Headless Godot viewport PNG saving was unreliable in this environment, so final preview rendering uses Godot `--write-movie` with the Windows display driver and keeps the final frame.
- Initial direct shared-edge generation was not useful for visual validation until explicit shared-edge geometry was written and loaded from `seam_geometry.json`.
- Debug red shared-edge output was used only to verify placement and is not a deliverable preview.

## Validation

Passed:

- `godot --headless --path . --import`
- Godot `--write-movie` render for baseline and all four seam rounds.
- Visual check of `map_godot_seam_preview.png`.
- Zoom comparison against `map_no_seam_baseline.png`.
- Contact sheet check for all six baked tile assets.

Visual result:

- The seam is a narrow dark recess with a slight lit lip, closer to the provided reference than the baseline.
- No obvious white edge was visible in the selected preview.
- No obvious double-line was visible at shared-edge junctions.
- No wrong shared-edge side wall was added.
- The six tile types remain standalone baked tile assets and are not dependent on whole-map generation.

## Why Stop Here

Stopped after four optimization rounds because the fourth round reached the intended prototype target: readable shared seams at map scale without turning into a black outline. Further tuning would need a formal art direction decision rather than more candidate-only iteration.

## Formal Integration Next Steps

If this direction enters the formal pipeline, change these systems intentionally:

1. Add seam data generation to the formal tile pipeline rather than keeping `seam_geometry.json` as a candidate artifact.
2. Decide whether seam rendering belongs in the Godot tile pipeline scene, the runtime map renderer, or baked tile edge metadata.
3. Add map-height or adjacency rules before drawing side walls on non-shared exposed edges.
4. Add visual regression previews for baseline, seam-enabled, and high-contrast tile combinations.
5. Promote selected bake settings into the formal asset manifest only after art review.

