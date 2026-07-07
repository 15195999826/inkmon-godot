# overworld 水面 shader（water_bodies 驱动）

> 2026-07-07 落地。water 格（`terrain=="water"`）改用 canvas shader 渲染（toon 青绿 +
> voronoi 裂纹动态），替代 baked 水 tile。融合自探索 `inkmon美术探索/fable-水shader-v1`：
> **动态骨架取 water_scene（voronoi 裂纹 + 顺流漂移 + 瀑布能力），配色取 toon 青绿**（用户拍板）。
> 同日追加：落差瀑布实装（world_main 北部高地河 e1 → 两格宽瀑布 → e0 潭）。

## 数据流

```
content/maps/*.map.json  "water_bodies"
        │  (InkMonMapLoader.load_bundle: 读 + validate_water_bodies 校验 + 透传 bundle)
        ▼
InkMonRender2DWaterLayer.build_materials(water_bodies, edge_px, elevations)
        │  每片水域一个水面 ShaderMaterial：岸线段 seg + 落水段 fall + flow/flow_span 推导注入；
        │  相邻 body 落差边（上位侧 edge 0/1/2）额外产出瀑布面段 faces
        ▼  { "materials": { Vector2i(cell) -> ShaderMaterial }, "faces": [面段] }
InkMonRender2DBakedHexMap
        │  water 格出 shader 水面 Polygon2D（UV=平面坐标, material=所属 body），进画家序
        │  与周围 tile 按 screen-y 穿插；上位格紧跟着出瀑布竖直面（lift 差换算 face_height）；
        │  未收录的 water 格回退 baked 水 tile
        ▼
water_surface.gdshader（水面） / water_face.gdshader（瀑布竖直面）
```

## water_bodies schema（inkmon-map/1 扩展）

map doc 顶层数组，每片水域一个对象：

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | string | 水域标识（日志/调试用） |
| `flow` | `[x, y]` | 平面流向向量（shader 顺流漂移方向；缺省或零向量 → 默认 `-x`） |
| `cells` | `[[q, r], ...]` | 属于该水域的格；**必须都是 `terrain=="water"`，不可跨 body 重复，且同 elevation（一片水面一个水位）** |

**瀑布没有显式字段**：相邻两个 body 有 elevation 差 → 上位侧朝镜头（edge 0/1/2，即屏幕
下方三边）的交界边自动成为瀑布——渲染层出竖直面 + 下位水面注入落水翻涌。落差水路 =
上下两个 body 拼接（如 `river_upper` e1 + `river_lower` e0）。

示例见 `content/maps/world_main.map.json`（`river_upper` 北界高地河 5 格 e1 →
`river_lower` 潭/下游 8 格 e0 → `creek_mid` 3 格 e0 斜带；upper 的 (2,-4)/(3,-4)
两格唇口向南跌出三段锯齿瀑布面）。

## 校验（`InkMonMapLoader.validate_water_bodies`，fail loud）

- 每个 cell 必须是地图里 `terrain=="water"` 的格（否则水面会摆到旱地/空格）
- 同一格不可被多个 water_body 收录
- body 内所有 cell 同 elevation（落差请拆成相邻两个 body）
- 空/缺省 `water_bodies` = 无 shader 水面，water 格回退 baked 水 tile（合法 fallback）

## 地图守则（高位水，渲染层 push_warning 兜底）

高位水格（elevation>0）改用 shader 水面后**没有 baked 侧壁**，它的朝镜头三边（edge 0/1/2）
必须贴：同 body 水 / 同高陆地（河岸，如 world_main 的 g1 岸格）/ 更低的相邻 body 水（=瀑布）。
贴更低陆地或图外 → 侧壁露洞，`InkMonRender2DWaterLayer` 会 push_warning 点名格子。
背对镜头的落差边不可见（不出瀑布面），同样 push_warning 提示调整地图。

## 岸线与连续性

岸线段 = body cell 的边中，邻居**不属于任何 water_body** 的那些 → 只在水陆交界画岸沫；
两片水域相邻（同水位）时交界不画岸沫（连续水面）；有落差时交界是瀑布不是岸。几何用
flat-top `_plane_center` / `_hex_corner`（与 baked_hex_map 同公式、同 `EDGE_NEIGHBOR_DIRS`
约定，自洽）。

## 风格调参（shader uniform，美术可直接 Inspector 调）

`water_surface.gdshader`：`deep_color` / `mid_color` / `shallow_color`（青绿三档深浅）、
`crackle_color` / `crackle_alpha` / `crackle_scale`（裂纹网线）、`drift_speed`（漂移速度）、
`contact_shadow`（贴岸阴影）、`shimmer_strength`（斑驳）。
`water_face.gdshader`：`top_color` / `bottom_color` / `streak_color`（瀑布面三色）、
`fall_speed`（下落条纹速度）、`lip_height`（顶部翻边亮线）；`face_height` 由 baked_hex_map
按海拔 lift 差注入，勿手调。逐 body 差异化配色可后续在 `water_bodies` 加 `style` 字段 +
build_materials 里 override uniform。

## ⚠ Lab 契约同步待办

`inkmon-map/1` schema 这次加了 `water_bodies` 顶层块 —— 需同步到 Lab
`inkmon-lab/docs/architecture/godot-contract.md` 的地图 schema 定义（本机 lab 仓不可达，
**未同步**）。字段结构 / 校验规则如上（含 body 内同水位 + 瀑布自动推导语义）；这是纯表演层
数据（不进 GridMapModel），逻辑侧地图装载不依赖它。

## 验证

- **probe**：`inkmon/tests/shot_water_overworld.tscn`（非 headless，截 瀑布/河/溪/全景 +
  A/B 动画帧——瀑布下落条纹与水面裂纹漂移都要在动）
- **回归**：`inkmon/overworld-live` + `inkmon/patch`（launcher 组；含 shader 水面的 overworld
  live 链路不崩 + 高差通行规则不受地形改造影响）

## 退役

`inkmon/tests/shot_waterfall_probe.*`（Blender NPR 瀑布帧序列贴崖缝）是本方案的**竞品路线**，
用户选 shader 后作废——可删（git 未跟踪）。
