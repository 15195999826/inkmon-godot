# 黑线专项：角线与缝线

Source run: `blender/textures/_candidates/left-warp-corner-ink-20260616-01`

## 定位

这个实验专门处理“哪些黑线该保留，哪些黑线该去掉”的问题。

## 结论

- 目标不是去掉所有黑线，而是区分 `3D corner crease / silhouette ink` 和错误的 `UV seam / template panel line`。
- 右侧 paper-net UV 的 seam 不应作为最终黑线来源。
- 侧边竖向拐角线如果存在，应像 3D corner crease，而不是错层、双线或面板边界。
- 后续更可靠的方向是从左侧 3D target fitting 到 UV，再由 Blender/Godot 控制额外描边。

## 关键文件

- `diagnostic_corner_ink_compare.png`
- `raw/source_dual_canvas_raw.png`
- `raw/dual_left_design.png`
- `uv/dual_left_design_warp_uv.png`
- `baked/`
- `left_warp_prepare_report.json`
- `left_warp_corner_ink_summary.json`
- `原始报告.md`

