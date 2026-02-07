## RenderWorld - 渲染状态管理
##
## 管理战斗回放的渲染状态，将 VisualAction 应用到状态上。
##
## 职责分离：
## - ActionScheduler 管理"时序"（什么时候执行）
## - RenderWorld 管理"状态"（当前值是什么）
class_name FrontendRenderWorld
extends RefCounted


# ========== 信号 ==========

## 角色状态变化信号
signal actor_state_changed(actor_id: String, state: Dictionary)

## 飘字创建信号
signal floating_text_created(data: Dictionary)

## 角色死亡信号
signal actor_died(actor_id: String)


# ========== 内部状态 ==========

## Actor 状态 Map（actor_id -> Dictionary）
var _actors: Dictionary = {}

## 插值位置 Map（actor_id -> Vector2）用于移动动画
var _interpolated_positions: Dictionary = {}

## 活跃的飘字
var _floating_texts: Array[Dictionary] = []

## 活跃的程序化特效
var _procedural_effects: Array[Dictionary] = []

## 震屏状态
var _screen_shake: Dictionary = {}

## 六边形网格布局
var _layout: GridLayout

## 动画配置
var _animation_config: FrontendAnimationConfig

## 位置格式配置（type -> format）
var _position_formats: Dictionary = {}

## 实例 ID 计数器
var _next_instance_id: int = 0

## 内部世界时间（毫秒）
var _world_time_ms: int = 0

## 脏标记 Map（actor_id -> bool）用于批量触发信号 (修复 M1)
var _dirty_actors: Dictionary = {}


# ========== 构造函数 ==========

func _init(
	animation_config: FrontendAnimationConfig = null
) -> void:
	_animation_config = animation_config if animation_config != null else FrontendAnimationConfig.create_default()


# ========== 初始化 ==========

## 从回放数据初始化角色状态
func initialize_from_replay(replay_data: Dictionary) -> void:
	_actors.clear()
	_interpolated_positions.clear()
	_floating_texts.clear()
	_procedural_effects.clear()
	_screen_shake.clear()
	
	# 从 configs 读取 positionFormats
	var configs: Dictionary = replay_data.get("configs", {})
	_position_formats = configs.get("positionFormats", {})
	
	# 从 mapConfig 创建 GridLayout
	var map_config_dict: Dictionary = replay_data.get("mapConfig", {})
	if not map_config_dict.is_empty():
		var grid_config := GridMapConfig.from_dict(map_config_dict)
		_layout = GridLayout.new(
			grid_config.grid_type,
			grid_config.size,
			Vector2.ZERO,
			grid_config.orientation,
			Vector2.ONE
		)
	
	var initial_actors: Array = replay_data.get("initialActors", [])
	for actor_data in initial_actors:
		var actor_dict := actor_data as Dictionary
		_initialize_actor(actor_dict)
	
	# 初始化完成后触发状态同步 (修复 M3)
	for actor_id in _actors.keys():
		actor_state_changed.emit(actor_id, _actors[actor_id])


## 初始化单个角色
func _initialize_actor(actor_data: Dictionary) -> void:
	var actor_id: String = actor_data.get("id", "")
	if actor_id.is_empty():
		return
	
	var actor_type: String = actor_data.get("type", "")
	var position_arr: Array = actor_data.get("position", [])
	var hex_pos = _extract_hex_position(position_arr, actor_type)  # HexCoord
	
	var attributes: Dictionary = actor_data.get("attributes", {})
	
	_actors[actor_id] = {
		"id": actor_id,
		"type": actor_type,
		"display_name": actor_data.get("displayName", ""),
		"team": actor_data.get("team", 0),
		"position": hex_pos.to_dict(),  # 存储为 Dictionary 以便序列化
		"visual_hp": attributes.get("hp", 100.0),
		"max_hp": attributes.get("maxHp", attributes.get("max_hp", 100.0)),
		"is_alive": true,
		"flash_progress": 0.0,
		"tint_color": Color.WHITE,
	}
	
	_interpolated_positions[actor_id] = Vector2(hex_pos.q, hex_pos.r)


## 从位置数组提取六边形坐标
## 根据 positionFormats 配置解释 position 数组的含义
func _extract_hex_position(position_arr: Array, actor_type: String) -> HexCoord:
	if position_arr.is_empty():
		return HexCoord.zero()
	
	# 查找该类型的位置格式，默认为 "world"
	var format: String = _position_formats.get(actor_type, "world")
	
	if format == "hex":
		# position 是 [q, r, z]，直接取 q, r
		var q := int(position_arr[0]) if position_arr.size() > 0 else 0
		var r := int(position_arr[1]) if position_arr.size() > 1 else 0
		return HexCoord.new(q, r)
	else:
		# position 是 [x, y, z] 世界坐标，需要转换为 hex
		var world_pos := Vector3(
			position_arr[0] if position_arr.size() > 0 else 0.0,
			position_arr[1] if position_arr.size() > 1 else 0.0,
			position_arr[2] if position_arr.size() > 2 else 0.0
		)
		var axial: Vector2i = _layout.pixel_to_coord(Vector2(world_pos.x, world_pos.z))
		return HexCoord.from_axial(axial)


# ========== 动作应用 ==========

## 应用活跃动作到状态
func apply_actions(active_actions: Array[FrontendActionScheduler.ActiveAction]) -> void:
	for active_action: FrontendActionScheduler.ActiveAction in active_actions:
		# 跳过延迟中的动作
		if active_action.is_delaying:
			continue
		_apply_action(active_action)


## 应用单个动作
func _apply_action(active_action: FrontendActionScheduler.ActiveAction) -> void:
	var action: FrontendVisualAction = active_action.action
	var progress: float = active_action.progress
	
	match action.type:
		FrontendVisualAction.ActionType.MOVE:
			_apply_move_action(action, progress)
		FrontendVisualAction.ActionType.UPDATE_HP:
			_apply_update_hp_action(action, progress)
		FrontendVisualAction.ActionType.FLOATING_TEXT:
			_apply_floating_text_action(action, active_action.id)
		FrontendVisualAction.ActionType.PROCEDURAL_VFX:
			_apply_procedural_vfx_action(action, active_action.id, progress)
		FrontendVisualAction.ActionType.DEATH:
			_apply_death_action(action, progress)


## 应用移动动作
func _apply_move_action(action: FrontendMoveAction, progress: float) -> void:
	var interpolated_pos := action.get_interpolated_hex(progress)
	_interpolated_positions[action.actor_id] = interpolated_pos
	
	# 动画完成时更新 Actor 的实际位置
	if progress >= 1.0:
		var actor: Dictionary = _actors.get(action.actor_id, {})
		if not actor.is_empty():
			actor["position"] = action.to_hex.to_dict()  # HexCoord -> Dictionary
			actor_state_changed.emit(action.actor_id, actor)


## 应用血条更新动作
func _apply_update_hp_action(action: FrontendUpdateHPAction, progress: float) -> void:
	var actor: Dictionary = _actors.get(action.actor_id, {})
	if actor.is_empty():
		print("[Frontend:RenderWorld] ⚠️ UpdateHP 找不到 actor: %s" % action.actor_id)
		return
	
	# 线性插值 HP
	actor["visual_hp"] = action.get_interpolated_hp(progress)
	
	# 动画完成时确保精确值
	if progress >= 1.0:
		actor["visual_hp"] = action.to_hp
		actor["is_alive"] = action.to_hp > 0
		print("[Frontend:RenderWorld] HP更新完成: actor=%s hp=%.0f->%.0f alive=%s" % [
			action.actor_id, action.from_hp, action.to_hp, actor["is_alive"]
		])
	
	_dirty_actors[action.actor_id] = true


## 应用飘字动作
func _apply_floating_text_action(action: FrontendFloatingTextAction, action_id: String) -> void:
	# 检查是否已存在（避免重复添加）
	for text in _floating_texts:
		if text.get("id") == action_id:
			return
	
	print("[Frontend:RenderWorld] 飘字: actor=%s text='%s' pos=%s" % [
		action.actor_id, action.text, action.position
	])
	
	var text_data := {
		"id": action_id,
		"actor_id": action.actor_id,
		"text": action.text,
		"color": action.color,
		"position": action.position,
		"start_time": _world_time_ms,
		"duration": action.duration,
		"style": action.style,
	}
	
	_floating_texts.append(text_data)
	floating_text_created.emit(text_data)


## 应用程序化特效动作
func _apply_procedural_vfx_action(action: FrontendProceduralVFXAction, action_id: String, progress: float) -> void:
	match action.effect:
		FrontendProceduralVFXAction.EffectType.HIT_FLASH:
			if not action.actor_id.is_empty():
				var actor: Dictionary = _actors.get(action.actor_id, {})
				if not actor.is_empty():
					actor["flash_progress"] = action.get_flash_intensity(progress)
					_dirty_actors[action.actor_id] = true
		
		FrontendProceduralVFXAction.EffectType.SHAKE:
			var offset := action.get_shake_offset(progress)
			_screen_shake = {
				"offset_x": offset.x,
				"offset_y": offset.y,
			}
		
		FrontendProceduralVFXAction.EffectType.COLOR_TINT:
			if not action.actor_id.is_empty():
				var actor: Dictionary = _actors.get(action.actor_id, {})
				if not actor.is_empty():
					actor["tint_color"] = action.tint_color if progress < 1.0 else Color.WHITE
					_dirty_actors[action.actor_id] = true
	
	# 添加到程序化特效列表（避免重复）
	for effect in _procedural_effects:
		if effect.get("id") == action_id:
			return
	
	_procedural_effects.append({
		"id": action_id,
		"effect": action.effect,
		"actor_id": action.actor_id,
		"start_time": _world_time_ms,
		"duration": action.duration,
		"intensity": action.intensity,
		"color": action.tint_color,
	})


## 应用死亡动作
func _apply_death_action(action: FrontendDeathAction, progress: float) -> void:
	var actor: Dictionary = _actors.get(action.actor_id, {})
	if actor.is_empty():
		print("[Frontend:RenderWorld] ⚠️ Death 找不到 actor: %s" % action.actor_id)
		return
	
	actor["is_alive"] = false
	actor["visual_hp"] = 0.0
	actor["death_progress"] = progress
	
	if progress >= 1.0:
		print("[Frontend:RenderWorld] 死亡动画完成: actor=%s" % action.actor_id)
		actor_died.emit(action.actor_id)
	
	actor_state_changed.emit(action.actor_id, actor)


# ========== 清理 ==========

## 清理过期效果
func cleanup(now_ms: int) -> void:
	# 清理过期飘字
	_floating_texts = _floating_texts.filter(func(text: Dictionary) -> bool:
		return now_ms - text.get("start_time", 0) < text.get("duration", 0.0)
	)
	
	# 清理过期程序化特效
	_procedural_effects = _procedural_effects.filter(func(effect: Dictionary) -> bool:
		return now_ms - effect.get("start_time", 0) < effect.get("duration", 0.0)
	)
	
	# 清理震屏
	var has_active_shake := _procedural_effects.any(func(e: Dictionary) -> bool:
		return e.get("effect") == FrontendProceduralVFXAction.EffectType.SHAKE
	)
	if not has_active_shake:
		_screen_shake.clear()
	
	# 清理 Actor 的临时效果
	for actor_id: String in _actors.keys():
		var actor: Dictionary = _actors[actor_id]
		
		var has_active_flash := _procedural_effects.any(func(e: Dictionary) -> bool:
			return e.get("effect") == FrontendProceduralVFXAction.EffectType.HIT_FLASH and e.get("actor_id") == actor_id
		)
		if not has_active_flash:
			actor["flash_progress"] = 0.0
		
		var has_active_tint := _procedural_effects.any(func(e: Dictionary) -> bool:
			return e.get("effect") == FrontendProceduralVFXAction.EffectType.COLOR_TINT and e.get("actor_id") == actor_id
		)
		if not has_active_tint:
			actor["tint_color"] = Color.WHITE


# ========== 状态获取 ==========

## 获取当前渲染状态
func get_state() -> Dictionary:
	return {
		"actors": _actors.duplicate(true),
		"interpolated_positions": _interpolated_positions.duplicate(),
		"floating_texts": _floating_texts.duplicate(true),
		"procedural_effects": _procedural_effects.duplicate(true),
		"screen_shake": _screen_shake.duplicate(),
	}


## 创建 VisualizerContext（只读视图）
func as_context() -> FrontendVisualizerContext:
	return FrontendVisualizerContext.new(
		_actors,
		_interpolated_positions,
		_animation_config,
		_layout
	)


## 获取角色世界坐标
func get_actor_world_position(actor_id: String) -> Vector3:
	if _interpolated_positions.has(actor_id):
		var pos: Vector2 = _interpolated_positions[actor_id]
		var pixel := _layout.coord_to_pixel(Vector2i(roundi(pos.x), roundi(pos.y)))
		return Vector3(pixel.x, 0.0, pixel.y)
	
	var actor: Dictionary = _actors.get(actor_id, {})
	if actor.is_empty():
		return Vector3.ZERO
	
	var pos: Dictionary = actor.get("position", {})
	var pixel := _layout.coord_to_pixel(Vector2i(pos.get("q", 0) as int, pos.get("r", 0) as int))
	return Vector3(pixel.x, 0.0, pixel.y)


## 获取震屏偏移
func get_screen_shake_offset() -> Vector2:
	return Vector2(
		_screen_shake.get("offset_x", 0.0) as float,
		_screen_shake.get("offset_y", 0.0) as float
	)


# ========== 重置 ==========

## 重置到初始状态
func reset_to(replay_data: Dictionary) -> void:
	_world_time_ms = 0
	initialize_from_replay(replay_data)


## 推进内部世界时间
func advance_time(delta_ms: int) -> void:
	_world_time_ms += delta_ms


## 获取内部世界时间
func get_world_time() -> int:
	return _world_time_ms


## 批量触发脏标记的 Actor 状态变化信号
func flush_dirty_actors() -> void:
	for actor_id: String in _dirty_actors.keys():
		if _actors.has(actor_id):
			actor_state_changed.emit(actor_id, _actors[actor_id])
	_dirty_actors.clear()


# ========== 直接状态更新 ==========

## 直接更新 Actor HP（无动画）
func set_actor_hp(actor_id: String, hp: float) -> void:
	var actor: Dictionary = _actors.get(actor_id, {})
	if not actor.is_empty():
		actor["visual_hp"] = hp
		actor["is_alive"] = hp > 0
		actor_state_changed.emit(actor_id, actor)


## 直接更新 Actor 位置（无动画）
func set_actor_position(actor_id: String, hex: HexCoord) -> void:
	var actor: Dictionary = _actors.get(actor_id, {})
	if not actor.is_empty():
		actor["position"] = hex.to_dict()
		_interpolated_positions[actor_id] = Vector2(hex.q, hex.r)
		actor_state_changed.emit(actor_id, actor)


## 标记 Actor 死亡
func set_actor_dead(actor_id: String) -> void:
	var actor: Dictionary = _actors.get(actor_id, {})
	if not actor.is_empty():
		actor["is_alive"] = false
		actor["visual_hp"] = 0.0
		actor_state_changed.emit(actor_id, actor)
		actor_died.emit(actor_id)
