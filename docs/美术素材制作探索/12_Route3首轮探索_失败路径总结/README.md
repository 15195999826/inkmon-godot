# Route3 首轮探索：失败路径总结

Source run: `blender/textures/_candidates/route3-first-round-20260616-01`

## 定位

这是 Route 3 首轮大矩阵探索的结论归档。它主要告诉我们哪些方向不要继续投入。

## 结论

- Group A `paper-net salvage`：几何能过 QC，但审美上仍有 panel seam 和侧壁分割感，不适合作为主路线。
- Group B `continuous wall strip`：结构上优于 paper-net，侧壁连续性更好，但 top surface/rim 仍需要额外方案。
- Group D `mesh / edge calibration`：mesh 和 edge preset 能改善观感，但不能单独修复错误的 source/UV 语义。

## 后续影响

这轮之后路线转向：单 3D 地块生图、per-image fitting、21 图矩阵、deterministic seam。

## 关键文件

- `group_a_paper_net_compare.png`
- `group_b_continuous_wall_strip_compare.png`
- `group_d_mesh_edge_compare.png`
- `route3_first_round_summary.json`
- `原始报告.md`

