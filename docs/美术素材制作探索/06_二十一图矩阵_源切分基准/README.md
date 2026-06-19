# 二十一图矩阵：源切分基准

Source run: `blender/textures/_candidates/left-warp-source-cut-variants-baked-20260616-01`

## 定位

这是 7 个 source-cut variant 的冻结基准，也是后续 21 图矩阵脚本曾经读取的 recipe 来源。

## 结论

- 7 个 variant 用于判断 wall seam / corner crease / source ownership 的归属。
- 这一层是“从 3D target 切 source”的基准，不是最终审美结论。
- 如果未来 `single_design_21_matrix.py` 已完全改成从 fitted top/sidecar 重新生成 recipe，这个旧目录才可以删除。

## 关键文件

- `source_cut_variants_uv_report.json`
- `source_cut_variants_bake_summary.json`
- `shots/source_cut_variants_full_tile_compare.png`
- `shots/source_cut_variants_corner_zoom_compare.png`
- `原始报告.md`

