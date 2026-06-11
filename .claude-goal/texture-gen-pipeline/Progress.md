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

Consistency review: no divergence —— Phase 0 五项 Deliverables 全交付（对话内信号①-④齐 + 阶段 commit）；
Non-goals 未侵入（`git diff 652d897..HEAD -- inkmon scripts addons` 零改动；未写 lab 代码；
零 gpt-image-2 调用；水地形未碰）；CONTEXT.md 领域语言贯穿 README/注释（设计稿/UV 贴图/入库/
车间/_candidates 缓冲不构成第三真相）；adr/0009 角度冻结 = warp 合法性前提，往返恒等已实拍验证；
adr/0010 决定 2（tile 几何逻辑住 godot 仓）/决定 3（provenance 字段、_candidates 永不 commit）落地。

## 待办（后续 phase，gate = lab MCP generate+export 可用）

- Phase 1 = Round 1：草 e0 三方案 bake-off → 用户定主力 → 首次入库
- Phase 2 = Round 2：顶面网格填充流原型 + 图片装饰首例（灌木级）
