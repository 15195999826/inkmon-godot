# InkMon Tile Template Sets

This directory is grouped by camera/view and tile model type.

## Sets

- `standard-templates/`: shared template set for mode 1 `圆边` and mode 2 `硬边`, `pitch=35.26`, `yaw=-15`.
- `standard-edged-templates/`: mode 3 `倒角`, explicit top bevel / sloped edge band, `pitch=35.26`, `yaw=-15`.

## Blender Model

All sets reference the persistent model file:

`blender/models/template_tiles/hex_tile_template_models.blend`

Use the object and camera recorded in each set's `model.json`.

## Notes

- `standard-templates/` is the default template set for existing texgen tools and both standard-prism modes.
- `standard-edged-templates/` is the candidate-only bevel/edge template set for the same production view.
- Edge template sets are experimental/candidate-only until formally integrated.
- `quality=low` remains the texture-gen default; template set choice does not imply image quality.
