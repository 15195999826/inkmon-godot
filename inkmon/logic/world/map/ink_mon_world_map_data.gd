class_name InkMonWorldMapData
extends RefCounted
## 世界大地图地理 (P2 拍板, glossary §4.9): 开档 new_game 一次生成、永久固定、进据点档。
##
## 只存地理 (biome/量化场/河流/地标/持久点亮迷雾); 趟内节点图与趟内视野住 InkMonMissionState
## (transient, 不在本类)。刻意不进 GI grid 机器 —— 出征大地图的逻辑真相是趟内节点图,
## 本类只是节点图长在其上的固定地理底 (main-game-architecture §9 双 grid 现状不动)。
## 序列化风格对齐 InkMonPlayerActor: static from_dict / 实例 to_dict / `as Dictionary` null guard /
## 数值一律 int() 归一 (存档经 JSON 后整数变 float, 归一保 roundtrip 深相等)。
##
## adr/0012 生成管线: elevation(FBM+ridge+domain warp) / moisture(FBM+warp) / temperature(纬度带+抖动)
## 三场按未压扁平面坐标采样 → 616 格秩归一 (biome 覆盖率跨 seed 稳定) → 查表得每格 biome;
## 河流 = 高地格逐格走最低"势能"(raw 高程 × 陆地衰减) 直到入海/汇入先成河。全部入档永久固定。


## v1 唯一区域 (多区域 = Phase 5+)。
const REGION_EAST_WILDS := "east_wilds"
const DEFAULT_WIDTH := 28
const DEFAULT_HEIGHT := 22
## 旧 3-kind 地形 (battle 皮肤映射域, M2.2 链路不动): biome 经 biome_to_terrain 投影到此域。
const TERRAIN_PLAIN := "plain"
const TERRAIN_FOREST := "forest"
const TERRAIN_HILL := "hill"
## biome (adr/0012 决定二): "环境"的 mock 数据形状 —— 未来区域生态野群表 / 六元素亲和
## (fire/water/wind/earth/light/dark, 映射表待拍板) 都挂在 biome id 上。
const BIOME_PLAIN := "plain"
const BIOME_FOREST := "forest"
const BIOME_HILL := "hill"
const BIOME_MOUNTAIN := "mountain"
const BIOME_TUNDRA := "tundra"
const BIOME_DRY := "dry"
## 存档/数据纹理用 int 码 = 本数组下标 (顺序进契约, 不得重排; 追加只许尾插)。
const BIOME_ORDER: Array[String] = [BIOME_PLAIN, BIOME_FOREST, BIOME_HILL, BIOME_MOUNTAIN, BIOME_TUNDRA, BIOME_DRY]
## biome 阈值作用在秩归一域 [0,1] —— 数值即覆盖率 (0.87 = 高程前 13% 为山), 跨 seed 稳定。
const BIOME_MOUNTAIN_MIN := 0.87
const BIOME_HILL_MIN := 0.72
const BIOME_TUNDRA_MAX_T := 0.10
const BIOME_FOREST_MIN_M := 0.58
const BIOME_DRY_MAX_M := 0.24
const BIOME_DRY_MIN_T := 0.58
## 量化档位 (elev/moist 0..QUANT_MAX 入档; 数据纹理同域)。
const QUANT_MAX := 255
## 地形噪声 ("完整地形图"拍板 2026-07-05: 地貌连续成片): 频率按未压扁平面单位
## (世界宽 ~28.5 单位 → 特征尺度 ~8 单位, 一图 4-5 个地貌团)。地形入档, 噪声只在开档跑一次
## —— 跨平台浮点漂移不影响已有档。
const TERRAIN_NOISE_FREQUENCY := 0.13
const RIDGE_NOISE_FREQUENCY := 0.085
const MOISTURE_NOISE_FREQUENCY := 0.09
const TEMPERATURE_NOISE_FREQUENCY := 0.15
## domain warp (有机地貌边界): 位移幅度单位 = 平面单位。
const WARP_AMPLITUDE := 2.0
const WARP_FREQUENCY := 0.09
## seed 派生偏移 (各场独立, 互不贴着长)。
const MOISTURE_SEED_OFFSET := 7919
const RIDGE_SEED_OFFSET := 104729
const TEMPERATURE_SEED_OFFSET := 1299709
const COAST_SEED_OFFSET := 15485863
## 纬度温度带: t = lat*系数 + 偏置 - 高程降温 + 噪声抖动 (北冷南暖, 锚在可玩矩形)。
## 纬度重映射 [LAT_LO, LAT_LO+LAT_SPAN]: 极端气候带只在南北边缘偶发点缀。
const TEMP_LAT_LO := 0.15
const TEMP_LAT_SPAN := 0.7
const TEMP_LAT_SCALE := 1.05
const TEMP_LAT_BIAS := -0.03
const TEMP_ELEV_DROP := 0.30
const TEMP_JITTER := 0.20
## 海洋视觉边框 (adr/0012 决定三): 可玩矩形恒陆地, 海岸线长在矩形外 margin 带。
## ⚠ 本组常量与 world_map_sheet.gdshader 的海岸公式成对 (shader 无法调 GDScript, 双份同值):
## land = 1 - smoothstep(COAST_FALL_START, OCEAN_MARGIN-1, 矩形外距离 × (COAST_JITTER_BASE + coast01))。
const OCEAN_MARGIN := 6.0
const COAST_FALL_START := 0.6
const COAST_JITTER_BASE := 0.65
const COAST_NOISE_FREQUENCY := 0.22
## 河流 (adr/0012): 源头取高程秩前列、彼此 axial 距离 ≥ SPACING 的格; 逐格走最低势能
## (raw 高程 × 陆地衰减), 允许爬出局部坑 (走最低未访邻格); 入海或汇入先成河即成。
const RIVER_MAX_COUNT := 3
const RIVER_SOURCE_SPACING := 7
const RIVER_MAX_STEPS := 400
const RIVER_MIN_POINTS := 4
## 河流坐标定点化倍率 (入档 int, 读回 /RIVER_COORD_SCALE; float 直存过 JSON 不保 roundtrip 深相等)。
const RIVER_COORD_SCALE := 100.0
## 地标 kind: site = 委托目标候选。
const LANDMARK_SITE := "site"
const SITE_COUNT := 3
## 出生点距地图几何中心的最大 offset 偏移 ("随机出生在靠近中心的点位"契约)。
const ENTRY_CENTER_JITTER := 2
## 地标距入口的最小 axial 距离 (保证"走过去的路"有长度)。
## ⚠ 与尺寸联动: 南北方向最短 (最坏 = 高/2 - jitter - 1 行), 正南北近格被滤后靠斜向格补位
## (扇区 120° 恒覆盖斜向, 枚举法 + assert 兜底; smoke 多 seed 扫描焊死)。改尺寸要复核。
const MIN_TARGET_DISTANCE := 9
## site 扇区两侧内缩角 (15°), 保证任两 site 相对入口的方位角差 ≥ 30° —— 目标真正散布不同方向。
const SITE_SECTOR_MARGIN := TAU / 24.0


var generation_seed := 0
var region_id := REGION_EAST_WILDS
var width := DEFAULT_WIDTH
var height := DEFAULT_HEIGHT
## 出征进入大地图的起点格 (据点在大地图上的位置)。
var entry_coord := Vector2i.ZERO
## 逐格数据 (row-major offset 序, 下标 = cell_index): biome int 码 / 量化高程 / 量化湿度。
var biome_codes := PackedInt32Array()
var elevation_levels := PackedInt32Array()
var moisture_levels := PackedInt32Array()
## 河流折线 (平面坐标, hex 间距 = 1 单位; 表现层直接变换绘制)。
var rivers: Array[PackedVector2Array] = []
## 地标: {id: String, coord: Vector2i, kind: String}。
var landmarks: Array[Dictionary] = []
## 持久点亮 (跨趟累积, 进存档): Vector2i -> true。趟内视野是另一层, 住 MissionState (P2 迷雾两层)。
var revealed_cells: Dictionary = {}


## 开档一次性生成 (同 seed 同图, 确定性)。
## rng 消耗序钉死 (同 seed 同图): ① entry jitter ② 扇区相位 ③ 逐扇区挑 site
## (地形场/biome/河流全走噪声与确定性排序, 不耗 rng)。
static func generate(seed_value: int) -> InkMonWorldMapData:
	var map := InkMonWorldMapData.new()
	map.generation_seed = seed_value
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var center_offset := Vector2i(int(DEFAULT_WIDTH / 2.0), int(DEFAULT_HEIGHT / 2.0))
	var entry_offset := center_offset + Vector2i(
		rng.randi_range(-ENTRY_CENTER_JITTER, ENTRY_CENTER_JITTER),
		rng.randi_range(-ENTRY_CENTER_JITTER, ENTRY_CENTER_JITTER))
	map.entry_coord = offset_to_axial(entry_offset.x, entry_offset.y)
	# 扇区相位随机: 不同档的"三个方向"整体旋转, 世界朝向也独一无二。
	var sector_phase := rng.randf() * TAU
	# === 地形场 (adr/0012 决定一): raw 场 → 秩归一 → biome 查表 (噪声走公共工厂, 与表现层同源) ===
	var elevation_noise := make_elevation_noise(seed_value)
	var ridge_noise := make_ridge_noise(seed_value)
	var moisture_noise := make_moisture_noise(seed_value)
	var temperature_noise := _make_field_noise(seed_value + TEMPERATURE_SEED_OFFSET, TEMPERATURE_NOISE_FREQUENCY, 3, false)
	var cell_count := DEFAULT_WIDTH * DEFAULT_HEIGHT
	var raw_elevation := PackedFloat64Array()
	var raw_moisture := PackedFloat64Array()
	raw_elevation.resize(cell_count)
	raw_moisture.resize(cell_count)
	for row in range(DEFAULT_HEIGHT):
		for col in range(DEFAULT_WIDTH):
			var sample := axial_to_plane(offset_to_axial(col, row))
			var index := row * DEFAULT_WIDTH + col
			raw_elevation[index] = _raw_elevation(elevation_noise, ridge_noise, sample)
			raw_moisture[index] = raw_moisture_at(moisture_noise, sample)
	# 双域量化 (shot 自验踩过的坑): biome 分类走秩归一 (覆盖率跨 seed 稳定);
	# 入档渲染场走 min-max (保空间平滑 —— 秩会把邻格小差放大成大跳变,
	# hillshade/雪顶/密林渐变全图撒胡椒)。分类秩场再过一轮 hex 邻域低通:
	# 秩放大的邻格跳变会把 biome 撒成碎花, 低通后地貌成大片连贯团 (同为 shot 踩坑)。
	var elevation_rank := _hex_smooth(_rank_quantize(raw_elevation))
	var moisture_rank := _hex_smooth(_rank_quantize(raw_moisture))
	map.elevation_levels = _minmax_quantize(raw_elevation)
	map.moisture_levels = _minmax_quantize(raw_moisture)
	map.biome_codes.resize(cell_count)
	for row in range(DEFAULT_HEIGHT):
		for col in range(DEFAULT_WIDTH):
			var index := row * DEFAULT_WIDTH + col
			var sample := axial_to_plane(offset_to_axial(col, row))
			var elevation01 := float(elevation_rank[index]) / float(QUANT_MAX)
			var moisture01 := float(moisture_rank[index]) / float(QUANT_MAX)
			var jitter01 := (temperature_noise.get_noise_2d(sample.x, sample.y) + 1.0) * 0.5
			var temperature := _temperature(row, elevation01, jitter01)
			map.biome_codes[index] = _classify_biome(elevation01, moisture01, temperature)
	# site 放置: 全格按相对入口的平面方位角分进 SITE_COUNT 个扇区桶 (界内 + 距离达标 + 扇区 margin),
	# 每桶随机挑 1 格 —— 枚举法必然成功 (桶空 = 尺寸/距离常量配置错误, assert 兜底), 无 attempts 抽奖。
	var sector_width := TAU / float(SITE_COUNT)
	var entry_plane := axial_to_plane(map.entry_coord)
	var buckets: Array = []
	for sector in range(SITE_COUNT):
		buckets.append([] as Array[Vector2i])
	for row in range(DEFAULT_HEIGHT):
		for col in range(DEFAULT_WIDTH):
			var cell := offset_to_axial(col, row)
			if _axial_distance(map.entry_coord, cell) < MIN_TARGET_DISTANCE:
				continue
			var relative := fposmod((axial_to_plane(cell) - entry_plane).angle() - sector_phase, TAU)
			var sector := int(relative / sector_width)
			var in_sector := relative - float(sector) * sector_width
			if in_sector < SITE_SECTOR_MARGIN or in_sector > sector_width - SITE_SECTOR_MARGIN:
				continue
			(buckets[sector] as Array[Vector2i]).append(cell)
	for sector in range(SITE_COUNT):
		var candidates := buckets[sector] as Array[Vector2i]
		Log.assert_crash(not candidates.is_empty(), "InkMonWorldMapData",
			"site sector %d empty (seed %d) - size/distance constants misconfigured" % [sector, seed_value])
		var site_cell := candidates[rng.randi_range(0, candidates.size() - 1)]
		map.landmarks.append({
			"id": "site_%d" % (map.landmarks.size() + 1),
			"coord": site_cell,
			"kind": LANDMARK_SITE,
		})
	# 入口与地标格保持 plain 底 (皮肤上由地标/据点自己画)。
	map._force_plain(map.entry_coord)
	for landmark in map.landmarks:
		map._force_plain(landmark.get("coord", Vector2i.ZERO) as Vector2i)
	# === 河流 (确定性, 不耗 rng): 源头按高程秩降序枚举 ===
	# coast 噪声必须走公共工厂 —— 与 shader 海岸线同源 (codex review High: 各配各的参数会漂)。
	map._trace_rivers(elevation_noise, ridge_noise, make_coast_noise(seed_value))
	return map


static func from_dict(data: Dictionary) -> InkMonWorldMapData:
	var map := InkMonWorldMapData.new()
	map.generation_seed = int(data.get("generation_seed", 0))
	map.region_id = str(data.get("region_id", REGION_EAST_WILDS))
	map.width = int(data.get("width", DEFAULT_WIDTH))
	map.height = int(data.get("height", DEFAULT_HEIGHT))
	var entry := data.get("entry", {}) as Dictionary
	if entry != null and not entry.is_empty():
		map.entry_coord = Vector2i(int(entry.get("q", 0)), int(entry.get("r", 0)))
	var cells := data.get("cells", {}) as Dictionary
	if cells != null:
		map.biome_codes = _read_int_array(cells.get("biome", []) as Array)
		map.elevation_levels = _read_int_array(cells.get("elev", []) as Array)
		map.moisture_levels = _read_int_array(cells.get("moist", []) as Array)
	var expected := map.width * map.height
	Log.assert_crash(map.biome_codes.size() == expected and map.elevation_levels.size() == expected
		and map.moisture_levels.size() == expected, "InkMonWorldMapData",
		"cell arrays size mismatch (expected %d, got %d/%d/%d) - corrupt save"
		% [expected, map.biome_codes.size(), map.elevation_levels.size(), map.moisture_levels.size()])
	var rivers_source := data.get("rivers", []) as Array
	if rivers_source != null:
		for river_value in rivers_source:
			var flat := river_value as Array
			if flat == null or flat.size() < 4:
				continue
			var polyline := PackedVector2Array()
			@warning_ignore("integer_division")
			polyline.resize(flat.size() / 2)
			for point_index in range(polyline.size()):
				polyline[point_index] = Vector2(
					float(int(flat[point_index * 2])) / RIVER_COORD_SCALE,
					float(int(flat[point_index * 2 + 1])) / RIVER_COORD_SCALE)
			map.rivers.append(polyline)
	var landmarks_source := data.get("landmarks", []) as Array
	if landmarks_source != null:
		for landmark_value in landmarks_source:
			var landmark := landmark_value as Dictionary
			if landmark != null:
				map.landmarks.append({
					"id": str(landmark.get("id", "")),
					"coord": Vector2i(int(landmark.get("q", 0)), int(landmark.get("r", 0))),
					"kind": str(landmark.get("kind", "")),
				})
	var revealed_source := data.get("revealed", []) as Array
	if revealed_source != null:
		for revealed_value in revealed_source:
			var revealed := revealed_value as Dictionary
			if revealed != null:
				map.revealed_cells[Vector2i(int(revealed.get("q", 0)), int(revealed.get("r", 0)))] = true
	return map


func to_dict() -> Dictionary:
	# Dictionary 遍历序 = 插入序 (Godot 保证); generate 与 from_dict 都按固定序插入 → to_dict 稳定,
	# roundtrip 深相等成立 (smoke 焊死)。
	var rivers_data: Array = []
	for polyline in rivers:
		var flat: Array[int] = []
		for point in polyline:
			flat.append(roundi(point.x * RIVER_COORD_SCALE))
			flat.append(roundi(point.y * RIVER_COORD_SCALE))
		rivers_data.append(flat)
	var landmarks_data: Array[Dictionary] = []
	for landmark in landmarks:
		var landmark_cell := landmark.get("coord", Vector2i.ZERO) as Vector2i
		landmarks_data.append({
			"id": str(landmark.get("id", "")),
			"q": landmark_cell.x,
			"r": landmark_cell.y,
			"kind": str(landmark.get("kind", "")),
		})
	var revealed_data: Array[Dictionary] = []
	for revealed_key in revealed_cells:
		var revealed_cell := revealed_key as Vector2i
		revealed_data.append({"q": revealed_cell.x, "r": revealed_cell.y})
	return {
		"generation_seed": generation_seed,
		"region_id": region_id,
		"width": width,
		"height": height,
		"entry": {"q": entry_coord.x, "r": entry_coord.y},
		"cells": {
			"biome": Array(biome_codes),
			"elev": Array(elevation_levels),
			"moist": Array(moisture_levels),
		},
		"rivers": rivers_data,
		"landmarks": landmarks_data,
		"revealed": revealed_data,
	}


## 世界边界语义 = odd-r offset 矩形 (屏幕上是真矩形, 不是 axial 斜移平行四边形)。
func in_bounds(coord: Vector2i) -> bool:
	var offset := axial_to_offset(coord)
	return offset.x >= 0 and offset.x < width and offset.y >= 0 and offset.y < height


## 逐格数据下标 (row-major offset 序); 出界返回 -1。
func cell_index(coord: Vector2i) -> int:
	if not in_bounds(coord):
		return -1
	var offset := axial_to_offset(coord)
	return offset.y * width + offset.x


## 界内返回 biome id (BIOME_*); 出界返回 "" (值类型无结果约定)。
func biome_at(coord: Vector2i) -> String:
	var index := cell_index(coord)
	if index < 0:
		return ""
	return BIOME_ORDER[biome_codes[index]]


## 旧 3-kind 地形投影 (battle 皮肤映射域): 界内返回 TERRAIN_*; 出界返回 ""。
func terrain_at(coord: Vector2i) -> String:
	var biome := biome_at(coord)
	if biome == "":
		return ""
	return biome_to_terrain(biome)


## biome → battle 皮肤 3-kind (M2.2 链路: plain→grass / forest→dirt / hill→stone 在战斗侧)。
static func biome_to_terrain(biome: String) -> String:
	match biome:
		BIOME_FOREST:
			return TERRAIN_FOREST
		BIOME_HILL, BIOME_MOUNTAIN:
			return TERRAIN_HILL
	return TERRAIN_PLAIN


## 委托目标候选 = kind 为 site 的地标格。
## 按地标 id 取坐标 (Phase 3 委托目标寻址)。未知 id = 程序 bug (委托单只指向真实地标) → 响亮失败。
func landmark_coord(landmark_id: String) -> Vector2i:
	for landmark in landmarks:
		if str(landmark.get("id", "")) == landmark_id:
			return landmark.get("coord", Vector2i.ZERO) as Vector2i
	Log.assert_crash(false, "InkMonWorldMapData", "unknown landmark id: %s" % landmark_id)
	return Vector2i.ZERO


func get_target_candidates() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for landmark in landmarks:
		if str(landmark.get("kind", "")) == LANDMARK_SITE:
			result.append(landmark.get("coord", Vector2i.ZERO) as Vector2i)
	return result


func reveal_cell(coord: Vector2i) -> void:
	if in_bounds(coord):
		revealed_cells[coord] = true


func is_revealed(coord: Vector2i) -> bool:
	return revealed_cells.has(coord)


func _has_landmark_at(coord: Vector2i) -> bool:
	for landmark in landmarks:
		if (landmark.get("coord", Vector2i.ZERO) as Vector2i) == coord:
			return true
	return false


func _force_plain(coord: Vector2i) -> void:
	var index := cell_index(coord)
	if index >= 0:
		biome_codes[index] = BIOME_ORDER.find(BIOME_PLAIN)


# === 生成内部 (adr/0012) ===


## 场噪声公共工厂 (adr/0012 决定四): 生成入档 cells 与表现层连续场纹理必须同一组噪声 ——
## 两边都从这里拿, 渲染的逐像素地貌与入档格真相同源 (对齐在格中心)。
static func make_elevation_noise(seed_value: int) -> FastNoiseLite:
	return _make_field_noise(seed_value, TERRAIN_NOISE_FREQUENCY, 3, true)


static func make_ridge_noise(seed_value: int) -> FastNoiseLite:
	return _make_field_noise(seed_value + RIDGE_SEED_OFFSET, RIDGE_NOISE_FREQUENCY, 4, true)


static func make_moisture_noise(seed_value: int) -> FastNoiseLite:
	return _make_field_noise(seed_value + MOISTURE_SEED_OFFSET, MOISTURE_NOISE_FREQUENCY, 4, true)


## raw 场公共入口 (供表现层按同一公式烘连续场)。
static func raw_elevation_at(elevation_noise: FastNoiseLite, ridge_noise: FastNoiseLite, plane: Vector2) -> float:
	return _raw_elevation(elevation_noise, ridge_noise, plane)


static func raw_moisture_at(moisture_noise: FastNoiseLite, plane: Vector2) -> float:
	return (moisture_noise.get_noise_2d(plane.x, plane.y) + 1.0) * 0.5


## 海岸噪声工厂 (公共): 河流入海判定与表现层 sheet shader 的海岸线必须同源 —— 两边都从这里拿,
## 保证"河流嘴长在海里"零漂移 (adr/0012 决定三配对点)。warp 开 + 5 octave: 提方差,
## 否则 FBM 挤中间 → 海岸衰减距离趋同 → 轮廓贴成矩形 (shot 踩过)。
static func make_coast_noise(seed_value: int) -> FastNoiseLite:
	return _make_field_noise(seed_value + COAST_SEED_OFFSET, COAST_NOISE_FREQUENCY, 5, true)


## 场噪声工厂: SIMPLEX_SMOOTH + FBM; warped = domain warp 开 (有机地貌边界)。
static func _make_field_noise(seed_value: int, frequency: float, octaves: int, warped: bool) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = seed_value
	noise.frequency = frequency
	noise.fractal_octaves = octaves
	if warped:
		noise.domain_warp_enabled = true
		noise.domain_warp_type = FastNoiseLite.DOMAIN_WARP_SIMPLEX
		noise.domain_warp_amplitude = WARP_AMPLITUDE
		noise.domain_warp_frequency = WARP_FREQUENCY
	return noise


## raw 高程 = FBM 底 + 山脊分量 (ridged: 1-|n| 平方 → 连绵山带而非圆包)。
static func _raw_elevation(elevation_noise: FastNoiseLite, ridge_noise: FastNoiseLite, sample: Vector2) -> float:
	var base01 := (elevation_noise.get_noise_2d(sample.x, sample.y) + 1.0) * 0.5
	var ridge01 := 1.0 - absf(ridge_noise.get_noise_2d(sample.x, sample.y))
	return 0.55 * base01 + 0.55 * ridge01 * ridge01


## 纬度温度 (北冷南暖; 高地降温; 噪声抖动)。row 直接当纬度轴 (offset 行 = 屏幕南北);
## 纬度重映射见 TEMP_LAT_LO/SPAN 注释 (mock 拍板占比, shot 对照校准)。
static func _temperature(row: int, elevation01: float, jitter01: float) -> float:
	var lat01 := TEMP_LAT_LO + TEMP_LAT_SPAN * float(row) / float(maxi(DEFAULT_HEIGHT - 1, 1))
	return clampf(lat01 * TEMP_LAT_SCALE + TEMP_LAT_BIAS - TEMP_ELEV_DROP * (elevation01 - 0.5)
		+ (jitter01 - 0.5) * TEMP_JITTER, 0.0, 1.0)


## biome 查表 (elev/moist 在秩归一域, 阈值即覆盖率; 高程优先 → 气候 → 湿度)。
static func _classify_biome(elevation01: float, moisture01: float, temperature: float) -> int:
	var biome := BIOME_PLAIN
	if elevation01 > BIOME_MOUNTAIN_MIN:
		biome = BIOME_MOUNTAIN
	elif elevation01 > BIOME_HILL_MIN:
		biome = BIOME_HILL
	elif temperature < BIOME_TUNDRA_MAX_T:
		biome = BIOME_TUNDRA
	elif moisture01 > BIOME_FOREST_MIN_M:
		biome = BIOME_FOREST
	elif moisture01 < BIOME_DRY_MAX_M and temperature > BIOME_DRY_MIN_T:
		biome = BIOME_DRY
	return BIOME_ORDER.find(biome)


## 秩归一量化: 值升序排名 (值相等按下标, 全确定性) → 0..QUANT_MAX 均匀铺开。
## 覆盖率跨 seed 稳定 (根治 FBM 分布挤中间导致的"整图全山/全平原"漂移)。
static func _rank_quantize(raw_values: PackedFloat64Array) -> PackedInt32Array:
	var order: Array[int] = []
	order.resize(raw_values.size())
	for index in range(raw_values.size()):
		order[index] = index
	order.sort_custom(func(left: int, right: int) -> bool:
		if raw_values[left] == raw_values[right]:
			return left < right
		return raw_values[left] < raw_values[right])
	var quantized := PackedInt32Array()
	quantized.resize(raw_values.size())
	var denominator := float(maxi(raw_values.size() - 1, 1))
	for rank in range(order.size()):
		quantized[order[rank]] = roundi(float(rank) * float(QUANT_MAX) / denominator)
	return quantized


## hex 邻域低通 (自权 3 + 六邻各 1): 只为 biome 分类场消秩跳变, 值域仍 0..QUANT_MAX 附近。
static func _hex_smooth(values: PackedInt32Array) -> PackedInt32Array:
	var directions: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
		Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]
	var smoothed := PackedInt32Array()
	smoothed.resize(values.size())
	for row in range(DEFAULT_HEIGHT):
		for col in range(DEFAULT_WIDTH):
			var index := row * DEFAULT_WIDTH + col
			var cell := offset_to_axial(col, row)
			var total := values[index] * 3
			var weight := 3
			for direction in directions:
				var neighbor_offset := axial_to_offset(cell + direction)
				if neighbor_offset.x < 0 or neighbor_offset.x >= DEFAULT_WIDTH \
						or neighbor_offset.y < 0 or neighbor_offset.y >= DEFAULT_HEIGHT:
					continue
				total += values[neighbor_offset.y * DEFAULT_WIDTH + neighbor_offset.x]
				weight += 1
			@warning_ignore("integer_division")
			smoothed[index] = total / weight
	return smoothed


## min-max 量化: 线性拉满 0..QUANT_MAX, 保留场的空间平滑 (入档渲染场用;
## 与秩归一分工见 generate 内注释)。
static func _minmax_quantize(raw_values: PackedFloat64Array) -> PackedInt32Array:
	var lowest := INF
	var highest := -INF
	for value in raw_values:
		lowest = minf(lowest, value)
		highest = maxf(highest, value)
	var span := maxf(highest - lowest, 1e-9)
	var quantized := PackedInt32Array()
	quantized.resize(raw_values.size())
	for index in range(raw_values.size()):
		quantized[index] = roundi((raw_values[index] - lowest) / span * float(QUANT_MAX))
	return quantized


## 可玩矩形的平面包围盒 (海岸衰减/河流入海判定共用)。
func _playable_plane_rect() -> Rect2:
	var max_x := float(width - 1) + 0.5
	var max_y := float(height - 1) * sqrt(3.0) / 2.0
	return Rect2(0.0, 0.0, max_x, max_y)


## 某平面点在视觉海岸线语义下是否为海 (公共: smoke 锁河口↔海岸一致性用;
## coast_noise 必须来自 make_coast_noise, 否则失去与 shader 的同源保证)。
func is_visual_sea(plane: Vector2, coast_noise: FastNoiseLite) -> bool:
	return _land_factor(plane, coast_noise) < 0.5


## 离岸小岛参数 (⚠ 与 shader land_factor 的 isle 项成对): 采样点 = sheet 矩形内的
## 缩放偏移重映射 (与 coast 场解相关), 阈值/距离带/岛陆系数三常量两端同值。
const ISLE_UV_SCALE := 0.53
const ISLE_UV_OFFSET := Vector2(0.31, 0.17)
const ISLE_THRESHOLD := 0.72
const ISLE_NEAR := 1.8
const ISLE_FAR_INSET := 0.8
const ISLE_LAND := 0.75


## 陆地系数 (与 shader 海岸公式成对, 见常量块注释): 1 = 腹地, <0.5 = 海。
## 含离岸小岛项 (codex review: 岛若只在 shader, 河口可能撞上视觉岛) —— 河流/河口/smoke
## 与渲染共用同一片海。
func _land_factor(plane: Vector2, coast_noise: FastNoiseLite) -> float:
	var rect := _playable_plane_rect()
	var dx := maxf(maxf(rect.position.x - plane.x, plane.x - rect.end.x), 0.0)
	var dy := maxf(maxf(rect.position.y - plane.y, plane.y - rect.end.y), 0.0)
	var outside := sqrt(dx * dx + dy * dy)
	if outside <= 0.0:
		return 1.0
	var coast01 := (coast_noise.get_noise_2d(plane.x, plane.y) + 1.0) * 0.5
	var land := 1.0 - smoothstep(COAST_FALL_START, OCEAN_MARGIN - 1.0, outside * (COAST_JITTER_BASE + coast01))
	var sheet := rect.grow(OCEAN_MARGIN)
	var isle_plane := sheet.position + (plane - sheet.position) * ISLE_UV_SCALE \
		+ ISLE_UV_OFFSET * sheet.size
	var isle01 := (coast_noise.get_noise_2d(isle_plane.x, isle_plane.y) + 1.0) * 0.5
	if isle01 > ISLE_THRESHOLD and outside >= ISLE_NEAR and outside <= OCEAN_MARGIN - ISLE_FAR_INSET:
		land = maxf(land, ISLE_LAND)
	return land


## 河流追踪: 源头 = 高程秩降序、彼此 spacing 达标的格; 每步走最低势能未访邻格 (可爬坑),
## 入海 (land<0.5) 或汇入已成河即成功。全确定性 (排序 + 固定方向序), 不耗 rng。
func _trace_rivers(elevation_noise: FastNoiseLite, ridge_noise: FastNoiseLite, coast_noise: FastNoiseLite) -> void:
	var order: Array[int] = []
	order.resize(elevation_levels.size())
	for index in range(elevation_levels.size()):
		order[index] = index
	order.sort_custom(func(left: int, right: int) -> bool:
		if elevation_levels[left] == elevation_levels[right]:
			return left < right
		return elevation_levels[left] > elevation_levels[right])
	var accepted_cells: Dictionary = {}
	var sources: Array[Vector2i] = []
	for order_index in order:
		if rivers.size() >= RIVER_MAX_COUNT:
			break
		@warning_ignore("integer_division")
		var source := offset_to_axial(order_index % width, order_index / width)
		var spaced := true
		for existing in sources:
			if _axial_distance(source, existing) < RIVER_SOURCE_SPACING:
				spaced = false
				break
		if not spaced:
			continue
		var polyline := _walk_river(source, elevation_noise, ridge_noise, coast_noise, accepted_cells)
		sources.append(source)
		if polyline.size() >= RIVER_MIN_POINTS:
			rivers.append(polyline)
			for point_index in range(polyline.size()):
				accepted_cells[plane_to_axial(polyline[point_index])] = true


## 单条河从 source 走到海/汇入。探索 = 逐格走最低势能未访邻格 (允许爬出局部坑);
## 成河 = 在探索过的格集合上 BFS 取 source→终点最短链 —— 逃坑期的盆地漫游不进河道
## (否则河变"电路板蛇形", shot 自验踩过)。失败 (步数耗尽/困死) 返回空。
func _walk_river(source: Vector2i, elevation_noise: FastNoiseLite, ridge_noise: FastNoiseLite,
		coast_noise: FastNoiseLite, accepted_cells: Dictionary) -> PackedVector2Array:
	var directions: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
		Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]
	var rect := _playable_plane_rect().grow(OCEAN_MARGIN + 1.0)
	var visited: Dictionary = {source: true}
	var current := source
	var terminal := source
	var reached := false
	for _step in range(RIVER_MAX_STEPS):
		var current_plane := axial_to_plane(current)
		if _land_factor(current_plane, coast_noise) < 0.5 \
				or (accepted_cells.has(current) and current != source):
			terminal = current
			reached = true
			break
		var best := Vector2i.ZERO
		var best_potential := INF
		var found := false
		for direction in directions:
			var neighbor := current + direction
			if visited.has(neighbor):
				continue
			var neighbor_plane := axial_to_plane(neighbor)
			if not rect.has_point(neighbor_plane):
				continue
			var potential := _raw_elevation(elevation_noise, ridge_noise, neighbor_plane) \
				* _land_factor(neighbor_plane, coast_noise)
			if potential < best_potential:
				best_potential = potential
				best = neighbor
				found = true
		if not found:
			return PackedVector2Array()
		current = best
		visited[current] = true
	if not reached:
		return PackedVector2Array()
	# BFS 最短链 (队内序 + 固定方向序 → 全确定性)。
	var queue: Array[Vector2i] = [source]
	var previous: Dictionary = {source: source}
	var cursor := 0
	while cursor < queue.size():
		var cell := queue[cursor]
		cursor += 1
		if cell == terminal:
			break
		for direction in directions:
			var neighbor := cell + direction
			if visited.has(neighbor) and not previous.has(neighbor):
				previous[neighbor] = cell
				queue.append(neighbor)
	if not previous.has(terminal):
		return PackedVector2Array()
	var chain: Array[Vector2i] = []
	var walk_back := terminal
	while true:
		chain.append(walk_back)
		if walk_back == source:
			break
		walk_back = previous[walk_back] as Vector2i
	chain.reverse()
	var path := PackedVector2Array()
	path.resize(chain.size())
	for chain_index in range(chain.size()):
		path[chain_index] = axial_to_plane(chain[chain_index])
	return path


static func _read_int_array(source: Array) -> PackedInt32Array:
	var result := PackedInt32Array()
	if source == null:
		return result
	result.resize(source.size())
	for index in range(source.size()):
		result[index] = int(source[index])
	return result


static func _axial_distance(a: Vector2i, b: Vector2i) -> int:
	return HexCoord.from_axial(a).distance_to(HexCoord.from_axial(b))


## odd-r offset ↔ axial (pointy-top)。offset 空间 = 屏幕对齐的矩形网格 (奇数行右错半格),
## 世界边界/遍历/中心都用它; axial 是存储与距离计算的真相坐标。
static func offset_to_axial(col: int, row: int) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(col - (row - (row & 1)) / 2, row)


static func axial_to_offset(cell: Vector2i) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(cell.x + (cell.y - (cell.y & 1)) / 2, cell.y)


## axial(pointy-top) → 未压扁平面 (hex 间距 = 1 单位)。方向/角度计算的几何真相 ——
## axial 空间本身是斜坐标系, 直接在 (q,r) 上做角度/垂直会歪 30°; view 的 iso squish 是再上一层皮肤变换。
static func axial_to_plane(cell: Vector2i) -> Vector2:
	return Vector2(float(cell.x) + float(cell.y) * 0.5, float(cell.y) * sqrt(3.0) / 2.0)


static func plane_to_axial(plane: Vector2) -> Vector2i:
	var r := plane.y * 2.0 / sqrt(3.0)
	var q := plane.x - r * 0.5
	return Vector2i(int(round(q)), int(round(r)))
