# tile_pipeline — 标准地块美术管线

Blender 资产工厂 → 固定视角烘焙 PNG → Godot 拼装。adr/0008 保守主案中"标准地块 + 装饰"
一半的管线验证（整图面片 + YSort 标注另案）。概念图气质清单见
`.claude-goal/tile-art-pipeline/Goal.md`。

## 链路（单一真相 = manifest.json）

```
blender/scripts/bake_assets.py        ← 所有角度/比例/配色/材质参数（CONFIG + PALETTE）
  └─ 烘焙 → inkmon/tools/tile_pipeline/assets/baked/*.png + manifest.json
       └─ Godot: tile_pipeline_scene.gd 读 manifest 拼装（不写任何角度常量）
```

- **manifest.json**（Blender 写、Godot 读）：`pitch_deg` / `yaw_deg` / `hex_orientation`
  (flat_top) / `px_per_hex_edge` / `elevation_step_world` / 每资产 `anchor_px` + `variants`
- 资产：地块 = 草/土/石/水 × 海拔 0-2 × 噪声变体（grass 3 / 其余 2）；装饰 = 针叶树两档 +
  石头堆 + 灌木（带 Cycles shadow catcher 接地影）
- 手绘感：Freestyle 墨线（轮廓 + Perlin 抖动笔触）+ 每地形程序化 shader（石板 voronoi 裂纹、
  砌石侧壁层带、草唇/苔藓爬石顶缘、水波带 + 涟漪碎板高光）

## 改视角 / 改参数 → 重烘 → Godot 自动跟随

> ⚠ **adr/0009：相机角度已冻结为美术契约。** 本节"改视角自动跟随"仅对程序化材质资产成立；
> 含生图贴图的资产（见根目录 `CONTEXT.md`）改角度 = 全量重新生图 + 重审设计稿，不是重烘。

1. 改 `blender/scripts/bake_assets.py` 的 `CONFIG`（如 `pitch_deg` / `yaw_deg` /
   `px_per_unit`）或 `PALETTE` / `TERRAIN_VARIANTS`
2. 重烘（Blender MCP 内执行，或命令行）：
   ```bash
   blender --background blender/test.blend --python blender/scripts/bake_assets.py
   ```
   （交互式：`exec(open("blender/scripts/bake_assets.py").read()); bake_all()`，
   子集烘焙 `bake_all(subset=["tile_grass_e0", ...])`）
3. **必须重导入**（Godot 运行时读 `.godot/imported/` 缓存，跳过这步会看旧图）：
   ```bash
   godot --headless --path . --import
   ```
4. 跑拼装场景看效果（编辑器 F6 / dev-agent 截图流程见 `DEV_AGENT.md`）

Godot 端零修改 —— 布局/海拔/锚点全部按 manifest 计算（投影公式复用
`InkMonRender2DIsoProjection`，flat-top 布局公式在 `tile_pipeline_scene.gd`）。

## 几何对齐契约（Blender ↔ Godot）

- Godot 平面 (px, py)（y 向下）↔ Blender 世界 (px, -py, 0)（Z 上）
- 相机 `rotation_euler = (90°-pitch, 0, yaw)` 正交；资产原点（tile 顶面中心 / 装饰落地点）
  投到画布中心 = `anchor_px`
- 海拔不进模型：tile 顶面恒 z=0，海拔只加深侧壁；Godot 按
  `elevation × elevation_step_world × px_per_unit × cos(pitch)` 抬锚点
- hex flat-top：Blender 角点 60°·i；Godot `center = edge·(1.5q, √3(r+q/2))`

## 已知坑

- **rebake 后必须 `--import`**，否则 Godot 场景显示旧贴图（.ctex 缓存）
- Blender 材质同名会互删：变体材质名必须带 `_v<N>` 后缀（脚本已处理）
- `blender/.gdignore` 阻止 Godot 把 .blend 当场景导入，别删
