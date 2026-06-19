# Standard Edged Templates Model

Use this set for mode 3 `倒角`: current view plus explicit top bevel / sloped edge band.

- View: `pitch=35.26`, `yaw=-15`
- Blender model: `blender/models/template_tiles/hex_tile_template_models.blend`
- Object: `standard_edged_hex_prism_bevel_band`
- Camera: `camera_standard_edged_pitch35_26_yaw_minus15`
- Geometry: flat-top hex with inset top and bevel band
- Bevel: `bevel_inset_world=0.055`, `bevel_drop_world=0.035`
- Inner edge: `0.9364914703891412`

Regenerate:

```powershell
python blender/scripts/texgen/beveled_tile_prototype.py --stage templates --template-out blender/templates/standard-edged-templates
```
