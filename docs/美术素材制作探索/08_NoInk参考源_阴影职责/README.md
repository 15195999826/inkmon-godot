# NoInk 参考源：阴影职责

Source run: `blender/textures/_candidates/original-no-ink-map-20260617-01`

## 定位

用于拆分贴图与渲染职责：贴图尽量不携带最终阴影和粗描边，最终 lighting/shadow/edge 由 Blender/Godot 负责。

## 结论

- 生图 prompt 应要求 `no cast shadow`、`no drop shadow`、纯白背景。
- UV / source image 应更接近 albedo/material detail。
- 最终阴影、shared seam、rim highlight 不应依赖 AI baked-in shadow。

## 关键文件

- `raw/`
- `baked_512_original_no_ink/`
- `NoInk地图预览.png`
- `NoInk地图透明版.png`
- `原始报告.json`

