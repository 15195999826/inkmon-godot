# Route 3 Left-Warp Corner Ink Test

## Summary

This run uses the left 3D target from `template-connected-20260616-01/raw/dual_canvas_raw.png` as the visual truth. The right paper-net UV is not used for the main candidates.

## Inputs

- source dual canvas: `D:\GodotProjects\inkmon\inkmon-godot\blender\textures\_candidates\template-connected-20260616-01\raw\dual_canvas_raw.png`
- extracted left design: `D:\GodotProjects\inkmon\inkmon-godot\blender\textures\_candidates\left-warp-corner-ink-20260616-01\raw\dual_left_design.png`
- left-warp UV: `D:\GodotProjects\inkmon\inkmon-godot\blender\textures\_candidates\left-warp-corner-ink-20260616-01\uv\dual_left_design_warp_uv.png`
- QC log: `D:\GodotProjects\inkmon\inkmon-godot\blender\textures\_candidates\left-warp-corner-ink-20260616-01\logs\qc_dual_left_design_warp_uv.txt`

## Test Matrix

- `v0_texture_only`: left-warp UV with `ink_enabled=false`; keeps only AI target ink already present in the warped texture.
- `v1_silhouette_top_only`: Freestyle on, marked wall-wall corner/stitch edges excluded.
- `v2_controlled_corner_crease`: Freestyle base lines plus a separate marked wall-corner line set.

## Outputs

- baked candidates: `D:\GodotProjects\inkmon\inkmon-godot\blender\textures\_candidates\left-warp-corner-ink-20260616-01\baked`
- full scene: `D:\GodotProjects\inkmon\inkmon-godot\blender\textures\_candidates\left-warp-corner-ink-20260616-01\shots\left_warp_corner_ink\full.png`
- closeup: `D:\GodotProjects\inkmon\inkmon-godot\blender\textures\_candidates\left-warp-corner-ink-20260616-01\shots\left_warp_corner_ink\closeup.png`
- single baked compare: `D:\GodotProjects\inkmon\inkmon-godot\blender\textures\_candidates\left-warp-corner-ink-20260616-01\shots\left_warp_corner_ink\single_baked_tile_compare.png`
- diagnostic compare: `D:\GodotProjects\inkmon\inkmon-godot\blender\textures\_candidates\left-warp-corner-ink-20260616-01\shots\diagnostic_corner_ink_compare.png`
- slot mapping: `D:\GodotProjects\inkmon\inkmon-godot\blender\textures\_candidates\left-warp-corner-ink-20260616-01\logs\left_warp_corner_ink_slot_mapping.json`
- backup dir: `D:\GodotProjects\inkmon\inkmon-godot\blender\textures\_candidates\left-warp-corner-ink-20260616-01\backups\before_route3_bake_matrix`

## Result

Visual read from this run:

- Best current slot: `tile_grass_e0_v0.png` / `v0_texture_only`.
- The left-warp UV path fixes the obvious grass-lip height mismatch seen in the right-paper-UV route. QC also passes, so this is not a geometry coverage failure.
- `v0_texture_only` is closest to the source left 3D target: the vertical corner ink comes from the AI target texture itself and reads like a 3D crease instead of a UV panel seam.
- `v1_silhouette_top_only` and `v2_controlled_corner_crease` add too much Blender-side edge emphasis on this asset. Their outer/corner lines look more like extra rendered engineering lines than the source target's softer dark crease.
- `v2_controlled_corner_crease` proves the separate line set is technically controllable, but the default `2.0px / 0.35px` crease is still not the visual winner for this source.

Answer to the black-line question:

- Keep: the dark 3D corner crease already present in the left 3D target / left-warp UV.
- Remove or avoid: black lines sourced from right-side paper-net UV panel seams.
- Avoid for now: extra Blender wall-wall corner crease unless it is much more tightly matched to the source target.

Recommended next test:

- Treat `left 3D target -> design_warp UV -> bake with ink disabled or very restrained ink` as the Route 3 baseline.
- If Blender ink is needed later, tune it against `v0_texture_only`, not against the right paper-net UV.

## Current Slot State

The scene slots are intentionally left applied:

- `tile_grass_e0_v0.png` = `v0_texture_only`
- `tile_grass_e0_v1.png` = `v1_silhouette_top_only`
- `tile_grass_e0_v2.png` = `v2_controlled_corner_crease`

These are temporary candidate overrides, not approved production assets.
