# 原始候选完整归档

这里存放从 `blender/textures/_candidates/` 搬出的剩余完整候选目录。

`_candidates` 现在保持为空，只作为后续新实验的临时输出缓冲。旧 recipe / 旧样本读取由 `blender/scripts/texgen/archive_paths.py` 做路径兼容：优先读 `_candidates/<run>`，如果不存在则读这里的中文归档目录。

## 目录映射

| 旧 `_candidates` 目录 | 新归档目录 |
|---|---|
| loose files | `00_零散候选文件` |
| `single-stage-tile-6-variants-20260617-01` | `01_单地块标准方案_六地块样本_完整候选` |
| `tile-pipeline-seam-prototype-20260617-01` | `02_Godot拼接缝_当前最佳参数_完整候选` |
| `beveled-tile-prototype-20260617-01` | `03_顶面倒角模型_模式3原型_完整候选` |
| `original-no-ink-map-20260617-01` | `04_NoInk参考源_阴影职责_完整候选` |
| `template-connected-20260616-01` | `05_DualCanvas早期参考_路线3诊断_完整候选` |
| `left-warp-corner-ink-20260616-01` | `06_黑线专项_角线与缝线_完整候选` |
| `left-warp-source-cut-variants-baked-20260616-01` | `07_二十一图矩阵_源切分基准_完整候选` |
| `left-warp-source-cut-variants-top-edge-clean-20260616-01` | `08_二十一图矩阵_顶边清理_完整候选` |
| `quality-bake` | `09_Bake清晰度基准_完整候选` |

## 使用规则

- 新实验仍输出到 `blender/textures/_candidates/<run>`。
- 旧实验复现如果需要读取 frozen recipe，走 `archive_paths.existing_run(repo, run_name)`。
- 不要在新代码里直接硬编码这里的中文目录；集中通过 `archive_paths.py` 映射。

