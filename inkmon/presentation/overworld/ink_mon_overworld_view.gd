class_name InkMonOverworldView
extends Node2D

## 主世界 overworld 表演层 —— 真 2D 等轴占位渲染（adr/0005）。
## 逻辑 hex 网格不变；本层把逻辑坐标渲染成 **等轴 2D**:地面 hex 垂直压扁成菱形(ISO_SQUISH),
## 单位直立站在上面(脚下椭圆影)。占位视觉 = Polygon2D 色块,待 Seedance 烘帧管线落地后换 AnimatedSprite2D。
##
## 对外契约保持与旧 3D 版**完全一致**(Presentation 零改):coord_to_world 仍返 Vector3(x,0,z)。
## 内部以 2D 像素工作 + 等轴压扁;public 处 (x,z) ↔ 2D (x,y) 互转。pick/coord_to_screen 走 canvas_transform。


const MAP_RADIUS := 4
const INVALID_COORD := Vector2i(-999999, -999999)
const PLAYER_HEIGHT := 0.48
const NPC_HEIGHT := 0.42
const MOVE_STEP_DURATION := 0.22
const CLICK_PULSE_DURATION := 0.34
const CAMERA_FOLLOW_SPEED := 5.0

## 2D 像素尺度:逻辑网格 size 放大到像素量级,否则世界单位太小不可见。
const GRID_PIXEL_SIZE := 56.0
## 等轴垂直压扁系数(地面 hex 的 y 方向压成菱形;~0.55 ≈ 经典 iso 俯斜)。
const ISO_SQUISH := 0.55
const CAMERA_ZOOM := 1.0
## 占位 marker 视觉上抬(直立站在格心上方,脚底落格心),仅影响 VisualRoot,不影响 marker 根的格心定位。
const PLAYER_VISUAL_LIFT := -14.0
const NPC_VISUAL_LIFT := -12.0
const PLAYER_RADIUS := 16.0
const NPC_RADIUS := 15.0


var player_coord := Vector2i.ZERO
var near_npc_id := ""
var npc_defs: Dictionary = {}

var _grid_model: GridMapModel
var _grid_renderer: GridMapRenderer2D
var _ground: Node2D
var _camera: Camera2D
var _units_root: Node2D
var _feedback_root: Node2D
var _player_node: Node2D
var _player_visual_root: Node2D
var _npc_nodes: Dictionary = {}
var _npc_visual_roots: Dictionary = {}
var _target_marker: Node2D
var _click_pulse_nodes: Array[Node2D] = []
var _move_tween: Tween
var _idle_time := 0.0
var _move_animation_active := false
var _move_animation_finished_count := 0
var _ground_tile_count := 0


func _ready() -> void:
	_build_scene()
	set_player_coord(player_coord)
	set_npcs(npc_defs)


func _process(delta: float) -> void:
	_idle_time += delta
	_update_idle_animation(delta)
	_update_camera_follow(delta)


func set_player_coord(coord: Vector2i) -> void:
	player_coord = coord
	if _player_node != null and not _move_animation_active:
		_player_node.position = _coord_to_world2d(coord)
		_update_camera_follow(1.0)


func snap_player_coord(coord: Vector2i) -> void:
	_cancel_move_tween()
	_move_animation_active = false
	player_coord = coord
	if _player_node != null:
		_player_node.position = _coord_to_world2d(coord)
	_update_camera_follow(1.0)


func clear_move_feedback() -> void:
	if _target_marker != null and is_instance_valid(_target_marker):
		_target_marker.queue_free()
	_target_marker = null
	for pulse in _click_pulse_nodes:
		if pulse != null and is_instance_valid(pulse):
			pulse.queue_free()
	_click_pulse_nodes.clear()


## P4 逐格补间:Logic 每跨一格 emit actor_position_changed → view 在相邻两格间补一步。
func step_player(_from_cell: Vector2i, to_cell: Vector2i) -> void:
	player_coord = to_cell
	if _player_node == null:
		return
	_cancel_move_tween()
	_move_animation_active = true
	var to_position := _coord_to_world2d(to_cell)
	_move_tween = create_tween()
	_move_tween.tween_property(_player_node, "position", to_position, MOVE_STEP_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_move_tween.finished.connect(_on_step_tween_finished)


func _on_step_tween_finished() -> void:
	_move_animation_active = false
	_move_animation_finished_count += 1
	if _player_node != null:
		_player_node.position = _coord_to_world2d(player_coord)
	_update_camera_follow(1.0)


func show_move_target(coord: Vector2i) -> void:
	_show_target_marker(coord)
	_spawn_click_pulse(coord)


func is_move_animation_active() -> bool:
	return _move_animation_active


func get_player_visual_coord() -> Vector2i:
	if _player_node == null:
		return player_coord
	return _world2d_to_coord(_player_node.position)


func set_near_npc_id(npc_id: String) -> void:
	near_npc_id = npc_id
	for key in _npc_nodes.keys():
		var node := _npc_nodes[key] as Node2D
		if node == null:
			continue
		node.scale = Vector2.ONE * (1.18 if str(key) == near_npc_id else 1.0)


## 当前高亮 NPC 节点的 scale.x(>1 = 已放大强调);无高亮返回 1.0。debug-only。
func _get_highlight_scale() -> float:
	if near_npc_id == "":
		return 1.0
	var node := _npc_nodes.get(near_npc_id, null) as Node2D
	return node.scale.x if node != null else 0.0


func set_npcs(defs: Dictionary) -> void:
	npc_defs = defs.duplicate(true)
	if _units_root == null:
		return
	for node_value in _npc_nodes.values():
		var node := node_value as Node
		if node != null:
			node.queue_free()
	_npc_nodes.clear()
	_npc_visual_roots.clear()

	for npc_id_value in npc_defs.keys():
		var npc_id := str(npc_id_value)
		var npc_def := npc_defs[npc_id] as Dictionary
		if npc_def == null:
			continue
		var coord := npc_def.get("coord", Vector2i.ZERO) as Vector2i
		var node := _create_npc_marker(npc_id, str(npc_def.get("display_name", npc_id)))
		_units_root.add_child(node)
		node.position = _coord_to_world2d(coord)
		_npc_nodes[npc_id] = node
		var visual_root := node.get_node_or_null("VisualRoot") as Node2D
		if visual_root != null:
			_npc_visual_roots[npc_id] = visual_root
	set_near_npc_id(near_npc_id)


func has_coord(coord: Vector2i) -> bool:
	return _grid_model != null and _grid_model.has_tile(HexCoord.new(coord.x, coord.y))


## 公开契约保持返回 Vector3(x,0,z):x/z = 等轴 2D 像素 x/y(Presentation 不感知 2D 化)。
func coord_to_world(coord: Vector2i) -> Vector3:
	var pixel := _coord_to_world2d(coord)
	return Vector3(pixel.x, 0.0, pixel.y)


func world_to_coord(world_position: Vector3) -> Vector2i:
	return _world2d_to_coord(Vector2(world_position.x, world_position.z))


func coord_to_screen(coord: Vector2i) -> Vector2:
	if _grid_model == null:
		return Vector2.ZERO
	return _world2d_to_screen(_coord_to_world2d(coord))


func pick_coord_from_screen(screen_position: Vector2) -> Dictionary:
	if _grid_model == null:
		return {
			"ok": false,
			"message": "grid is not ready",
			"coord": INVALID_COORD,
		}
	var world2d := _screen_to_world2d(screen_position)
	var coord := _world2d_to_coord(world2d)
	return {
		"ok": has_coord(coord),
		"message": "picked hex" if has_coord(coord) else "picked outside hex map",
		"coord": coord,
		"world": {
			"x": world2d.x,
			"y": 0.0,
			"z": world2d.y,
		},
	}


func get_tile_screen_position(coord: Vector2i) -> Dictionary:
	if not has_coord(coord):
		return {
			"ok": false,
			"message": "coord outside overworld grid",
		}
	var screen := _world2d_to_screen(_coord_to_world2d(coord))
	return {
		"ok": true,
		"message": "tile screen position",
		"data": {
			"coord": {"q": coord.x, "r": coord.y},
			"x": screen.x,
			"y": screen.y,
		},
	}


func get_debug_state() -> Dictionary:
	var visual_coord := get_player_visual_coord()
	var visual_position := _player_node.position if _player_node != null else Vector2.ZERO
	var camera_position := _camera.position if _camera != null else Vector2.ZERO
	return {
		"node_type": "InkMonOverworldView",
		"tile_count": _grid_model.get_tile_count() if _grid_model != null else 0,
		"env_tile_count": _ground_tile_count,
		"player_coord": {"q": player_coord.x, "r": player_coord.y},
		"player_visual_coord": {"q": visual_coord.x, "r": visual_coord.y},
		"player_visual_position": {"x": visual_position.x, "y": 0.0, "z": visual_position.y},
		"player_idle_offset_y": _player_visual_root.position.y if _player_visual_root != null else 0.0,
		"npc_idle_sample_y": _get_npc_idle_sample_y(),
		"camera_position": {"x": camera_position.x, "y": 0.0, "z": camera_position.y},
		"npc_count": _npc_nodes.size(),
		"near_npc_highlight": near_npc_id,
		"near_npc_highlight_scale": _get_highlight_scale(),
		"camera_ready": _camera != null,
		"move_animation_active": _move_animation_active,
		"move_animation_finished_count": _move_animation_finished_count,
		"target_feedback_active": _target_marker != null and is_instance_valid(_target_marker),
		"click_pulse_count": _click_pulse_nodes.size(),
		"idle_animation": true,
		"camera_follow": _camera != null,
		"iso_squish": ISO_SQUISH,
	}


func _build_scene() -> void:
	# 地面层:垂直压扁成等轴菱形。网格渲染器画原始 hex,_ground 的 scale.y 把它压成 iso。
	_ground = Node2D.new()
	_ground.name = "Ground"
	_ground.scale = Vector2(1.0, ISO_SQUISH)
	add_child(_ground)

	_grid_renderer = GridMapRenderer2D.new()
	_grid_renderer.name = "GridRenderer2D"
	_ground.add_child(_grid_renderer)

	var cfg := GridMapConfig.new()
	cfg.grid_type = GridMapConfig.GridType.HEX
	cfg.orientation = GridMapConfig.Orientation.POINTY
	cfg.draw_mode = GridMapConfig.DrawMode.RADIUS
	cfg.radius = MAP_RADIUS
	cfg.size = GRID_PIXEL_SIZE
	_grid_model = GridMapModel.new()
	_grid_model.initialize(cfg)
	_grid_renderer.set_model(_grid_model)
	_grid_renderer.grid_color = Color(0.06, 0.05, 0.04, 0.42)
	_grid_renderer.highlight_color = Color(1.0, 0.82, 0.24, 0.95)
	_grid_renderer.line_width = 2.0

	_populate_ground_tiles()
	_grid_renderer.render_grid()

	_build_camera()

	# 单位/反馈层:不压扁(单位直立);位置走 _coord_to_world2d(已含 iso 压扁的 y)。
	_feedback_root = Node2D.new()
	_feedback_root.name = "FeedbackRoot"
	add_child(_feedback_root)

	_units_root = Node2D.new()
	_units_root.name = "UnitsRoot"
	add_child(_units_root)
	_player_node = _create_player_marker()
	_units_root.add_child(_player_node)


## 占位地面:grass 铺满 + road 沿三轴覆盖。filled 数即 env_tile_count。
func _populate_ground_tiles() -> void:
	var coords := _grid_model.get_all_coords()
	_grid_renderer.fill_tiles(coords, Color(0.28, 0.56, 0.24))
	var road: Array[HexCoord] = []
	for coord in coords:
		var axial := coord.to_axial()
		if axial.x == 0 or axial.y == 0 or axial.x + axial.y == 0:
			road.append(coord)
	if not road.is_empty():
		_grid_renderer.fill_tiles(road, Color(0.56, 0.46, 0.31))
	_ground_tile_count = coords.size()


func _build_camera() -> void:
	_camera = Camera2D.new()
	_camera.name = "OverworldCamera"
	_camera.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)
	add_child(_camera)
	_camera.make_current()


func _create_player_marker() -> Node2D:
	var root := Node2D.new()
	root.name = "PlayerAvatar"
	# 脚下椭圆影(压扁,贴等轴地面),坐落格心。
	var shadow := _make_disc("Shadow", PLAYER_RADIUS * 0.95, Color(0.0, 0.0, 0.0, 0.26), ISO_SQUISH)
	root.add_child(shadow)

	var visual_root := Node2D.new()
	visual_root.name = "VisualRoot"
	visual_root.position = Vector2(0.0, PLAYER_VISUAL_LIFT)
	root.add_child(visual_root)
	_player_visual_root = visual_root

	var body := _make_disc("Body", PLAYER_RADIUS, Color(0.08, 0.28, 0.58))
	visual_root.add_child(body)
	var head := _make_disc("Head", PLAYER_RADIUS * 0.55, Color(0.86, 0.70, 0.54))
	head.position = Vector2(0.0, -PLAYER_RADIUS * 0.95)
	visual_root.add_child(head)
	return root


func _create_npc_marker(npc_id: String, display_name: String) -> Node2D:
	var root := Node2D.new()
	root.name = "NPC_%s" % npc_id
	var shadow := _make_disc("Shadow", NPC_RADIUS * 0.95, Color(0.0, 0.0, 0.0, 0.26), ISO_SQUISH)
	root.add_child(shadow)

	var visual_root := Node2D.new()
	visual_root.name = "VisualRoot"
	visual_root.position = Vector2(0.0, NPC_VISUAL_LIFT)
	root.add_child(visual_root)

	var body := _make_disc("Body", NPC_RADIUS, _npc_color(npc_id))
	visual_root.add_child(body)

	var label := Label.new()
	label.name = "NameLabel"
	label.text = display_name
	label.position = Vector2(-NPC_RADIUS * 1.6, -NPC_RADIUS * 3.0)
	label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	visual_root.add_child(label)
	return root


## 逻辑格 → 等轴 2D 像素:hex pixel 的 y 乘 ISO_SQUISH(与 _ground 的 scale.y 一致,故单位落点对齐地面)。
func _coord_to_world2d(coord: Vector2i) -> Vector2:
	if _grid_model == null:
		return Vector2.ZERO
	var pixel := _grid_model.coord_to_world(HexCoord.new(coord.x, coord.y))
	return Vector2(pixel.x, pixel.y * ISO_SQUISH)


## 等轴 2D 像素 → 逻辑格:先把 y 反压(/ISO_SQUISH)还原成 hex 平面,再查格。pick 往返自洽靠这一步。
func _world2d_to_coord(world2d: Vector2) -> Vector2i:
	if _grid_model == null:
		return INVALID_COORD
	return _grid_model.world_to_coord(Vector2(world2d.x, world2d.y / ISO_SQUISH)).to_axial()


## 世界 2D → 屏幕像素:经默认 canvas(受 Camera2D 影响)的 transform。HUD 在独立 CanvasLayer,不受相机影响。
func _world2d_to_screen(world2d: Vector2) -> Vector2:
	var viewport := get_viewport()
	if viewport == null:
		return world2d
	return viewport.get_canvas_transform() * world2d


func _screen_to_world2d(screen_position: Vector2) -> Vector2:
	var viewport := get_viewport()
	if viewport == null:
		return screen_position
	return viewport.get_canvas_transform().affine_inverse() * screen_position


func _show_target_marker(coord: Vector2i) -> void:
	if _target_marker != null and is_instance_valid(_target_marker):
		_target_marker.queue_free()
	_target_marker = _make_disc("TargetHighlight", GRID_PIXEL_SIZE * 0.5, Color(1.0, 0.78, 0.18, 0.68), ISO_SQUISH)
	_feedback_root.add_child(_target_marker)
	_target_marker.position = _coord_to_world2d(coord)


func _spawn_click_pulse(coord: Vector2i) -> void:
	var pulse := _make_disc("ClickPulse", GRID_PIXEL_SIZE * 0.34, Color(1.0, 0.95, 0.42, 0.42), ISO_SQUISH)
	_feedback_root.add_child(pulse)
	pulse.position = _coord_to_world2d(coord)
	_click_pulse_nodes.append(pulse)
	var tween := create_tween()
	tween.tween_property(pulse, "scale", Vector2(1.65, 1.65), CLICK_PULSE_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func() -> void:
		_click_pulse_nodes.erase(pulse)
		if is_instance_valid(pulse):
			pulse.queue_free()
	)


## 占位圆盘/椭圆 Polygon2D。y_scale < 1 = 压扁成贴地等轴椭圆(地面影 / 目标高亮);=1 = 直立圆(单位本体)。
func _make_disc(marker_name: String, radius: float, color: Color, y_scale: float = 1.0) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.name = marker_name
	poly.color = color
	poly.polygon = _ellipse_points(radius, radius * y_scale, 24)
	return poly


func _ellipse_points(rx: float, ry: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(segments):
		var angle := float(i) * TAU / float(segments)
		points.append(Vector2(cos(angle) * rx, sin(angle) * ry))
	return points


func _cancel_move_tween() -> void:
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = null


func _update_idle_animation(_delta: float) -> void:
	if _player_visual_root != null:
		_player_visual_root.position.y = PLAYER_VISUAL_LIFT + sin(_idle_time * 3.2) * 4.0
	for npc_id_value in _npc_visual_roots.keys():
		var npc_id := str(npc_id_value)
		var visual_root := _npc_visual_roots[npc_id] as Node2D
		if visual_root == null:
			continue
		var phase := float(abs(npc_id.hash()) % 100) / 100.0 * TAU
		visual_root.position.y = NPC_VISUAL_LIFT + sin(_idle_time * 2.1 + phase) * 3.0


func _update_camera_follow(delta: float) -> void:
	if _camera == null or _player_node == null:
		return
	var weight := clampf(delta * CAMERA_FOLLOW_SPEED, 0.0, 1.0)
	_camera.position = _camera.position.lerp(_player_node.position, weight)


func _get_npc_idle_sample_y() -> float:
	for visual_root_value in _npc_visual_roots.values():
		var visual_root := visual_root_value as Node2D
		if visual_root != null:
			return visual_root.position.y
	return 0.0


func _npc_color(npc_id: String) -> Color:
	match npc_id:
		"shop":
			return Color(0.93, 0.64, 0.24)
		"trainer":
			return Color(0.70, 0.20, 0.18)
		"cultivation":
			return Color(0.27, 0.58, 0.34)
		"guild":
			return Color(0.26, 0.34, 0.72)
		"advancement":
			return Color(0.70, 0.50, 0.18)
		_:
			return Color(0.45, 0.36, 0.58)
