# concept素材-v1

定位：用 `docs/concept.jpg` 的风格生成的新一轮地块与装饰物素材源。

这里不再复用 `fable-圆角-v1` 的旧纹理。当前流程是：

1. `raw/`：texture-gen 生成的完整 3D 六边形地块图，白底。
2. `decor_raw/`：texture-gen 生成的树、灌木、石堆，白底。
3. `tools/prepare_patch_assets.py`：只从画布边缘 flood-fill 清理白底，缩放到 512 patch。
4. `tools/prepare_design_warp_uvs.py`：把 raw 反投影成标准 paper-net UV，供硬边/圆边 Blender bake 诊断。
5. `tools/prepare_beveled_uvs.py`：把 raw 反投影成 explicit top-edge bevel UV，供倒角 Blender bake 诊断。
6. `tools/prepare_concept_decors.py`：把 decor raw 清底、缩放、写入各 concept manifest。
7. `assets/baked/`：Godot `codex-面片-v1/asset_scene.tscn` 读取的透明 tile patch、concept decor 与 `manifest.json`。

这版先验证“完整 3D tile image -> 标准 patch / UV -> Godot 拼图”的三条路线。它不是 fable baked；decor 也已换成 concept 风格，不混入旧 fable decor。

当前已生成：

- `raw_contact_12.png`：12 张 raw tile 总览。
- `decor_raw_contact.png`：4 张 decor raw 总览。
- `decor_processed_contact.png`：4 张透明 decor 总览。
- `assets/concept_patch_contact.png`：透明 patch 总览。
- `uv/design_warp_uv_contact.png`：标准 paper-net UV 总览。
- `beveled_uv/beveled_uv_contact.png`：explicit top-edge bevel UV 总览。
- `assets/baked/tile_<terrain>_e<e>_v0.png`：Godot 实际读取的 tile patch。
- `assets/baked/decor_<name>.png`：Godot 实际读取的 concept decor。
- `assets/baked/manifest.json`：只引用 concept tile/decor，不引用 fable texture/decor。

运行：

```powershell
python .\inkmon美术探索\concept素材-v1\tools\prepare_patch_assets.py
python .\inkmon美术探索\concept素材-v1\tools\prepare_design_warp_uvs.py
python .\inkmon美术探索\concept素材-v1\tools\prepare_beveled_uvs.py
python .\inkmon美术探索\concept素材-v1\tools\prepare_concept_decors.py
```

宽 rim 倒角候选使用单独参数输出：

```powershell
python .\inkmon美术探索\concept素材-v1\tools\prepare_beveled_uvs.py --out-dir .\inkmon美术探索\concept素材-v1\beveled_uv_wide_rim --bevel-inset-world 0.085 --bevel-drop-world 0.050
```
