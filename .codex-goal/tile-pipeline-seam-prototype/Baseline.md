# Baseline

## Existing Chain

Raw tile candidates live in:

`blender/textures/_candidates/single-stage-tile-6-variants-20260617-01/raw/`

Existing bake chain:

1. `blender/scripts/texgen/single_design_21_matrix.py --stage prepare`
2. `C:\Program Files\Blender Foundation\Blender 4.2\blender.exe --factory-startup --background --python blender/scripts/texgen/single_design_21_matrix.py -- --stage bake`
3. Candidate output is a 512x512 alpha PNG from the existing `bake_tile_candidate()` path.

Existing Godot assembly reference:

`inkmon/tools/tile_pipeline/tile_pipeline_scene.gd`

Rules reused here:

- manifest-driven pitch/yaw/edge size;
- `_center_of_flat_top(axial, edge_px)`;
- `InkMonRender2DIsoProjection.ground_basis(pitch, yaw)`;
- sort by projected ground center `y`, then `x`, then tile before decoration;
- complete `Sprite2D` tile ordering, not wall/top split.

## Rejected Prior Candidate

`blender/textures/_candidates/blender-owned-tile-seam-20260617-01/` was inspected only as a visual reference. It is not accepted as final because the map preview was produced by a Python/Blender-side compositor rather than Godot assembly.
