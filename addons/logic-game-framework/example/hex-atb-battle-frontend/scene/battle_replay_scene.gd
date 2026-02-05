## BattleReplayScene - 战斗回放主场景
##
## 管理整个战斗回放的 3D 场景，包含：
## - BattleDirector（回放控制）
## - 单位管理
## - 相机控制
## - UI 控制
class_name FrontendBattleReplayScene
extends Node3D




# ========== 导出属性 ==========

## 单位视图场景（可选，如果不设置则使用默认）
@export var unit_view_scene: PackedScene


# ========== 节点引用 ==========

var _director: FrontendBattleDirector
var _units_root: Node3D
var _effects_root: Node3D
var _camera_rig: LomoCameraRig
var _ui_layer: CanvasLayer
var _hex_grid_renderer: GridMapRenderer3D

## 单位视图 Map（actor_id -> UnitView）
var _unit_views: Dictionary = {}

## 六边形网格世界模型（用于渲染）
var _hex_world: GridMapModel

## 位置格式配置（type -> format）
var _position_formats: Dictionary = {}


# ========== 初始化 ==========

func _ready() -> void:
	_setup_scene_structure()
	_setup_camera()
	_setup_lighting()
	_setup_hex_grid_renderer()


## 设置场景结构
func _setup_scene_structure() -> void:
	# 创建 BattleDirector
	_director = FrontendBattleDirector.new()
	_director.name = "BattleDirector"
	add_child(_director)
	
	# 连接信号
	_director.actor_state_changed.connect(_on_actor_state_changed)
	_director.floating_text_created.connect(_on_floating_text_created)
	_director.actor_died.connect(_on_actor_died)
	_director.frame_changed.connect(_on_frame_changed)
	_director.playback_ended.connect(_on_playback_ended)
	
	# 创建单位根节点
	_units_root = Node3D.new()
	_units_root.name = "UnitsRoot"
	add_child(_units_root)
	
	# 创建特效根节点
	_effects_root = Node3D.new()
	_effects_root.name = "EffectsRoot"
	add_child(_effects_root)
	
	# 创建 UI 层
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "UILayer"
	add_child(_ui_layer)


func _exit_tree() -> void:
	# 断开 Director 信号连接 (修复 C1: 内存泄漏)
	if _director:
		_director.actor_state_changed.disconnect(_on_actor_state_changed)
		_director.floating_text_created.disconnect(_on_floating_text_created)
		_director.actor_died.disconnect(_on_actor_died)
		_director.frame_changed.disconnect(_on_frame_changed)
		_director.playback_ended.disconnect(_on_playback_ended)


## 设置相机（使用 LomoCameraRig）
func _setup_camera() -> void:
	var camera_scene := preload("res://addons/lomolib/camera/lomo_camera_rig.tscn")
	_camera_rig = camera_scene.instantiate() as LomoCameraRig
	_camera_rig.name = "CameraRig"
	
	# 配置相机参数（适合战斗场景）
	_camera_rig.default_arm_length = 20.0
	_camera_rig.min_zoom = 8.0
	_camera_rig.max_zoom = 40.0
	_camera_rig.default_pitch = -50.0
	_camera_rig.move_speed = 15.0
	
	add_child(_camera_rig)
	_camera_rig.make_current()


## 设置光照
func _setup_lighting() -> void:
	# 方向光
	var dir_light := DirectionalLight3D.new()
	dir_light.name = "DirectionalLight"
	dir_light.position = Vector3(5, 10, 5)
	dir_light.rotation_degrees = Vector3(-45, 45, 0)
	dir_light.light_energy = 1.0
	dir_light.shadow_enabled = true
	add_child(dir_light)
	
	# 环境光
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.2, 0.2, 0.3)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.4, 0.4, 0.5)
	env.ambient_light_energy = 0.5
	world_env.environment = env
	add_child(world_env)


## 设置六边形网格渲染器
func _setup_hex_grid_renderer() -> void:
	_hex_grid_renderer = GridMapRenderer3D.new()
	_hex_grid_renderer.name = "GridMapRenderer"
	# 配置渲染器颜色
	_hex_grid_renderer.grid_color = Color(0.4, 0.45, 0.5, 0.8)
	_hex_grid_renderer.highlight_color = Color.YELLOW
	_hex_grid_renderer.fill_color = Color(0.2, 0.6, 1.0, 0.2)
	add_child(_hex_grid_renderer)


## 从回放数据设置六边形网格
func _setup_hex_grid_from_replay(replay_data: Dictionary) -> void:
	var map_config: Dictionary = replay_data.get("mapConfig", {})
	
	if map_config.is_empty():
		print("[BattleReplayScene] No mapConfig in replay data, using default grid")
		# 使用默认配置
		map_config = {
			"draw_mode": "row_column",
			"rows": 9,
			"columns": 9,
			"size": 10.0,
			"orientation": "flat",
		}
	
	print("[BattleReplayScene] Setting up hex grid: %s" % map_config)
	
	# 创建 GridMapConfig
	var grid_config := GridMapConfig.new()
	grid_config.grid_type = GridMapConfig.GridType.HEX
	grid_config.size = float(map_config.get("size", 10.0))
	grid_config.origin = Vector2.ZERO
	
	# 转换方向枚举（支持枚举数值和字符串）
	var orientation_val: Variant = map_config.get("orientation", 0)
	if orientation_val is int:
		grid_config.orientation = (orientation_val as int) as GridMapConfig.Orientation
	else:
		grid_config.orientation = GridMapConfig.Orientation.FLAT if str(orientation_val) == "flat" else GridMapConfig.Orientation.POINTY
	
	# 转换绘制模式（支持枚举数值和字符串）
	var draw_mode_val: Variant = map_config.get("draw_mode", 0)
	if draw_mode_val is int:
		grid_config.draw_mode = (draw_mode_val as int) as GridMapConfig.DrawMode
	else:
		var draw_mode_str := str(draw_mode_val)
		if draw_mode_str == "radius":
			grid_config.draw_mode = GridMapConfig.DrawMode.RADIUS
		else:
			grid_config.draw_mode = GridMapConfig.DrawMode.ROW_COLUMN
	
	# 设置行列或半径
	if grid_config.draw_mode == GridMapConfig.DrawMode.ROW_COLUMN:
		grid_config.rows = int(map_config.get("rows", 9))
		grid_config.columns = int(map_config.get("columns", 9))
	else:
		grid_config.radius = int(map_config.get("radius", 4))
	
	# 创建 GridMapModel 并初始化
	_hex_world = GridMapModel.new()
	_hex_world.initialize(grid_config)
	
	# 设置渲染器的数据模型并渲染
	_hex_grid_renderer.set_model(_hex_world)
	_hex_grid_renderer.render_grid()


# ========== 公共方法 ==========

## 加载并播放回放
func load_and_play(replay_data: Dictionary) -> void:
	load_replay(replay_data)
	_director.play()


## 加载回放（不自动播放）
func load_replay(replay_data: Dictionary) -> void:
	# 读取 positionFormats 配置
	var configs: Dictionary = replay_data.get("configs", {})
	_position_formats = configs.get("positionFormats", {})
	
	_director.load_replay(replay_data)
	_setup_hex_grid_from_replay(replay_data)
	_spawn_units(replay_data)
	_clear_effects()  # 清理旧特效 (修复 M4)


## 播放
func play() -> void:
	_director.play()


## 暂停
func pause() -> void:
	_director.pause()


## 切换播放/暂停
func toggle() -> void:
	_director.toggle()


## 重置
func reset() -> void:
	_director.reset()
	_reset_unit_views()
	_clear_effects()  # 清理特效 (修复 M4)


## 设置播放速度
func set_speed(new_speed: float) -> void:
	_director.set_speed(new_speed)


## 获取 Director
func get_director() -> FrontendBattleDirector:
	return _director


# ========== 内部方法 ==========

## 生成单位
func _spawn_units(replay_data: Dictionary) -> void:
	# 清除现有单位
	for child in _units_root.get_children():
		child.queue_free()
	_unit_views.clear()
	
	var initial_actors: Array = replay_data.get("initialActors", [])
	print("[BattleReplayScene] Spawning %d units" % initial_actors.size())
	
	for actor_data in initial_actors:
		var actor_dict := actor_data as Dictionary
		var actor_id: String = actor_dict.get("id", "")
		
		if actor_id.is_empty():
			continue
		
		# 创建单位视图
		var unit_view: FrontendUnitView
		if unit_view_scene:
			unit_view = unit_view_scene.instantiate() as FrontendUnitView
		else:
			unit_view = FrontendUnitView.new()
		
		unit_view.name = actor_id  # 设置节点名称 (修复 M2)
		_units_root.add_child(unit_view)
		_unit_views[actor_id] = unit_view
		
		# 初始化单位
		var display_name: String = actor_dict.get("displayName", "")
		var team: int = actor_dict.get("team", 0) as int
		var attributes: Dictionary = actor_dict.get("attributes", {})
		var max_hp: float = attributes.get("maxHp", attributes.get("max_hp", 100.0)) as float
		var current_hp: float = attributes.get("hp", 100.0) as float
		
		unit_view.initialize(actor_id, display_name, team, max_hp, current_hp)
		
		# 设置位置
		var actor_type: String = actor_dict.get("type", "")
		var position_arr: Array = actor_dict.get("position", [])
		var world_pos := _extract_world_position(position_arr, actor_type)
		unit_view.set_world_position(world_pos)


## 从位置数组提取世界坐标
## 根据 positionFormats 配置解释 position 数组的含义
func _extract_world_position(position_arr: Array, actor_type: String) -> Vector3:
	if position_arr.is_empty():
		return Vector3.ZERO
	
	# 查找该类型的位置格式，默认为 "world"
	var format: String = _position_formats.get(actor_type, "world")
	
	if format == "hex" and _hex_world != null:
		# position 是 [q, r, z]，转换为世界坐标
		var q := int(position_arr[0]) if position_arr.size() > 0 else 0
		var r := int(position_arr[1]) if position_arr.size() > 1 else 0
		var hex_coord := HexCoord.new(q, r)
		var pixel: Vector2 = _hex_world.coord_to_world(hex_coord)
		return Vector3(pixel.x, 0.0, pixel.y)
	else:
		# position 是 [x, y, z] 世界坐标，直接使用
		return Vector3(
			position_arr[0] if position_arr.size() > 0 else 0.0,
			position_arr[1] if position_arr.size() > 1 else 0.0,
			position_arr[2] if position_arr.size() > 2 else 0.0
		)


## 重置单位视图
func _reset_unit_views() -> void:
	var state := _director.get_render_state()
	var actors: Dictionary = state.get("actors", {})
	
	for actor_id in actors.keys():
		var actor_state: Dictionary = actors[actor_id]
		if _unit_views.has(actor_id):
			var unit_view: FrontendUnitView = _unit_views[actor_id]
			unit_view.update_state(actor_state)
			unit_view.visible = true
			unit_view.scale = Vector3.ONE


## 清理所有特效节点 (修复 M4)
func _clear_effects() -> void:
	for child in _effects_root.get_children():
		child.queue_free()


## 更新所有单位位置（修复 C2: 移动动画期间单位位置平滑更新）
func _update_all_unit_positions() -> void:
	for actor_id in _unit_views.keys():
		var unit_view: FrontendUnitView = _unit_views[actor_id]
		var world_pos := _director.get_actor_world_position(actor_id)
		unit_view.set_world_position(world_pos)


# ========== 信号处理 ==========

func _on_actor_state_changed(actor_id: String, state: Dictionary) -> void:
	if _unit_views.has(actor_id):
		var unit_view: FrontendUnitView = _unit_views[actor_id]
		unit_view.update_state(state)
		
		# 更新位置
		var world_pos := _director.get_actor_world_position(actor_id)
		unit_view.set_world_position(world_pos)


func _on_floating_text_created(data: Dictionary) -> void:
	var floating_text := FrontendFloatingTextView.new()
	_effects_root.add_child(floating_text)
	
	var text: String = data.get("text", "")
	var color: Color = data.get("color", Color.WHITE)
	var world_position: Vector3 = data.get("position", Vector3.ZERO)
	var style: int = data.get("style", 0)
	var duration: float = data.get("duration", 1000.0)
	
	floating_text.initialize(text, color, world_position, style, duration)


func _on_actor_died(actor_id: String) -> void:
	print("[BattleReplayScene] Actor died: %s" % actor_id)


func _on_frame_changed(_current_frame: int, _total_frames: int) -> void:
	# 可以在这里更新 UI
	pass


func _on_playback_ended() -> void:
	print("[BattleReplayScene] Playback ended")


func _process(_delta: float) -> void:
	# 更新所有单位位置（修复 C2: 移动动画期间单位位置平滑更新）
	_update_all_unit_positions()
	
	# 震屏效果（通过 LomoCameraRig 的位置偏移实现）
	var shake_offset := _director.get_screen_shake_offset()
	if shake_offset != Vector2.ZERO:
		# 临时偏移相机位置
		var base_pos := _camera_rig.global_position
		_camera_rig.global_position = base_pos + Vector3(shake_offset.x * 0.1, 0, shake_offset.y * 0.1)


## 获取相机 Rig（供外部访问）
func get_camera_rig() -> LomoCameraRig:
	return _camera_rig
