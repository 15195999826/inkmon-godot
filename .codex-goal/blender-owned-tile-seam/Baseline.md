# Baseline

## Inputs

- Template: `blender/templates/template_design_e0.png`
- Template sidecar: `blender/templates/template_design_e0.json`
- Style reference: `docs/concept.jpg`
- Raw tiles: `blender/textures/_candidates/single-stage-tile-6-variants-20260617-01/raw/*.png`

## Known Constraint

The recent user-provided seam screenshot is not available as a stable local input in this thread. The prototype therefore uses the written seam target plus visible references in `docs/concept.jpg` and the same-day map reference candidates, and flags this as a review limitation in `REPORT.md`.

## Baseline To Compare

`map_no_seam_baseline.png` is generated from cleaned single-tile top surfaces and exterior visible walls, with no deterministic shared-edge seam overlay.
