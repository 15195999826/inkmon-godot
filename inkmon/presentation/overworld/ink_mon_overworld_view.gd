class_name InkMonOverworldView
extends Node2D

## 主世界 overworld 表演层 —— 真 2D 等轴渲染（adr/0005），统一到共享 render2d 表演框架（adr/0007）。
##
## actor-state（玩家 / NPC 的位置 + 移动）走 InkMonOverworldLiveDriver（持共享 RenderWorld +
## scheduler + overworld_registry，live 事件源），投影到共享 InkMonRender2DAvatar；地图用
## flat-top baked tile 层 InkMonRender2DBakedHexMap（T2 契约：content/maps/world_main.map.json
## + 发布的 tile set；adr/0007 的 pointy 线框网格用法就此退役）。**view-local**（不进
## render_world）：相机跟随 / 点击脉冲 / 目标 marker / 屏幕拾取 / 坐标几何 / NPC 高亮缩放。
##
## 对外契约（presentation 调用 + dev-agent debug 面）保持不变:coord_to_world 仍返 Vector3(x,0,z)。

const WORLD_MAP_ID := "world_main"
## 视图显示密度（px/边）：素材原生 ~213px/边按此缩放，保住既有 avatar/marker/相机的像素尺度。
const DISPLAY_EDGE_PX := 64.0
const CAMERA_FOLLOW_SPEED := 5.0
const CLICK_PULSE_DURATION := 0.34
const INVALID_COORD := Vector2i(-999999, -999999)
## 玩家在 driver 里的内部 actor id（view 私有,与逻辑层 PLAYER_ID 解耦）。
const PLAYER_ID := "player"

var player_coord := Vector2i.ZERO
var near_npc_id := ""
var npc_defs: Dictionary = {}

var _grid: InkMonRender2DBakedHexMap
var _driver: InkMonOverworldLiveDriver
var _camera: Camera2D
var _units_root: Node2D
var _feedback_root: Node2D
var _target_marker: Node2D
var _click_pulse_nodes: Array[Node2D] = []
var _npc_ids: Array[String] = []
var _ground_tile_count := 0
var _move_finished_count := 0
var _was_player_moving := false


func _ready() -> void:
	_build_scene()


func _process(delta: float) -> void:
	_update_camera_follow(delta)
	_track_move_finished()


# ========== actor-state（经 driver） ==========

func set_player_coord(coord: Vector2i) -> void:
	player_coord = coord
	if _driver == null:
		return
	if _driver.get_avatar(PLAYER_ID) == null:
		_driver.seed_actor(PLAYER_ID, "", HexCoord.new(coord.x, coord.y), InkMonRender2DAvatar.Style.overworld_player())
	elif not _driver.is_actor_moving(PLAYER_ID):
		_driver.set_actor_position(PLAYER_ID, HexCoord.new(coord.x, coord.y))


func snap_player_coord(coord: Vector2i) -> void:
	player_coord = coord
	if _driver == null:
		return
	if _driver.get_avatar(PLAYER_ID) == null:
		_driver.seed_actor(PLAYER_ID, "", HexCoord.new(coord.x, coord.y), InkMonRender2DAvatar.Style.overworld_player())
	else:
		_driver.snap_actor(PLAYER_ID, HexCoord.new(coord.x, coord.y))


## P4 逐格补间:Logic 每跨一格 emit actor_position_changed → driver 在相邻两格间补一步（MoveAction）。
func step_player(from_cell: Vector2i, to_cell: Vector2i) -> void:
	player_coord = to_cell
	if _driver != null:
		_driver.enqueue_move(PLAYER_ID, HexCoord.new(from_cell.x, from_cell.y), HexCoord.new(to_cell.x, to_cell.y))


func set_npcs(defs: Dictionary) -> void:
	npc_defs = defs.duplicate(true)
	if _driver == null:
		return
	_npc_ids.clear()
	for npc_id_value in npc_defs.keys():
		var npc_id := str(npc_id_value)
		var npc_def := npc_defs[npc_id] as Dictionary
		if npc_def == null:
			continue
		var coord := npc_def.get("coord", Vector2i.ZERO) as Vector2i
		_driver.seed_actor(
			npc_id,
			InkMonText.npc_name(npc_id),
			HexCoord.new(coord.x, coord.y),
			InkMonRender2DAvatar.Style.overworld_npc(_npc_color(npc_id))
		)
		_npc_ids.append(npc_id)
	set_near_npc_id(near_npc_id)


## NPC 高亮缩放（view-local：driver 不管，view 拿 avatar 自己缩）。
func set_near_npc_id(npc_id: String) -> void:
	near_npc_id = npc_id
	if _driver == null:
		return
	for id in _npc_ids:
		var avatar := _driver.get_avatar(id)
		if avatar != null:
			avatar.set_highlight(1.18 if id == near_npc_id else 1.0)


func get_player_visual_coord() -> Vector2i:
	if _driver == null:
		return player_coord
	var axial := _driver.get_actor_axial(PLAYER_ID)
	return Vector2i(roundi(axial.x), roundi(axial.y))


func is_move_animation_active() -> bool:
	return _driver != null and _driver.is_actor_moving(PLAYER_ID)


# ========== view-local 反馈（目标 marker / 点击脉冲） ==========

func show_move_target(coord: Vector2i) -> void:
	_show_target_marker(coord)
	_spawn_click_pulse(coord)


func clear_move_feedback() -> void:
	if _target_marker != null and is_instance_valid(_target_marker):
		_target_marker.queue_free()
	_target_marker = null
	for pulse in _click_pulse_nodes:
		if pulse != null and is_instance_valid(pulse):
			pulse.queue_free()
	_click_pulse_nodes.clear()


# ========== 坐标 / 拾取（view-local，几何交共享 grid） ==========

func has_coord(coord: Vector2i) -> bool:
	return _grid != null and _grid.has_coord(coord)


## 公开契约保持返回 Vector3(x,0,z)。
func coord_to_world(coord: Vector2i) -> Vector3:
	var pixel := _coord_to_world2d(coord)
	return Vector3(pixel.x, 0.0, pixel.y)


func world_to_coord(world_position: Vector3) -> Vector2i:
	if _grid == null:
		return INVALID_COORD
	return _grid.world_to_coord_f(Vector2(world_position.x, world_position.z))


func coord_to_screen(coord: Vector2i) -> Vector2:
	return _world2d_to_screen(_coord_to_world2d(coord))


func pick_coord_from_screen(screen_position: Vector2) -> Dictionary:
	if _grid == null:
		return {"ok": false, "message": "grid is not ready", "coord": INVALID_COORD}
	var world2d := _screen_to_world2d(screen_position)
	var coord := _grid.world_to_coord_f(world2d)
	var ok := _grid.has_coord(coord)
	return {
		"ok": ok,
		"message": "picked hex" if ok else "picked outside hex map",
		"coord": coord,
		"world": {"x": world2d.x, "y": 0.0, "z": world2d.y},
	}


func get_tile_screen_position(coord: Vector2i) -> Dictionary:
	if not has_coord(coord):
		return {"ok": false, "message": "coord outside overworld grid"}
	var screen := _world2d_to_screen(_coord_to_world2d(coord))
	return {
		"ok": true,
		"message": "tile screen position",
		"data": {"coord": {"q": coord.x, "r": coord.y}, "x": screen.x, "y": screen.y},
	}


# ========== debug 面（dev-agent，键集逐字保留） ==========

func get_debug_state() -> Dictionary:
	var visual_coord := get_player_visual_coord()
	var visual_position := _driver.get_actor_pixel(PLAYER_ID) if _driver != null else Vector2.ZERO
	var camera_position := _camera.position if _camera != null else Vector2.ZERO
	return {
		"node_type": "InkMonOverworldView",
		"tile_count": _grid.get_all_coords().size() if _grid != null else 0,
		"env_tile_count": _ground_tile_count,
		"player_coord": {"q": player_coord.x, "r": player_coord.y},
		"player_visual_coord": {"q": visual_coord.x, "r": visual_coord.y},
		"player_visual_position": {"x": visual_position.x, "y": 0.0, "z": visual_position.y},
		"player_idle_offset_y": _player_idle_offset_y(),
		"npc_idle_sample_y": _npc_idle_sample_y(),
		"camera_position": {"x": camera_position.x, "y": 0.0, "z": camera_position.y},
		"npc_count": _npc_ids.size(),
		"near_npc_highlight": near_npc_id,
		"near_npc_highlight_scale": _highlight_scale(),
		"camera_ready": _camera != null,
		"move_animation_active": is_move_animation_active(),
		"move_animation_finished_count": _move_finished_count,
		"target_feedback_active": _target_marker != null and is_instance_valid(_target_marker),
		"click_pulse_count": _click_pulse_nodes.size(),
		"idle_animation": true,
		"camera_follow": _camera != null,
		# 键集逐字保留（dev-agent 契约）；值改为 baked 层的有效压扁系数 sin(pitch)。
		"iso_squish": _grid.effective_squish() if _grid != null else 0.0,
	}


# ========== 构建 ==========

func _build_scene() -> void:
	_grid = InkMonRender2DBakedHexMap.new()
	_grid.name = "BakedMap"
	add_child(_grid)
	var bundle := InkMonMapLoader.load_bundle(WORLD_MAP_ID)
	if bundle.is_empty() or not _grid.setup_from_bundle(bundle, DISPLAY_EDGE_PX):
		push_error("overworld view: world map failed to load (%s)" % WORLD_MAP_ID)
		return
	_ground_tile_count = _grid.tile_count()

	_build_camera()

	_feedback_root = Node2D.new()
	_feedback_root.name = "FeedbackRoot"
	add_child(_feedback_root)

	_units_root = Node2D.new()
	_units_root.name = "UnitsRoot"
	# Y-sort（T6, adr/0006 + ysort-occluder-marking）：单位（脚点 y）与面片遮挡体
	# （baseline_y）同场排序——单位在遮挡体基线之上（更远）时被重印像素盖住、
	# 探出半身；之下（更近）时画在遮挡体之后。开启前单位间是树序，开启后按 y
	# 排序（同为画家序正确方向）。
	_units_root.y_sort_enabled = true
	add_child(_units_root)
	_grid.build_occluders(_units_root)

	_driver = InkMonOverworldLiveDriver.new()
	_driver.name = "OverworldDriver"
	add_child(_driver)
	_driver.setup(_grid, _units_root, _feedback_root)
	_driver.start_live()


func _build_camera() -> void:
	_camera = Camera2D.new()
	_camera.name = "OverworldCamera"
	add_child(_camera)
	_camera.make_current()


# ========== 相机 / 移动完成计数 ==========

func _update_camera_follow(delta: float) -> void:
	if _camera == null or _driver == null:
		return
	if _driver.get_avatar(PLAYER_ID) == null:
		return
	var weight := clampf(delta * CAMERA_FOLLOW_SPEED, 0.0, 1.0)
	_camera.position = _camera.position.lerp(_driver.get_actor_pixel(PLAYER_ID), weight)


func _track_move_finished() -> void:
	var moving := is_move_animation_active()
	if _was_player_moving and not moving:
		_move_finished_count += 1
	_was_player_moving = moving


# ========== view-local marker / 几何 helpers ==========

func _show_target_marker(coord: Vector2i) -> void:
	if _target_marker != null and is_instance_valid(_target_marker):
		_target_marker.queue_free()
	_target_marker = _make_disc("TargetHighlight", _grid.edge_px() * 0.5, Color(1.0, 0.78, 0.18, 0.68), _grid.effective_squish())
	_feedback_root.add_child(_target_marker)
	_target_marker.position = _coord_to_world2d(coord)


func _spawn_click_pulse(coord: Vector2i) -> void:
	var pulse := _make_disc("ClickPulse", _grid.edge_px() * 0.34, Color(1.0, 0.95, 0.42, 0.42), _grid.effective_squish())
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


func _coord_to_world2d(coord: Vector2i) -> Vector2:
	return _grid.coord_to_world(coord.x, coord.y) if _grid != null else Vector2.ZERO


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


func _player_idle_offset_y() -> float:
	if _driver == null:
		return 0.0
	var avatar := _driver.get_avatar(PLAYER_ID)
	return avatar.get_idle_offset_y() if avatar != null else 0.0


func _npc_idle_sample_y() -> float:
	if _driver == null:
		return 0.0
	for id in _npc_ids:
		var avatar := _driver.get_avatar(id)
		if avatar != null:
			return avatar.get_idle_offset_y()
	return 0.0


func _highlight_scale() -> float:
	if near_npc_id == "" or _driver == null:
		return 1.0
	var avatar := _driver.get_avatar(near_npc_id)
	return avatar.scale.x if avatar != null else 0.0


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
