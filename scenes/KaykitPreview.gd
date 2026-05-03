## KayKit Hex Battle 静态预览 (新版: GridMapRenderer3D MultiMesh 渲染)
##
## 117 tile + 32 装饰 + 12 建筑 全部走 GridMapRenderer3D.set_tile_env(),
## scene tree 里只有 ~8 个 MultiMeshInstance3D 子节点。
## 6 个角色保留 PackedScene instance (有骨骼动画无法 MultiMesh)。
extends Node


# ---- KayKit mesh 路径 (env_id -> .gltf) ----

const ENV_MESH_PATHS := {
	&"grass":          "res://art/kaykit/hexagon/addons/kaykit_medieval_hexagon_pack/Assets/gltf/tiles/base/hex_grass.gltf",
	&"road":           "res://art/kaykit/hexagon/addons/kaykit_medieval_hexagon_pack/Assets/gltf/tiles/roads/hex_road_A.gltf",
	# river / river_cross 砍了 — KayKit hex_river_A 的水道方向跟 hex 形状是绑死的, 没法只转贴图。
	# 想要中央河需要用 ShaderMaterial 自定义 UV 旋转, 或者按方向换不同 river_*.gltf 子型号 (A/B/C/curvy/...)。
	&"hill_A":         "res://art/kaykit/hexagon/addons/kaykit_medieval_hexagon_pack/Assets/gltf/decoration/nature/hill_single_A.gltf",
	&"hill_B":         "res://art/kaykit/hexagon/addons/kaykit_medieval_hexagon_pack/Assets/gltf/decoration/nature/hill_single_B.gltf",
	&"hill_C":         "res://art/kaykit/hexagon/addons/kaykit_medieval_hexagon_pack/Assets/gltf/decoration/nature/hill_single_C.gltf",
	&"trees_A":        "res://art/kaykit/hexagon/addons/kaykit_medieval_hexagon_pack/Assets/gltf/decoration/nature/hills_A_trees.gltf",
	&"trees_B":        "res://art/kaykit/hexagon/addons/kaykit_medieval_hexagon_pack/Assets/gltf/decoration/nature/hills_B_trees.gltf",
	&"trees_C":        "res://art/kaykit/hexagon/addons/kaykit_medieval_hexagon_pack/Assets/gltf/decoration/nature/hills_C_trees.gltf",
	&"mountain_A":     "res://art/kaykit/hexagon/addons/kaykit_medieval_hexagon_pack/Assets/gltf/decoration/nature/mountain_A.gltf",
	&"mountain_B":     "res://art/kaykit/hexagon/addons/kaykit_medieval_hexagon_pack/Assets/gltf/decoration/nature/mountain_B.gltf",
	&"mountain_grass": "res://art/kaykit/hexagon/addons/kaykit_medieval_hexagon_pack/Assets/gltf/decoration/nature/mountain_A_grass.gltf",
	&"castle_blue":    "res://art/kaykit/hexagon/addons/kaykit_medieval_hexagon_pack/Assets/gltf/buildings/blue/building_castle_blue.gltf",
	&"barracks_blue":  "res://art/kaykit/hexagon/addons/kaykit_medieval_hexagon_pack/Assets/gltf/buildings/blue/building_barracks_blue.gltf",
	&"archery_blue":   "res://art/kaykit/hexagon/addons/kaykit_medieval_hexagon_pack/Assets/gltf/buildings/blue/building_archeryrange_blue.gltf",
	&"smith_blue":     "res://art/kaykit/hexagon/addons/kaykit_medieval_hexagon_pack/Assets/gltf/buildings/blue/building_blacksmith_blue.gltf",
	&"castle_red":     "res://art/kaykit/hexagon/addons/kaykit_medieval_hexagon_pack/Assets/gltf/buildings/red/building_castle_red.gltf",
	&"barracks_red":   "res://art/kaykit/hexagon/addons/kaykit_medieval_hexagon_pack/Assets/gltf/buildings/red/building_barracks_red.gltf",
	&"archery_red":    "res://art/kaykit/hexagon/addons/kaykit_medieval_hexagon_pack/Assets/gltf/buildings/red/building_archeryrange_red.gltf",
	&"smith_red":      "res://art/kaykit/hexagon/addons/kaykit_medieval_hexagon_pack/Assets/gltf/buildings/red/building_blacksmith_red.gltf",
}

# Tower 是 2 mesh (base + cap),第一版 MultiMesh 单 mesh 假设处理不了,走 PackedScene fallback。
const TOWER_BLUE_PATH := "res://art/kaykit/hexagon/addons/kaykit_medieval_hexagon_pack/Assets/gltf/buildings/blue/building_tower_A_blue.gltf"
const TOWER_RED_PATH := "res://art/kaykit/hexagon/addons/kaykit_medieval_hexagon_pack/Assets/gltf/buildings/red/building_tower_A_red.gltf"

# ---- 单位 (PackedScene path, team, axial coord) ----

const UNIT_DEFS := [
	["res://art/kaykit/adventurers/addons/kaykit_character_pack_adventures/Characters/gltf/Knight.glb",       "blue", Vector2i(-3, -1)],
	["res://art/kaykit/adventurers/addons/kaykit_character_pack_adventures/Characters/gltf/Mage.glb",         "blue", Vector2i(-3,  0)],
	["res://art/kaykit/adventurers/addons/kaykit_character_pack_adventures/Characters/gltf/Barbarian.glb",    "blue", Vector2i(-3,  1)],
	["res://art/kaykit/skeletons/addons/kaykit_character_pack_skeletons/Characters/gltf/Skeleton_Warrior.glb","red",  Vector2i( 3, -1)],
	["res://art/kaykit/skeletons/addons/kaykit_character_pack_skeletons/Characters/gltf/Skeleton_Mage.glb",   "red",  Vector2i( 3,  0)],
	["res://art/kaykit/skeletons/addons/kaykit_character_pack_skeletons/Characters/gltf/Skeleton_Rogue.glb",  "red",  Vector2i( 3,  1)],
]

# ---- 战场 layout (axial Vector2i 作 key) ----
# 13×9 hex 战场: q ∈ [-6,6], r ∈ [-4,4]

const RANGE_Q := Vector2i(-6, 6)
const RANGE_R := Vector2i(-4, 4)

const BUILDINGS := {
	# axial -> [env_id, facing_yaw_deg]; tower_blue/tower_red 走 PackedScene fallback
	Vector2i(-6,  0): [&"castle_blue",   90.0],
	Vector2i( 6,  0): [&"castle_red",   -90.0],
	Vector2i(-5, -2): [&"barracks_blue", 90.0],
	Vector2i(-5,  2): [&"archery_blue",  90.0],
	Vector2i(-5,  0): [&"smith_blue",    90.0],
	Vector2i(-4, -3): [&"tower_blue",     0.0],
	Vector2i(-4,  3): [&"tower_blue",     0.0],
	Vector2i( 5, -2): [&"barracks_red", -90.0],
	Vector2i( 5,  2): [&"archery_red",  -90.0],
	Vector2i( 5,  0): [&"smith_red",    -90.0],
	Vector2i( 4, -3): [&"tower_red",      0.0],
	Vector2i( 4,  3): [&"tower_red",      0.0],
}

const DECOR := {
	Vector2i(-6, -4): &"mountain_A", Vector2i(-6,  4): &"mountain_B",
	Vector2i( 6, -4): &"mountain_B", Vector2i( 6,  4): &"mountain_A",
	Vector2i(-5, -4): &"mountain_grass", Vector2i( 5, -4): &"mountain_grass",
	Vector2i(-5,  4): &"trees_A", Vector2i( 5,  4): &"trees_B",
	Vector2i(-4, -4): &"trees_B", Vector2i(-4,  4): &"trees_C",
	Vector2i( 4, -4): &"trees_C", Vector2i( 4,  4): &"trees_A",
	Vector2i(-3, -4): &"hill_A",  Vector2i(-3,  4): &"hill_B",
	Vector2i( 3, -4): &"hill_C",  Vector2i( 3,  4): &"hill_A",
	Vector2i(-2, -4): &"trees_A", Vector2i(-2,  4): &"hill_B",
	Vector2i( 2, -4): &"hill_C",  Vector2i( 2,  4): &"trees_C",
	Vector2i(-1, -4): &"hill_A",  Vector2i(-1,  4): &"hill_C",
	Vector2i( 1, -4): &"hill_B",  Vector2i( 1,  4): &"hill_A",
	Vector2i(-6, -3): &"trees_A", Vector2i(-6,  3): &"trees_B",
	Vector2i( 6, -3): &"trees_B", Vector2i( 6,  3): &"trees_A",
	Vector2i(-3, -3): &"hill_C",  Vector2i( 3,  3): &"hill_C",
	Vector2i(-2, -3): &"hill_A",  Vector2i( 2,  3): &"hill_B",
}


@onready var _camera_rig: LomoCameraRig = $CameraRig as LomoCameraRig
@onready var _units_root: Node3D = $Units

var _grid_renderer: GridMapRenderer3D
var _grid_model: GridMapModel


func _ready() -> void:
	_setup_grid()
	_register_envs()
	_populate_tiles()
	_populate_decor()
	_populate_buildings()
	_spawn_units()
	_play_idle_anims(_units_root)
	print("[KaykitPreview] tiles=%d  WASD/QE/Wheel/Space" % _grid_renderer.get_env_tile_count())


# ========== Grid setup ==========

func _setup_grid() -> void:
	_grid_renderer = GridMapRenderer3D.new()
	_grid_renderer.name = "GridRenderer"
	add_child(_grid_renderer)

	var cfg := GridMapConfig.new()
	cfg.grid_type = GridMapConfig.GridType.HEX
	cfg.orientation = GridMapConfig.Orientation.POINTY
	cfg.draw_mode = GridMapConfig.DrawMode.ROW_COLUMN
	cfg.rows = (RANGE_R.y - RANGE_R.x + 1) + 4   # 留余裕,model 内部 half_rows 算法
	cfg.columns = (RANGE_Q.y - RANGE_Q.x + 1) + 4
	cfg.size = 2.0 / sqrt(3.0)                   # KayKit hex_grass outer_radius

	_grid_model = GridMapModel.new()
	_grid_model.initialize(cfg)
	_grid_renderer.set_model(_grid_model)


# ========== Env mesh registration ==========

## 各 env 的 mesh 默认朝向偏移 (绕 Y 轴度数), 当前所有地形 mesh 的 hex 形状都按 pointy-top 默认放,
## 不需要偏移。需要时在这里加 (例如某个 mesh 内置朝向是 flat 但项目用 pointy)。
const ENV_YAW_OFFSETS := {
	&"road": 0.0,
}


func _register_envs() -> void:
	for env_id in ENV_MESH_PATHS:
		var path: String = ENV_MESH_PATHS[env_id]
		var ps: PackedScene = load(path)
		if ps == null:
			push_error("[KaykitPreview] failed to load %s" % path)
			continue
		var mesh := _extract_first_mesh(ps)
		if mesh == null:
			push_error("[KaykitPreview] no mesh in %s" % path)
			continue
		var yaw: float = ENV_YAW_OFFSETS.get(env_id, 0.0)
		_grid_renderer.register_env(env_id, mesh, yaw)


func _extract_first_mesh(ps: PackedScene) -> Mesh:
	var inst := ps.instantiate()
	var mi := _find_mesh_instance(inst)
	var mesh: Mesh = mi.mesh if mi != null else null
	inst.queue_free()
	return mesh


func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for c in node.get_children():
		var found := _find_mesh_instance(c)
		if found != null:
			return found
	return null


# ========== Tile / decor / buildings ==========

func _populate_tiles() -> void:
	# 全格满铺地形 (grass / road / river / river_cross), 不再 skip building/decor 位置。
	# 建筑和装饰走 add_decoration 叠在 grass 上方。
	for q in range(RANGE_Q.x, RANGE_Q.y + 1):
		for r in range(RANGE_R.x, RANGE_R.y + 1):
			var env_id := _tile_env_at(q, r)
			_grid_renderer.set_tile_env(HexCoord.new(q, r), env_id)


func _populate_decor() -> void:
	for key: Vector2i in DECOR:
		var env_id: StringName = DECOR[key]
		_grid_renderer.add_decoration(HexCoord.new(key.x, key.y), env_id)


func _populate_buildings() -> void:
	for key: Vector2i in BUILDINGS:
		var entry: Array = BUILDINGS[key]
		var env_id: StringName = entry[0]
		var facing: float = entry[1]
		if env_id == &"tower_blue" or env_id == &"tower_red":
			# Tower 是 2 mesh (base + cap), v1 MultiMesh 单 mesh 假设处理不了, 走 PackedScene fallback。
			var p := TOWER_BLUE_PATH if env_id == &"tower_blue" else TOWER_RED_PATH
			var ps: PackedScene = load(p)
			if ps != null:
				var inst := ps.instantiate() as Node3D
				add_child(inst)
				var pixel := _grid_model.coord_to_world(HexCoord.new(key.x, key.y))
				inst.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(facing)), Vector3(pixel.x, 0.0, pixel.y))
		else:
			_grid_renderer.add_decoration(HexCoord.new(key.x, key.y), env_id, facing)


func _tile_env_at(q: int, r: int) -> StringName:
	# 中央 r=0 行铺道路贯通战场 (q=±6 是城堡装饰区,留 grass 让城堡叠在草地上)
	if r == 0 and q != -6 and q != 6:
		return &"road"
	return &"grass"


# ========== Units ==========

func _spawn_units() -> void:
	for entry: Array in UNIT_DEFS:
		var path: String = entry[0]
		var team: String = entry[1]
		var coord: Vector2i = entry[2]
		var ps: PackedScene = load(path)
		if ps == null:
			continue
		var inst := ps.instantiate() as Node3D
		inst.name = path.get_file().get_basename()
		_units_root.add_child(inst)
		var pixel := _grid_model.coord_to_world(HexCoord.new(coord.x, coord.y))
		var yaw := 90.0 if team == "blue" else -90.0
		inst.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), Vector3(pixel.x, 0.0, pixel.y))


func _play_idle_anims(root: Node) -> void:
	var anim := _find_animation_player(root)
	if anim != null:
		var idle := _find_idle_anim(anim)
		if idle != "":
			anim.play(idle)
	for c in root.get_children():
		_play_idle_anims(c)


func _find_animation_player(node: Node) -> AnimationPlayer:
	for c in node.get_children():
		if c is AnimationPlayer:
			return c as AnimationPlayer
	return null


func _find_idle_anim(anim: AnimationPlayer) -> String:
	for n: StringName in anim.get_animation_list():
		if "idle" in String(n).to_lower():
			return n
	var list := anim.get_animation_list()
	return list[0] if list.size() > 0 else ""


# ========== Input ==========

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if (event as InputEventKey).keycode == KEY_SPACE and _camera_rig != null:
			_camera_rig.reset_camera()
