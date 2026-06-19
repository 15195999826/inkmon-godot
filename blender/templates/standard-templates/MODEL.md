# Standard Templates Model

Use this set for the standard-prism pipelines:

- mode 1 `圆边`: current production, standard prism + Blender bevel modifier.
- mode 2 `硬边`: diagnostic, same prism + no bevel + flat face shading.

- View: `pitch=35.26`, `yaw=-15`
- Blender model: `blender/models/template_tiles/hex_tile_template_models.blend`
- Object: `standard_hex_prism`
- Camera: `camera_standard_pitch35_26_yaw_minus15`
- Geometry: flat-top hex prism, `hex_edge_world=1.0`, `thickness_world=0.55`

Regenerate:

```powershell
python blender/scripts/texgen/make_templates.py -o blender/templates/standard-templates
```
