# 单地块标准方案：六地块样本

Source run: `blender/textures/_candidates/single-stage-tile-6-variants-20260617-01`

## 定位

这是当前最值得延续的第一版生产方向：AI 只生成独立单个 3D 地块，后续 fitting、21 图矩阵、拼接缝和最终渲染由本地工具接管。

## 结论

- 单地块生成比 whole-map generation 更可控。
- AI 不应该负责最终 tile-to-tile seam。
- 六个 raw tile 都可作为第一版视觉探索样本，但仍需要 fitting 和 deterministic seam。

## 关键文件

- `六地块raw联系表.png`
- `raw/`
- `原始报告.md`

