class_name InkMonOverworldView3D
extends Node3D


const MAP_RADIUS := 4
const INVALID_COORD := Vector2i(-999999, -999999)
const PLAYER_HEIGHT := 0.48
const NPC_HEIGHT := 0.42
const MOVE_STEP_DURATION := 0.22
const CLICK_PULSE_DURATION := 0.34
const CAMERA_FOLLOW_SPEED := 5.0

const GRASS_TILE_PATH := "res://art/kaykit/hexagon/addons/kaykit_medieval_hexagon_pack/Assets/gltf/tiles/base/hex_grass.gltf"
const ROAD_TILE_PATH := "res://art/kaykit/hexagon/addons/kaykit_medieval_hexagon_pack/Assets/gltf/tiles/roads/hex_road_A.gltf"


signal player_move_animation_finished(final_coord: Vector2i)


var player_coord := Vector2i.ZERO
var near_npc_id := ""
var npc_defs: Dictionary = {}

var _grid_model: GridMapModel
var _grid_renderer: GridMapRenderer3D
var _camera: Camera3D
var _camera_offset := Vector3(5.5, 8.0, 8.0)
var _units_root: Node3D
var _feedback_root: Node3D
var _player_node: Node3D
var _player_visual_root: Node3D
var _npc_nodes: Dictionary = {}
var _npc_visual_roots: Dictionary = {}
var _path_preview_nodes: Array[Node3D] = []
var _target_marker: Node3D
var _click_pulse_nodes: Array[Node3D] = []
var _move_tween: Tween
var _idle_time := 0.0
var _move_animation_active := false
var _move_animation_finished_count := 0
var _move_animation_started_msec := 0
var _last_animation_path: Array[Dictionary] = []
var _last_requested_target := INVALID_COORD
var _last_resolved_target := INVALID_COORD


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
		_player_node.global_position = _coord_to_actor_position(coord, PLAYER_HEIGHT)
		_update_camera_follow(1.0)


func snap_player_coord(coord: Vector2i) -> void:
	_cancel_move_tween()
	_move_animation_active = false
	player_coord = coord
	if _player_node != null:
		_player_node.global_position = _coord_to_actor_position(coord, PLAYER_HEIGHT)
	_update_camera_follow(1.0)


func play_player_path(path: Array[Vector2i], requested_target: Vector2i, resolved_target: Vector2i) -> void:
	_show_move_feedback(path, requested_target, resolved_target)
	player_coord = resolved_target
	_last_requested_target = requested_target
	_last_resolved_target = resolved_target
	_last_animation_path = _path_dicts(path)
	if _player_node == null:
		_finish_move_animation(resolved_target)
		return
	if path.is_empty():
		snap_player_coord(resolved_target)
		_finish_move_animation(resolved_target)
		return

	_cancel_move_tween()
	_move_animation_active = true
	_move_animation_started_msec = Time.get_ticks_msec()
	_move_tween = create_tween()
	_move_tween.set_parallel(false)
	for step_coord in path:
		var step_position := _coord_to_actor_position(step_coord, PLAYER_HEIGHT)
		_move_tween.tween_property(_player_node, "global_position", step_position, MOVE_STEP_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_move_tween.finished.connect(func() -> void:
		_finish_move_animation(resolved_target)
	)


func is_move_animation_active() -> bool:
	return _move_animation_active


func get_player_visual_coord() -> Vector2i:
	if _player_node == null:
		return player_coord
	return world_to_coord(_player_node.global_position)


func set_near_npc_id(npc_id: String) -> void:
	near_npc_id = npc_id
	for key in _npc_nodes.keys():
		var node := _npc_nodes[key] as Node3D
		if node == null:
			continue
		node.scale = Vector3.ONE * (1.18 if str(key) == near_npc_id else 1.0)


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
		node.global_position = coord_to_world(coord) + Vector3(0.0, NPC_HEIGHT, 0.0)
		_npc_nodes[npc_id] = node
		var visual_root := node.get_node_or_null("VisualRoot") as Node3D
		if visual_root != null:
			_npc_visual_roots[npc_id] = visual_root
	set_near_npc_id(near_npc_id)


func has_coord(coord: Vector2i) -> bool:
	return _grid_model != null and _grid_model.has_tile(HexCoord.new(coord.x, coord.y))


func coord_to_world(coord: Vector2i) -> Vector3:
	if _grid_model == null:
		return Vector3.ZERO
	var pixel := _grid_model.coord_to_world(HexCoord.new(coord.x, coord.y))
	return Vector3(pixel.x, 0.0, pixel.y)


func world_to_coord(world_position: Vector3) -> Vector2i:
	if _grid_model == null:
		return INVALID_COORD
	var coord := _grid_model.world_to_coord(Vector2(world_position.x, world_position.z))
	return coord.to_axial()


func coord_to_screen(coord: Vector2i) -> Vector2:
	if _camera == null:
		return Vector2.ZERO
	var world_position := coord_to_world(coord) + Vector3(0.0, 1.15, 0.0)
	if _camera.is_position_behind(world_position):
		return Vector2.ZERO
	return _camera.unproject_position(world_position)


func pick_coord_from_screen(screen_position: Vector2) -> Dictionary:
	if _camera == null:
		return {
			"ok": false,
			"message": "camera is not ready",
			"coord": INVALID_COORD,
		}
	var origin := _camera.project_ray_origin(screen_position)
	var direction := _camera.project_ray_normal(screen_position)
	if absf(direction.y) < 0.0001:
		return {
			"ok": false,
			"message": "ray is parallel to hex plane",
			"coord": INVALID_COORD,
		}
	var distance := -origin.y / direction.y
	if distance < 0.0:
		return {
			"ok": false,
			"message": "ray points away from hex plane",
			"coord": INVALID_COORD,
		}
	var hit := origin + direction * distance
	var coord := world_to_coord(hit)
	return {
		"ok": has_coord(coord),
		"message": "picked hex" if has_coord(coord) else "picked outside hex map",
		"coord": coord,
		"world": {
			"x": hit.x,
			"y": hit.y,
			"z": hit.z,
		},
	}


func get_tile_screen_position(coord: Vector2i) -> Dictionary:
	if not has_coord(coord):
		return {
			"ok": false,
			"message": "coord outside overworld grid",
		}
	var world_position := coord_to_world(coord) + Vector3(0.0, 0.03, 0.0)
	var screen := _camera.unproject_position(world_position) if _camera != null else Vector2.ZERO
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
	var visual_position := _player_node.global_position if _player_node != null else Vector3.ZERO
	var camera_position := _camera.global_position if _camera != null else Vector3.ZERO
	return {
		"node_type": "InkMonOverworldView3D",
		"tile_count": _grid_model.get_tile_count() if _grid_model != null else 0,
		"env_tile_count": _grid_renderer.get_env_tile_count() if _grid_renderer != null else 0,
		"player_coord": {"q": player_coord.x, "r": player_coord.y},
		"player_visual_coord": {"q": visual_coord.x, "r": visual_coord.y},
		"player_visual_position": {"x": visual_position.x, "y": visual_position.y, "z": visual_position.z},
		"player_idle_offset_y": _player_visual_root.position.y if _player_visual_root != null else 0.0,
		"npc_idle_sample_y": _get_npc_idle_sample_y(),
		"camera_position": {"x": camera_position.x, "y": camera_position.y, "z": camera_position.z},
		"npc_count": _npc_nodes.size(),
		"camera_ready": _camera != null,
		"move_animation_active": _move_animation_active,
		"move_animation_finished_count": _move_animation_finished_count,
		"last_animation_path": _last_animation_path.duplicate(true),
		"last_requested_target": {"q": _last_requested_target.x, "r": _last_requested_target.y},
		"last_resolved_target": {"q": _last_resolved_target.x, "r": _last_resolved_target.y},
		"path_preview_count": _path_preview_nodes.size(),
		"target_feedback_active": _target_marker != null and is_instance_valid(_target_marker),
		"click_pulse_count": _click_pulse_nodes.size(),
		"idle_animation": true,
		"camera_follow": _camera != null,
	}


func _build_scene() -> void:
	_grid_renderer = GridMapRenderer3D.new()
	_grid_renderer.name = "GridRenderer3D"
	add_child(_grid_renderer)

	var cfg := GridMapConfig.new()
	cfg.grid_type = GridMapConfig.GridType.HEX
	cfg.orientation = GridMapConfig.Orientation.POINTY
	cfg.draw_mode = GridMapConfig.DrawMode.RADIUS
	cfg.radius = MAP_RADIUS
	cfg.size = 2.0 / sqrt(3.0)
	_grid_model = GridMapModel.new()
	_grid_model.initialize(cfg)
	_grid_renderer.set_model(_grid_model)
	_grid_renderer.grid_color = Color(0.06, 0.05, 0.04, 0.42)
	_grid_renderer.highlight_color = Color(1.0, 0.82, 0.24, 0.95)
	_grid_renderer.render_grid()

	_register_tile_envs()
	_populate_tiles()
	_build_lighting()
	_build_camera()

	_feedback_root = Node3D.new()
	_feedback_root.name = "FeedbackRoot"
	add_child(_feedback_root)

	_units_root = Node3D.new()
	_units_root.name = "UnitsRoot"
	add_child(_units_root)
	_player_node = _create_player_marker()
	_units_root.add_child(_player_node)


func _register_tile_envs() -> void:
	var grass_mesh := _create_hex_tile_mesh(Color(0.28, 0.56, 0.24))
	var road_mesh := _create_hex_tile_mesh(Color(0.56, 0.46, 0.31))
	_grid_renderer.register_env(&"grass", grass_mesh)
	_grid_renderer.register_env(&"road", road_mesh)


func _populate_tiles() -> void:
	for coord in _grid_model.get_all_coords():
		var axial := coord.to_axial()
		var env_id := &"road" if axial.x == 0 or axial.y == 0 or axial.x + axial.y == 0 else &"grass"
		_grid_renderer.set_tile_env(coord, env_id)


func _build_lighting() -> void:
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.38, 0.52, 0.58)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.78, 0.80, 0.70)
	environment.ambient_light_energy = 0.72
	world_env.environment = environment
	add_child(world_env)

	var light := DirectionalLight3D.new()
	light.name = "SunLight"
	light.light_energy = 2.5
	light.rotation_degrees = Vector3(-48.0, 42.0, 0.0)
	add_child(light)


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "OverworldCamera"
	_camera.current = true
	_camera.position = _camera_offset
	_camera.fov = 42.0
	add_child(_camera)
	_camera.look_at(Vector3.ZERO, Vector3.UP)


func _create_player_marker() -> Node3D:
	var root := Node3D.new()
	root.name = "PlayerAvatar"

	var visual_root := Node3D.new()
	visual_root.name = "VisualRoot"
	root.add_child(visual_root)
	_player_visual_root = visual_root

	var body := MeshInstance3D.new()
	body.name = "Body"
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.20
	body_mesh.height = 0.72
	body.mesh = body_mesh
	body.material_override = _material(Color(0.08, 0.28, 0.58))
	visual_root.add_child(body)

	var head := MeshInstance3D.new()
	head.name = "Head"
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.18
	head.mesh = head_mesh
	head.position = Vector3(0.0, 0.48, 0.0)
	head.material_override = _material(Color(0.86, 0.70, 0.54))
	visual_root.add_child(head)
	return root


func _create_npc_marker(npc_id: String, display_name: String) -> Node3D:
	var root := Node3D.new()
	root.name = "NPC_%s" % npc_id

	var visual_root := Node3D.new()
	visual_root.name = "VisualRoot"
	root.add_child(visual_root)

	var body := MeshInstance3D.new()
	body.name = "Body"
	var body_mesh := CylinderMesh.new()
	body_mesh.top_radius = 0.18
	body_mesh.bottom_radius = 0.22
	body_mesh.height = 0.62
	body.mesh = body_mesh
	body.material_override = _material(_npc_color(npc_id))
	visual_root.add_child(body)

	var label := Label3D.new()
	label.name = "NameLabel"
	label.text = display_name
	label.position = Vector3(0.0, 0.72, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 28
	label.modulate = Color(1.0, 0.88, 0.45)
	visual_root.add_child(label)
	return root


func _load_first_mesh(path: String) -> Mesh:
	var ps: PackedScene = load(path)
	if ps == null:
		return null
	var inst := ps.instantiate()
	var mesh_instance := _find_mesh_instance(inst)
	var mesh: Mesh = mesh_instance.mesh if mesh_instance != null else null
	inst.queue_free()
	return mesh


func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_mesh_instance(child)
		if found != null:
			return found
	return null


func _create_hex_tile_mesh(color: Color) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var center := Vector3.ZERO
	for i in range(6):
		var angle_a := PI / 6.0 + float(i) * TAU / 6.0
		var angle_b := PI / 6.0 + float((i + 1) % 6) * TAU / 6.0
		vertices.append(center)
		vertices.append(Vector3(cos(angle_a), 0.0, sin(angle_a)) * 1.05)
		vertices.append(Vector3(cos(angle_b), 0.0, sin(angle_b)) * 1.05)
		colors.append(color)
		colors.append(color)
		colors.append(color)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mesh.surface_set_material(0, mat)
	return mesh


func _coord_to_actor_position(coord: Vector2i, height: float) -> Vector3:
	return coord_to_world(coord) + Vector3(0.0, height, 0.0)


func _show_move_feedback(path: Array[Vector2i], requested_target: Vector2i, resolved_target: Vector2i) -> void:
	_clear_path_preview()
	_show_target_marker(resolved_target)
	_spawn_click_pulse(requested_target)
	for step_coord in path:
		var node := _create_disc_marker("PathStep", 0.16, 0.05, Color(0.26, 0.72, 1.0, 0.92))
		_feedback_root.add_child(node)
		node.global_position = coord_to_world(step_coord) + Vector3(0.0, 0.08, 0.0)
		_path_preview_nodes.append(node)


func _show_target_marker(coord: Vector2i) -> void:
	if _target_marker != null and is_instance_valid(_target_marker):
		_target_marker.queue_free()
	_target_marker = _create_disc_marker("TargetHighlight", 0.62, 0.035, Color(1.0, 0.78, 0.18, 0.68))
	_feedback_root.add_child(_target_marker)
	_target_marker.global_position = coord_to_world(coord) + Vector3(0.0, 0.055, 0.0)


func _spawn_click_pulse(coord: Vector2i) -> void:
	var pulse := _create_disc_marker("ClickPulse", 0.42, 0.03, Color(1.0, 0.95, 0.42, 0.42))
	_feedback_root.add_child(pulse)
	pulse.global_position = coord_to_world(coord) + Vector3(0.0, 0.09, 0.0)
	_click_pulse_nodes.append(pulse)
	var tween := create_tween()
	tween.tween_property(pulse, "scale", Vector3(1.65, 1.0, 1.65), CLICK_PULSE_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func() -> void:
		_click_pulse_nodes.erase(pulse)
		if is_instance_valid(pulse):
			pulse.queue_free()
	)


func _create_disc_marker(marker_name: String, radius: float, height: float, color: Color) -> Node3D:
	var marker := MeshInstance3D.new()
	marker.name = marker_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 48
	marker.mesh = mesh
	marker.material_override = _transparent_material(color)
	return marker


func _clear_path_preview() -> void:
	for node in _path_preview_nodes:
		if node != null and is_instance_valid(node):
			node.queue_free()
	_path_preview_nodes.clear()


func _cancel_move_tween() -> void:
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = null


func _finish_move_animation(final_coord: Vector2i) -> void:
	_move_animation_active = false
	_move_animation_finished_count += 1
	if _player_node != null:
		_player_node.global_position = _coord_to_actor_position(final_coord, PLAYER_HEIGHT)
	player_coord = final_coord
	_update_camera_follow(1.0)
	player_move_animation_finished.emit(final_coord)


func _update_idle_animation(delta: float) -> void:
	if _player_visual_root != null:
		_player_visual_root.position.y = sin(_idle_time * 3.2) * 0.045
		_player_visual_root.rotation.y = sin(_idle_time * 1.4) * 0.08
	for npc_id_value in _npc_visual_roots.keys():
		var npc_id := str(npc_id_value)
		var visual_root := _npc_visual_roots[npc_id] as Node3D
		if visual_root == null:
			continue
		var phase := float(abs(npc_id.hash()) % 100) / 100.0 * TAU
		visual_root.position.y = sin(_idle_time * 2.1 + phase) * 0.035
		visual_root.rotation.y += 0.15 * delta


func _update_camera_follow(delta: float) -> void:
	if _camera == null or _player_node == null:
		return
	var target := _player_node.global_position
	target.y = 0.0
	var desired_position := target + _camera_offset
	var weight := clampf(delta * CAMERA_FOLLOW_SPEED, 0.0, 1.0)
	_camera.global_position = _camera.global_position.lerp(desired_position, weight)
	_camera.look_at(target, Vector3.UP)


func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	return mat


func _transparent_material(color: Color) -> StandardMaterial3D:
	var mat := _material(color)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	return mat


func _path_dicts(path: Array[Vector2i]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for coord in path:
		result.append({"q": coord.x, "r": coord.y})
	return result


func _get_npc_idle_sample_y() -> float:
	for visual_root_value in _npc_visual_roots.values():
		var visual_root := visual_root_value as Node3D
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
