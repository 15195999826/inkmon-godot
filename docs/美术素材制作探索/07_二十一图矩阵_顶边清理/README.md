# 二十一图矩阵：顶边清理

Source run: `blender/textures/_candidates/left-warp-source-cut-variants-top-edge-clean-20260616-01`

## 定位

这是 21 图矩阵思想的明确版本：原始 7 张、top edge clean 7 张、top edge clean + Blender ink 7 张。

## 结论

- 用户认可的方向是：先保留原始 7 个 source-cut variant，再额外生成顶边清理和 Blender 描边版本。
- 顶边清理不应该对像素颜色做复杂语义处理，优先调整几何裁剪区域。
- 这个实验保留了 `top_edge_inset = 18px` 的关键试验值。

## 关键文件

- `shots/top_edge_clean_21_compare_by_variant.png`
- `shots/top_edge_clean_21_compare_by_group.png`
- `top_edge_21_matrix_summary.json`
- `原始报告.md`

