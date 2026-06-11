# 生图管线 — 提示词定稿 + 首批资产 showcase 场景（用户称 Round 2.5）

> 位置：Round 1/2（主力方案已定、三流全链路已通，见 `.claude-goal/texture-gen-pipeline/`）与
> Round 3 放量之间。设计真相不变：根 `CONTEXT.md` + `docs/adr/0009` + `docs/adr/0010`。

## Objective

AI 自行把主力方案的提示词迭代到"自评 OK"水平并**定稿成文档**，用该提示词生成一小批资产、
拼出全新 showcase 场景供用户验收——为用户在 lab 沉淀 session 配方提供**实证过的提示词原料**。
（后续：用户 lab 沉淀 session → 填 `gen_config.json` 映射 → 另开 Round 3 放量 goal。）

## Deliverables

- **`Prompts.md`（本目录）**：每类资产（地形×海拔 / 顶面变体 / 图片装饰）的定稿提示词全文 +
  所用参考图 + 代表性 lab image id + 调试轮数与放弃路径注记——用户沉淀 session 的直接原料
- **一小批生成资产**（规模自裁，明确小于 Round 3）：建议 草/土/石 e0 全覆盖 + 草 e1/e2 +
  草顶面变体 ≥2（网格填充流）+ 图片装饰 ≥1（灌木级）
- **showcase 新场景实拍**：tile_pipeline 场景整图 + 近景截图（如需 showcase 地图/场景小改，
  限 `inkmon/tools/tile_pipeline/`）
- **用户验收后批准品入库**：designs/ + textures/ + provenance JSON；未获批准的只留
  `_candidates/`（gitignored），不入库

## Non-Goals

- Round 3 放量（3 地形 × 3 海拔 × 变体池铺满）；session 沉淀（用户在 lab UI 做）
- 水地形、过渡地形
- 不碰 `inkmon/logic|presentation|host`、`scripts/`、`addons/`；不写 lab 仓代码
- 不追求提示词理论最优——收敛标准 = QC 稳过 + AI 气质五项自评达标 + 用户看场景点头

## Validation

- 每张生成图 `texgen/qc.py` 数值打印；几何问题一律 QC 数值裁决（截图自评漏几何是既有案底），
  气质（体块/配色/元素/质感/光）才走截图自评
- showcase 截图路径出现在 transcript 且 godot.log 无 SCRIPT ERROR
- 入库文件清单 + provenance 字段齐（prompt/方案/参考图/lab session+image id）

## Completion Gate

- `Prompts.md` 定稿且字段齐全
- showcase 实拍截图在 transcript 出现，**用户明确表态验收**（不得代决）
- 批准品入库 commit；每 phase 有 Progress.md checkpoint（commit + codex review）
- Final Consistency Review 写入 Progress.md：`Consistency review: <no divergence|N items resolved>`
