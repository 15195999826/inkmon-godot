# codex-面片-v1

定位：整块 3D 地块图作为 image patch 拼装。

这个方向要验证的是：AI 生图可以给出完整六边形 3D 地块，但可能存在 scale / yaw / pitch 偏差；如果先把输入图矫正到标准 manifest 角度和尺寸，再像装饰物 sprite 一样作为面片拼地图，是否能得到更接近原图审美的结果。

当前文件：

- `program_scene.tscn`：程序化 / 旧资产占位入口，验证 patch 拼图、层高抬升、YSort 与装饰物排序。
- `asset_scene.tscn`：读取 `../concept素材-v1/assets/baked`，定位为 `docs/concept.jpg` 风格的新素材面片候选；旧 fable baked 只作为诊断对照，不再作为本轮候选。

当前验证：

- `shots/concept_asset.png`：concept 新素材面片拼装截图。
- `shots/concept_asset_decor.png`：concept 新素材面片 + concept decor 样板图。
- `asset_scene.tscn` 已使用 concept decor，避免混入 fable 风格素材。

后续计划：

- 增加自动锚定/人工参数拟合工具：输入纯白背景 tile image，输出标准化 patch。
- 继续改进自动锚定/人工参数拟合，让不同 raw tile 在 scale / yaw / pitch 偏差下仍能稳定输出标准 patch。
