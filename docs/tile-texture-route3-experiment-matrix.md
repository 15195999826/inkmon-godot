# Route 3 Dual Canvas Texture Experiments

本文记录 tile 生图管线 Route 3 的后续试验矩阵。目标不是直接把 AI 生成的 3D view 当最终 sprite，
而是在 Blender 中尽最大努力还原 AI 3D view 的体块、材质、边缘和完成度，同时保留 Blender 统一光照、
阴影、墨线、角度契约和后续可调空间。

## Fixed Contract

- 只测 `grass e0`，先不扩到 e1/e2 或其他地形。
- 相机角度不改：继续遵守 `docs/adr/0009-camera-angle-frozen-art-contract.md`。
- `_candidates` 是候选缓冲，不入库、不 commit。
- 不直接使用 AI 3D view 作为最终 baked tile。
- AI 3D view 只作为 visual target / teacher。
- 右侧 UV/atlas 只提供 material source，不写最终阴影。
- 最终 baked PNG 必须来自 Blender mesh/material/lighting/Freestyle。
- 每轮临时覆盖 `tile_grass_e0_v0/v1/v2` 做 Godot scene 对比。
- 每次覆盖 baked PNG 后必须跑 `godot --headless --path . --import`。
- Godot 侧不改 `tile_pipeline_scene` 逻辑，除非单独批准。

## Adjustable Dimensions

### 1. AI Canvas Template

可调项：

- `dual_canvas_paper_net`: 左侧 3D view + 右侧 paper-net UV。
- `dual_canvas_paper_net_no_lines`: paper-net 只保留淡边界，不画 hinge / stitch / outer ink。
- `dual_canvas_atlas`: 左侧 3D view + 右侧 `top hex + continuous wall strip`。
- `material_atlas`: 左侧 3D view + 右侧纯材质块，例如 grass albedo / wall stone albedo / rim moss。

判断点：

- AI 是否会把 seam 当结构线画死。
- 右侧贴图能否在 Blender 中连续映射。
- 左侧 3D target 和右侧 material source 是否风格一致。

### 2. AI Output Representation

可调项：

- `paper-net UV`: 最接近现有几何，但 wall panel seam 风险最高。
- `continuous wall strip`: 墙面一整条连续材质，优先用于解决墙面断裂。
- `per-face atlas`: 顶面、左墙、前墙、右墙分开，但必须禁止边线和阴影。
- `material-only atlas`: AI 只画材质，结构线由 Blender 程序化生成。

判断点：

- 顶面和侧壁是否自然衔接。
- 墙面是否出现 panel break / double line / dirty seam。
- 材质是否能支持 Blender 重新打光。

### 3. Prompt Contract

右侧 UV/atlas 固定禁用：

- `no cast shadow`
- `no drop shadow`
- `no baked lighting`
- `no hard seam line`
- `no panel border`
- `no black outline on UV or atlas`

右侧 UV/atlas 固定强调：

- `albedo only`
- `flat material texture only`
- `continuous material across wall strip`
- `Blender will add final lighting, shadow, bevel and ink edges`

左侧 3D target 固定强调：

- high quality hand-painted isometric hex tile
- dark olive grass
- rich stone wall detail
- clear but clean ink line
- heavy chunky volume
- no low-poly toy look

生成质量：

- 探索阶段用 `quality: low`。
- 锁定方向后再用 `medium` 或 `high` 做最终候选。

### 4. UV / Atlas Postprocess

可调项：

- 清理 top-wall hinge line。
- 清理 wall-wall stitch seam。
- 淡化或移除 outer outline。
- wall strip 横向 bleed / wrap padding。
- material source 色彩归一化。
- shadow/highlight removal。

判断点：

- postprocess 后是否仍能被 Blender 正确采样。
- seam 是否来自贴图本身，还是来自 Blender mesh/Freestyle。
- clean 只作为 bake 输入；几何 QC 仍针对原始 extracted UV。

### 5. Blender Mesh

可调项：

- `bevel_width`
- `bevel_segments`
- wall corner sharp/smooth 策略。
- top grass lip / rim mesh。
- wall brick relief 是否由 mesh/procedural 生成。
- wall-wall stitch edge 是否保留几何边，但不吃 Freestyle。

判断点：

- 体块是否厚重。
- 边缘是否锐利但不脏。
- wall-wall 转角是否像自然立体边，而不是贴图裂缝。

### 6. Blender UV Mapping

可调项：

- 每个 wall face 继续用 paper-net panel。
- 3 个可见 wall face 共享 continuous wall strip。
- wall 使用 object/world coords 采样，减少 face seam。
- seam 处 overlap / bleed。
- 顶面 hex mask 与墙面 strip mask 分离。

判断点：

- 墙砖是否连续。
- 侧壁是否避免明显 panel break。
- 顶面草边和墙体是否有自然过渡。

### 7. Blender Shader / Material

可调项：

- Image texture 直贴。
- Image texture + procedural noise detail。
- AI 只给 base albedo，草叶/草边/墙砖裂缝由 shader 加。
- 墙砖 masonry 由 procedural shader 生成。
- 顶面和侧壁使用不同 color grading。

判断点：

- 是否接近参考图的手绘完成度。
- 是否避免 AI 贴图把结构线画死。
- 同一材质在多 tile 拼场景中是否重复感过强。

### 8. Freestyle / Ink Edge

可调项：

- 全局 Freestyle。
- 排除 wall-wall stitch edge。
- 只画 silhouette + top outer edge。
- 分层控制 outer outline / top rim / internal crease。
- `ink_thickness_px`
- `ink_wobble_px`
- `ink_color`

判断点：

- 墨线清楚但不脏。
- stitch seam 不应被画成黑裂缝。
- silhouette 不应丢失体块感。

### 9. Lighting / Shadow

可调项：

- `sun_energy`
- `sun_elevation_deg`
- `sun_azimuth_deg`
- `sun_softness_deg`
- `ambient_strength`
- Freestyle on/off diagnostic。

判断点：

- 阴影统一来自 Blender。
- UV/atlas 不自带阴影。
- 不出现 AI baked shadow + Blender shadow 的双重阴影。

### 10. Godot Scene Evaluation

固定输出：

- single baked tile compare。
- full tile_pipeline scene。
- closeup scene。
- slot mapping。
- import log。

判断点：

- 单 tile 好看不够，必须看拼场景。
- 重点看相邻 tile 衔接、水道旁边、高低差旁边、装饰遮挡附近。

## Experiment Groups

每组实验允许多轮微调，但同一轮中不要同时改太多维度。每组至少输出 `v0/v1/v2` 三个 slot 对比。

### Group A: Paper-Net Salvage

目的：

- 判断现有 paper-net route 是否还能救。
- 验证 seam 问题是否主要来自模板线、贴图采样、Freestyle，还是 paper-net 表达本身。

变量：

- Template: `dual_canvas_paper_net_no_lines`
- Postprocess: clean hinge + clean stitch + optional outer outline fade
- Blender: `crisp_no_stitch_ink`

建议 slot：

- `v0`: current paper-net + current crisp settings
- `v1`: no template seam lines + seam clean + no stitch Freestyle
- `v2`: v1 + outer outline fade / bleed

成功标准：

- wall-wall seam 明显变轻。
- 顶面和侧壁不出现白边、透明洞、材质断裂。
- 如果仍有明显 panel break，则 paper-net route 降级为备选。

### Group B: Continuous Wall Strip

目的：

- 优先解决墙面 panel break。
- 让 AI 右侧生成连续墙面材质，而不是 3 块分离 wall panel。

变量：

- Template: `dual_canvas_atlas`
- Right panel: `top hex + continuous wall strip`
- Blender mapping: 3 个 visible walls 共享同一条 strip
- Freestyle: exclude wall stitch edge

建议 slot：

- `v0`: strip mapping + production_current edge
- `v1`: strip mapping + crisp edge + no stitch ink
- `v2`: strip mapping + heavy outer ink + no stitch ink

成功标准：

- 墙面横向连续，wall-wall seam 不再像黑裂缝。
- 视觉上比 Group A 更接近左侧 3D target。
- 顶面草边和墙砖自然衔接。

### Group C: Material Atlas + Blender Structure

目的：

- 减少 AI 画死结构线。
- 把砖墙、草边、墨线尽量交给 Blender procedural/mesh 控制。

变量：

- Template: `material_atlas`
- AI output: grass albedo / wall stone albedo / moss rim material
- Blender: procedural masonry side wall + shader grass detail

建议 slot：

- `v0`: AI grass + AI wall material, minimal procedural
- `v1`: AI grass + procedural masonry wall
- `v2`: AI material + procedural masonry + procedural grass rim

成功标准：

- 衔接比 paper-net 更自然。
- 墙砖细节丰富但不依赖贴图 seam。
- 风格仍接近左侧 3D target，而不是回到程序化玩具感。

### Group D: Mesh / Edge Calibration

目的：

- 固定一张较好的 atlas，只调 Blender mesh 和 Freestyle。
- 找到最接近参考图的体块和墨线参数。

变量：

- `bevel_width`
- `bevel_segments`
- wall corner edge mark
- Freestyle layer selection
- `ink_thickness_px`
- `ink_wobble_px`

建议 slot：

- `v0`: current production
- `v1`: crisp edge, low wobble
- `v2`: heavy outer ink, stitch edge excluded

成功标准：

- 边缘锐利，体块厚重。
- 墨线清楚但不脏。
- stitch seam 不抢眼。

### Group E: Lighting / Shadow Calibration

目的：

- 固定一张较好的 atlas 和 mesh，只调 Blender 光照。
- 确认阴影职责完全归 Blender。

变量：

- sun energy / softness / elevation / azimuth
- ambient strength
- Freestyle diagnostic on/off

建议 slot：

- `v0`: production lighting
- `v1`: softer shadow, higher ambient
- `v2`: lower sun, warmer ambient

成功标准：

- 没有双重阴影。
- 顶面和侧壁层次清楚。
- 拼场景中不显脏、不浮、不塑料。

### Group F: Target-Matching Prompt Pass

目的：

- 不改 Blender 结构，只迭代 prompt。
- 用左侧 3D target 的完成度约束右侧 material source。

变量：

- Prompt style language
- reference image weight
- `quality: low` vs later `medium/high`
- atlas side instructions

建议 slot：

- `v0`: baseline prompt
- `v1`: stronger hand-painted stone wall detail
- `v2`: stronger dark olive grass + cleaner ink

成功标准：

- 右侧 material source 更像左侧 3D target，但不把阴影/边线画入 atlas。
- 进入 Blender 后仍能保持材质质量。

## Recommended First Goal Scope

第一轮 goal 建议只做三组，避免变量爆炸：

1. Group A: Paper-Net Salvage
2. Group B: Continuous Wall Strip
3. Group D: Mesh / Edge Calibration

如果 Group B 明显胜出，再进入第二轮：

1. Group C: Material Atlas + Blender Structure
2. Group E: Lighting / Shadow Calibration
3. Group F: Target-Matching Prompt Pass

## Per-Experiment Output Contract

每个 experiment run 至少保存：

- `_candidates/<run>/raw/`
- `_candidates/<run>/refs/`
- `_candidates/<run>/atlas/` or `_candidates/<run>/uv/`
- `_candidates/<run>/processed/`
- `_candidates/<run>/baked/<group>/`
- `_candidates/<run>/shots/<group>/full.png`
- `_candidates/<run>/shots/<group>/closeup.png`
- `_candidates/<run>/shots/<group>/single_baked_tile_compare.png`
- `_candidates/<run>/logs/qc*.txt`
- `_candidates/<run>/logs/import*.log`
- `_candidates/<run>/logs/slot_mapping*.json`
- `_candidates/<run>/logs/prompt*.md`
- `_candidates/<run>/logs/preset*.json`

## Report Template

每组实验报告使用同一格式：

```md
## Group <X>: <name>

### Hypothesis

### Changed Dimensions

### Fixed Dimensions

### Inputs

- reference image:
- base template:
- raw generation:
- exported source:

### Processing

- QC:
- postprocess:
- bake presets:
- Godot import:

### Screenshots

- single baked compare:
- full scene:
- closeup:

### Result

- best slot:
- failed slots:
- seam assessment:
- style assessment:
- Blender controllability:

### Decision

- keep / iterate / reject

### Next Adjustment
```

## Current Working Notes

- Route 3 paper-net 已证明：清理 UV seam 可以减轻贴图黑线，但 wall-wall seam 仍会受 mesh crease、
  Freestyle 和材质 panel break 影响。
- `crisp_no_stitch_ink` 比单纯 `crisp_edge` 更适合处理 stitch seam，但仍不能保证 1:1 还原 AI 3D view。
- 下一步最值得试的是 `continuous wall strip`，因为它直接消除 wall panel 断裂来源，同时保留 Blender 渲染福利。
