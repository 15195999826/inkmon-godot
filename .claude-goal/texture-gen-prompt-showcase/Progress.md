# Progress

## Current State

- Status: active（2026-06-11 启动）
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

## Checkpoints

- （<date> - <phase> - commit <sha> - codex: <pass|N fixed> - 格式）

## Open Review Findings

- None

## Consistency Review

- （收尾填）

## Blockers

- None
