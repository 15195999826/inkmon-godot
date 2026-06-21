# 美术素材制作探索

这个目录是对 `blender/textures/_candidates/` 和 `.codex-goal/` 的精选归档，不是生产资源目录。

目标是保留“为什么这样做”的证据：哪些路线有效、哪些路线失败、哪些参数值得进入后续工具。`_candidates` 现在只作为新实验临时缓冲；已保留的完整旧候选放在 `原始候选完整归档/`。

## 当前结论

- 第一版地块方案优先走“单个 3D 地块生图 -> fitting/auto-anchor -> 21 图矩阵 -> Blender/Godot 接管拼接缝”。
- `dual_canvas` 的右侧 paper-net UV 不适合作为最终贴图来源，容易产生 panel seam、黑线错位和侧边高度错位。
- AI 生图不会严格跟模板，必须允许 per-image fitting。纯白背景能帮助自动锚定，但仍要允许人工校正参数。
- UV/贴图负责 albedo 和材料细节；阴影、共享边 seam、最终受光边应由 Blender/Godot 管线接管。
- `quality=low` 可以用于风格验证；清晰度主要靠更高 internal bake、Lanczos downsample 和 mild `UnsharpMask`。
- 三条模型管线要分开命名和测试：`圆边`、`硬边`、`顶面边倒角`。

## 目录索引

流程总览页：[`三管线完整流程图.html`](./三管线完整流程图.html)

| 目录 | 定位 |
|---|---|
| `01_单地块标准方案_六地块样本` | 第一版单地块 raw 生成方向，6 个地块样本 |
| `02_Godot拼接缝_当前最佳参数` | Godot candidate scene 验证过的 seam overlay 参数 |
| `03_Blender拼接缝_十轮迭代结论` | Blender/Python seam 迭代过程和失败原因 |
| `04_单3D模板准确度_自动锚定依据` | 证明 AI 会偏离模板，需要 fitting/auto-anchor |
| `05_顶面倒角模型_模式3原型` | `顶面边倒角` 模型原型和视觉风险 |
| `06_二十一图矩阵_源切分基准` | 7 个 source-cut variant 的冻结基准 |
| `07_二十一图矩阵_顶边清理` | 21 图矩阵：原始 / top edge clean / Blender ink |
| `08_NoInk参考源_阴影职责` | no-ink 参考源，辅助拆分贴图与渲染职责 |
| `09_DualCanvas早期参考_路线3诊断` | dual canvas 早期三模式对比和诊断资产 |
| `10_黑线专项_角线与缝线` | corner crease 与 UV seam 的黑线专项 |
| `11_Bake清晰度基准_2048降采样sharp80` | bake 清晰度参数基准 |
| `12_Route3首轮探索_失败路径总结` | paper-net / continuous wall strip / mesh edge 的首轮结论 |
| `原始候选完整归档` | 从 `_candidates` 搬出的剩余完整候选目录 |

## 清理原则

`_candidates` 已清空，只保留为空目录作为后续新实验缓冲。旧 recipe / 旧样本读取不要直接硬编码中文目录；使用 `blender/scripts/texgen/archive_paths.py`。
