# codex-倒角-v1

定位：程序化顶面倒角六边形盒子。

目标是验证“顶面边倒角 / rim band”是否能提供更厚重的体块感，同时让相邻地块边界保持清楚。

当前文件：

- `program_scene.tscn`：程序化倒角版本，复用 `inkmon美术探索/art_tile_map_base.gd`。
- `asset_scene.tscn`：Blender explicit top-edge bevel bake 资产版本，读取本目录 `assets/concept-baked`。素材源来自 `../concept素材-v1/raw` 和 `../concept素材-v1/decor_raw`，不是 fable 旧纹理。
- `asset_ink_scene.tscn`：同一套倒角几何和 beveled UV，但读取 `assets/concept-baked-ink`，用于观察 Blender Freestyle 墨线。
- `asset_wide_rim_scene.tscn`：宽 rim 候选，读取 `assets/concept-baked-wide-rim`，用于观察更明显的顶面边倒角。

当前验证：

- `assets/concept_beveled_baked_contact.png`：12 张 concept top-edge bevel baked tile 总览。
- `assets/concept_beveled_ink_baked_contact.png`：12 张 concept top-edge bevel + Freestyle ink baked tile 总览。
- `shots/concept_asset.png`：Godot 拼图截图。
- `shots/concept_asset_ink.png`：Godot 墨线版拼图截图。
- `shots/concept_asset_wide_rim.png`：宽 rim 无 decor 截图。
- `shots/concept_asset_wide_rim_decor.png`：宽 rim + concept decor 样板图。
- Blender bake 参数：`mode3_top_edge_bevel`，`samples=16`，分别测试 `ink_enabled=false/true`。
- 宽 rim bake 参数：`bevel_inset_world=0.085`，`bevel_drop_world=0.050`。

后续计划：

- 以 `asset_wide_rim_scene.tscn` 作为当前优先候选，继续调整 rim 明暗、外框墨线强度。
- 对比硬边和圆角，观察顶面边缘是否更接近参考图那种厚重体块。
