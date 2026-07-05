# 大地图 = 分层噪声 biome 生成 + shader 地图纸渲染（多风格纯表现层切换）

出征大地图 v1（低分辨率最近格色块烘焙 + LINEAR 放大 + hex 格线叠满）观感不成立：只有 3 种地形色、
无海陆结构、无立体感、格线盖脸。2026-07-05 与用户对齐（Python mock 四轮出图拍板）：目标观感 =
文明6/泰拉瑞亚/MC 式"世界地图"，**不画 hex 格线**；美术语言遵循世界观特征——low poly / faceted
geometry / sharp edges / ink sketch texture / 六元素。

**决定一：生成端 = 分层噪声场 → biome 查表，canonical 结构只有一套。**
elevation（FBM + ridge + domain warp）/ moisture（FBM）/ temperature（纬度带 + 噪声抖动）三场，
按未压扁平面坐标采样（沿用既有防剪切拍板）。量化分双域（shot 自验校准出的实现细则）：
**分类场 = 秩归一 + hex 邻域低通**（覆盖率跨 seed 稳定 + 地貌成大片连贯团，根治"整图全山"与
"秩跳变碎花"两个漂移）；**入档渲染场 = min-max 量化**（保空间平滑，hillshade/雪顶/密林渐变不撒胡椒）。
落选方案：Voronoi 板块（区域图尺度杀鸡用牛刀）、WFC（拼不出连续地貌）、侵蚀模拟（只借"河流 =
逐格走最低邻格 + 已访集合 BFS 取河道"一招）。

**决定二：地理入档的范围 = biome + 量化场 + 河流 polyline。**
每格 biome id / elevation / moisture（0..255 量化）与河流折线（定点数坐标）开档一次生成、进档永久
固定（对齐 P2"世界地理固定"拍板）；temperature 不入档（分类期中间量）。`SAVE_VERSION` 4→5，旧档
丢弃重开（§5.2 无迁移惯例）。`terrain_at()` 保留旧 3-kind API（biome→plain/forest/hill 静态映射），
野群战斗皮肤链路（M2.2）零改动。biome 即"环境"的 mock 数据形状：未来区域生态野群表 / **六元素亲和**
（fire/water/wind/earth/light/dark，映射表待拍板）挂在 biome id 上，逻辑层跟上时无需再改存档形状。

**决定三：海洋只是视觉边框，可玩矩形恒为陆地。**
28×22 可玩格全部是陆地；海岸线/浅滩/离岸小岛长在矩形外的 margin 带（噪声扰动距离衰减），
纯 shader 演出——节点生成、选路、委托寻址零逻辑影响。图内湖泊/水系可通行性 = 环境进逻辑层那轮再议。

**决定四：渲染端 = 一张 map sheet（canvas_item shader），CPU 只烘数据不烘颜色。**
CPU 每世界一次烘**连续场纹理**（elev/moist raw 归一 + coast + 斑驳，sheet 全域逐像素采噪声——
渲染真相是连续场而非 616 格放大；616 格放大出不了 3D 起伏感/过渡衔接，用户验收踩过后修正）
秩归一在烘焙时逐像素完成直接入纹理（biome 阈值在秩域=覆盖率语义，与逻辑层分类同阈值），
另烘**真模糊着色场与三档模糊陆地带**（box×3≈高斯；hillshade/海深/浅滩/海滩全走模糊场——
shader 稀疏差分冒充模糊会让阴影与色块形体不同频，读作"云影贴花"而非地形阴面，用户对照定位）；
上色/分类/墨线/纸纹在 shader 逐像素完成（任意缩放不糊、Web 导出兼容、调参即时）。烘焙数学
单独成类（`InkMonMapBakeMath`），并提供 **Ref CPU 参照模式**（map_viewer 内一键 A/B：同世界
同数值的整管线 CPU 逐像素参照图，shader 版与其对齐即达标——渲染差异定位的固定手段）。
入档 cells 仍是玩法/环境唯一真相。**对齐口径 = 同源近似而非 bit 级**：逻辑侧的
分类平滑（hex 低通）与温度抖动刻意不进 shader（视觉不需要、复刻只添管线耦合），临界格允许
视觉发散——与"mock 本就无格"的拍板语境一致；离岸小岛项进 `_land_factor` 共享公式（河流/
河口/渲染同一片海，常量两端同值成对维护）。
落选：CPU 高分辨率烘色（GDScript 逐像素十秒级）、TileMap tileset（要美术且自带格子感）、AI 整图
（同 seed 不可复现、与逻辑格无法对齐；texture-gen 后续只做细节素材）。hex 格线与矩形描边删除；
迷雾三态 / 节点 / 走廊 / 地标旗 / 棋子全部原样叠加，war3 拍板不动。

**决定五：风格 = biome→颜色表 + 开关 uniform，纯表现层随时切换。**
canonical 生成不随风格变；每风格一张色表 + 参数（facet 面片化 / 墨线强度 / hillshade / 纸纹 / 色阶
量化 / 河流显隐）。默认风格 = **墨线面片**（faceted Voronoi 面片 + 墨线描界 + 苔藓橄榄色板，对齐
战斗场景概念图与世界观 low poly / sharp edges / ink sketch）；备选：苔藓水彩 / 明亮水彩 / 素净水彩 / 扁平色块 /
**codex 暗色重墨版**（应用户要求由 codex 模型自主设计，2026-07-05）。风格偏好存 `user://`
（表现层偏好不进 GI/存档，adr/0002 三叉），出征 HUD 按钮循环切换。

## Consequences

- 影响文件：`ink_mon_world_map_data.gd`（生成重写）、`ink_mon_world_gi.gd`（SAVE_VERSION 5）、
  `ink_mon_mission_map_view.gd`（sheet 化）、新增 `world_map_sheet.gdshader` + `ink_mon_map_style_presets.gd`
  + sheet 子节点类、`translations.csv`（风格名文案 + 字体子集重跑）、`smoke_world_map_data`（契约按
  v2 数据形状重写：秩归一域 / biome 邻聚率 / 河流硬不变量 / roundtrip）。
- 跨平台确定性口径：逐格数据入档 = 玩法层强一致；shader 细节噪声/海岸扰动由 seed 重建，属装饰级，
  ULP 漂移可接受（与"地形入档故跨平台浮点无碍"同一口径的延伸）。
- 大地图观感自验从单张 shot 变为逐风格多张（shot_mission_map 扩展）。
- 战斗场景美术（概念图 diorama）与大地图是"实景 vs 地图纸"关系：共享色板气质，不共享贴图管线。
