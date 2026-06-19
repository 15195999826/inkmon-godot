# Tile Texture Bake Pipeline Modes

本文定义当前 tile texture bake 的三条模型管线。后续对话里说“圆边 / 硬边 / 倒角”或“模式 1 / 2 / 3”，
均以本文和 `blender/scripts/texgen/tile_pipeline_modes.py` 为准。

## Summary

| 模式 | 名称 | 用途 | Mesh contract | UV / template contract |
|---|---|---|---|---|
| 1 | 圆边 | current production 默认 | standard hex prism + Blender `Bevel` modifier + smooth normals | `standard-templates`；standard paper-net UV / atlas |
| 2 | 硬边 | no-bevel diagnostic | same standard hex prism, no bevel modifier, flat face shading | `standard-templates`；和模式 1 共用 UV |
| 3 | 倒角 | explicit top-edge bevel candidate | explicit `top + bevel_0..5 + wall_*` faces | `standard-edged-templates`；必须使用 beveled UV |

## Mode 1: 圆边 / Rounded Production

代码真相：

- `blender/scripts/texgen/tile_pipeline_modes.py::MODE1_ROUNDED`
- `blender/scripts/bake_assets.py::build_hex_tile()`

行为：

- 创建 standard flat-top hex prism。
- 使用 production 默认 `Bevel` modifier。
- 默认 `bevel_width=0.06`, `bevel_segments=3`。
- 启用 smooth normals。
- 当前正式 tile bake 默认使用此模式。

适用：

- production bake。
- 仍然希望 Blender 负责柔和边缘、统一光照、统一 Freestyle 的路线。

## Mode 2: 硬边 / Hard No-Bevel Diagnostic

代码真相：

- `blender/scripts/texgen/tile_pipeline_modes.py::MODE2_HARD`
- `blender/scripts/bake_assets.py::build_hex_tile()` + mode 2 config patch。

行为：

- 仍创建 standard flat-top hex prism。
- 不添加 `Bevel` modifier。
- 关闭 smooth normals，使用 flat face shading。
- UV topology 与模式 1 相同。

适用：

- 诊断贴图自身是否带来 seam / dirty edge。
- 排除 production bevel / smooth normal 对黑线和缝的影响。
- 21 matrix 的 no-bevel 对比输出。

注意：

- 模式 2 不是 production 默认。
- 它可以帮我们看清贴图问题，但未必是最终美术方向。

## Mode 3: 倒角 / Explicit Top-Edge Bevel

代码真相：

- `blender/scripts/texgen/tile_pipeline_modes.py::MODE3_TOP_EDGE_BEVEL`
- `blender/scripts/texgen/beveled_tile_prototype.py`

行为：

- 不复用 standard prism topology。
- 显式创建 `top + bevel_0..5 + wall_3/4/5` 面。
- 顶面边缘倒角是 mesh 面，不是 Blender `Bevel` modifier。
- 使用 `standard-edged-templates` / `beveled_uv`。

适用：

- 尝试还原参考图中顶面边缘的厚重 chamfer band。
- 需要把 top-wall transition 交给 mesh topology，而不是贴图黑线或 Freestyle。

注意：

- 模式 3 不能直接吃模式 1/2 的 paper-net UV。
- 它需要单独的 source fitting、UV layout 和 QC。
- 当前仍是 candidate prototype，未进入 production bake。

## Shared vs Independent

必须共享：

- camera angle / `manifest` contract。
- output canvas / anchor / scale。
- Godot import path and manifest shape。
- final production naming convention。

可以独立或 preset 化：

- source fitting / panel extraction。
- UV layout。
- mesh topology。
- edge ownership / seam cleanup。
- Blender ink / Freestyle strategy。
- diagnostic lighting。
- QC and debug overlays。

原则：

- 同一 mesh face topology 才能共用 UV layout。
- mesh 多了面、少了面、或 face ownership 变了，就必须有自己的 UV layout。
- source 图不同不一定要求不同 UV，但通常需要不同 source fit / cut。

## Code Entry Points

- Shared mode registry: `blender/scripts/texgen/tile_pipeline_modes.py`
- Mode 1 / 2 bake entry: `blender/scripts/bake_assets.py`
- Mode 3 prototype entry: `blender/scripts/texgen/beveled_tile_prototype.py`
- 21 matrix entry: `blender/scripts/texgen/single_design_21_matrix.py`
- Source-cut recipe generator: `blender/scripts/texgen/source_cut_recipe_gen.py`
