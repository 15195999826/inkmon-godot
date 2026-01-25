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
var _camera_rig: Node3D
var _camera: Camera3D
var _ui_layer: CanvasLayer

## 单位视图 Map（actor_id -> UnitView）
var _unit_views: Dictionary = {}


# ========== 初始化 ==========

func _ready() -> void:
	_setup_scene_structure()
	_setup_camera()
	_setup_lighting()
	_setup_ground()


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


## 设置相机
func _setup_camera() -> void:
	_camera_rig = Node3D.new()
	_camera_rig.name = "CameraRig"
	_camera_rig.position = Vector3(0, 15, 10)
	_camera_rig.rotation_degrees = Vector3(-50, 0, 0)
	add_child(_camera_rig)
	
	_camera = Camera3D.new()
	_camera.name = "Camera3D"
	_camera.fov = 45.0
	_camera_rig.add_child(_camera)


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


## 设置地面
func _setup_ground() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	
	var plane := PlaneMesh.new()
	plane.size = Vector2(50, 50)
	ground.mesh = plane
	
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.35, 0.4)
	ground.material_override = material
	
	add_child(ground)


# ========== 公共方法 ==========

## 加载并播放回放
func load_and_play(replay_data: Dictionary) -> void:
	_director.load_replay(replay_data)
	_spawn_units(replay_data)
	_director.play()


## 加载回放（不自动播放）
func load_replay(replay_data: Dictionary) -> void:
	_director.load_replay(replay_data)
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
func set_speed(speed: float) -> void:
	_director.set_speed(speed)


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
	var hex_config := FrontendHexGridConfig.create_default_3d()
	
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
		var position_data: Dictionary = actor_dict.get("position", {})
		var hex_pos := _extract_hex_position(position_data)
		var world_pos := hex_config.hex_to_world(hex_pos)
		unit_view.set_world_position(world_pos)


## 从位置数据提取六边形坐标
func _extract_hex_position(position_data: Dictionary) -> Vector2i:
	if position_data.has("hex"):
		var hex: Dictionary = position_data["hex"]
		return Vector2i(hex.get("q", 0) as int, hex.get("r", 0) as int)
	
	if position_data.has("world"):
		var world: Dictionary = position_data["world"]
		# 简化处理：假设 world.x 和 world.y 是 hex 坐标
		return Vector2i(roundi(world.get("x", 0.0) as float), roundi(world.get("y", 0.0) as float))
	
	return Vector2i.ZERO


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


func _on_frame_changed(current_frame: int, total_frames: int) -> void:
	# 可以在这里更新 UI
	pass


func _on_playback_ended() -> void:
	print("[BattleReplayScene] Playback ended")


func _process(_delta: float) -> void:
	# 更新所有单位位置（修复 C2: 移动动画期间单位位置平滑更新）
	_update_all_unit_positions()
	
	# 应用震屏效果
	var shake_offset := _director.get_screen_shake_offset()
	if shake_offset != Vector2.ZERO:
		_camera_rig.position.x = shake_offset.x * 0.1
		_camera_rig.position.z = 10 + shake_offset.y * 0.1
	else:
		_camera_rig.position.x = 0
		_camera_rig.position.z = 10
