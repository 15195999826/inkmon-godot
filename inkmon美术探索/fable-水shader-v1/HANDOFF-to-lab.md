# 交接：世界地图水面渲染 —— shader 方案（已验证，定为最终技术路线）

> **来源**：inkmon-godot `inkmon美术探索/fable-水shader-v1/`（探索仓，目录已冻结 2026-07-02）
> **交接对象**：inkmon-lab 生产管线的「水面渲染」任务
> **日期**：2026-07-07
> **状态**：✅ 技术选型验证通过；🎨 最终美术风格待与定稿美术对齐

## 一句话结论

`canvas_item` shader + **到岸距离场**做 hex 水面，**技术路线验证通过，定为该任务最终方案**。
最终美术风格待定稿美术拍板，但**风格与技术解耦**——换风格只改 shader 着色段，几何/集成/契约都不动。

## 为什么这个方案 OK（验证依据）

- 18 轮参考图对比迭代 + codex 两轮独立第二视角复查，收敛。
- 纯 GDScript + `.gdshader`，**无 GDExtension 依赖**。
- 动画全 `TIME` 驱动，**无 CPU tick / 无每帧脚本开销**。
- 距离场逐像素解析，**零预烘焙贴图**——水域形状改动零成本，不用重烘焙。
- 同一技术骨架跑通了两种截然不同的风格（灰蓝写实 / 青绿卡通），证明骨架承得住美术方向的摇摆。

## 核心技术骨架（要移植进生产的部分）

1. **每个水格 = 一片 `Polygon2D`**，UV 通道直通 hex 平面坐标（px）。
2. **岸线段注入**：邻居非水且为可见边 → 一条线段，以 uniform 数组（上限 96）注入；shader 逐像素求「到岸距离」`sd`。深浅渐变 / 贴岸白沫 / 尾流 / 湿边**全部由 `sd` 驱动**。
3. **多水位（阶地瀑布）**：按 `elevation` 分组，各水位一套独立材质；水位落差处补竖直截面 quad（图边河口 / 瀑布落差共用一套 face shader）。
4. **嵌入感**：水面按 `water_recess_world` 下沉，露出一条岸壁，配贴岸接触阴影。

## 依赖的 manifest 契约字段（已在 Art Asset Contract 内，无新增）

`pitch_deg` · `yaw_deg` · `px_per_hex_edge` · `px_per_unit` · `thickness_world` · `elevation_step_world` · `water_recess_world`

—— 与 tile 烘焙管线**共用同一份 manifest**，水面渲染不引入任何新契约字段。

## 待美术对齐（交给 lab + 定稿美术拍板）

- **锚定哪版风格**：灰蓝写实 / 青绿卡通 / 或按定稿美术出第三种——需要定稿美术的**水体样图**做锚。
- 配色 / 白沫密度 / 裂纹强度 / 湿边强度 / 流速——**全是 uniform**，美术可直接在 Inspector 调参，无需改代码。
- 是否保留瀑布落差机制、岸壁露出高度取多少。

## 集成路径（探索 → 生产）

- **落点**：主游戏 `inkmon/presentation/render2d/views/baked_hex_map.gd` + `inkmon/logic/services/content/ink_mon_map_loader.gd` 的水地块渲染分支。
- **替换数据源**：探索用的 `InkMonIsoSandboxDemoMap`（假 demo 图）→ 真实 `content/maps/world_main.map.json` 的水格。
- **可直接移植**：岸线段注入逻辑（邻居判定 + 可见边筛选）、距离场 shader、截面 quad 生成。
- ⚠️ 探索目录已冻结，**正式落地按 lab `godot-contract.md` 的 Art Asset Contract 重新安家**，不要从探索目录 `inkmon美术探索/` 直接 `preload` 引用。

## 产物清单（探索仓，供参考/复用）

| 类型 | 文件 |
|---|---|
| 灰蓝写实版（终版） | `water_scene.tscn` + `water_surface.gdshader` + `water_face.gdshader` + `water_scene.gd` |
| 青绿卡通版 | `water_scene_toon.tscn` + `water_surface_toon.gdshader` + `water_face_toon.gdshader` + `water_scene_toon.gd` |
| 对照图 | `shots/water_v1_*.png`（灰蓝）· `shots/toon_v1_*.png`（青绿）· `reference/water_ref.png`（原参考图） |
| 迭代记录 | `README.md` |

> 探索文件当前 untracked（未 commit）。若要作为 lab 移植的参照基线保留，交接前先在 inkmon-godot 提交一次。
