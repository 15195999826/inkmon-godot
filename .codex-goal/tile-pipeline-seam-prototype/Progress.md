# Progress

## 2026-06-17

- Active goal confirmed in Codex goal state.
- Read `single_design_21_matrix.py`, `source_cut_recipe_gen.py`, `top_edge_21_matrix.py`, `tile_pipeline_scene.gd`, and tile pipeline manifest.
- Found `blender` is not in PATH; using `C:\Program Files\Blender Foundation\Blender 4.2\blender.exe`.
- `blender/test.blend` failed as a Blender entry; switched to `--factory-startup --background` to avoid invalid blend and user addon side effects.
- Ran prepare+bake for all 6 raw tiles under `blender/textures/_candidates/tile-pipeline-seam-prototype-20260617-01/bakes/`.
- Selected `top_edge_clean_no_ink/original_both_faces_own` per tile and copied them to `assets/baked_tiles/`.
- Added candidate-only Godot scene under `inkmon/tools/tile_pipeline/candidate_seam_preview/`.
- Generated `seam_geometry.json` for the candidate radius-2 map.
- Rendered Godot baseline and four seam iterations with `--write-movie`.
- Selected `round_04_final-narrow-seam` as `map_godot_seam_preview.png`.
- Generated `map_seam_zoom_compare.png`, `tile_contact_sheet.png`, and `REPORT.md`.
