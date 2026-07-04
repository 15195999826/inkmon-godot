class_name InkMonWorldMapData
extends RefCounted
## 世界大地图地理 (P2 拍板, glossary §4.9): 开档 new_game 一次生成、永久固定、进据点档。
##
## 只存地理 (地形 / 地标 / 持久点亮迷雾); 趟内节点图与趟内视野住 InkMonMissionState (transient, 不在本类)。
## 刻意不进 GI grid 机器 (不占 WorldGameplayInstance.grid / 不参与 astar/占格) —— 出征大地图的逻辑
## 真相是趟内节点图, 本类只是节点图长在其上的固定地理底 (main-game-architecture §9 双 grid 现状不动)。
## 序列化风格对齐 InkMonPlayerActor: static from_dict / 实例 to_dict / `as Dictionary` null guard /
## 数值一律 int() 归一 (存档经 JSON 后整数变 float, 归一保 roundtrip 深相等)。


## v1 唯一区域 (多区域 = Phase 5+)。
const REGION_EAST_WILDS := "east_wilds"
const DEFAULT_WIDTH := 28
const DEFAULT_HEIGHT := 22
## 地形 kind (v1 纯皮肤语义)。plain 是默认底 —— terrain 字典只存非 plain 的稀疏格。
const TERRAIN_PLAIN := "plain"
const TERRAIN_FOREST := "forest"
const TERRAIN_HILL := "hill"
## 地形噪声 ("完整地形图"拍板 2026-07-05: 地貌连续成片, hex 只是叠加网格边界, 不是色块拼凑):
## 频率按未压扁平面单位 (世界宽 ~39 单位 → 特征尺度 ~8 单位, 一图 4-5 个地貌团)。
## 地形入档, 噪声只在开档跑一次 —— 跨平台浮点漂移不影响已有档。
const TERRAIN_NOISE_FREQUENCY := 0.13
const HILL_THRESHOLD := 0.34
const FOREST_THRESHOLD := 0.22
## vegetation 噪声的 seed 派生偏移 (与 elevation 噪声独立, 林区不贴着丘陵长)。
const VEGETATION_SEED_OFFSET := 7919
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
## 稀疏地形: Vector2i(axial q, r) -> TERRAIN_* (不含 plain)。
var terrain: Dictionary = {}
## 地标: {id: String, coord: Vector2i, kind: String}。
var landmarks: Array[Dictionary] = []
## 持久点亮 (跨趟累积, 进存档): Vector2i -> true。趟内视野是另一层, 住 MissionState (P2 迷雾两层)。
var revealed_cells: Dictionary = {}


## 开档一次性生成 (同 seed 同图, 确定性)。v1: 矩形区域 + 连续噪声地貌 (成片林区/丘陵带) +
## 出生点靠中心随机 + 3 个目标地标按方向扇区散布四方 (每趟出征方向天然多样, "像一个世界")。
## 皮肤质量 (走廊寻形 / 区域生态 / 多区域) = Phase 5+, 数据形状以本类为准先钉死。
## rng 消耗序钉死 (同 seed 同图): ① entry jitter ② 扇区相位 ③ 逐扇区挑 site (地形走噪声不耗 rng)。
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
	# 地形 = 两张独立 FBM 噪声按未压扁平面坐标采样 (axial 斜坐标直接采样会把地貌团剪切拉斜):
	# elevation 高段 → 丘陵带; vegetation 高段 (且非丘陵) → 林区。
	var elevation_noise := FastNoiseLite.new()
	elevation_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	elevation_noise.seed = seed_value
	elevation_noise.frequency = TERRAIN_NOISE_FREQUENCY
	elevation_noise.fractal_octaves = 3
	var vegetation_noise := FastNoiseLite.new()
	vegetation_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	vegetation_noise.seed = seed_value + VEGETATION_SEED_OFFSET
	vegetation_noise.frequency = TERRAIN_NOISE_FREQUENCY
	vegetation_noise.fractal_octaves = 3
	for row in range(DEFAULT_HEIGHT):
		for col in range(DEFAULT_WIDTH):
			var cell := offset_to_axial(col, row)
			if cell == map.entry_coord:
				continue
			var sample := axial_to_plane(cell)
			if elevation_noise.get_noise_2d(sample.x, sample.y) > HILL_THRESHOLD:
				map.terrain[cell] = TERRAIN_HILL
			elif vegetation_noise.get_noise_2d(sample.x, sample.y) > FOREST_THRESHOLD:
				map.terrain[cell] = TERRAIN_FOREST
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
		# 地标格保持 plain 底 (皮肤上由地标自己画)。
		map.terrain.erase(site_cell)
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
	var terrain_source := data.get("terrain", []) as Array
	if terrain_source != null:
		for cell_value in terrain_source:
			var cell := cell_value as Dictionary
			if cell != null:
				map.terrain[Vector2i(int(cell.get("q", 0)), int(cell.get("r", 0)))] = str(cell.get("t", TERRAIN_PLAIN))
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
	var terrain_data: Array[Dictionary] = []
	for terrain_key in terrain:
		var terrain_cell := terrain_key as Vector2i
		terrain_data.append({"q": terrain_cell.x, "r": terrain_cell.y, "t": str(terrain[terrain_key])})
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
		"terrain": terrain_data,
		"landmarks": landmarks_data,
		"revealed": revealed_data,
	}


## 世界边界语义 = odd-r offset 矩形 (屏幕上是真矩形, 不是 axial 斜移平行四边形)。
func in_bounds(coord: Vector2i) -> bool:
	var offset := axial_to_offset(coord)
	return offset.x >= 0 and offset.x < width and offset.y >= 0 and offset.y < height


## 界内返回地形 kind (默认 plain); 出界返回 "" (值类型无结果约定)。
func terrain_at(coord: Vector2i) -> String:
	if not in_bounds(coord):
		return ""
	return str(terrain.get(coord, TERRAIN_PLAIN))


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
