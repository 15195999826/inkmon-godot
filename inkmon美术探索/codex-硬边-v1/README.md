# codex-硬边-v1

定位：程序化硬边六边形盒子。

目标是验证没有 Blender bevel / smooth edge 时，六边形地块是否能获得更清晰、更可控的拼接边界。

当前文件：

- `program_scene.tscn`：程序化硬边版本，复用 `inkmon美术探索/art_tile_map_base.gd`。
- `asset_scene.tscn`：Blender `mode2_hard` / 无 bevel bake 资产版本，读取本目录 `assets/concept-baked`。素材源来自 `../concept素材-v1/raw` 和 `../concept素材-v1/decor_raw`，不是 fable 旧纹理。
- `asset_ink_scene.tscn`：同一套硬边几何和 concept UV，但读取 `assets/concept-baked-ink`，用于观察 Blender Freestyle 墨线。

当前验证：

- `assets/concept_hard_baked_contact.png`：12 张 concept hard baked tile 总览。
- `assets/concept_hard_ink_baked_contact.png`：12 张 concept hard + Freestyle ink baked tile 总览。
- `shots/concept_asset.png`：Godot 拼图截图。
- `shots/concept_asset_ink.png`：Godot 墨线版拼图截图。
- `shots/concept_asset_decor.png`：Godot concept tile + concept decor 样板图。
- Blender bake 参数：`mode2_hard`，`samples=16`，分别测试 `ink_enabled=false/true`。

后续计划：

- 只把 `fable-圆角-v1` 当旧基线对照；继续调参时以 `docs/concept.jpg` 风格的新素材为准。
- 观察 YSort、侧壁交接、黑色描边是否稳定。
- 如果硬边胜出，再优化 Blender 光照、墨线和贴图清晰度。
