# texture-gen-pipeline — Progress

goal-start-ref: 652d897

## Phase 0 — 基建 ✅（2026-06-11，commit 8e1e297）

- ① 线稿模板：`blender/scripts/texgen/make_templates.py` 产出四版本 ×（SVG + PNG 底图 + sidecar JSON），
  e0/e1/e2 × design/uv/dual + grid 共 30 文件 → `blender/templates/`（gitignore，确定性可重生成）；
  角度/px_per_hex_edge/hex_orientation/厚度/海拔步长全部读 baked `manifest.json`，无第二份常量
- ② warp/mask/QC：`warp.py`（design 逐面仿射 + cut 网格裁切）+ `qc.py`（边缘偏差/覆盖率/轮廓 IoU，
  阈值读 gen_config，判废 exit 1）对 `make_placeholder.py` 手工占位图三件全 PASS：
  design QC mean 0.11px / coverage 1.000 / IoU 1.000；warped UV mean 0.50px / coverage 0.997；
  grid mean 0.12px / coverage 1.000。top 面 stretch 比 1.732 = 1/sin(35.26°)，与 Goal 风险注记
  "纵向拉伸 ~1.73x" 精确吻合；wall_5 掠射角 stretch 3.2（Round 1 分辨率档位风险的实底）
- ③ 占位图全链路：占位设计稿 → warp → `--candidate-tile` 烘焙（覆盖 tile_grass_e0_v0）+
  `--candidate-decor` 烘焙（占位 sprite → alpha 面片，锚点自动算落 (256.0, 255)，亚像素吻合）→
  `godot --import` → tile_pipeline DevAgent 截图
  `dev-agent/sessions/texgen-phase0/screenshots/01-phase0-fullchain.png`，棋盘格/条纹往返恒等
  肉眼可证，godot.log 零 SCRIPT ERROR；验证后 baked PNG 已 git checkout 还原 + 重 import
- ④ 目录与约定：`blender/designs/`（README）、`blender/textures/`（README + gen_config.json
  骨架 + provenance.template.json：prompt/方案/参考图/lab session+image id）、
  `blender/textures/_candidates/` + `blender/templates/` + `__pycache__/` gitignore 条目
- ⑤ bake_assets.py：tile image texture 材质（textures/ 命名自动发现，变体数 max 取齐）、
  hex mesh UV 按 texgen.uv_layout 赋值（与模板/warp 同函数零 drift；背面三壁映对侧、底面收拢）、
  图片装饰 alpha 面片（⟂ 冻结相机、shadow catcher 接地影、Freestyle 对面片关闭）、
  候选试评 CLI；Blender 5.1.2（Steam 版 `E:/SteamLibrary/steamapps/common/Blender/blender.exe`）跑通

实现选择注记（非 divergence）：
- 模板除 SVG 外同步出 PNG 底图（gpt-image-2 要 raster）与 sidecar JSON（warp/QC 的运行时契约），
  超出 Goal 字面但服务 Phase 1
- `blender/templates/` 走 gitignore：与 renders/ 同理，脚本确定性产物不入库
- UV 展开布局常量（画布 1024 / 纹素密度 256px/u / 网格画布 1536）定义在 texgen/geometry.py 单处，
  网格与 UV 同纹素密度 → 种子顶面零缩放贴入

外部 review（codex，gpt-5.5，base 652d897）修复 2 条：
- P2 `_textures_dir()` 原用 `//textures`（blend 相对路径）——不带 test.blend 跑 CLI 时 discovery
  静默扑空回退程序化材质；改为按脚本目录定位，已验证外部 cwd + 无 blend 模式下解析正确
- P3 geometry `_faces_world`/`design_layout`/`wall_corners_lr` 补吃 manifest `hex_edge_world`
  （原 hardcode 单位 edge；edge=1.0 时无实际影响，但违反单一真相承诺）；QC 三件回归全 PASS

Consistency review: no divergence —— Phase 0 五项 Deliverables 全交付（对话内信号①-④齐 + 阶段 commit）；
Non-goals 未侵入（`git diff 652d897..HEAD -- inkmon scripts addons` 零改动；未写 lab 代码；
零 gpt-image-2 调用；水地形未碰）；CONTEXT.md 领域语言贯穿 README/注释（设计稿/UV 贴图/入库/
车间/_candidates 缓冲不构成第三真相）；adr/0009 角度冻结 = warp 合法性前提，往返恒等已实拍验证；
adr/0010 决定 2（tile 几何逻辑住 godot 仓）/决定 3（provenance 字段、_candidates 永不 commit）落地。

## Phase 1 = Round 1 — 三方案 bake-off（进行中）

goal-start-ref（Round 1+2 段）: 81d7c37；前置自检 ✅（texture-gen MCP history 可用 / Blender MCP
连着 test.blend / Blender CLI 5.1.2 存在 / HEAD=81d7c37 工作树干净）

阶段决策：交付物 = 图像资产 + 确定性几何工具，无运行时逻辑——不写单测/不 TDD；质量卡口走
qc.py 数值断言（判废重摇）+ Godot 实拍（与 Phase 0 同节奏）。新增 warp.py `dual` 提取
（双联右 panel → 标准 UV 画布；仿射从 sidecar uv_top↔uv 模板三点解出，不复制 dual_layout 公式）
与 bake_assets.py `--subset`（入库重烘只烘目标资产，防全量 rebake 非确定性噪声弄脏 git），
先占位图往返断言验证再接真图。

① 三方案全链路（2026-06-11，全部 _candidates/round1/，gitignored）：
- 设计稿：裸模式 generate（底图 template_design_e0.png，n=2，lab session_mq99ou77_905tl）→
  cand1 QC PASS（edge mean 1.74px / cov 0.997 / IoU 0.973，img_mq99qbn1_6wj0b）；cand2 判废
  （mean 4.06 超限 + IoU 0.889）
- design_warp：cand1 → warp → QC PASS（mean 0.00px / cov 0.997 / IoU 0.997）
- design_uv_gpt：二次调用（底图 template_uv_e0.png + 参考图 cand1，session_mq99s3j9_v4az5）→
  cand1 判废（IoU 0.925）；cand2 QC PASS（mean 0.02px / IoU 0.992，img_mq99v5y4_4zjb7）
- dual_canvas：1536x1024（session_mq99wtz6_bdqg4 + 重摇 session_mq99zlnv_ajt4q 共 4 张）→
  3 张整体跑版判废（IoU 0.63-0.65）；cand2（img_mq99y43y_4xpcd）右 panel 收获面全 ≤2px/检出
  100%，仅左 panel 草沿翻边 max 11px 超限——**判定口径：dual 路线按提取后 UV 成品 QC**（与
  design_warp 的 warped QC 同口径；`--faces` 过滤的 IoU 因前景含左 panel 结构性失真，不可用）→
  warp.py dual 提取（upscale 1.524 与理论 1024/672 精确一致）→ QC PASS（mean 0.00 / IoU 0.997）
- 烘焙三件（Blender CLI --candidate-tile）→ 覆盖 tile_grass_e0_v0-v2 → --import → tile_pipeline
  实拍三图（基线已 git checkout 还原 + 重 import）：
  - dev-agent/sessions/texgen-round1-warp/screenshots/01-round1-design-warp.png
  - dev-agent/sessions/texgen-round1-uvgpt/screenshots/01-round1-uv-gpt.png
  - dev-agent/sessions/texgen-round1-dual/screenshots/01-round1-dual-canvas.png
  实拍 diff 验证三贴图均生效（差异带 = 草 e0 河岸区，2.2-2.8% 像素）；肉眼：warp 与 uvgpt 均
  锐利成立，dual 明显偏软糊（672px 放大 1.52x 的分辨率代价，Goal 风险注记应验）

② 用户拍板（2026-06-11 对话内）：**design_warp 定为风格定调流主力方案**（锐利度/忠实度最优 +
1 次调用；uvgpt 同级但 vibe 级漂移风险；dual 偏软糊出局）。

③ 批准稿首次入库：
- `blender/designs/design_grass_e0_design_warp_20260611.png` + `.provenance.json`
- `blender/textures/tile_grass_e0_v0.png` + `.provenance.json`（provenance 字段齐：prompt/方案/
  参考图/lab session+image id/QC 摘要/批准时刻）
- `--subset tile_grass_e0` 重烘（subset CLI 首次实测 ✅；v0 image texture / v1 v2 程序化），
  manifest 内容零变化（仅行尾重写）→ `--import` → 实拍
  dev-agent/sessions/texgen-round1-final/screenshots/01-round1-final-ingested.png（v0 新贴图与
  v1/v2 程序化混排，符合只批 v0 的入库事实）

## Round Log

- Round 1 - 草 e0 三方案 bake-off - 生图 8 张（设计稿 2 / uvgpt UV 2 / dual 4 含重摇）废 5 活 3 -
  主力=design_warp（用户拍板）- 入库 design×1 + UV×1 - 实拍：texgen-round1-{warp,uvgpt,dual,final}

## 待办（后续 phase）

- Phase 2 = Round 2：顶面网格填充流原型 + 图片装饰首例（灌木级）
