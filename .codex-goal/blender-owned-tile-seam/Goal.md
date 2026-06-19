# Blender-Owned Tile Seam Prototype

## Objective

Produce a candidate-only prototype that proves deterministic map seams can be owned by Blender/Python instead of image generation.

## Scope

- Work only under `blender/textures/_candidates/blender-owned-tile-seam-20260617-01/`.
- Use the six current single-stage raw tile renders as independent tile surfaces.
- Do not modify `tile_pipeline_scene.tscn`, production manifests, ADRs, or shared pipeline scripts.

## Deliverables

- `map_no_seam_baseline.png`
- `map_blender_seam_preview.png`
- `map_seam_zoom_compare.png`
- `tile_contact_sheet.png`
- `REPORT.md`

## Completion Gate

Stop when there is a best preview worth user judgment, with parameters and failed attempts documented.
