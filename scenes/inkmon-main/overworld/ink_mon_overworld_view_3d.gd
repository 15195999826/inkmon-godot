class_name InkMonOverworldView3D
extends Node3D


const MAP_RADIUS := 4
const INVALID_COORD := Vector2i(-999999, -999999)
const PLAYER_HEIGHT := 0.48
const NPC_HEIGHT := 0.42

const GRASS_TILE_PATH := "res://art/kaykit/hexagon/addons/kaykit_medieval_hexagon_pack/Assets/gltf/tiles/base/hex_grass.gltf"
const ROAD_TILE_PATH := "res://art/kaykit/hexagon/addons/kaykit_medieval_hexagon_pack/Assets/gltf/tiles/roads/hex_road_A.gltf"


var player_coord := Vector2i.ZERO
var near_npc_id := ""
var npc_defs: Dictionary = {}

var _grid_model: GridMapModel
var _grid_renderer: GridMapRenderer3D
var _camera: Camera3D
var _units_root: Node3D
var _player_node: Node3D
var _npc_nodes: Dictionary = {}


func _ready() -> void:
	_build_scene()
	set_player_coord(player_coord)
	set_npcs(npc_defs)


func set_player_coord(coord: Vector2i) -> void:
	player_coord = coord
	if _player_node != null:
		_player_node.global_position = coord_to_world(coord) + Vector3(0.0, PLAYER_HEIGHT, 0.0)


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
	return {
		"node_type": "InkMonOverworldView3D",
		"tile_count": _grid_model.get_tile_count() if _grid_model != null else 0,
		"env_tile_count": _grid_renderer.get_env_tile_count() if _grid_renderer != null else 0,
		"player_coord": {"q": player_coord.x, "r": player_coord.y},
		"npc_count": _npc_nodes.size(),
		"camera_ready": _camera != null,
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
	_camera.position = Vector3(5.5, 8.0, 8.0)
	_camera.fov = 42.0
	add_child(_camera)
	_camera.look_at(Vector3.ZERO, Vector3.UP)


func _create_player_marker() -> Node3D:
	var root := Node3D.new()
	root.name = "PlayerAvatar"

	var body := MeshInstance3D.new()
	body.name = "Body"
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.20
	body_mesh.height = 0.72
	body.mesh = body_mesh
	body.material_override = _material(Color(0.08, 0.28, 0.58))
	root.add_child(body)

	var head := MeshInstance3D.new()
	head.name = "Head"
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.18
	head.mesh = head_mesh
	head.position = Vector3(0.0, 0.48, 0.0)
	head.material_override = _material(Color(0.86, 0.70, 0.54))
	root.add_child(head)
	return root


func _create_npc_marker(npc_id: String, display_name: String) -> Node3D:
	var root := Node3D.new()
	root.name = "NPC_%s" % npc_id

	var body := MeshInstance3D.new()
	body.name = "Body"
	var body_mesh := CylinderMesh.new()
	body_mesh.top_radius = 0.18
	body_mesh.bottom_radius = 0.22
	body_mesh.height = 0.62
	body.mesh = body_mesh
	body.material_override = _material(_npc_color(npc_id))
	root.add_child(body)

	var label := Label3D.new()
	label.name = "NameLabel"
	label.text = display_name
	label.position = Vector3(0.0, 0.72, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 28
	label.modulate = Color(1.0, 0.88, 0.45)
	root.add_child(label)
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


func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	return mat


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
