# Placeholder Geometry Fixtures

这个目录存放手工占位图，用来在不调用 texture-gen 的情况下验证 tile 生图管线的几何链路。

它们不是正式美术资产，也不是 Round 2.5 入库基线。用途是 smoke test / debug：确认模板几何、warp、grid mask、sprite anchor 这些数学约定是否正常。

## 定位

这里是 `blender/templates/` 下的验证夹具目录。它的价值不是“好看”，而是让我们用稳定、可重建、颜色语义明确的图片快速定位问题：

- 模板改了以后，先用这里的占位图确认几何链路有没有断。
- warp / cut / grid mask / sprite anchor 出问题时，用这里的图排除生图随机性。
- 正式 AI 图效果异常时，可以和这里的输出对比，判断问题来自几何处理还是来自生图本身。

不要把这里当作生产模板、候选资产或审美参考。

## 生成方式

```powershell
python blender/scripts/texgen/make_placeholder.py -e 0
```

默认输出到本目录。

## 文件说明

- `placeholder_design_e0.png`
  - 脚本生成。
  - 1024x1024 3D 地块占位设计稿。
  - 顶面网格和三侧壁彩色条纹用于肉眼检查 `design -> UV` warp 是否对齐。

- `placeholder_grid.png`
  - 脚本生成。
  - 1536x1536 七格俯视 grid。
  - 用于检查 grid cell mask、单格裁切和环形坐标是否正确。

- `placeholder_sprite_bush.png`
  - 脚本生成。
  - 512x512 透明底灌木占位 sprite。
  - 故意偏离画布中心并保留底部空白，用于验证 alpha bbox 和 bottom-center anchor。

- `placeholder_uv_e0.png`
  - 历史早期 UV 占位/中间产物。
  - 当前 `make_placeholder.py` 不再生成它。

- `placeholder_cut_0_0.png`
  - 历史早期单格裁切测试产物。
  - 当前无脚本依赖。

- `_shot_crop.png`
  - 历史截图裁切。
  - 当前无脚本依赖。

## 使用原则

- 可以用它们快速验证几何链路，不要用来判断最终审美。
- 如果这些 PNG 丢失，可以用 `make_placeholder.py` 重新生成核心三张：`placeholder_design_e0.png`、`placeholder_grid.png`、`placeholder_sprite_bush.png`。
- 不要把这里的图片写入 production baked assets。
- 如果后续新增验证图，优先保持颜色/线条语义明确，并在本 README 里补一条文件说明。
