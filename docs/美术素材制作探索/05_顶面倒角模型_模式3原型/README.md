# 顶面倒角模型：模式3原型

Source run: `blender/textures/_candidates/beveled-tile-prototype-20260617-01`

## 定位

这是三条模型管线里的 `顶面边倒角` / `mode3_top_edge_bevel` 原型。它用 explicit bevel mesh 解决顶面和侧壁之间只有黑线的问题。

## 结论

- explicit bevel mesh 可行，能把 top-wall join 变成真实 chamfer band。
- 当前版本在 stitched map 中会出现重复 golden rim，tile-to-tile seam 比参考图更明显。
- 后续若继续模式3，需要缩窄并压暗 bevel band，或让共享边只由一侧拥有。

## 关键文件

- `圆边_vs_倒角对比.png`
- `当前圆边map预览.png`
- `倒角map预览.png`
- `fit/`
- `templates/`
- `原始报告.md`

