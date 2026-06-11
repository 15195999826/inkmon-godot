# 定稿提示词（Round 2.5 promptlock）

> 用途：用户在 lab 沉淀 session（配方）的直接原料。每节 = 一类资产的定稿提示词全文 +
> 参考图 + 代表性 lab image id + 调试轮数与放弃路径注记。
> 设计真相：根 `CONTEXT.md` + `docs/adr/0009`（角度冻结）+ `docs/adr/0010`（lab 宿主/两段制）。

## 通用配方（风格定调流 design_warp 主力）

- **底图**（image-to-image）：`blender/templates/template_design_e<N>.png`（海拔对应版本）
- **参考图**：`blender/designs/design_grass_e0_design_warp_20260611.png`（Round 1 批准稿 = 家族锚）
- **参数**：size `1024x1024`，单批 n=3（重摇缓冲）
- **后处理链**：export → `texgen/rimfix.py -e <N>`（内部棱线按模板原位重描，外轮廓不碰）→
  `texgen/qc.py`（判废重摇）→ `texgen/warp.py design -e <N>` → warped QC → 烘焙试评
- **实测产率**（strict QC pass / 张）：草 e0 ~1/3（raw）；土 e0 3/3；石 e0 2/3；
  草 e1 ~2/3（rimfix 后）；草 e2 ~1/3（rimfix 后）——按批重摇即可，勿为产率放宽阈值
- **骨架共性**：①「底图黑线即最终线，保留原位，只在线内填色」框架（替代"重画轮廓"措辞，
  消除整边重绘漂移）②「参考图 = 家族风格锚 + paint a natural variation, not a pixel copy」
  ③ flat ambient light / board-game hand-painted look 收尾

## 草 e0（定稿 = A3 措辞，调试 5 批 15 张）

```
Hand-painted stylized game art, hex terrain tile. The base image is a black line-art template on white: one large flat-top hexagon (the TOP face) with three quadrilateral side walls below it (visible cliff sides of the tile). The black template lines in the base image are FINAL and already in the correct position: keep every line exactly where it is and exactly as thick as it is — never move, redraw, re-position or thicken any line. Paint the color surfaces INSIDE the existing lines and let the original lines remain visible on top as the ink outlines. The white background outside the tile must stay pure white right up to the outer line — nothing may be painted past it. TOP face = lush hand-painted grass in bright warm olive-yellow-green, with small grass tufts, subtle darker green patches and a few tiny wildflowers; no grass tuft may touch or cross any black line. SIDE WALLS = warm brown earth and soil strata with a few embedded grey stones, slightly darker than the top. Where the grass meets the top rim of each wall, paint an almost-straight boundary with only a very shallow scalloped grass fringe (two or three pixels deep at most) hanging onto the wall. Match the reference image's palette and brushwork exactly (it is the approved tile of this family); paint a natural variation, not a pixel copy. Style: rich hand-painted texture, soft flat ambient light (no strong cast shadows, no specular highlights), board-game hand-painted look. Nothing else added.
```

- 底图 `template_design_e0.png`；参考图 = 批准稿（见通用配方）
- 代表 image id：`img_mq9ctyhp_uugdm`（A3 cand1，mean 0.92/max 6/IoU 0.976）、
  `img_mq9d2r1m_zk9pd`（A3b 复测 cand1，mean 1.14/max 8/IoU 0.976）；session `session_mq9ce26y_9clmh`
- 调试注记：A1（Round 1 词 + 边缘加固）1/3 → A2（顶缘直挺/浅花边/墨线不加粗）1/3 →
  **A3（"黑线即最终线"框架）定稿**，复测 A3b 再 1/3 且数值最佳。
  **放弃路径 A4**：A3 + "尺规直线零抖动 + 翻边不遮线" → 0/3 反向恶化——过度约束破坏
  image-to-image 稳定性，"再加约束更稳"被证伪

## 土 e0（定稿 = D1 措辞，一次到位 3/3）

```
Hand-painted stylized game art, hex terrain tile. The base image is a black line-art template on white: one large flat-top hexagon (the TOP face) with three quadrilateral side walls below it (visible cliff sides of the tile). The black template lines in the base image are FINAL and already in the correct position: keep every line exactly where it is and exactly as thick as it is — never move, redraw, re-position or thicken any line. Paint the color surfaces INSIDE the existing lines and let the original lines remain visible on top as the ink outlines. The white background outside the tile must stay pure white right up to the outer line — nothing may be painted past it. This is a DIRT tile (no grass anywhere): TOP face = bare dry earth in warm tan-brown, hand-painted, with subtle darker brown patches, a few scattered small pebbles and faint hairline cracks; nothing may touch or cross any black line. SIDE WALLS = the same earth slightly darker, as horizontal soil strata with a few embedded grey stones. The reference image is another tile of this family (a grass tile): match its palette warmth, brushwork, ink-outline feel and lighting exactly, but paint NO grass on this tile — it defines the style only, not the content. Style: rich hand-painted texture, soft flat ambient light (no strong cast shadows, no specular highlights), board-game hand-painted look. Nothing else added.
```

- 底图 `template_design_e0.png`；参考图 = 草批准稿（跨地形当家族风格锚，显式声明"只取风格不取内容"）
- 代表 image id：`img_mq9dd9lp_yaj7p`（D1 cand1，mean 1.45/max 8/IoU 0.972）；session `session_mq9dac4n_vjs83`
- 调试注记：1 批 3/3 raw PASS——无草沿翻边 = e0 草的主抖动源在土上天然不存在

## 石 e0（定稿 = S2 措辞，调试 2 批 6 张）

```
Hand-painted stylized game art, hex terrain tile. The base image is a black line-art template on white: one large flat-top hexagon (the TOP face) with three quadrilateral side walls below it (visible cliff sides of the tile). The black template lines in the base image are FINAL and already in the correct position: keep every line exactly where it is and exactly as thick as it is — never move, redraw, re-position or thicken any line. Paint the color surfaces INSIDE the existing lines and let the original lines remain visible on top as the ink outlines. The white background outside the tile must stay pure white right up to the outer line — nothing may be painted past it. This is a STONE tile (no grass, no soil): TOP face = weathered grey rock surface, hand-painted, made of large cracked stone slabs with thin darker joints and hairline fissures, subtle cool-grey value variation, and a few tiny moss flecks in some crevices; nothing may touch or cross any black line. SIDE WALLS = rough stacked stone layers in slightly darker grey, with horizontal banding. The rim where the top face meets each wall must stay a crisp dark ink line exactly on the template line — do NOT paint a light beveled lip, rounded worn edge band, or highlight strip along that rim; the stone surface color runs flat right up to the dark line on both sides. The reference image is another tile of this family (a grass tile): match its palette warmth, brushwork, ink-outline feel and lighting exactly, but paint NO grass on this tile — it defines the style only, not the content. Style: rich hand-painted texture, soft flat ambient light (no strong cast shadows, no specular highlights), board-game hand-painted look. Nothing else added.
```

- 底图 `template_design_e0.png`；参考图 = 草批准稿（同上）
- 代表 image id：`img_mq9dmo9f_b47cd`（S2 cand1，mean 1.03/max 8/IoU 0.974）；session `session_mq9detrl_lu93w`
- 调试注记：S1 0/3，诊断 = 模型沿顶棱画 ~15px 浅灰**风化圆角唇边**盖掉模板线（石材特有）；
  S2 加「顶棱保持深色墨线/禁唇边高光带」→ 2/3。放弃路径：无（一次修正命中）

## 草 e1 / e2（定稿 = E2 措辞 + rimfix 流程，调试 5 批 14 张）

```
Hand-painted stylized game art, hex terrain tile. The base image is a black line-art template on white: one large flat-top hexagon (the TOP face) with three quadrilateral side walls below it (visible cliff sides of the tile). The black template lines in the base image are FINAL and already in the correct position: keep every line exactly where it is and exactly as thick as it is — never move, redraw, re-position or thicken any line. Paint the color surfaces INSIDE the existing lines and let the original lines remain visible on top as the ink outlines. The white background outside the tile must stay pure white right up to the outer line — nothing may be painted past it. TOP face = lush hand-painted grass in bright warm olive-yellow-green, with small grass tufts, subtle darker green patches and a few tiny wildflowers; no grass tuft may touch or cross any black line. SIDE WALLS = warm brown earth and soil strata with a few embedded grey stones, slightly darker than the top. The dark rim line where the grass top meets each wall must remain clearly visible as one continuous dark line along its ENTIRE length: the grass stops at that line, with at most a tiny fringe of short grass tips just below it — never long blades, never burying or interrupting the line, and the fringe must stay much thinner than the rim line itself is long. Match the reference image's palette and brushwork exactly (it is the approved tile of this family); paint a natural variation, not a pixel copy. Style: rich hand-painted texture, soft flat ambient light (no strong cast shadows, no specular highlights), board-game hand-painted look. Nothing else added.
```

- 底图 `template_design_e1.png` / `template_design_e2.png`；参考图 = 草 e0 批准稿
- **必须走 rimfix**：`python blender/scripts/texgen/rimfix.py <design.png> -e <1|2> -o <out.png>` 后再 QC
- 代表 image id：e1 `img_mq9dwl3y_g9drz`（E2 cand2，rimfix 后 mean 0.80/max 3/IoU 0.990）、
  e2 `img_mq9efp9t_6w0i6`（F1 cand3，rimfix 后 mean 1.10/max 9/IoU 0.987）；
  session e1 `session_mq9do4l5_brd61` / e2 `session_mq9ed55b_75pg8`
- 调试注记：高墙海拔下模型把草/土棱线画成有机软过渡/深须帘（±10px 蜿蜒、整段埋线），
  且参考图自带翻边在与文字指令对抗——措辞迭代 E1(A3 原文)0/2、E2(线可见性)0/3、
  E3(零翻边)0/3、E4(石材句式硬移植)0/3 全灭，证实**提示词不可修**。
  解法 = `texgen/rimfix.py` 确定性棱线重描（内部共享边按 sidecar 先验原位重画；外轮廓不碰，
  真废稿不洗白——负测试过）。E2 措辞 raw 数值最佳（mean ~1.1/IoU 0.99）故 rimfix 配 E2。
  放弃路径：E3 零翻边措辞（数值无优势且气质损失）、E4 句式硬移植（反向恶化）

## 草顶面变体（顶面网格填充流；定稿 = Round 2a 原文，前序 goal 2/2 PASS）

```
The base image is a top-down hexagonal grid canvas: three hexagon cells are already FILLED with a hand-painted grass texture (bright warm olive-yellow-green, small tufts, tiny wildflowers), and four hexagon cells are EMPTY (white with thin black outlines). Task: fill the four empty hexagon cells with grass in EXACTLY the same hand-painted style as the three filled cells — same palette, same brush-stroke density, same tuft and wildflower scale — but give each cell its own natural variation (do not clone the seed cells pixel-for-pixel). Paint each empty cell fully to its edges: no white background, no black outline strokes left inside any cell. Do NOT repaint, recolor or modify the three already-filled cells; do not blur the boundaries between cells. The white background outside all hexagons stays pure white.
```

- 底图 = `warp.py seed` 产出的种子画布（批准稿顶面贴 0_0,1_0,-1_1 三格），1536×1536
- 流程：`warp.py seed`（种子贴入）→ generate → `warp.py cut -q <q> -r <r>`（逐空格收获）→
  拼回 UV 画布 → QC；种子格只作上下文锚**永不回收为成品**
- 代表 image id：`img_mq9b2ds4_cvvmc`；session `session_mq9b0m29_a9yd3`（Round 2a，2/2 QC 双 PASS：
  edge mean 0.32/0.33px、检出 100%、IoU 0.996/0.993）
- 调试注记：Round 2a 一次到位；已知护栏 = image-to-image 会轻度重绘种子格（均差 ~6/255），
  种子格不可回收

## 图片装饰（sprite 流；定稿 = Round 2b 原文 + sprite_key 键控，前序 goal 用户批准入库）

```
A single bush, game decoration sprite, isolated on a FULLY TRANSPARENT background (PNG alpha, no backdrop, no ground plane, no cast shadow — the game engine adds the ground shadow itself). Hand-painted stylized game art matching the reference image's terrain tile style: rounded painterly foliage clumps in warm olive-green with brighter yellow-green highlights on top and darker green in the shadows underneath, a few small leaf details, clean dark painterly ink outline around the silhouette. The bush sits upright, roughly centered horizontally, its base near the lower part of the canvas. Soft flat ambient light, board-game hand-painted look. Nothing else in the image — one bush only, fully transparent everywhere outside the bush.
```

- 无线稿模板；参考图 = 草 e0 批准稿（风格锚）。换装饰主体时替换 "A single bush" 与
  foliage 描述段落，骨架（透明底声明/风格锚/底部锚点/平光）不动
- **必须走 sprite_key**：gpt-image-2 经 lab 无 transparent background 参数，提示词要不到真 alpha
  （实测全不透明/棋盘格画进像素）→ `texgen/sprite_key.py` 确定性键控（透明占比阈值判废）
- 代表 image id：`img_mq9bihpz_nft35`（已入库 decor_bush）；session `session_mq9bgroy_pszq2`
- 调试注记：Round 2b 两张全假透明，sprite_key 救活 cand1（透明占比 0.749）；
  放弃路径 = 提示词直要透明底（模型能力缺口，不可措辞修复）
