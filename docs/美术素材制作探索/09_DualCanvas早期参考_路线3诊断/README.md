# DualCanvas 早期参考：路线3诊断

Source run: `blender/textures/_candidates/template-connected-20260616-01`

## 定位

这是早期 `design_warp` / `design_uv_gpt` / `dual_canvas` 三模式对比的候选记录，用来解释为什么后来不再信任右侧 paper-net UV。

## 结论

- `dual_canvas` 左侧 3D target 往往比右侧 paper-net UV 更接近目标审美。
- 右侧 paper-net UV 容易把地块分割成 panel，后续 bake 会放大 seam 问题。
- `design_warp` 仍是重要参考，因为它保留了 3D target 的整体体块感。

## 关键文件

- `raw/dual_canvas_raw.png`
- `raw/design_warp_design.png`
- `uv/`
- `baked/`
- `compare_baked_tiles.png`
- `compare_closeup.png`
- `compare_full.png`

