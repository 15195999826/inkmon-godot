# 重设计 Brief — InkMon 三管线素材生产追踪页

> **怎么用这份文件**
> 1. 打开 **claude.ai/design**,把下面 `=== 粘贴区开始 ===` 到 `=== 粘贴区结束 ===` 之间的**全部内容**作为第一条 prompt 贴进去。
> 2. 可选但强烈建议:把 `三管线完整流程图.html` 这个文件、以及一张当前页面的截图一起附上,让它看到"现状长啥样"。
> 3. 在 claude.ai/design 里多轮迭代,直到布局/交互满意。
> 4. **带回来**:把它生成的代码**全选复制**发我,或导出项目文件告诉我路径,或者每个屏截图发我(代码最佳,我能看到精确间距/结构)。我会把设计**翻译成 vanilla HTML/CSS/JS** 落到真实页面,保留配色 + 接真实 `pipeline_artifacts.json`。

> ⚠️ **落地约束(claude.ai/design 可以不管,但你心里有数)**:最终目标是**单文件、无构建的 vanilla HTML**,用 `python -m http.server` 打开。claude.ai/design 产出的 React/Tailwind 只用来定**设计**,我会换回 vanilla 实现 —— 视觉和 UX 照搬,技术栈换回去。

---

```
=== 粘贴区开始 ===

帮我重新设计一个内部工具的 UI/UX。配色我已经很满意,请严格沿用我给的色板,只重做布局、信息架构和交互。这是一个数据密集的「审计看板」,桌面优先,不是营销页 —— 优先信息清晰度和操作效率,不要花哨动效。

## 这是什么工具

「InkMon 三管线素材生产追踪页」。我们用 AI(texture-gen)生成等距六边形地形砖块,然后过 3 条不同的生产管线(建模/烘焙路线)把它变成游戏里能用的资产。这个页面读取一份固定结构的 JSON(612 条 artifact 记录),把**每块砖在每条管线里、每个阶段的真实产物**串成一条**可审计的链路** —— 让人能查:这张图是哪次 AI call 生成的、prompt 是什么、call_id 多少、文件落在哪、哪一步缺了/不适用。

## 用户与核心任务(请围绕这 3 件事设计)

用户 = 开发者/技术美术,在做资产审计。三个核心任务:
1. **一眼看健康度**:612 条记录里,哪些 tile / 哪些阶段 / 哪条管线是 OK / missing / not_applicable?哪里有洞?现在这点完全看不出来,必须逐个点进去 —— 这是最大痛点。
2. **追一块砖的旅程**:选定「某 tile × 某管线 × 某 variant」,沿 8 个阶段走一遍,逐阶段看产物图 + 它的出处(prompt、call_id、quality/size、duration、文件路径)。
3. **比对结果**:跨管线/跨 variant 对比同一块砖的最终效果。

## 必须保留的配色(暖纸 + 墨色,这是已经好的部分)

CSS 变量,请原样沿用、不要换色相:
- `--bg: #efebe2`(暖米底)、`--surface: #fffdf8`(卡片)、`--surface-2: #f7f2e8`
- `--ink: #211d18`(主文字)、`--muted: #70675b`(次要文字)、`--line: #d8cfc0`(描边)
- `--accent: #9b4f2f`(赤陶/主强调)、`--accent-2: #2f6f7a`(青/次强调)
- 状态色:`--ok: #286b3a`(绿)、`--warn: #a65628`(橙)、`--miss: #a53333`(红)
- 左侧深色栏:背景 `#2a241e`,文字 `#f5efe4`
整体是「painterly tactical RPG / 暖纸墨线」气质,沿用即可。字体保持系统无衬线(Segoe UI / 微软雅黑)。

## 数据模型(请照这个真实结构设计,别臆造字段)

**tiles(16 个)**:
- 12 个地形砖 `kind:"tile"`:grass / dirt / stone / water,各 3 档 e0/e1/e2(如 `grass_e0`)
- 4 个装饰物 `kind:"decor"`:`decor_pine` / `decor_pine_tall` / `decor_bush` / `decor_rocks`

**pipelines(3 条)**,每条有若干 variant 和有序 stage:
- `hard` 管线A:硬边 — variants:`current`(默认)/`ink`;stages:8 个(见下)
- `bevel` 管线B:顶面倒角 — variants:`regular` / `wide_rim`(默认) / `ink`;stages:8 个
- `patch` 管线C:面片 — variants:`fit`(默认);stages:7 个(**没有 uv 阶段**)

**stages(阶段,有顺序,是这个工具的主轴)**:
`ai_call`(AI 调用) → `raw`(AI 原图) → `fit`(几何套版叠加) → `uv`(UV,仅 hard/bevel) → `mesh`(模型预览) → `baked`(烘焙成品 PNG) → `manifest`(清单) → `godot_scene`(Godot 场景截图)

**artifact(612 条,主体数据)**,每条字段:
- `pipeline` / `variant` / `tile_id` / `stage`:四元组定位
- `kind`:`image`(单图) | `image_set`(多图,如多个 baked 变体) | `metadata`(如 ai_call,无图,纯数据) | `note`
- `status`:`ok` | `missing` | `not_applicable`
- `title` / `notes`:人读标题与说明
- `path`:产物文件路径;`source_script` / `source_report`:出处
- `data`:富数据。**对 ai_call 阶段尤其重要**,含 `call_id` / `quality` / `size` / `duration_ms` / `status` / 以及**很长的 prompt 文本**(几百字)和 `inputs`(底图/参考图列表)

**还有**:`overview`(5 张总览对比大图:final_compare / raw_contact / standard_uv_contact / beveled_uv_contact / patch_contact)、`warnings`(6 条,如某 tile 的 call.json 缺失或 hash 不匹配)、`generated_at` / `schema_version`。

## 当前 UX 痛点(明确要解决的)

1. **总览页是一条长竖滚**:5 张大图 + 3 张表硬堆,没有"健康度概览",看不出哪里缺。
2. **阶段时间线只是一排会换行的按钮**,没有"流程/流向"感,不像管线。
3. **artifact 详情直接 dump 原始 JSON**(`<pre>` 一坨),最有价值的 **prompt 文本埋在 JSON 里**,人读极差。
4. **16 个 tile 用一个纯文字下拉**,没分组(grass/dirt/stone/water 家族)、没缩略图。
5. **612 条记录无搜索/筛选**(比如"只看所有 missing 的")。
6. 每次点击整页重渲染,丢失滚动位置。

## 请设计这些屏 / 关键改进

**A. 总览仪表盘(Overview)** —— 从"长滚动"改成"一眼看懂":
- 顶部一行 KPI:总 artifact 数、warning 数、OK/missing/N·A 占比。
- **核心新增:覆盖矩阵(coverage matrix)** —— 行=tile(按家族分组),列=stage,单元格用状态色块(绿/红/橙/灰)。一眼看出所有洞。可按 pipeline×variant 切换这个矩阵看的是哪一层。点单元格直接跳到对应详情。
- 5 张总览对比图做成整洁画廊(缩略图 + 点击放大 lightbox),不要 5 张大图竖排。
- warning 列表醒目呈现(红色,带 tile/stage 定位,可点击跳转)。
- texture-gen 台账表 / variant 矩阵表保留,但要可排序/可筛选、扫读友好。

**B. 管线追踪页(每条 pipeline)**:
- 顶部:tile 选择器(**按家族分组,带缩略图最好**)+ variant 选择器。
- **阶段流程条**:把 8(或 7)个 stage 画成**水平 stepper / 流程**,有连接线和流向,每个节点带状态点(绿/红/橙/灰);当前阶段高亮;**绝不丑陋换行**(窄屏可横向滚动或紧凑化)。
- 主区:左大图查看器(支持放大/lightbox;image_set 多图网格;raw↔baked 可并排对比),右侧 **人读详情卡**:
  - 把 `data` 里关键字段做成带标签的行(call_id / status / quality·size / duration),**不要直接甩 JSON**。
  - **prompt 单独成块**:可读排版、可折叠、可一键复制(这是审计核心证据)。
  - 文件路径做成可复制的 chip / 链接。
  - 底部留一个"查看原始 JSON"折叠区做兜底。

**C. 全局**:
- 顶部全局搜索/筛选:按 tile、status(尤其"只看 missing/异常")、stage 过滤。
- 状态用一致的色语义(绿 ok / 红 missing / 橙 not_applicable),并配图标或形状,别只靠颜色。
- 深链接:tab + tile + variant + stage 进 URL,可分享、刷新不丢;点击不丢滚动位置。
- 桌面优先、高信息密度(这是审计工具不是落地页),但要有干净的响应式收拢。

## 输出要求
给我一套完整、可点击的高保真设计:总览仪表盘(含覆盖矩阵)、一条管线的追踪页(含阶段流程条 + 人读详情卡 + prompt 块)、tile 选择器、搜索/筛选态、空/缺失态。多用真实感的占位数据(就用上面的 tile 名、stage 名、status)。严格沿用我给的暖纸墨色板。

=== 粘贴区结束 ===
```
