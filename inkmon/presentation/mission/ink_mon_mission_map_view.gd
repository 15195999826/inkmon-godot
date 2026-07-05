class_name InkMonMissionMapView
extends Node2D
## 出征大地图 view (P2: 逻辑真相 = 趟内节点图快照; adr/0012: 地形是一张"地图纸")。
##
## 只画 + 报点击, 不持 IWorldQuery / 不 submit (表演层 routing 规则: root 接线)。
## 数据源 = root 推入的两份值拷贝快照 (get_mission_snapshot / get_world_map_snapshot);
## 本 view 不持任何逻辑层引用。
##
## 渲染分层 (adr/0012 决定四): 地形 = InkMonMissionMapSheet 子节点 (shader 逐像素上色,
## CPU 只烘 biome/elev/moist 数据纹理 + coast/warp/mottle 辅助场纹理, 每世界一次);
## 本节点 _draw 依次叠 河流 polyline → 迷雾 → 地标旗 → 走廊 → 节点 → 棋子。
## hex 格线与矩形描边已按拍板删除 ("大地图就是世界地图", 交互高亮不靠格线)。
## 风格 (决定五) = InkMonMapStylePresets 预设整组下发 shader uniform, set_map_style 即时切换。


signal node_clicked(node_id: int)


const HEX_SIZE := 20.0
## 2:1 等轴纵向压扁 (对齐 render2d 字典: squish 0.5 ↔ pitch 30°)。
const ISO_SQUISH := 0.5
## 迷雾遮罩烘焙分辨率 (px per view-plane px): 低分辨率 + LINEAR 放大 → 柔和雾缘。
const FOG_BAKE_SCALE := 0.35
## 连续场纹理分辨率 (px per 平面单位): 渲染真相 = 连续场逐像素 (mock 同法, adr/0012 决定四),
## 起伏/过渡的细节密度由它决定 —— 616 格放大出不来 3D 起伏感 (用户验收踩过)。
const FIELD_BAKE_PX_PER_UNIT := 8.0
## 分位 CDF LUT 宽度: raw 归一值 → 秩01, biome 阈值的覆盖率语义靠它与逻辑层同域。
const CDF_LUT_WIDTH := 256
const NODE_RADIUS := 10.0
const FIT_MARGIN := 48.0
const PIECE_SPEED := 420.0
const RIVER_WIDTH_UNDER := 5.0
const RIVER_WIDTH_CORE := 2.4

const COLOR_EDGE_UNDER := Color(0.05, 0.06, 0.07, 0.55)
const COLOR_EDGE := Color(0.62, 0.59, 0.50, 0.75)
const COLOR_EDGE_NEXT := Color(0.98, 0.92, 0.55, 0.95)
const COLOR_NODE := Color(0.78, 0.77, 0.72)
const COLOR_NODE_VISITED := Color(0.45, 0.45, 0.43)
const COLOR_NODE_NEXT := Color(1.0, 0.95, 0.6)
const COLOR_NODE_START := Color(0.55, 0.8, 0.55)
const COLOR_NODE_TARGET := Color(1.0, 0.78, 0.25)
## 野群战斗节点 (M2.1): 未访红, 走过退灰; 可达性由亮金走廊边表达, 不占节点色。
const COLOR_NODE_BATTLE := Color(0.85, 0.42, 0.36)
const COLOR_NODE_RIM := Color(0.08, 0.09, 0.10, 0.9)
const COLOR_PIECE := Color(0.3, 0.65, 0.95)
const COLOR_SITE_MARK := Color(1.0, 0.65, 0.15)
## 非本趟目标的地标旗 (画出全部地标 = 世界上还有别的方向可去)。
const COLOR_SITE_IDLE := Color(0.72, 0.58, 0.36, 0.85)
## 迷雾三态 (Phase 4, war3 拍板): 黑 = 从未点亮 (近全遮), 灰 = 持久 revealed (半透), 亮 = 视野圆。
const COLOR_FOG_DARK := Color(0.03, 0.035, 0.045, 0.97)
const COLOR_FOG_GRAY := Color(0.04, 0.045, 0.055, 0.55)
## seen 灰态节点 (Q4.5 最后所见快照) 的暗化系数与 "?" 节点色。
const SEEN_NODE_DIM := 0.55
const COLOR_NODE_UNKNOWN := Color(0.62, 0.6, 0.55)

## 苔藓斑驳噪声 seed 派生 (纯表现层美学场, 与逻辑层无配对关系)。
const MOTTLE_SEED_OFFSET := 424267


var _mission: Dictionary = {}
var _landmarks: Array[Dictionary] = []
var _map_width := 0
var _map_height := 0
var _generation_seed := 0
var _biome_codes := PackedInt32Array()
var _elevation_levels := PackedInt32Array()
var _moisture_levels := PackedInt32Array()
var _rivers: Array[PackedVector2Array] = []
var _target_site := Vector2i.ZERO
var _piece_pos := Vector2.ZERO
var _piece_target := Vector2.ZERO
var _piece_placed := false
## 地图纸子节点 (地理开档固定 → 数据纹理 hash 缓存, 一趟只烘一次)。
var _sheet: InkMonMissionMapSheet = null
var _sheet_view_rect := Rect2()
var _map_bake_hash := 0
## 当前风格 (adr/0012 决定五; root 从 user:// 偏好初始化)。
var map_style_id := InkMonMapStylePresets.DEFAULT_STYLE
var _style_preset: Dictionary = InkMonMapStylePresets.preset(InkMonMapStylePresets.DEFAULT_STYLE)
## 迷雾遮罩 (Phase 4): 视野每步变 → 每次 refresh 重烘 (低分辨率, 毫秒级)。
var _fog_texture: ImageTexture = null
var _revealed_lookup: Dictionary = {}
var _sight_range := 0
var _sight_center := Vector2i.ZERO


func _init() -> void:
	# 迷雾低分辨率遮罩靠 LINEAR 放大融成柔和雾缘 (显式钉死不赌主题)。
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sheet = InkMonMissionMapSheet.new()
	_sheet.name = "MapSheet"
	add_child(_sheet)


## root 推入两份快照 (出征开始 / 每步 progressed 后调)。
func refresh(mission_snapshot: Dictionary, world_map_snapshot: Dictionary) -> void:
	_mission = mission_snapshot
	_map_width = int(world_map_snapshot.get("width", 0))
	_map_height = int(world_map_snapshot.get("height", 0))
	_generation_seed = int(world_map_snapshot.get("generation_seed", 0))
	var cells := world_map_snapshot.get("cells", {}) as Dictionary
	if cells != null:
		_biome_codes = _to_int_array(cells.get("biome", []) as Array)
		_elevation_levels = _to_int_array(cells.get("elev", []) as Array)
		_moisture_levels = _to_int_array(cells.get("moist", []) as Array)
	_rivers.clear()
	var rivers_source := world_map_snapshot.get("rivers", []) as Array
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
					float(int(flat[point_index * 2])) / InkMonWorldMapData.RIVER_COORD_SCALE,
					float(int(flat[point_index * 2 + 1])) / InkMonWorldMapData.RIVER_COORD_SCALE)
			_rivers.append(polyline)
	_landmarks.clear()
	var landmarks_source := world_map_snapshot.get("landmarks", []) as Array
	if landmarks_source != null:
		for landmark_value in landmarks_source:
			var landmark := landmark_value as Dictionary
			if landmark != null:
				_landmarks.append({
					"coord": Vector2i(int(landmark.get("q", 0)), int(landmark.get("r", 0))),
					"kind": str(landmark.get("kind", "")),
				})
	_target_site = _mission.get("target_site_coord", Vector2i.ZERO) as Vector2i
	# 迷雾数据 (Phase 4): 持久点亮集 + 当前视野圆; 视野每步变 → 雾罩每次重烘。
	_revealed_lookup.clear()
	var revealed_source := world_map_snapshot.get("revealed", []) as Array
	if revealed_source != null:
		for revealed_value in revealed_source:
			var revealed := revealed_value as Dictionary
			if revealed != null:
				_revealed_lookup[Vector2i(int(revealed.get("q", 0)), int(revealed.get("r", 0)))] = true
	_sight_range = int(_mission.get("sight_range", 0))
	_sight_center = _mission.get("current_coord", Vector2i.ZERO) as Vector2i
	# cache key 含逐格数据本体 (codex review Medium: 渲染数据真相是 cells 不是 seed,
	# 同 seed 异 cells 的档不能复用旧纹理)。
	var bake_hash := hash([_map_width, _map_height, _generation_seed,
		_biome_codes, _elevation_levels, _moisture_levels])
	if bake_hash != _map_bake_hash:
		_map_bake_hash = bake_hash
		_rebuild_sheet()
	_bake_fog_texture()
	_fit_to_viewport()
	var current_pos := _node_plane_pos(int(_mission.get("current_node_id", 0)))
	if _piece_placed:
		_piece_target = current_pos
	else:
		_piece_pos = current_pos
		_piece_target = current_pos
		_piece_placed = true
	queue_redraw()


## 风格切换 (adr/0012 决定五): 纯 uniform 下发, 不重烘数据纹理, 即时生效。
func set_map_style(style_id: String) -> void:
	map_style_id = style_id
	_style_preset = InkMonMapStylePresets.preset(style_id)
	_apply_style_uniforms()
	queue_redraw()


## 测试/交互友好: 节点的屏幕坐标 (UI smoke 用它算点击点)。
func node_screen_position(node_id: int) -> Vector2:
	return get_global_transform_with_canvas() * _node_plane_pos(node_id)


func _process(delta: float) -> void:
	if _piece_pos.distance_to(_piece_target) > 0.5:
		_piece_pos = _piece_pos.move_toward(_piece_target, PIECE_SPEED * delta)
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _mission.is_empty() or not visible:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	# 用事件自带坐标转本地(make_input_local), 不依赖 viewport 鼠标态 —— push_input 注入(UI smoke)同样可靠。
	var local := (make_input_local(mouse_event) as InputEventMouseButton).position
	var next_ids := _next_ids()
	for node in _nodes():
		var node_id := int(node.get("id", -1))
		if not next_ids.has(node_id):
			continue
		if local.distance_to(_node_plane_pos(node_id)) <= NODE_RADIUS * 1.6:
			node_clicked.emit(node_id)
			get_viewport().set_input_as_handled()
			return


func _draw() -> void:
	if _mission.is_empty():
		return
	# 地形 = _sheet 子节点 (show_behind_parent, 永远垫底); 此处从河流层开始往上叠。
	_draw_rivers()
	# 迷雾层 (Phase 4): 盖在地形/河流之上 (黑区一起吞, war3 纯黑); 图元层画在雾上。
	if _fog_texture != null:
		draw_texture_rect(_fog_texture, _sheet_view_rect, false)
	_draw_landmarks()
	_draw_corridors()
	_draw_nodes()
	# 玩家棋子 (补间位): 白描边 + 本色。
	draw_circle(_piece_pos, NODE_RADIUS * 0.72, Color(0.95, 0.96, 0.98))
	draw_circle(_piece_pos, NODE_RADIUS * 0.55, COLOR_PIECE)


# === 地图纸 (adr/0012 决定四): 数据纹理 + 辅助场纹理 + uniform 下发 ===


## 可玩世界的平面矩形 (未压扁平面单位; 与 InkMonWorldMapData._playable_plane_rect 同几何)。
func _playable_plane_rect() -> Rect2:
	return Rect2(0.0, 0.0, float(_map_width - 1) + 0.5, float(_map_height - 1) * sqrt(3.0) / 2.0)


## sheet 平面矩形 = 可玩矩形四周加海洋边框带 (决定三)。
func _sheet_plane_rect() -> Rect2:
	return _playable_plane_rect().grow(InkMonWorldMapData.OCEAN_MARGIN)


## 平面单位 → view 坐标 (含 HEX 缩放 + iso squish)。与 _axial_to_plane 同一变换:
## view = HEX_SIZE·√3 · (plane.x, squish·plane.y)。
func _plane_to_view(plane: Vector2) -> Vector2:
	var scale_factor := HEX_SIZE * sqrt(3.0)
	return Vector2(plane.x * scale_factor, plane.y * scale_factor * ISO_SQUISH)


func _plane_rect_to_view(rect: Rect2) -> Rect2:
	var top_left := _plane_to_view(rect.position)
	var bottom_right := _plane_to_view(rect.end)
	return Rect2(top_left, bottom_right - top_left)


## 世界变化 (开档/换档) 时重烘连续场纹理 + CDF LUT + 下发矩形/分类 uniform + 当前风格。
func _rebuild_sheet() -> void:
	if _map_width <= 0 or _map_height <= 0 or _biome_codes.is_empty():
		_sheet.set_sheet_rect(Rect2())
		_sheet_view_rect = Rect2()
		return
	var play_rect := _playable_plane_rect()
	var sheet_rect := _sheet_plane_rect()
	_sheet_view_rect = _plane_rect_to_view(sheet_rect)
	_sheet.set_sheet_rect(_sheet_view_rect)
	# 可玩格中心的 raw 场样本: min-max 归一范围与 CDF (分位) 都从它来 —— 与 generate 的
	# 量化/秩域同一批采样点, 渲染分类与入档 cells 对齐在格中心 (亚格细节纯视觉发散)。
	var cell_raws := _sample_cell_raw_fields()
	var elev_raws := cell_raws.get("elev") as PackedFloat64Array
	var moist_raws := cell_raws.get("moist") as PackedFloat64Array
	var elev_range := _raw_range(elev_raws)
	var moist_range := _raw_range(moist_raws)
	_sheet.set_sheet_uniform("field_tex", _bake_field_texture(sheet_rect, elev_range, moist_range))
	_sheet.set_sheet_uniform("cdf_tex", _bake_cdf_texture(elev_raws, moist_raws, elev_range, moist_range))
	_sheet.set_sheet_uniform("sheet_origin", sheet_rect.position)
	_sheet.set_sheet_uniform("sheet_size", sheet_rect.size)
	_sheet.set_sheet_uniform("play_origin", play_rect.position)
	_sheet.set_sheet_uniform("play_size", play_rect.size)
	_sheet.set_sheet_uniform("ocean_margin", InkMonWorldMapData.OCEAN_MARGIN)
	# biome 阈值/纬度温度常量单一来源 = 数据类 (分类语义两端同域)。
	_sheet.set_sheet_uniform("biome_mountain_min", InkMonWorldMapData.BIOME_MOUNTAIN_MIN)
	_sheet.set_sheet_uniform("biome_hill_min", InkMonWorldMapData.BIOME_HILL_MIN)
	_sheet.set_sheet_uniform("biome_tundra_max_t", InkMonWorldMapData.BIOME_TUNDRA_MAX_T)
	_sheet.set_sheet_uniform("biome_forest_min_m", InkMonWorldMapData.BIOME_FOREST_MIN_M)
	_sheet.set_sheet_uniform("biome_dry_max_m", InkMonWorldMapData.BIOME_DRY_MAX_M)
	_sheet.set_sheet_uniform("biome_dry_min_t", InkMonWorldMapData.BIOME_DRY_MIN_T)
	_sheet.set_sheet_uniform("temp_lat_lo", InkMonWorldMapData.TEMP_LAT_LO)
	_sheet.set_sheet_uniform("temp_lat_span", InkMonWorldMapData.TEMP_LAT_SPAN)
	_sheet.set_sheet_uniform("temp_lat_scale", InkMonWorldMapData.TEMP_LAT_SCALE)
	_sheet.set_sheet_uniform("temp_lat_bias", InkMonWorldMapData.TEMP_LAT_BIAS)
	_sheet.set_sheet_uniform("temp_elev_drop", InkMonWorldMapData.TEMP_ELEV_DROP)
	_apply_style_uniforms()


## 可玩格中心 raw 场采样 (与 generate 同噪声同公式同采样点)。
func _sample_cell_raw_fields() -> Dictionary:
	var elevation_noise := InkMonWorldMapData.make_elevation_noise(_generation_seed)
	var ridge_noise := InkMonWorldMapData.make_ridge_noise(_generation_seed)
	var moisture_noise := InkMonWorldMapData.make_moisture_noise(_generation_seed)
	var elev_raws := PackedFloat64Array()
	var moist_raws := PackedFloat64Array()
	elev_raws.resize(_map_width * _map_height)
	moist_raws.resize(_map_width * _map_height)
	for row in range(_map_height):
		for col in range(_map_width):
			var plane := InkMonWorldMapData.axial_to_plane(InkMonWorldMapData.offset_to_axial(col, row))
			var index := row * _map_width + col
			elev_raws[index] = InkMonWorldMapData.raw_elevation_at(elevation_noise, ridge_noise, plane)
			moist_raws[index] = InkMonWorldMapData.raw_moisture_at(moisture_noise, plane)
	return {"elev": elev_raws, "moist": moist_raws}


static func _raw_range(raw_values: PackedFloat64Array) -> Vector2:
	var lowest := INF
	var highest := -INF
	for value in raw_values:
		lowest = minf(lowest, value)
		highest = maxf(highest, value)
	return Vector2(lowest, maxf(highest - lowest, 1e-9))


## 连续场纹理 (sheet 矩形域, 与 shader UV 同映射): r = elev_raw 归一 (hillshade/雪顶的连续真相),
## g = moist_raw 归一, b = coast01 (⚠ 与河流生成同一 FastNoiseLite —— make_coast_noise,
## 海岸线/河口零漂移), a = 苔藓斑驳。~8 万像素, 每世界一次, 亚秒级。
func _bake_field_texture(sheet_rect: Rect2, elev_range: Vector2, moist_range: Vector2) -> ImageTexture:
	var elevation_noise := InkMonWorldMapData.make_elevation_noise(_generation_seed)
	var ridge_noise := InkMonWorldMapData.make_ridge_noise(_generation_seed)
	var moisture_noise := InkMonWorldMapData.make_moisture_noise(_generation_seed)
	var coast_noise := InkMonWorldMapData.make_coast_noise(_generation_seed)
	var mottle_noise := _make_mottle_noise(_generation_seed + MOTTLE_SEED_OFFSET)
	var image_width := maxi(8, int(ceil(sheet_rect.size.x * FIELD_BAKE_PX_PER_UNIT)))
	var image_height := maxi(8, int(ceil(sheet_rect.size.y * FIELD_BAKE_PX_PER_UNIT)))
	var image := Image.create(image_width, image_height, false, Image.FORMAT_RGBA8)
	for py in range(image_height):
		for px in range(image_width):
			var plane := sheet_rect.position + Vector2(
				(float(px) + 0.5) / FIELD_BAKE_PX_PER_UNIT, (float(py) + 0.5) / FIELD_BAKE_PX_PER_UNIT)
			var elev_raw := InkMonWorldMapData.raw_elevation_at(elevation_noise, ridge_noise, plane)
			var moist_raw := InkMonWorldMapData.raw_moisture_at(moisture_noise, plane)
			image.set_pixel(px, py, Color(
				clampf((elev_raw - elev_range.x) / elev_range.y, 0.0, 1.0),
				clampf((moist_raw - moist_range.x) / moist_range.y, 0.0, 1.0),
				(coast_noise.get_noise_2d(plane.x, plane.y) + 1.0) * 0.5,
				(mottle_noise.get_noise_2d(plane.x, plane.y) + 1.0) * 0.5))
	return ImageTexture.create_from_image(image)


## 分位 CDF LUT (256×1, r = elev / g = moist): raw 归一值 → 秩01。shader 用它把连续场
## 换回覆盖率语义再过 biome 阈值 —— mock 的 per-pixel percentile 同款 (adr/0012 决定一)。
func _bake_cdf_texture(elev_raws: PackedFloat64Array, moist_raws: PackedFloat64Array,
		elev_range: Vector2, moist_range: Vector2) -> ImageTexture:
	var sorted_elev := elev_raws.duplicate()
	var sorted_moist := moist_raws.duplicate()
	sorted_elev.sort()
	sorted_moist.sort()
	var image := Image.create(CDF_LUT_WIDTH, 1, false, Image.FORMAT_RGBA8)
	for lut_x in range(CDF_LUT_WIDTH):
		var fraction := float(lut_x) / float(CDF_LUT_WIDTH - 1)
		image.set_pixel(lut_x, 0, Color(
			_rank01_of(sorted_elev, elev_range.x + elev_range.y * fraction),
			_rank01_of(sorted_moist, moist_range.x + moist_range.y * fraction),
			0.0, 1.0))
	return ImageTexture.create_from_image(image)


## 升序数组内 raw 值的秩01 (≤raw 的样本数-1 / n-1, 对齐 _rank_quantize 语义)。
static func _rank01_of(sorted_values: PackedFloat64Array, raw_value: float) -> float:
	var low := 0
	var high := sorted_values.size()
	while low < high:
		@warning_ignore("integer_division")
		var mid := (low + high) / 2
		if sorted_values[mid] <= raw_value:
			low = mid + 1
		else:
			high = mid
	return clampf(float(low - 1) / float(maxi(sorted_values.size() - 1, 1)), 0.0, 1.0)


static func _make_mottle_noise(seed_value: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = seed_value
	noise.frequency = 1.6
	noise.fractal_octaves = 3
	return noise


func _apply_style_uniforms() -> void:
	var uniforms := _style_preset.get("uniforms", {}) as Dictionary
	for uniform_name in uniforms:
		_sheet.set_sheet_uniform(str(uniform_name), uniforms[uniform_name])


## 河流 overlay (adr/0012): 存档折线 → view 坐标两层描线; 显隐/配色随风格预设。
func _draw_rivers() -> void:
	if not bool(_style_preset.get("rivers", true)) or _rivers.is_empty():
		return
	var under_color := _style_preset.get("river_under", Color(0.15, 0.18, 0.19, 0.8)) as Color
	var core_color := _style_preset.get("river_core", Color(0.34, 0.41, 0.45, 0.9)) as Color
	for polyline in _rivers:
		var view_points := PackedVector2Array()
		view_points.resize(polyline.size())
		for point_index in range(polyline.size()):
			view_points[point_index] = _plane_to_view(polyline[point_index])
		# hex 中心链是 60° 锯齿, Chaikin 两轮磨成有机河曲 (纯绘制层, 不动存档折线)。
		var smoothed := _chaikin(view_points, 2)
		draw_polyline(smoothed, under_color, RIVER_WIDTH_UNDER, true)
		draw_polyline(smoothed, core_color, RIVER_WIDTH_CORE, true)


# === 迷雾 (Phase 4, war3 三态; 渲染语义不动) ===


## 某世界格的迷雾态 (Phase 4 三态): lit(视野圆) / revealed(持久点亮=灰) / dark(黑)。
func _cell_fog_state(cell: Vector2i) -> String:
	if _axial_distance(cell, _sight_center) <= _sight_range:
		return "lit"
	if _revealed_lookup.has(cell):
		return "revealed"
	return "dark"


static func _axial_distance(a: Vector2i, b: Vector2i) -> int:
	var dq := a.x - b.x
	var dr := a.y - b.y
	# 三项 abs 之和恒为偶数 (axial 距离公式), 整除无损。
	@warning_ignore("integer_division")
	return (absi(dq) + absi(dr) + absi(dq + dr)) / 2


## 迷雾遮罩烘焙: 覆盖整张 sheet (海洋边框继承最近岸格的雾态 → 雾缘连续)。
## 视野每步变 → 每次 refresh 重烘 (~9 万像素毫秒级); LINEAR 放大融成柔和雾缘。
func _bake_fog_texture() -> void:
	if _sheet_view_rect.size.x <= 0.0 or _sheet_view_rect.size.y <= 0.0:
		_fog_texture = null
		return
	var image_width := maxi(8, int(ceil(_sheet_view_rect.size.x * FOG_BAKE_SCALE)))
	var image_height := maxi(8, int(ceil(_sheet_view_rect.size.y * FOG_BAKE_SCALE)))
	var image := Image.create(image_width, image_height, false, Image.FORMAT_RGBA8)
	for py in range(image_height):
		for px in range(image_width):
			var view_pos := _sheet_view_rect.position + Vector2(
				(float(px) + 0.5) / FOG_BAKE_SCALE, (float(py) + 0.5) / FOG_BAKE_SCALE)
			var offset := InkMonWorldMapData.axial_to_offset(_view_to_axial_approx(view_pos))
			offset.x = clampi(offset.x, 0, _map_width - 1)
			offset.y = clampi(offset.y, 0, _map_height - 1)
			var cell := InkMonWorldMapData.offset_to_axial(offset.x, offset.y)
			match _cell_fog_state(cell):
				"lit":
					image.set_pixel(px, py, Color(0, 0, 0, 0))
				"revealed":
					image.set_pixel(px, py, COLOR_FOG_GRAY)
				_:
					image.set_pixel(px, py, COLOR_FOG_DARK)
	_fog_texture = ImageTexture.create_from_image(image)


## view 坐标 → 近似最近 axial cell (round 误差半格内, 低分辨率插值糊化吃掉)。
func _view_to_axial_approx(view_pos: Vector2) -> Vector2i:
	var scale_factor := HEX_SIZE * sqrt(3.0)
	return InkMonWorldMapData.plane_to_axial(Vector2(
		view_pos.x / scale_factor, view_pos.y / (scale_factor * ISO_SQUISH)))


# === 图元层 (节点/走廊/旗/棋子; 渲染语义不动) ===


## 地标旗: 本趟目标金色高亮**永显** (Q4.4 拍板: 委托自带情报, 带粮距离目测的锚);
## 其余旗随所在格迷雾态 (黑区不显)。
func _draw_landmarks() -> void:
	for landmark in _landmarks:
		var coord := landmark.get("coord", Vector2i.ZERO) as Vector2i
		var pos := _axial_to_plane(coord)
		var is_current := coord == _target_site
		if not is_current and _cell_fog_state(coord) == "dark":
			continue
		if is_current:
			draw_circle(pos, NODE_RADIUS * 1.9, Color(COLOR_SITE_MARK.r, COLOR_SITE_MARK.g, COLOR_SITE_MARK.b, 0.18))
			draw_circle(pos, NODE_RADIUS * 1.3, Color(COLOR_SITE_MARK.r, COLOR_SITE_MARK.g, COLOR_SITE_MARK.b, 0.25))
		var flag_color := COLOR_SITE_MARK if is_current else COLOR_SITE_IDLE
		var pole_top := pos + Vector2(0.0, -HEX_SIZE * 1.15)
		draw_line(pos, pole_top, flag_color.darkened(0.35), 2.0)
		draw_colored_polygon(PackedVector2Array([pole_top,
			pole_top + Vector2(HEX_SIZE * 0.75, HEX_SIZE * 0.22),
			pole_top + Vector2(0.0, HEX_SIZE * 0.45)]), flag_color)
		draw_circle(pos, 3.0, flag_color.darkened(0.4))


## 节点是否可绘 (Q4.4 黑区不露骨架): lit/seen 可绘; hidden 只有作为下一跳时以 "?" 浮出。
func _node_drawable(node: Dictionary, next_ids: Array[int]) -> bool:
	if str(node.get("visibility", "lit")) != "hidden":
		return true
	return next_ids.has(int(node.get("id", -1)))


## 走廊 (v1 直线): 深色宽线打底 + 面线; 当前可选边亮金加粗。
## 迷雾 (Q4.4): 两端都可绘 (lit/seen/下一跳?) 才画 —— 黑区走廊全不显示。
func _draw_corridors() -> void:
	var current_id := int(_mission.get("current_node_id", 0))
	var next_ids := _next_ids()
	var drawable_ids: Dictionary = {}
	for node in _nodes():
		if _node_drawable(node, next_ids):
			drawable_ids[int(node.get("id", -1))] = true
	var edges := _mission.get("edges", {}) as Dictionary
	for from_key in edges:
		var from_id := int(from_key)
		if not drawable_ids.has(from_id):
			continue
		var from_pos := _node_plane_pos(from_id)
		var to_list := edges[from_key] as Array
		if to_list == null:
			continue
		for to_value in to_list:
			var to_id := int(to_value)
			if not drawable_ids.has(to_id):
				continue
			var to_pos := _node_plane_pos(to_id)
			var is_next := from_id == current_id and next_ids.has(to_id)
			draw_line(from_pos, to_pos, COLOR_EDGE_UNDER, 6.0 if is_next else 4.5)
			draw_line(from_pos, to_pos,
				COLOR_EDGE_NEXT if is_next else COLOR_EDGE, 3.0 if is_next else 1.8)


func _draw_nodes() -> void:
	var current_id := int(_mission.get("current_node_id", 0))
	var next_ids := _next_ids()
	for node in _nodes():
		if not _node_drawable(node, next_ids):
			continue
		var node_id := int(node.get("id", -1))
		var pos := _node_plane_pos(node_id)
		var visibility := str(node.get("visibility", "lit"))
		draw_circle(pos, NODE_RADIUS + 2.0, COLOR_NODE_RIM)
		if visibility == "hidden":
			# 下一跳圆外节点 = "?" (Q4.2: 可点不可知)。
			draw_circle(pos, NODE_RADIUS, COLOR_NODE_UNKNOWN)
			var font := ThemeDB.fallback_font
			draw_string(font, pos + Vector2(-4.0, 5.0), "?", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(0.12, 0.12, 0.14))
			continue
		var node_color := _node_color(node, node_id, next_ids)
		if visibility == "seen":
			# 灰态 = 最后所见快照 (Q4.5): 按快照 kind 上色再统一暗化。
			var seen_node: Dictionary = node.duplicate()
			seen_node["kind"] = str(node.get("seen_kind", node.get("kind", "")))
			node_color = _node_color(seen_node, node_id, next_ids).darkened(SEEN_NODE_DIM)
		draw_circle(pos, NODE_RADIUS, node_color)
		if node_id == current_id:
			draw_arc(pos, NODE_RADIUS + 5.0, 0.0, TAU, 24, COLOR_PIECE, 2.5)


func _node_color(node: Dictionary, node_id: int, next_ids: Array[int]) -> Color:
	match str(node.get("kind", "")):
		InkMonMissionMapData.NODE_START:
			return COLOR_NODE_START
		InkMonMissionMapData.NODE_TARGET:
			return COLOR_NODE_TARGET
		InkMonMissionMapData.NODE_BATTLE:
			return COLOR_NODE_VISITED if bool(node.get("visited", false)) else COLOR_NODE_BATTLE
	if next_ids.has(node_id):
		return COLOR_NODE_NEXT
	if bool(node.get("visited", false)):
		return COLOR_NODE_VISITED
	return COLOR_NODE


func _nodes() -> Array:
	var nodes := _mission.get("nodes", []) as Array
	return nodes if nodes != null else []


func _next_ids() -> Array[int]:
	var result: Array[int] = []
	var source := _mission.get("next_node_ids", []) as Array
	if source != null:
		for value in source:
			result.append(int(value))
	return result


func _node_plane_pos(node_id: int) -> Vector2:
	for node in _nodes():
		if int(node.get("id", -1)) == node_id:
			return _axial_to_plane(node.get("coord", Vector2i.ZERO) as Vector2i)
	return Vector2.ZERO


## axial(pointy-top) → 等轴 view 坐标 (y 压扁 ISO_SQUISH)。
func _axial_to_plane(cell: Vector2i) -> Vector2:
	return _plane_to_view(InkMonWorldMapData.axial_to_plane(cell))


## Chaikin 切角: 每轮把折线角替换成 1/4·3/4 点, 两轮足以把 60° hex 锯齿磨成河曲。
static func _chaikin(points: PackedVector2Array, iterations: int) -> PackedVector2Array:
	var current := points
	for _iteration in range(iterations):
		if current.size() < 3:
			break
		var refined := PackedVector2Array()
		refined.append(current[0])
		for segment_index in range(current.size() - 1):
			var from_point := current[segment_index]
			var to_point := current[segment_index + 1]
			refined.append(from_point.lerp(to_point, 0.25))
			refined.append(from_point.lerp(to_point, 0.75))
		refined.append(current[current.size() - 1])
		current = refined
	return current


static func _to_int_array(source: Array) -> PackedInt32Array:
	var result := PackedInt32Array()
	if source == null:
		return result
	result.resize(source.size())
	for index in range(source.size()):
		result[index] = int(source[index])
	return result


## 全图 fit 进 viewport (v1 单区域一屏可见, 免相机): 按可玩区域 fit, 海洋边框自然出血
## 到屏幕外 —— 地图铺满全屏, 无深色底板边条 (adr/0012 决定三)。
func _fit_to_viewport() -> void:
	if _map_width <= 0 or _map_height <= 0:
		return
	var bounds := _plane_rect_to_view(_playable_plane_rect()).grow(HEX_SIZE * 2.0)
	var min_pos := bounds.position
	var content := bounds.size
	# 用 viewport 原生尺寸: get_viewport_rect() 是 local 系(受本节点已设 transform 逆变换),
	# 第二次 refresh 会用歪掉的尺寸算 fit → 地图漂移。
	var viewport_size := get_viewport().get_visible_rect().size
	if content.x <= 0.0 or content.y <= 0.0 or viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var fit := minf(
		(viewport_size.x - FIT_MARGIN * 2.0) / content.x,
		(viewport_size.y - FIT_MARGIN * 2.0) / content.y)
	scale = Vector2.ONE * fit
	position = (viewport_size - content * fit) * 0.5 - min_pos * fit
