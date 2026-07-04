class_name InkMonMissionMapView
extends Node2D
## 出征大地图 view (P2: hex 只是渲染皮肤, 逻辑真相 = 趟内节点图快照)。
##
## 只画 + 报点击, 不持 IWorldQuery / 不 submit (表演层 routing 规则: root 接线)。
## 数据源 = root 推入的两份值拷贝快照 (get_mission_snapshot / get_world_map_snapshot);
## 本 view 不持任何逻辑层引用。v1 自绘皮肤 (深色底板 + 地形明度微扰/描边 + 全地标旗 +
## 双层走廊线 + 描边节点 + 棋子补间), 真美术化 = Phase 5+。


signal node_clicked(node_id: int)


const HEX_SIZE := 20.0
## 2:1 等轴纵向压扁 (对齐 render2d 字典: squish 0.5 ↔ pitch 30°)。
const ISO_SQUISH := 0.5
## 地形烘焙分辨率 (px per view-plane px): 低分辨率图 + LINEAR 放大 → 色块边界融成连续地貌
## ("完整地形图"拍板 2026-07-05: 地形是一张图, hex 只是叠加的网格边界)。
const TERRAIN_BAKE_SCALE := 0.35
const NODE_RADIUS := 10.0
const FIT_MARGIN := 48.0
const PIECE_SPEED := 420.0

const COLOR_BACKDROP := Color(0.09, 0.10, 0.12)
const COLOR_HEX_BORDER := Color(0.0, 0.0, 0.0, 0.24)
const COLOR_PLAIN := Color(0.40, 0.45, 0.31)
const COLOR_FOREST := Color(0.20, 0.34, 0.20)
const COLOR_HILL := Color(0.44, 0.38, 0.27)
const COLOR_EDGE_UNDER := Color(0.05, 0.06, 0.07, 0.55)
const COLOR_EDGE := Color(0.62, 0.59, 0.50, 0.75)
const COLOR_EDGE_NEXT := Color(0.98, 0.92, 0.55, 0.95)
const COLOR_NODE := Color(0.78, 0.77, 0.72)
const COLOR_NODE_VISITED := Color(0.45, 0.45, 0.43)
const COLOR_NODE_NEXT := Color(1.0, 0.95, 0.6)
const COLOR_NODE_START := Color(0.55, 0.8, 0.55)
const COLOR_NODE_TARGET := Color(1.0, 0.78, 0.25)
const COLOR_NODE_RIM := Color(0.08, 0.09, 0.10, 0.9)
const COLOR_PIECE := Color(0.3, 0.65, 0.95)
const COLOR_SITE_MARK := Color(1.0, 0.65, 0.15)
## 非本趟目标的地标旗 (画出全部地标 = 世界上还有别的方向可去)。
const COLOR_SITE_IDLE := Color(0.72, 0.58, 0.36, 0.85)


var _mission: Dictionary = {}
var _terrain_lookup: Dictionary = {}
var _landmarks: Array[Dictionary] = []
var _map_width := 0
var _map_height := 0
var _target_site := Vector2i.ZERO
var _piece_pos := Vector2.ZERO
var _piece_target := Vector2.ZERO
var _piece_placed := false
## 烘好的连续地形底图 (hash 缓存: 地理开档固定, 一趟只烘一次)。
var _terrain_texture: ImageTexture = null
var _terrain_rect := Rect2()
var _terrain_bake_hash := 0


func _init() -> void:
	# 低分辨率地形图靠 LINEAR 放大融成连续地貌 (默认继承也常是 linear, 显式钉死不赌主题)。
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


## root 推入两份快照 (出征开始 / 每步 progressed 后调)。
func refresh(mission_snapshot: Dictionary, world_map_snapshot: Dictionary) -> void:
	_mission = mission_snapshot
	_map_width = int(world_map_snapshot.get("width", 0))
	_map_height = int(world_map_snapshot.get("height", 0))
	_terrain_lookup.clear()
	var terrain_source := world_map_snapshot.get("terrain", []) as Array
	if terrain_source != null:
		for cell_value in terrain_source:
			var cell := cell_value as Dictionary
			if cell != null:
				_terrain_lookup[Vector2i(int(cell.get("q", 0)), int(cell.get("r", 0)))] = str(cell.get("t", ""))
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
	var bake_hash := hash([_map_width, _map_height, _terrain_lookup])
	if bake_hash != _terrain_bake_hash or _terrain_texture == null:
		_terrain_bake_hash = bake_hash
		_bake_terrain_texture()
	_fit_to_viewport()
	var current_pos := _node_plane_pos(int(_mission.get("current_node_id", 0)))
	if _piece_placed:
		_piece_target = current_pos
	else:
		_piece_pos = current_pos
		_piece_target = current_pos
		_piece_placed = true
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
	_draw_terrain()
	_draw_landmarks()
	_draw_corridors()
	_draw_nodes()
	# 玩家棋子 (补间位): 白描边 + 本色。
	draw_circle(_piece_pos, NODE_RADIUS * 0.72, Color(0.95, 0.96, 0.98))
	draw_circle(_piece_pos, NODE_RADIUS * 0.55, COLOR_PIECE)


## 地理底图 = 烘好的连续地形图铺底 + hex 细格线叠层 + 地图纸描边
## ("完整地形图": 关掉格线仍是一张完整地图)。v1 全明, 迷雾表现 = Phase 4。
func _draw_terrain() -> void:
	if _terrain_texture != null:
		draw_texture_rect(_terrain_texture, _terrain_rect, false)
	for row in range(_map_height):
		for col in range(_map_width):
			var points := _hex_points(_axial_to_plane(InkMonWorldMapData.offset_to_axial(col, row)))
			var outline := points.duplicate()
			outline.append(points[0])
			draw_polyline(outline, COLOR_HEX_BORDER, 1.0)
	if _terrain_texture != null:
		draw_rect(_terrain_rect, COLOR_BACKDROP, false, 3.0)


## 逐像素采样最近 cell 烘低分辨率地形图。超界像素 clamp 到最近界内 cell 颜色 —— 底图是一张
## 完整矩形"地图纸"(无 odd-r 边缘锯齿), 可玩边界由 hex 格线终止表达。
## 地理开档固定 → hash 缓存, 一趟只烘一次 (~40k 像素, 毫秒级)。
func _bake_terrain_texture() -> void:
	var bounds := _world_plane_bounds()
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		_terrain_texture = null
		return
	var image_width := maxi(8, int(ceil(bounds.size.x * TERRAIN_BAKE_SCALE)))
	var image_height := maxi(8, int(ceil(bounds.size.y * TERRAIN_BAKE_SCALE)))
	var image := Image.create(image_width, image_height, false, Image.FORMAT_RGBA8)
	for py in range(image_height):
		for px in range(image_width):
			var plane := bounds.position + Vector2(
				(float(px) + 0.5) / TERRAIN_BAKE_SCALE, (float(py) + 0.5) / TERRAIN_BAKE_SCALE)
			var offset := InkMonWorldMapData.axial_to_offset(_plane_to_axial_approx(plane))
			offset.x = clampi(offset.x, 0, _map_width - 1)
			offset.y = clampi(offset.y, 0, _map_height - 1)
			var cell := InkMonWorldMapData.offset_to_axial(offset.x, offset.y)
			var base := _terrain_color(cell)
			var shade := _cell_shade(cell)
			image.set_pixel(px, py, Color(base.r * shade, base.g * shade, base.b * shade, 1.0))
	_terrain_texture = ImageTexture.create_from_image(image)
	_terrain_rect = bounds


## view 平面 (含 HEX_SIZE 缩放 + iso squish) → 近似最近 axial cell (round 误差半格内, 插值糊化吃掉)。
func _plane_to_axial_approx(plane: Vector2) -> Vector2i:
	var r := plane.y / (HEX_SIZE * 1.5 * ISO_SQUISH)
	var q := plane.x / (HEX_SIZE * sqrt(3.0)) - r * 0.5
	return Vector2i(int(round(q)), int(round(r)))


## 全部地标画旗 (本趟目标金色高亮 + 光晕; 其余暗金 = 世界上还有别的方向)。
func _draw_landmarks() -> void:
	for landmark in _landmarks:
		var coord := landmark.get("coord", Vector2i.ZERO) as Vector2i
		var pos := _axial_to_plane(coord)
		var is_current := coord == _target_site
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


## 走廊 (v1 直线): 深色宽线打底 + 面线; 当前可选边亮金加粗。
func _draw_corridors() -> void:
	var current_id := int(_mission.get("current_node_id", 0))
	var next_ids := _next_ids()
	var edges := _mission.get("edges", {}) as Dictionary
	for from_key in edges:
		var from_id := int(from_key)
		var from_pos := _node_plane_pos(from_id)
		var to_list := edges[from_key] as Array
		if to_list == null:
			continue
		for to_value in to_list:
			var to_id := int(to_value)
			var to_pos := _node_plane_pos(to_id)
			var is_next := from_id == current_id and next_ids.has(to_id)
			draw_line(from_pos, to_pos, COLOR_EDGE_UNDER, 6.0 if is_next else 4.5)
			draw_line(from_pos, to_pos,
				COLOR_EDGE_NEXT if is_next else COLOR_EDGE, 3.0 if is_next else 1.8)


func _draw_nodes() -> void:
	var current_id := int(_mission.get("current_node_id", 0))
	var next_ids := _next_ids()
	for node in _nodes():
		var node_id := int(node.get("id", -1))
		var pos := _node_plane_pos(node_id)
		draw_circle(pos, NODE_RADIUS + 2.0, COLOR_NODE_RIM)
		draw_circle(pos, NODE_RADIUS, _node_color(node, node_id, next_ids))
		if node_id == current_id:
			draw_arc(pos, NODE_RADIUS + 5.0, 0.0, TAU, 24, COLOR_PIECE, 2.5)


## per-cell 明度微扰 [0.96, 1.04): 整数 hash, 无 rng, 帧间/跑次稳定 (烘进底图后成柔和纹理)。
func _cell_shade(cell: Vector2i) -> float:
	var hashed := absi((cell.x * 92837111) ^ (cell.y * 689287499))
	return 0.96 + float(hashed % 1000) / 1000.0 * 0.08


func _node_color(node: Dictionary, node_id: int, next_ids: Array[int]) -> Color:
	match str(node.get("kind", "")):
		InkMonMissionMapData.NODE_START:
			return COLOR_NODE_START
		InkMonMissionMapData.NODE_TARGET:
			return COLOR_NODE_TARGET
	if next_ids.has(node_id):
		return COLOR_NODE_NEXT
	if bool(node.get("visited", false)):
		return COLOR_NODE_VISITED
	return COLOR_NODE


func _terrain_color(cell: Vector2i) -> Color:
	match str(_terrain_lookup.get(cell, "")):
		InkMonWorldMapData.TERRAIN_FOREST:
			return COLOR_FOREST
		InkMonWorldMapData.TERRAIN_HILL:
			return COLOR_HILL
	return COLOR_PLAIN


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


## axial(pointy-top) → 等轴平面 (y 压扁 ISO_SQUISH)。
func _axial_to_plane(cell: Vector2i) -> Vector2:
	var x := HEX_SIZE * sqrt(3.0) * (float(cell.x) + float(cell.y) * 0.5)
	var y := HEX_SIZE * 1.5 * float(cell.y) * ISO_SQUISH
	return Vector2(x, y)


func _hex_points(center: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(6):
		var angle := TAU * (float(i) + 0.5) / 6.0
		points.append(center + Vector2(cos(angle) * HEX_SIZE, sin(angle) * HEX_SIZE * ISO_SQUISH))
	return points


## offset 矩形世界的四角 (axial 坐标): 包围盒 / 底板共用。
func _world_corner_cells() -> Array[Vector2i]:
	return [
		InkMonWorldMapData.offset_to_axial(0, 0),
		InkMonWorldMapData.offset_to_axial(_map_width - 1, 0),
		InkMonWorldMapData.offset_to_axial(_map_width - 1, _map_height - 1),
		InkMonWorldMapData.offset_to_axial(0, _map_height - 1),
	]


## 世界 offset 矩形的 view 平面包围盒 (±2 hex margin): fit 与地形烘焙共用, 保证底图与格线对位。
func _world_plane_bounds() -> Rect2:
	if _map_width <= 0 or _map_height <= 0:
		return Rect2()
	var corners := _world_corner_cells()
	var min_pos := _axial_to_plane(corners[0])
	var max_pos := min_pos
	for corner in corners:
		var pos := _axial_to_plane(corner)
		min_pos = min_pos.min(pos)
		max_pos = max_pos.max(pos)
	min_pos -= Vector2.ONE * HEX_SIZE * 2.0
	max_pos += Vector2.ONE * HEX_SIZE * 2.0
	return Rect2(min_pos, max_pos - min_pos)


## 全图 fit 进 viewport (v1 单区域一屏可见, 免相机)。
func _fit_to_viewport() -> void:
	if _map_width <= 0 or _map_height <= 0:
		return
	var bounds := _world_plane_bounds()
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
