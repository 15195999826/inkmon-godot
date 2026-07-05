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
## adr/0012 生成管线 (A2 拍板 2026-07-05: 噪声源 = mockgen 值噪声, 与用户拍板基准图同族):
## uint32 整数 hash 值噪声 (跨平台位级确定, GPU 复刻可同源) → domain warp → elevation
## (FBM+ridge²) / moisture / 纬度温度(+抖动) → 616 格双域量化 (分类=秩+hex 低通 / 渲染场=minmax)
## → biome 查表; 河流 = 最低势能探索 + BFS 河道。全部入档永久固定。
## ⚠ 场公式与 GPU 场 shader (map_gpu_fields.gdshader) 成对: 常量/公式两端同值,
## 改一处必改另一处 (hash 位级同源, 浮点仅 float64/float32 精度差 = 同源近似口径)。


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
## === mock 场常量 (A2: 与基准图 mockgen 逐字同值; GPU 场 shader 同一组) ===
## 频率按未压扁平面单位 (hex 间距 = 1); 地形入档, 生成只在开档跑一次。
const ELEV_FREQ := 0.13
const ELEV_OCTAVES := 5
const RIDGE_FREQ := 0.085
const RIDGE_OCTAVES := 4
const MOIST_FREQ := 0.09
const MOIST_OCTAVES := 4
const TEMP_NOISE_FREQ := 0.15
const TEMP_NOISE_OCTAVES := 3
const WARP_FREQ := 0.09
const WARP_OCTAVES := 4
const WARP_AMPLITUDE := 2.0
const COAST_FREQ := 0.22
const COAST_OCTAVES := 4
const ISLE_FREQ := 0.30
const ISLE_OCTAVES := 4
const ISLE_THRESHOLD := 0.63
const ISLE_NEAR := 1.8
const ISLE_FAR_INSET := 0.8
const ISLE_LAND := 0.75
## seed 派生偏移 (mock 同值)。
const WARP_X_SEED := 11
const WARP_Y_SEED := 12
const COAST_SEED := 5
const ISLE_SEED := 21
const RIDGE_SEED := 33
const MOIST_SEED := 7
const TEMP_SEED := 9
## 海洋视觉边框 (adr/0012 决定三): 陆地矩形恒陆地, 海岸线长在矩形外 margin 带 (mock 6.5)。
const OCEAN_MARGIN := 6.5
const COAST_FALL_START := 0.6
const COAST_JITTER_BASE := 0.65
## 纬度温度带 (mock): t = lat·1.05 − 0.03 − 0.30·(elev−0.5) + (jitter−0.5)·0.20,
## lat = (y+2)/(PLANE_H+4)。北冷南暖, 高地降温。
const TEMP_LAT_SCALE := 1.05
const TEMP_LAT_BIAS := -0.03
const TEMP_ELEV_DROP := 0.30
const TEMP_JITTER := 0.20
const TEMP_LAT_ANCHOR := 2.0
## 河流 (adr/0012): 源头取高程秩前列、彼此 axial 距离 ≥ SPACING 的格; 逐格走最低势能
## (raw 高程 × 陆地系数), 允许爬出局部坑; 入海或汇入先成河即成, 已访集合 BFS 取河道。
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
## (地形场/biome/河流全走值噪声与确定性排序, 不耗 rng)。
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
	# === 地形场 (adr/0012 决定一; A2 值噪声): raw 场 → 秩归一 → biome 查表 ===
	# 可玩格全在陆地矩形内 (land=1) → mock 的海岸高程压制项恒为 1, 逐格省略。
	var cell_count := DEFAULT_WIDTH * DEFAULT_HEIGHT
	var raw_elevation := PackedFloat64Array()
	var raw_moisture := PackedFloat64Array()
	var jitter01 := PackedFloat64Array()
	raw_elevation.resize(cell_count)
	raw_moisture.resize(cell_count)
	jitter01.resize(cell_count)
	for row in range(DEFAULT_HEIGHT):
		for col in range(DEFAULT_WIDTH):
			var sample := axial_to_plane(offset_to_axial(col, row))
			var warped := warp_plane(sample, seed_value)
			var index := row * DEFAULT_WIDTH + col
			raw_elevation[index] = raw_elevation_at(warped, seed_value)
			raw_moisture[index] = raw_moisture_at(warped, seed_value)
			jitter01[index] = temperature_noise_at(sample, seed_value)
	# 双域量化: biome 分类走秩归一+hex 低通 (覆盖率稳定+地貌成片); 入档渲染场走 min-max (空间平滑)。
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
			var temperature := _temperature(sample.y, elevation01, jitter01[index])
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
	map._trace_rivers()
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


# === 值噪声与场 (A2: mock 逐字同源; ⚠ 与 map_gpu_fields.gdshader 成对) ===


## uint32 整数 hash → [0,1)。跨平台位级确定 (int64 掩码模拟 uint32 wrap, 与 numpy/GLSL 同余)。
static func _hash01(ix: int, iy: int, seed_value: int) -> float:
	var h := ((ix * 2654435761) & 0xFFFFFFFF) ^ ((iy * 2246822519) & 0xFFFFFFFF) \
		^ ((seed_value * 3266489917) & 0xFFFFFFFF)
	h = ((h ^ (h >> 13)) * 668265263) & 0xFFFFFFFF
	h = h ^ (h >> 15)
	return float(h & 0xFFFFFF) / 16777216.0


static func _vnoise(x: float, y: float, seed_value: int) -> float:
	var x0f := floorf(x)
	var y0f := floorf(y)
	var fx := x - x0f
	var fy := y - y0f
	var ix := int(x0f)
	var iy := int(y0f)
	var u := fx * fx * (3.0 - 2.0 * fx)
	var v := fy * fy * (3.0 - 2.0 * fy)
	var n00 := _hash01(ix, iy, seed_value)
	var n10 := _hash01(ix + 1, iy, seed_value)
	var n01 := _hash01(ix, iy + 1, seed_value)
	var n11 := _hash01(ix + 1, iy + 1, seed_value)
	return (n00 * (1.0 - u) + n10 * u) * (1.0 - v) + (n01 * (1.0 - u) + n11 * u) * v


static func value_fbm(plane: Vector2, seed_value: int, freq: float, octaves: int) -> float:
	var total := 0.0
	var amp := 1.0
	var f := freq
	var norm := 0.0
	for octave in range(octaves):
		total += _vnoise(plane.x * f, plane.y * f, seed_value + octave * 131) * amp
		norm += amp
		amp *= 0.5
		f *= 2.0
	return total / norm


## domain warp (mock: W = P + 2·(fbm−0.5)·2): 有机地貌边界的来源。
static func warp_plane(plane: Vector2, seed_value: int) -> Vector2:
	var wx := value_fbm(plane, seed_value + WARP_X_SEED, WARP_FREQ, WARP_OCTAVES) * 2.0 - 1.0
	var wy := value_fbm(plane, seed_value + WARP_Y_SEED, WARP_FREQ, WARP_OCTAVES) * 2.0 - 1.0
	return plane + Vector2(wx, wy) * WARP_AMPLITUDE


## raw 高程 (warped 坐标; FBM 底 + 山脊分量 ridge² → 连绵山带)。不含海岸压制 (调用方乘 land 项)。
static func raw_elevation_at(warped: Vector2, seed_value: int) -> float:
	var base01 := value_fbm(warped, seed_value, ELEV_FREQ, ELEV_OCTAVES)
	var ridge01 := 1.0 - absf(2.0 * value_fbm(warped, seed_value + RIDGE_SEED, RIDGE_FREQ, RIDGE_OCTAVES) - 1.0)
	return clampf(0.55 * base01 + 0.55 * ridge01 * ridge01, 0.0, 1.0)


static func raw_moisture_at(warped: Vector2, seed_value: int) -> float:
	return value_fbm(Vector2(warped.x * 0.95, warped.y), seed_value + MOIST_SEED, MOIST_FREQ, MOIST_OCTAVES)


## 温度抖动场 (未 warp 坐标, mock 同款)。
static func temperature_noise_at(plane: Vector2, seed_value: int) -> float:
	return value_fbm(plane, seed_value + TEMP_SEED, TEMP_NOISE_FREQ, TEMP_NOISE_OCTAVES)


## 陆地矩形 (mock PLANE_W = 宽+0.5): 格中心全在其内 → 可玩格恒陆地; 海岸衰减从矩形边起算。
func land_plane_rect() -> Rect2:
	return Rect2(0.0, 0.0, float(width) + 0.5, float(height - 1) * sqrt(3.0) / 2.0)


## 陆地系数 (mock 公式; 含离岸小岛): 1 = 腹地, <0.5 = 海。河流入海判定与渲染共用同一片海。
func land_factor_at(plane: Vector2) -> float:
	var rect := land_plane_rect()
	var dx := maxf(maxf(rect.position.x - plane.x, plane.x - rect.end.x), 0.0)
	var dy := maxf(maxf(rect.position.y - plane.y, plane.y - rect.end.y), 0.0)
	var outside := sqrt(dx * dx + dy * dy)
	if outside <= 0.0:
		return 1.0
	var warped := warp_plane(plane, generation_seed)
	var coast_jit := COAST_JITTER_BASE + value_fbm(warped, generation_seed + COAST_SEED, COAST_FREQ, COAST_OCTAVES)
	var land := 1.0 - smoothstep(COAST_FALL_START, OCEAN_MARGIN - 1.0, outside * coast_jit)
	var isle01 := value_fbm(warped, generation_seed + ISLE_SEED, ISLE_FREQ, ISLE_OCTAVES)
	if isle01 > ISLE_THRESHOLD and outside > ISLE_NEAR and outside < OCEAN_MARGIN - ISLE_FAR_INSET:
		land = maxf(land, ISLE_LAND)
	return land


## 某平面点在视觉海岸线语义下是否为海 (smoke 锁河口↔海岸一致性用)。
func is_visual_sea(plane: Vector2) -> bool:
	return land_factor_at(plane) < 0.5


## 纬度温度 (mock: lat 锚 (y+2)/(PLANE_H+4); 高地降温; 噪声抖动)。
static func _temperature(plane_y: float, elevation01: float, jitter01: float) -> float:
	var plane_h := float(DEFAULT_HEIGHT - 1) * sqrt(3.0) / 2.0
	var lat01 := clampf((plane_y + TEMP_LAT_ANCHOR) / (plane_h + TEMP_LAT_ANCHOR * 2.0), 0.0, 1.0)
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


## min-max 量化: 线性拉满 0..QUANT_MAX, 保留场的空间平滑 (入档渲染场用)。
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


## 河流追踪: 源头 = 高程秩降序、彼此 spacing 达标的格; 每步走最低势能未访邻格 (可爬坑),
## 入海 (land<0.5) 或汇入已成河即成功。全确定性 (排序 + 固定方向序), 不耗 rng。
func _trace_rivers() -> void:
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
		var polyline := _walk_river(source, accepted_cells)
		sources.append(source)
		if polyline.size() >= RIVER_MIN_POINTS:
			rivers.append(polyline)
			for point_index in range(polyline.size()):
				accepted_cells[plane_to_axial(polyline[point_index])] = true


## 单条河从 source 走到海/汇入。探索 = 逐格走最低势能未访邻格 (允许爬出局部坑);
## 成河 = 在探索过的格集合上 BFS 取 source→终点最短链。失败 (步数耗尽/困死) 返回空。
## 势能 memo 按格缓存 (值噪声场每次采样 ~30 次 vnoise, 不缓存河流追踪会秒级)。
func _walk_river(source: Vector2i, accepted_cells: Dictionary) -> PackedVector2Array:
	var directions: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
		Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]
	var rect := land_plane_rect().grow(OCEAN_MARGIN + 1.0)
	var visited: Dictionary = {source: true}
	var potential_memo: Dictionary = {}
	var land_memo: Dictionary = {}
	var current := source
	var terminal := source
	var reached := false
	for _step in range(RIVER_MAX_STEPS):
		var current_plane := axial_to_plane(current)
		if _land_memoized(current, current_plane, land_memo) < 0.5 \
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
			var potential: float
			if potential_memo.has(neighbor):
				potential = potential_memo[neighbor]
			else:
				potential = raw_elevation_at(warp_plane(neighbor_plane, generation_seed), generation_seed) \
					* _land_memoized(neighbor, neighbor_plane, land_memo)
				potential_memo[neighbor] = potential
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


func _land_memoized(cell: Vector2i, plane: Vector2, memo: Dictionary) -> float:
	if memo.has(cell):
		return memo[cell]
	var land := land_factor_at(plane)
	memo[cell] = land
	return land


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
## axial 空间本身是斜坐标系, 直接在 (q,r) 上做角度/垂直会歪 30°; view 的缩放是再上一层皮肤变换。
static func axial_to_plane(cell: Vector2i) -> Vector2:
	return Vector2(float(cell.x) + float(cell.y) * 0.5, float(cell.y) * sqrt(3.0) / 2.0)


static func plane_to_axial(plane: Vector2) -> Vector2i:
	var r := plane.y * 2.0 / sqrt(3.0)
	var q := plane.x - r * 0.5
	return Vector2i(int(round(q)), int(round(r)))
