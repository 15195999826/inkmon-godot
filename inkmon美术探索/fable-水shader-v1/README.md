# fable-水shader-v1：shader 水面还原参考图水质感

> 2026-07-07。以 `codex-倒角-v1/program_scene.tscn` 为基底：剔除水地块，改用 canvas shader
> 水面还原参考图（`reference/water_ref.png`，hex 地台 diorama）的水质感 + 动画。
> 共迭代 18 轮截图对比（含 codex 两轮第二视角分析），第 18 轮收敛。

**两个可跑变体（并存，共用同一基类 / 截图机制）**：

| 场景 | 风格 | shader | 脚本 |
|---|---|---|---|
| `water_scene.tscn` | 灰蓝写实（终版，贴参考图 diorama 水质感） | `water_surface.gdshader` + `water_face.gdshader` | `water_scene.gd` |
| `water_scene_toon.tscn` | 青绿卡通（R10 迭代态：高饱和三色分区 + 白沫描边 + dash 笔触 + 礁石尾流，水面平贴不下沉） | `water_surface_toon.gdshader` + `water_face_toon.gdshader` | `water_scene_toon.gd` |

`water_scene_toon.*` 是**应用户要求，从 `shots/style_a_turquoise_r10.png` 用完整编辑历史逐像素重建**——
重建输出 `shots/toon_v1_river.png` 与原截图字节完全一致（463532 B），确定性复刻成功。

## 跑法

```powershell
# 编辑器直接 F6 跑 water_scene.tscn；或命令行截图（须非 headless）：
$env:INKMON_ART_CAPTURE_PATH = "<输出.png>"          # 截图后自动退出
$env:INKMON_ART_CAPTURE_FOCUS = "river"              # 可选：聚焦河道中段
$env:INKMON_ART_CAPTURE_PATH_B = "<输出B.png>"       # 可选：延迟第二帧验证动画
$env:INKMON_ART_CAPTURE_DELAY_B = "1.5"
C:\Users\37065\.local\bin\godot_console.exe --path <repo> "res://inkmon美术探索/fable-水shader-v1/water_scene.tscn"
```

## 结构

| 文件 | 职责 |
|---|---|
| `water_scene.gd` | 继承 `InkMonArtTileMapBase` 重写 `_rebuild`：水地块剔除；每水格一片 `Polygon2D`（UV 直通 hex 平面坐标）；岸线段按水位分组注入 shader；上游阶地抬升（`TERRACE_MIN_Q`）制造瀑布落差；河口/瀑布竖直截面 quad；水面按 manifest `water_recess_world` 下沉嵌入 |
| `water_surface.gdshader` | 水面：灰蓝三段分区平涂（噪声蜿蜒边界）+ 明暗斑驳/泥灰脏色 + voronoi F2-F1 裂纹网线（fbm 掩码破碎，顺流漂移+cell 游动动画）+ 贴岸接触阴影 + 断续湿边亮线 + 落水基部翻涌/放射碎沫 |
| `water_face.gdshader` | 竖直截面（河口/瀑布共用）：灰蓝渐变 + 细密竖条纹下落动画（列噪声+纵向断裂）+ 顶部翻边亮线 + 底部雾化 |
| `shots/` | `water_v1_full/river/waterfall_closeup` = 终版；`_frameB` = 动画验证帧；`style_a_turquoise_r10` = 前 10 轮误锚风格存档（见下） |
| `reference/`（.gdignore） | 用户给的参考图原件 |

几何数据走 uniform 数组（岸线段 96 上限 / 落水线段 8 上限），shader 逐像素解析到岸距离——
无预烘焙贴图，全程序化，水域形状改动零成本。

## 迭代记录（要点）

- **R1-R10（弯路）**：把参考图误记成"高饱和青绿卡通水 + 白沫描边 + 顺流白笔触"，做了一版
  完成度不错的卡通水。**⚠ 可运行源码没有留存**：三个文件（surface/face shader + water_scene.gd）
  全程原地覆盖成灰蓝版，且这套文件从未 git commit（至今 untracked），磁盘和 git 都不存在青绿态源码；
  唯一残留是静态截图 `shots/style_a_turquoise_r10.png`，要复活只能照截图重建。
  **教训：参考图要在迭代中反复回读原图，不要凭首轮印象走十轮。**
- **R8 codex 介入①**：其第 1 条（水应是低饱和灰蓝）当时被我部分驳回——事后证明 codex 看的才是真参考图。
- **R11（转向）**：重读参考图原件后全面转向：灰蓝配色 / voronoi 裂纹 / 水面下沉嵌入 / 删礁石白圈。
- **R13**：上游整体抬升一级（含"贴高位水的低位岸地"自动抬升防穿帮），河道中段出现真瀑布落差 +
  落水翻涌；两级水体各自独立距离场材质。
- **R14 codex 介入②**：5 条全采纳——裂纹 fbm 破碎化、水色再压灰+泥灰色、贴岸亮圈收窄破边、
  瀑布条纹纵向断裂+底部雾化；其"各向异性顺流亮带"一条实测成乳白雾（R16-17），最终移除。
- **R18（收敛）**：剩余差距均为地块美术（石砌墙面/苔藓/植被）与场景构成，不在水面 shader 范围。

## 动画清单（TIME 驱动）

裂纹网线整体顺流漂移 + voronoi cell 正弦游动微光；明暗斑驳缓慢流变；湿边亮线呼吸；
瀑布条纹下落滚动 + 底部雾闪烁；落水翻涌宽度/亮度脉动 + 放射碎沫外扩。
验证方式：`INKMON_ART_CAPTURE_PATH_B` 双帧对比（`water_v1_river.png` vs `_frameB.png`）。
