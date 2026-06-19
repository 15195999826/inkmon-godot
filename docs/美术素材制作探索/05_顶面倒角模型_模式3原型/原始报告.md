# Beveled Tile Prototype

Candidate-only prototype for concept-style rounded top seams.

## Parameters

- pitch/yaw: current manifest `35.26 / -15`
- bevel_inset_world: `0.055`
- bevel_drop_world: `0.035`
- representative tile: `tile03`
- bake: `2048 internal -> 512 Lanczos + UnsharpMask(radius=0.75, percent=80, threshold=2)`
- ink: no Blender Freestyle / no Blender ink

## Prompt

```text
Create one isolated hand-painted isometric 3D hex terrain tile on a pure white background using the provided beveled template. Match the current InkMon hand-painted tile style: warm olive grass top, subtle stone path fragments, earthy/stone side walls, painterly board-game texture, soft ambient light, no cast shadow, no drop shadow, no ground shadow, no UI, no text. IMPORTANT: the narrow rim band around the top is a soft rounded bevel/chamfer, not a black outline. Paint face joins as subtle dark crevice shading plus a small light-catching bevel edge, similar to the concept map. Avoid heavy black strokes on top-wall joins and tile-to-tile joins. Keep the tile centered and complete, with visible front/left/right walls. Natural variation only; no trees, no characters, no water.

[texture-gen]
callId: call_mqhjhpe1_jezmo
quality: low
n: 4
size: 1024x1024
purpose: inkmon-beveled-tile-prototype
base_image_path: D:\GodotProjects\inkmon\inkmon-godot\blender\textures\_candidates\beveled-tile-prototype-20260617-01\templates\beveled_design_e0.png
reference_image_paths:
- D:\GodotProjects\inkmon\inkmon-godot\blender\textures\_candidates\original-no-ink-map-20260617-01\raw\raw_03.png
- D:\GodotProjects\inkmon\inkmon-godot\docs\concept.jpg
```

## Outputs

- raw contact: `D:\GodotProjects\inkmon\inkmon-godot\blender\textures\_candidates\beveled-tile-prototype-20260617-01\raw_contact.png`
- baked tile contact: `D:\GodotProjects\inkmon\inkmon-godot\blender\textures\_candidates\beveled-tile-prototype-20260617-01\baked_tile_contact.png`
- current vs beveled: `D:\GodotProjects\inkmon\inkmon-godot\blender\textures\_candidates\beveled-tile-prototype-20260617-01\compare_current_vs_beveled.png`
- current map: `D:\GodotProjects\inkmon\inkmon-godot\blender\textures\_candidates\beveled-tile-prototype-20260617-01\map_current_tile03_preview.png`
- beveled map: `D:\GodotProjects\inkmon\inkmon-godot\blender\textures\_candidates\beveled-tile-prototype-20260617-01\map_beveled_preview.png`

## Raw White Background Ratio

- raw_01: 49.16%
- raw_02: 50.02%
- raw_03: 49.63%
- raw_04: 53.52%

## UV White Ratio

- raw_01: 0.0004%
- raw_02: 0.0004%
- raw_03: 0.0000%
- raw_04: 0.0000%

## Visual Conclusion

- The explicit bevel mesh works: the top-wall join becomes a visible chamfer band instead of only a flat black outline.
- This default is not final: in the stitched map the bevel reads as a repeated golden rim, so tile-to-tile seams are more visible than the concept reference.
- The next pass should narrow and darken the bevel band, or make shared seams choose one owner side, so the map reads as dark crevice plus light catch instead of double highlight.
