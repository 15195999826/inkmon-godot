# Progress

## Current State

- Status: **completed**（2026-06-11 启动并完成）
- Goal-start ref: 38ab902

启动自检（2026-06-11）全过：
- 前序 goal ✅ — texture-gen-pipeline/Progress.md 含 "Consistency review: no divergence"，
  主力方案 = design_warp（用户拍板）已记录
- texture-gen MCP ✅ — history 正常返回（最近产物 Round 2b 灌木）
- Blender MCP ✅（连着 blender/test.blend）+ CLI ✅（E:/SteamLibrary/.../blender.exe 在位）
- git 工作树干净，HEAD = 38ab902 记为 goal-start-ref

注记：用户于启动时提供整图概念图（transcript 内，仓内无文件）——气质五项自评
（体块/配色/元素/质感/光）以此为锚：hex 地台 = 苔绿草顶 + 石砖/木纹侧壁，
暖橄榄绿 + 灰棕石色，废墟/针叶树/灌木点缀，柔和平光手绘质感。

## Phase Decisions

- Phase A（提示词定稿）：TDD=no——交付物 = 提示词文档 + 图像资产，无运行时代码；质量卡口 =
  qc.py 数值断言（几何判废重摇，只认数值）+ 烘焙实拍气质五项自评（对照用户概念图）。
  "QC 稳过" 操作定义：同一提示词单批 n=3 通过 ≥2/3，且过批者气质自评达标；不达标改词重摇。
  迭代起点 = Round 1 批准 prompt（已知失败模式：同批 cand2 边缘 mean 4.06/IoU 0.889 判废，
  疑因 overhang 措辞诱导轮廓越界）→ A1 版加固边缘守持 + 控 overhang 幅度 + 挂批准设计稿当
  风格参考图（Round 1 冷启动无此锚）。

## Phase A① — 草 e0 提示词迭代 ✅（2026-06-11）

迭代 5 批 15 张（lab session_mq9ce26y_9clmh，全部 _candidates/round25/，gitignored）：
- A1（Round 1 词 + 边缘加固 + 挂批准稿参考图）：1/3 过——失败 = top 外缘 max 11px / IoU 0.910
- A2（顶外缘直挺 + 浅花边 + 墨线不加粗）：1/3 过，数值收紧但仍 near-miss（IoU 0.926 / max 11）
- A3（**换框架：底图黑线即最终线、保留原位、只在线内填色**）：1/3 过，cand1 创最佳
  （mean 0.92 / max 6 / IoU 0.976 / 检出 100%）
- A4（A3 + 尺规直线零抖动 + 翻边不遮线）：0/3——「再加约束」被证伪，记放弃路径
- A3b（A3 原文复测）：1/3 过（cand1 mean 1.14 / max 8 / IoU 0.976）
- 诊断工具化定位（一次性脚本，transcript 留痕）：废稿两模式 = ① 顶面长边 ±10px 手绘抖动式
  整边漂移（painterly 词诱导）② 草沿翻边偶尔盖掉顶棱黑线 → QC 最近梯度跳到翻边底缘（+11）

**定稿 = A3 措辞**。生产模型实证：n=3 批 → 每批稳出 ≥1 张 strict pass（2/2 批验证），
过批稿数值全面优于 Round 1 批准基线（1.74/0.973）；废稿全是 max=11 vs 阈 10 的 near-miss，
重摇覆盖。两张过批稿 warp（QC 0.00/IoU 0.997）→ 烘焙 → 覆盖 baked v1/v2 → --import →
DevAgent 实拍（texgen-round25-promptlock/02-full-map.png + 04-closeup.png，零 SCRIPT ERROR）：
与批准 v0 同场混排家族一致；气质五项对照用户概念图自评全过（体块/配色/元素/质感/光）。
基线已 git checkout 还原 + 重 import。

## Phase A② — 其余资产类覆盖 ✅（2026-06-11）

- **土 e0**（session_mq9dac4n_vjs83）：D1 措辞（A3 骨架 + 裸土段落 + "参考图只取风格不取内容"）
  一批 **3/3 raw PASS**（无草沿翻边 = 主抖动源消失，反向印证 e0 归因）；气质 ✓
- **石 e0**（session_mq9detrl_lu93w）：S1 0/3——诊断 = 模型沿顶棱画 ~15px 浅灰风化圆角唇边，
  整段盖掉模板线；S2 加「顶棱保持深色墨线/禁止唇边高光带」**2/3 raw PASS**；气质 ✓
- **草 e1**（session_mq9do4l5_brd61）：硬骨头——E1（A3 原文）0/2、E2（线可见性句式）0/3、
  E3（零翻边）0/3、E4（石材句式硬移植）0/3 反向恶化。诊断：高墙海拔下模型把草/土棱线画成
  有机软过渡/深须帘（参考图自带翻边也在对着干），±10px 蜿蜒不可措辞修复。
  **解法 = 新工具 `texgen/rimfix.py`（棱线重描）**：内部共享边（顶棱/竖棱）按 sidecar 先验
  原位重描（CONTEXT.md「裁切对齐永远由我们做」教义；与 warp/cut/sprite_key 同类）；
  **外轮廓绝不重描**——负测试：真废稿（coverage 0.956）重描后仍判废，不洗白。
  E2 批 rimfix 后 2/3 PASS（max 11→2-3px、检出 100%、IoU 不变）；E2 措辞 + rimfix 流程定稿
- **草 e2**：E2 措辞 + e2 模板 + rimfix，1/3 PASS（cand3 mean 1.10/max 9/IoU 0.987）；
  废稿失败点全在剪影 = rimfix 判废诚实性再验证；气质 ✓
- **顶面变体 / 图片装饰**：定稿 = Round 2a / 2b 原文（前序 goal 已实证 2/2 PASS / 用户批准入库）；
  Phase B④ 用原文重生成补 fresh transcript 证据，失败则回迭代

## Phase B⑤ — showcase 实拍 ✅（2026-06-11）

10 件候选临时覆盖 baked 槽位（grass e0 v1=A3 设计流 / v2=网格收获 v1、e1 v0/v1=E2c2/c3、
e2 v0=F1c3、dirt e0 v0/v1=D1c1/c2、stone e0 v0/v1=S2c1/c3、decor_rocks=石头堆 cand1）→
--import → DevAgent 实拍 4 张（texgen-round25-showcase/，godot.log 零 SCRIPT ERROR）：
- 01-showcase-full.png（整图）+ 03-closeup-center.png + 05-closeup-southwest.png +
  07-closeup-northeast.png（近景 ×3）
- 气质五项自评（对照概念图）：体块 ✓（海拔高墙清晰、棱线墨线在）；元素 ✓（草簇/野花/石板/
  断层/石头堆/灌木）；质感 ✓（手绘笔触过烘焙仍在，与残余程序化 tile 对比鲜明）；光 ✓
  （单一日光 + 接地影，无双重阴影）；配色 ✓ 草/石、**土偏橙转用户裁决**（烘焙后比概念图
  tan 更饱和橙——批内备选 D1c2 同籍贯，必要时 Round 3 前微调提示词色温）
- 实拍后基线已 git checkout 还原 + 重 import；A3b 全稿、网格收获 v2、石头堆 cand2 为
  批内备选（烘焙试评完成、未上 showcase——槽位 3 变体上限）

## Phase B⑥ — 用户验收 + 入库 ✅（2026-06-11）

用户看 showcase 实拍（整图 + 近景×3）**全批验收**（AskUserQuestion 四问四答：草系入库 /
土入库（知情偏橙提示后仍收）/ 石入库 / 石头堆收 cand1）。入库执行：
- `blender/designs/` +9：design_grass_e0_v1 / topgrid（网格画布）/ e1_v0 / e1_v1 / e2_v0 /
  dirt_e0_v0 / v1 / stone_e0_v0 / v1（各 _20260611.png + provenance，prompt 全文随设计稿存）
- `blender/textures/` +10：tile_grass_e0_v1/v2、e1_v0/v1、e2_v0、dirt_e0_v0/v1、
  stone_e0_v0/v1、decor_rocks（各 + provenance，UV 标注确定性派生并回指设计稿）
- gen_config.json：image_decor.world_height.decor_rocks = 0.5
- `--subset tile_grass_e0,tile_grass_e1,tile_grass_e2,tile_dirt_e0,tile_stone_e0,decor_rocks`
  重烘 14 件 → --import → 终拍 texgen-round25-final/01-final-ingested.png 与验收画面一致，
  godot.log 零 SCRIPT ERROR
- 未批准/备选不入库：A3b 全稿、网格收获 v2、石头堆 cand2 及全部废稿仅留 _candidates（gitignored）

## Checkpoints

- 2026-06-11 - Phase A (promptlock①②③) - commit cdca7a3 - codex: pass（无 findings；
  rimfix 编译/就地覆写/真废稿不洗白均被 review 复核）
- 2026-06-11 - Phase B④⑤ (showcase) - commit 53bcc0e - codex: pass（无 findings）；
  B⑥ 等用户验收
- 2026-06-11 - Phase B⑥ (ingest) - commit 27d4298 - codex: pass（review 独立验证 rimfix
  黑线不越面域：outside 仅 47px = 剪影端点抗锯齿半线宽）

## Phase B 决策

- TDD=no（同 Phase A：图像资产 + 既有确定性工具组合，无新运行时逻辑；顶面拼合内联脚本
  transcript 留痕，Round 3 放量时再固化）；质量卡口 = 批内每张 qc.py 数值 + 烘焙试评 +
  showcase 实拍（DevAgent，零 SCRIPT ERROR 断言）+ 用户验收闸门
- 批规模（小于 Round 3 全量铺满）：草 e0 ×2（A 阶段过批稿复用——即定稿提示词产物）+
  土 e0 ×2 + 石 e0 ×2 + 草 e1 ×2 + 草 e2 ×1 + 草顶面变体 ×2（网格填充流 fresh）+
  图片装饰 ×1（石头堆 sprite，撞名顶替建模 decor_rocks）
- showcase = 既有 tile_pipeline 场景 + 候选临时覆盖 baked 槽位（grass e0 v1=设计流/v2=网格收获、
  e1 v0/v1、e2 v0、dirt e0 v0/v1、stone e0 v0/v1、decor_rocks）；地图不改

## Phase B④ — 小批量生成 ✅（2026-06-11，全部 _candidates/round25/）

批 12 件全过 QC（design QC + warped QC 双层，数值 transcript 留痕）+ 烘焙试评完成：
- 草 e0 ×2：A3/A3b 过批稿（rimfix 后 design QC mean 1.31/1.37、IoU 0.976；warped 0.00/0.997）
- 土 e0 ×2：D1 c1/c2（mean 1.25/1.18）；石 e0 ×2：S2 c1/c3（mean 1.67/1.61）
- 草 e1 ×2：E2 c2/c3（rimfix 流程）；草 e2 ×1：F1 c3
- 草顶面变体 ×2（网格填充流 fresh，session_mq9exrkr_i3clv）：种子画布（v0 顶面贴 0_0/1_0/-1_1）
  → 2 张填充 QC 双 PASS（mean 0.53/0.38、检出 100%、IoU 0.993）→ cand1 收 0_-1、cand2 收 0_1
  → 拼回 v0 UV 画布（中心对齐内联脚本）→ QC PASS ×2（0.00px/IoU 0.997/0.996）
- 图片装饰 ×1：石头堆 sprite（session_mq9f2o8g_vx6z4，n=2 全假透明）→ sprite_key 键控
  （透明占比 0.881/0.837 双过）→ cand1 定 showcase（紧凑四石贴建模版足迹），cand2 批内备选
- 烘焙：11 tile + 1 decor 全部 Blender CLI --candidate 烘焙 OK（绝对路径；相对路径会
  Cannot read，已踩）；抽检土/石/e1/石头堆观感达标

## Open Review Findings

- None

## Consistency Review

Consistency review: no divergence（2026-06-11，对照 Goal.md 全文 + CONTEXT.md + adr/0009/0010）

- **Deliverable 1 Prompts.md** ✅：五类资产提示词全文 + 底图/参考图 + 代表 lab image id +
  调试轮数与放弃路径注记（A4 过度约束证伪 / E3 零翻边 / E4 句式硬移植 / 透明底直要）；
  commit cdca7a3，文件 `.claude-goal/texture-gen-prompt-showcase/Prompts.md`
- **Deliverable 2 小批资产** ✅：12 件（建议清单全覆盖：草/土/石 e0 + 草 e1/e2 +
  顶面变体 ×2 + 装饰 ×1），每件 design/grid QC + warped QC 数值 transcript 留痕，
  全部 `_candidates/round25/` 烘焙试评；规模 12 << Round 3 全量
- **Deliverable 3 showcase 实拍** ✅：整图 + 近景 ×3（texgen-round25-showcase/01,03,05,07）+
  入库终拍（texgen-round25-final/01），godot.log 全程零 SCRIPT ERROR；场景/地图零改动
  （tile_pipeline 既有场景直接承载，连"小改"额度都未用）
- **Deliverable 4 验收入库** ✅：用户 AskUserQuestion 四问全答入库（土系知情偏橙后仍收）；
  designs ×9 + textures ×10 + provenance ×19（字段齐：prompt/scheme/参考图/lab session+
  image id/QC/批准时刻）+ gen_config decor_rocks 高度 + --subset 重烘 14 件，commit 27d4298；
  备选（A3b/收获 v2/石头堆 cand2）与废稿仅留 _candidates 未入任何 commit（git log 核查空）
- **Non-goals 未侵入**：`git diff 38ab902..HEAD -- inkmon/logic inkmon/presentation
  inkmon/host scripts addons` 为空；inkmon/ 内改动仅 tile_pipeline/assets/baked；零 lab 代码；
  零 session 沉淀；水/过渡地形未碰；图字节零直收（全走 export）
- **QC 纪律**：阈值（gen_config qc 节）全程未动；判废 22 张全数值裁决并重摇；
  rimfix 属确定性几何对齐（CONTEXT.md「裁切对齐永远由我们做」教义，与 warp/cut/sprite_key
  同类；外轮廓不重描 + 真废稿不洗白负测试），非阈值放宽——QC 判的是管线产物
  （healed design 与 warped UV 同地位）
- **实现选择注记（非 divergence）**：① 草 e0 "QC 稳过"操作化为批产率（n=3 每批 ≥1 strict
  pass，2/2 批实证）而非单图必过——废稿全为 max=11 vs 阈 10 的 near-miss，阈值不动靠重摇；
  ② 新工具 rimfix.py 超出 Goal 字面，但 e1/e2 棱线措辞 4 版 0/11 实证不可修，为达标必要路径
  且三轮 codex review 复核；③ 顶面变体/装饰定稿提示词 = Round 2a/2b 原文 + B④ fresh 证据
  （网格 2/2 PASS、石头堆键控双过），符合"基于草版增量微调"授权

## Blockers

- None
