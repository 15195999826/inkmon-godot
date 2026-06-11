# Goal: 生图资产管线 — godot 仓侧（几何工具链 + Round 1/2）

> **设计真相** = 根目录 `CONTEXT.md`（领域语言/两流辖区/卡口）+ `docs/adr/0009`（角度冻结）+
> `docs/adr/0010`（lab 宿主/车间入库两段制/MCP 契约）。本文是落地路线，不复述设计。
> 姊妹计划：inkmon-lab 仓 `docs/plan/current/texture-gen-mcp/BUILD-PLAN.md`（lab 侧四工具，并行开发）。

## 一句话目标

建成本仓侧"线稿模板 → gpt-image-2（经 lab MCP）→ 几何后处理 → Blender 烘焙 → Godot 实拍评估"
工具链，完成 Round 1（草 e0 三方案 bake-off 定主力）与 Round 2（网格填充流原型 + 图片装饰首例）。

## Deliverables（按 phase）

**Phase 0 — 基建（不依赖 lab，立即可做）**
- SVG 线稿模板生成脚本，四版本：3D 全貌 / UV 展开 / 双联 / 俯视网格；角度、px_per_hex_edge、
  hex_orientation 全部从 `assets/baked/manifest.json` 读，不写第二份常量
- 几何工具：正交反投影 warp（顶面 + 可见侧壁逐面仿射）、mask 裁切、数据级 QC
  （模板边缘偏差 / alpha 覆盖率 / 轮廓匹配，超阈值判废）
- `bake_assets.py` 改造：tile 材质支持 image texture（读 `blender/textures/`）；
  新增图片装饰 alpha 面片资产类型（shadow catcher 接地影 + 锚点从 alpha bottom-center 自动算）
- 目录与约定落地：`blender/designs|textures/`、`blender/textures/_candidates/`（加 .gitignore）、
  provenance JSON 字段（prompt/方案/参考图/lab session+image id）、`gen_config.json` 骨架
- **占位图全链路验证**：手工占位图 → warp → 贴材质 → 烘焙 → `--import` → Godot 截图，
  证明几何链路数学，不花一张 gpt-image-2

**Phase 1 = Round 1 — 三方案 bake-off（gate：lab MCP `generate`+`export` 可用）**
- 草 e0 单资产 × `design_warp` / `design_uv_gpt` / `dual_canvas` 三路全走（裸模式 + 粗提示词即可）
- Godot 拼装实拍三图对比 → **用户定主力方案** → 批准品首次入库（走完整后置闸门流程）

**Phase 2 = Round 2 — 两条新流首例（依赖 Round 1 批准稿）**
- 顶面网格填充流原型：种子 = Round 1 批准稿顶面提取；验证两风险（邻格渗透 / 种子笔触拉伸自洽）
- 图片装饰首例（灌木级）：透明底 sprite → alpha 面片烘焙 → manifest → 拼装场景同框验证接地影一致

## Non-goals

- 水地形（挂起等动态方案）、过渡地形（网格填充流的未来载体，不在本 goal）
- Round 3 放量（草/土/石 × e0-e2 全资产 + 变体池）——主力方案与现役 session 就位后另开
- lab 侧任何代码（姊妹计划辖区）；session 提示词调参（用户在 lab UI 做）
- 不碰 `inkmon/logic|presentation|host`、`scripts/`、`addons/`

## 评估基线

概念图气质五项（体块/配色/元素/质感/光）+ 上轮 11 轮截图（`sessions/tile-pipeline/screenshots/`）；
截图自评不可信几何（memory 案底）——对齐类问题一律走数据级 QC 断言。

## 完成条件

Phase 2 交付 + 主力方案已定 + 一致性审查（对照 CONTEXT.md / adr/0009 / adr/0010 无越界、
Non-goals 未侵入、Round Log 留痕）。

## 风险注记（实验回答，不预裁决）

- gpt-image-2 模板边界漂移 → QC 兜底重摇；分辨率档位是否够（warp 纵向拉伸 ~1.73x）
- 设计稿自带光影/墨线 vs Blender 光照与 Freestyle 双重叠加 → Round 1 实拍裁决
- 烘焙组合数按 max(顶面变体, 侧壁变体) 取，不按乘积
