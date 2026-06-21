# InkMon 美术探索

这个目录放 Godot 内可直接打开的地图美术探索场景。

当前旧基线是 `fable-圆角-v1`：Blender bake 出整块 tile PNG，再在 Godot 里按 manifest 拼装。

当前新素材源是 `concept素材-v1`：使用 `docs/concept.jpg` 风格重新生成的完整 3D 地块图与装饰物，再分别处理成 Godot 可拼装的透明 patch、标准 UV、倒角 UV。后续候选优先走这个素材源，`fable-圆角-v1` 只做旧基线诊断对照。

Codex 三条探索管线：

- `codex-硬边-v1`：程序化硬边 hex box，验证无 bevel 时的拼接、YSort、边界清晰度。
- `codex-倒角-v1`：程序化顶面倒角 hex box，验证顶面 rim / bevel 是否能让体块更厚重。
- `codex-面片-v1`：整块 tile image patch 拼装，验证“AI 生成完整 3D 地块后矫正成标准角度尺寸再作为面片渲染”的路线。
- `concept素材-v1`：`docs/concept.jpg` 风格 raw tile、透明 patch、UV、decor 输出目录。

当前 concept 三管线对比：

- 对比图：`concept三管线对比.png`
- 墨线对比：`concept墨线对比.png`
- 近景拼接对比：`concept近景拼接对比.png`
- 倒角宽度对比：`concept倒角宽度对比.png`
- fable 旧基线 vs concept 新素材最终对比：`concept_vs_fable最终对比.png`
- `codex-硬边-v1`：标准 UV 反投影 + Blender `mode2_hard` bake，边界最干净。
- `codex-倒角-v1`：beveled UV 反投影 + explicit top-edge bevel bake；`asset_wide_rim_scene.tscn` 的宽 rim 版本目前最接近厚重地块方向。
- `codex-面片-v1`：完整 3D tile sprite patch，最保留 raw 审美，但整块 sprite 覆盖感更强。

当前观察：

- 硬边 / 倒角的 Godot 拼图没有看到明显 YSort 错层。
- Blender ink 版本没有明显把内部缝线画脏，主要增强外轮廓和侧壁立体边。
- 默认倒角版的 bevel band 偏窄，和硬边差异不大；宽 rim 版本边界更清楚，是当前几何 bake 候选里优先看的版本。
- 面片版最保留 raw 单图风格，但大块 sprite 互相覆盖感更强，不如几何 bake 管线规整。
- concept decor 已替代旧 fable decor；当前样板图里使用的是 concept 风格树、灌木、石堆。

共享代码：

- `art_tile_map_base.gd`
  - 复用 `fable-圆角-v1/assets/baked/manifest.json` 的相机/比例/层高契约。
  - 复用 `InkMonIsoSandboxDemoMap.generate()`，保证三条探索和圆角基线对照的是同一张 sample map。
  - 支持 `INKMON_ART_CAPTURE_PATH` 环境变量在非 headless 运行时保存 viewport 截图。
- `art_camera_controller_2d.gd`
  - 美术观察用 2D 相机控制：WASD / 方向键平移，鼠标滚轮缩放，中键拖拽，Space 回到初始 framing。
  - 已接入三条 codex 探索场景、`fable-圆角-v1/tile_pipeline_scene.tscn` 和 seam candidate 预览场景。

每条管线都保留 `program_scene.tscn` 作为几何/排序基准，`asset_scene.tscn` / `asset_ink_scene.tscn` / 特化 scene 作为素材验证入口。

## 当前验证

2026-06-19 首轮程序版已跑通：

- `codex-硬边-v1/program_scene.tscn`
  - 截图：`codex-硬边-v1/shots/program.png`
  - 状态：可作为硬边几何/YSort 基线；视觉仍是占位风格。
- `codex-硬边-v1/asset_scene.tscn`
  - 截图：`codex-硬边-v1/shots/concept_asset_decor.png`
  - 状态：已切到 `concept素材-v1/uv` 反投影 UV + Blender `mode2_hard` bake，并使用 concept decor；不是 fable 旧纹理。
- `codex-硬边-v1/asset_ink_scene.tscn`
  - 截图：`codex-硬边-v1/shots/concept_asset_ink.png`
  - 状态：同一批 concept UV + Blender `mode2_hard` bake，但开启 Freestyle ink。
- `codex-倒角-v1/program_scene.tscn`
  - 截图：`codex-倒角-v1/shots/program.png`
  - 状态：顶面 rim 带来更清楚的体块层次；保留为几何/YSort 程序基线。
- `codex-倒角-v1/asset_scene.tscn`
  - 截图：`codex-倒角-v1/shots/concept_asset.png`
  - 状态：已接入 concept raw → beveled UV → explicit top-edge bevel bake；当前 bevel band 较窄，和硬边差异不大，但水道/顶面边界更亮。
- `codex-倒角-v1/asset_ink_scene.tscn`
  - 截图：`codex-倒角-v1/shots/concept_asset_ink.png`
  - 状态：同一批 beveled UV + explicit top-edge bevel bake，但开启 Freestyle ink。
- `codex-倒角-v1/asset_wide_rim_scene.tscn`
  - 截图：`codex-倒角-v1/shots/concept_asset_wide_rim_decor.png`
  - 状态：宽 rim 候选，`bevel_inset_world=0.085`、`bevel_drop_world=0.050`；当前更推荐从这个版本继续调。
- `codex-面片-v1/program_scene.tscn`
  - 截图：`codex-面片-v1/shots/program.png`
  - 状态：程序化 / 旧资产占位入口，只用于验证 image patch 拼装、层高抬升、装饰物排序，不作为本轮素材审美基准。
- `codex-面片-v1/asset_scene.tscn`
  - 截图：`codex-面片-v1/shots/concept_asset_decor.png`
  - 状态：已切到 `concept素材-v1/assets/baked`，使用 `docs/concept.jpg` 风格新素材和 concept decor；旧 fable 资产仅保留作诊断对照。

验证命令要用 console 版 Godot；`godot.exe` 是 GUI build，stdout 不可靠：

```powershell
C:\Users\37065\.local\bin\godot_console.exe --headless --path D:/GodotProjects/inkmon/inkmon-godot --import
$env:INKMON_ART_CAPTURE_PATH = "D:\GodotProjects\inkmon\inkmon-godot\inkmon美术探索\codex-硬边-v1\shots\program.png"
C:\Users\37065\.local\bin\godot_console.exe --path D:/GodotProjects/inkmon/inkmon-godot res://inkmon美术探索/codex-硬边-v1/program_scene.tscn
Remove-Item Env:INKMON_ART_CAPTURE_PATH
```

注意：`--headless` 使用 dummy rendering，不能从 viewport texture 截图；截图场景需要非 headless 运行。
