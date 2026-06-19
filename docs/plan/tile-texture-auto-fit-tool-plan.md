# Tile Texture Auto Fit Tool Plan

本文记录 tile 生图管线下一步工具计划：当 AI 生成的 single 3D tile 与数学模板存在像素偏差时，
先自动/人工拟合实际图块盒子，再基于确认后的 `fit.json` 自动生成 21 图矩阵。

## Background

当前 tile texture pipeline 已验证过多种路线：

- `dual_canvas`: 左侧 3D view + 右侧 UV / paper net。
- `design_warp`: AI 生成 3D design，再按固定几何映射到 UV。
- `single 3D + 21 matrix`: 直接用单个 3D 地块图作为 visual/material source，派生多组裁切和描边候选。

最新测试发现：即使 prompt 明确要求 preserve exact template，AI 输出仍可能相对模板出现 5-30px 级别偏差。
例如同一个 corrected `line6 unique-edge` single 3D template 下：

- `water_channel_e0` 基本贴合 sidecar。
- `grass_e0` / `stone_path_e0` 的后上边真实黑线比 sidecar 高约 25-30px。

这说明 template sidecar 不能再被当成每张 AI 输出的绝对真相。后处理必须接受 AI 有偏差，
并提供一个可校准的 source geometry。

## Problems

### 1. Fixed Sidecar Causes Wrong Sampling

现有 `template_design_e0.json` 描述的是模板的数学边界，不一定等于 AI 实际画出的地块边界。
如果继续用固定 sidecar 直接 warp，会导致：

- 顶面黑边被裁掉。
- 顶面边缘草皮 / 石块细节被吞。
- top-wall transition 丢失，贴到 Blender 后出现不自然硬缝。
- 某些模式下为了补黑边加大 source margin，又会采到背景或造成拉伸。

### 2. AI Output Variance Is Expected

这个偏差不是单张坏图的问题，而是图生图模型的常态：

- prompt 可以降低漂移，但不能保证逐像素跟随模板。
- 不同 tile type 的结构复杂度会影响跟随程度。
- low quality 更适合快速验证风格，但几何稳定性不会变成严格工程输出。

因此 pipeline 不能依赖“LLM 必须完全按模板生图”。

### 3. Manual Judgment Is Still Needed

纯自动算法很难判断所有边：

- 黑线可能被草丛、石块纹理、花朵遮挡。
- top-wall 共享边可能既像轮廓线，也像材质线。
- AI 可能画出断线、双线、局部粗线。

自动锚定应该作为 initial guess，最终仍需要人工确认。

## Proposed Workflow

目标流程：

1. 用户导入一张 single 3D tile image。
2. 工具基于纯白背景自动提取 tile mask。
3. 工具生成初始 `fit.json` 和 overlay preview。
4. 用户在工具里拖拽/微调六边形盒子，使 `top + 3 visible walls` 贴合实际图块。
5. 用户确认后保存 final `fit.json`。
6. `single_design_21_matrix.py` 使用 final `fit.json` 自动生成 21 图矩阵。
7. 后续可继续进入 Blender bake / Godot import / tile_pipeline scene 对比。

关键变化：

- 旧流程：`template_design_e0.json` -> warp / 21 matrix。
- 新流程：`template_design_e0.json` -> auto-fit initial guess -> user-confirmed `fit.json` -> warp / 21 matrix。

## Data Contract

第一版 `fit.json` 建议如下：

```json
{
  "schema": "inkmon.tile_source_fit.v1",
  "source_image": "raw/grass_e0.png",
  "template": "template_design_e0_line6_unique.json",
  "canvas": [1024, 1024],
  "faces": {
    "top": [[875.5, 371.2], [609.4, 217.6], [245.9, 273.9], [148.5, 483.7], [414.6, 637.3], [778.1, 581.1]],
    "wall_3": [[148.5, 483.7], [414.6, 637.3], [414.6, 806.4], [148.5, 652.7]],
    "wall_4": [[414.6, 637.3], [778.1, 581.1], [778.1, 750.1], [414.6, 806.4]],
    "wall_5": [[778.1, 581.1], [875.5, 371.2], [875.5, 540.3], [778.1, 750.1]]
  },
  "edge": {
    "top_outline_px": 18,
    "wall_seam_px": 8,
    "top_edge_clean_px": 0
  },
  "fit": {
    "mode": "auto_then_manual",
    "confidence": 0.82,
    "warnings": ["top_rear_edge_low_confidence"]
  }
}
```

Notes:

- `faces` 是实际 source image 坐标，不再是模板理论坐标。
- `edge` 是 21 matrix 的裁切/边线策略参数，允许跟随每张图单独保存。
- `fit.mode` 记录来源：`template`, `auto`, `manual`, `auto_then_manual`。
- `warnings` 用来提示哪些边需要人工重点看。

## Auto Fit Strategy

自动锚定只做 initial guess，不直接作为 production truth。

### Step 1. White Background Segmentation

要求生图 prompt 固定：

- `pure white background`
- `no cast shadow`
- `no drop shadow`
- `no ground shadow`
- `single isolated tile`

算法：

- 把接近白色的像素识别为 background。
- 提取最大 non-white connected component。
- 做小尺度 morphology close，减少草尖 / 细线断裂带来的 mask 孔洞。
- 输出 `tile_mask.png` 和 foreground bbox。

### Step 2. Coarse Box Fit

输入：

- `template_design_e0.json`
- `tile_mask`
- foreground bbox / convex hull

处理：

- 用 template 的 `top + wall_3 + wall_4 + wall_5` topology 作为初始形状。
- 按 foreground bbox 做 scale / translate。
- 用 convex hull 的主要边方向微调整体盒子。

输出：

- `auto_fit.json`
- `auto_overlay.png`
- `auto_report.json`

### Step 3. Edge Refinement

沿模板预期的可见边附近搜索 dark ink edge：

- top outer edges。
- top-wall shared edges。
- visible wall outer edges。
- wall-wall corner edges。

每条边只允许在小范围内移动，避免被内部石块线、草丛线误吸附。

输出 confidence：

- `high`: 边缘连续且与预期方向一致。
- `medium`: 局部断裂，但大方向一致。
- `low`: 边缘被遮挡、重复、或与纹理线混淆。

## Manual Fit Tool

第一版可以先做轻量工具，不需要一开始集成 Godot editor。

建议 UI 能力：

- 打开 source image。
- 显示 `top` red polygon 和 `wall_*` blue quads。
- 拖拽顶点。
- 整体 move / scale。
- 可开关 face fill overlay。
- 显示 raw / overlay side-by-side。
- 保存 `fit.json`。
- 一键运行 21 matrix preview。

第一版实现形式优先级：

1. CLI + generated overlay：最快验证算法。
2. 本地 HTML canvas tool：最适合人工拖点，依赖低。
3. Godot tool scene：后续如果要和 tile_pipeline workflow 深度整合再做。

## 21 Matrix Integration

`single_design_21_matrix.py` 后续应支持：

```powershell
python blender/scripts/texgen/single_design_21_matrix.py `
  --source raw/grass_e0.png `
  --fit-json fit/grass_e0.fit.json `
  --out blender/textures/_candidates/<run>/matrix
```

生成策略：

- 使用 `fit.json.faces.top` 作为 top source polygon。
- 使用 `fit.json.faces.wall_3|4|5` 作为 wall source quads。
- 输出原有 7 种 source ownership / seam 方案。
- 每种再派生：
  - original albedo edges。
  - selected top edge cleaned。
  - selected top edge cleaned + Blender ink ready。

最终仍形成 21 张候选图，供用户视觉裁定。

## Development Plan

### Phase 1. CLI Auto Fit Prototype

新增：

- `blender/scripts/texgen/auto_fit_design.py`

输入：

- `--image <raw.png>`
- `--template <template_design_e0.json>`
- `--out <fit_dir>`

输出：

- `auto_fit.json`
- `auto_overlay.png`
- `tile_mask.png`
- `auto_report.json`

验收：

- 对纯白背景 single 3D tile 能稳定分离主体。
- overlay 至少能给出可用 initial guess。
- report 标出低置信边。

### Phase 2. Fit JSON Matrix Support

修改：

- `blender/scripts/texgen/single_design_21_matrix.py`

能力：

- 支持 `--fit-json`。
- 默认继续兼容旧 `--template-json` 行为。
- matrix report 记录 `fit_json`、edge params、source image id。

验收：

- 同一 source image 下，template sidecar 与 manual fit sidecar 能生成可比较的 21 matrix。
- 不再因为固定 sidecar 明显裁掉顶面黑边。

### Phase 3. Manual Fit UI

新增一个轻量人工校准工具。

候选位置：

- `blender/scripts/texgen/fit_tool/`

建议文件：

- `index.html`
- `fit_tool.js`
- `README.md`

能力：

- load image + load fit json。
- drag vertices。
- save fit json。
- preview face overlay。

验收：

- 用户可以在 1-2 分钟内把 auto-fit overlay 调到满意。
- 保存的 `fit.json` 能直接喂给 21 matrix runner。

### Phase 4. Batch Runner

新增：

- `blender/scripts/texgen/run_single_3d_matrix.py`

能力：

- 输入 source image + optional fit json。
- 如果没有 fit json，先运行 auto fit。
- 生成 overlay。
- 生成 21 matrix。
- 可选进入 Blender bake matrix。

验收：

- 一个命令完成 `raw image -> fit diagnostics -> 21 matrix`。
- 输出目录结构稳定，适合写报告和人工对比。

## Acceptance Criteria

第一版工具成功标准：

- 对纯白背景 single 3D tile，能自动生成一个大致贴合的 `auto_fit.json`。
- 人工修正后，`fit.json` 能稳定驱动 21 matrix。
- 21 matrix 第一组能保留用户预期的原始黑边，不再因为数学模板偏差导致整组黑边丢失。
- cleaned 组只清理用户指定边，不误吞顶面草皮/石块细节。
- 文档和 report 能清楚说明：哪个结果来自 template sidecar，哪个来自 actual fit sidecar。

非目标：

- 不追求全自动零人工校准。
- 不推断不可见背面材质。
- 不在第一版修改 Godot `tile_pipeline_scene`。
- 不把 `_candidates` 入库为 production asset。

## Open Questions

- `fit.json` 的 edge 参数是否应每张图独立保存，还是后续抽象成 preset。
- manual UI 第一版用 plain HTML canvas，还是直接做 Godot tool scene。
- auto-fit 是否需要支持非纯白背景；当前建议先不支持。
- 21 matrix 的 7 种 source ownership 方案是否需要重新命名，避免和旧 dual-left 试验混淆。

## Current Next Step

建议下一步先实现 Phase 1 + Phase 2 的最小闭环：

1. 新增 `auto_fit_design.py`。
2. 用现有三张 low single 3D 测试图生成 `auto_fit.json` 和 overlay。
3. 修改 `single_design_21_matrix.py` 支持 `--fit-json`。
4. 对 `grass_e0` 跑一轮 fit-based 21 matrix。
5. 用户看 matrix 后决定是否进入 Phase 3 manual UI。
