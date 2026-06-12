# Tile 美术资产生成管线

地块/装饰物美术资产的 AI 生图 → Blender 烘焙 → Godot 拼装管线的领域语言。生图能力宿主在
inkmon-lab（MCP 操作活的 lab app，要求 lab 常驻打开）；Blender 环节在本仓根 `blender/`，
Godot 拼装环节在 `inkmon/tools/tile_pipeline/`。

## Language

**设计稿**:
GPT 按线稿模板画出的地块 3D 视角完成态画面——审美批准的对象，也是衍生 UV 贴图的源头。
_Avoid_: 地块图（与既有烘焙产物 tile PNG 撞名）

**UV 贴图**:
映射到 Blender 网格面（hex 顶面等）的纹理图，生图管线的最终交付物，进 Blender 材质。
_Avoid_: 贴图（裸用时歧义，见 Flagged ambiguities）

**线稿模板**:
我们自产的 SVG 结构线稿，喂给 gpt-image-2 当几何基准；每个像素归属哪个面先验已知。四个版本：
- **3D 全貌版** — 冻结角度下整块 tile（顶面+可见侧壁）；`design_warp` 全程用 + `design_uv_gpt` 第一步用
- **UV 展开版** — 纸模 unfold net：顶面 hex 居中，可见侧壁直接铰接在对应 hex 边上外展
  （生产参考图只有轮廓线与面分割线，无文字/虚线/刻线；net_v2，1536×1024）；`design_uv_gpt` 第二步用
- **双联版** — 左 3D 全貌右 UV 展开同画布；`dual_canvas` 用
- **俯视网格版** — 正俯视一圈 hex 网格，部分格预贴种子顶面；顶面网格填充流用

**风格定调流**:
3D 全貌线稿 → 设计稿 → 审批 → 提取的全 tile 生产流——定风格、出侧壁（含"同类多出几种"
的立边样式变体，每张全稿全审）、出首批种子顶面；bake-off 三方案在此流赛马。

**顶面网格填充流**:
俯视网格版线稿 + 种子顶面 → GPT 自然填空 → 按已知 hex 位置 mask 裁切收获的顶面变体量产流。
正俯视 = UV 本身，零 warp；一次调用收多格；收获可回炉当下轮种子；未来过渡地形（草土交界填空）
的预留载体。

**种子顶面**:
摆进俯视网格画布锚定家族一致性的已批准顶面——首批来源固定为风格定调流批准稿的顶面提取
（保证顶壁同源），不冷启动。

**图片装饰**:
GPT 透明底 sprite 经 Blender alpha 面片烘焙入库的装饰资产——与建模装饰共享 shadow catcher
接地影、manifest 锚点（烘焙时从 alpha 不透明像素 bottom-center 自动算）与可选 Freestyle 墨线。
_Avoid_: 直出 sprite（绕开烘焙工厂直进 Godot 的路线已否决）

**烘焙 PNG**:
Blender 固定相机（manifest 契约角度）烘出的最终 Godot 用图，含墨线/光影/侧壁。
既有概念，与设计稿严格区分：设计稿是 GPT 画的"理想完成态"，烘焙 PNG 是管线真实产物。

**生图方案**:
风格定调流内全 tile 设计稿→UV 贴图的三条候选路线，全部实现、Godot 实测后选主力
（bake-off，见 adr/0009）；顶面变体量产不走这里，走顶面网格填充流：
- `design_warp`（A′）— 设计稿 → 确定性反投影 warp → UV 贴图（1 次调用，像素级忠实，角度锁死）
- `design_uv_gpt`（A）— 设计稿 → GPT 二次调用展 UV（2 次调用，vibe 级忠实，角度无关）
- `dual_canvas`（B）— 左右双联画布一次生成设计稿+UV（1 次调用，分辨率减半，角度无关）

**生成 Session（配方）**:
用户在 lab 里实验沉淀的"提示词骨架 + 参考图组合"调参成果，lab 持有本体、按 id 引用；
AI 调 `generate` 主用 session 模式（继承配方 + 追加描述 + 自带几何底图；AI 携带的参考图与
session 参考图**合并**——网格填充塞邻居批准稿即走此口），裸模式留实验兜底。
地形 → 现役 session id 的映射归 git 管（`blender/textures/gen_config.json`）。

**车间**:
lab 侧的生成工作区——全部生成历史、废稿、候选、session 记录的归属地，永不被 godot 仓库直接引用。
**裸模式也无例外**：产物自动挂 scratch session 落图库；AI 永不直接收图字节（generate 只返回
image id + 只读预览路径），拿文件唯一通道是 export。

**入库**:
批准资产复制进 godot 仓库 `blender/` 下并 git 提交的动作及其结果——`blender/designs/`（设计稿存档）
+ `blender/textures/`（UV 贴图 + 每资产 provenance JSON：prompt/方案/参考图/lab session+image id）。
`blender/` 已挂 `.gdignore`，源图不会被 Godot 误导入。
候选评估缓冲 `blender/textures/_candidates/`（gitignore 永不 commit）不属于入库——烘焙试评用，
随时可清；lab = 原始资产真相，git = 批准品真相，缓冲区不构成第三真相。

## Relationships

- **线稿模板** 约束 **设计稿** 的几何（GPT 守不住边界 → 裁切对齐永远由我们做，数据级 QC 验偏差）
- 风格定调流内 **设计稿** → **UV 贴图** 按**生图方案**出（warp 派生 / GPT 二次展 UV / 双联同生）；
  相机角度已冻结为契约（adr/0009）
- 侧壁可见面纹理**进管线**（批什么得什么）；背面三壁被冻结相机豁免，不需要纹理
- 海拔三档**各画各审**：e0/e1/e2 每档独立设计稿独立批准（拒绝一稿裁切方案，闸门纯度优先）
- 变体辖区：顶面变体 = **顶面网格填充流**量产（空间上下文锚一致性）；侧壁变体 = 风格定调流多稿；
  烘焙组合数按 max(顶面变体数, 侧壁变体数) 取，不按乘积，防 baked PNG 爆炸
- v1 地形范围：草/土/石；**水挂起**——先定水的动态方案，再回头决定水是否/如何进生图管线
- 三站链路：lab **车间**（MCP 导出）→ **入库**（`blender/designs|textures/`，git）→ `bake_assets.py`
  读 textures/ 烘焙 → `assets/baked/` + manifest → Godot 拼装（末站不变）
- 质量卡口三连：① 数据级 QC（自动：模板边缘偏差/alpha 覆盖/轮廓匹配，判废重摇）→
  ② AI 截图自评（自动：烘焙 → Godot 拼装实拍 → 气质五项打分，复用 DevAgent 基建）→
  ③ **用户后置闸门：审批即入库**——审的是 Godot 实景 shortlist，点头那一下 = 触发导出入库

## Example dialogue

> **Dev:** "草地顶面想再加两个变体，是不是再画两张**设计稿**？"
> **Domain expert:** "不——设计稿归**风格定调流**，管定风格、出侧壁、出首批**种子顶面**；
> 顶面变体走**顶面网格填充流**：种子摆进俯视网格画布让 GPT 填空，裁出来就是 **UV 贴图**（零 warp）。"
> **Dev:** "那裁出来的图直接 commit 入库？"
> **Domain expert:** "先 export 到 `_candidates/` 烘焙试评、Godot 实拍出 shortlist——**后置闸门**
> 用户点头那一下才 export **入库** + commit；重烘出的 **烘焙 PNG** 才是 Godot 用的东西。"

## Flagged ambiguities

- "地块图" 同时被用于指 GPT 设计产物和烘焙 tile PNG —— 解决：前者叫**设计稿**，后者叫**烘焙 PNG**。
- "贴图" 裸用时可能指 UV 贴图 / 烘焙 PNG / 图片装饰 sprite —— 解决：默认指 **UV 贴图**，其余用全名。
