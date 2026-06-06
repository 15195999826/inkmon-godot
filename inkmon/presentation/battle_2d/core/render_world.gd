## InkMonBattle2DRenderWorld - 渲染状态管理
##
## 管理战斗回放的 render-state，把 VisualAction 应用到状态上。ActionScheduler 管"时序"，
## RenderWorld 管"状态"。平移自 hex frontend（见 docs/adr/0006）：坐标全用逻辑 axial
## （_interpolated_positions = q,r 浮点），hex→像素转换在 animator→view 边界做、本类不碰像素。
##
## 首版只处理 active 路径（MOVE / APPLY_HP_DELTA / FLOATING_TEXT / PROCEDURAL_VFX / DEATH）；
## dormant 动作类型（attack_vfx / projectile / buff / shield / bump / facing / cone）的 handler
## 待对应机制落地再 JIT 补，ActionType 枚举已预留。
class_name InkMonBattle2DRenderWorld
extends RefCounted


# ========== 信号 ==========

signal actor_state_changed(actor_id: String, state: InkMonBattle2DActorRenderState)
signal actor_spawned(actor_id: String, state: InkMonBattle2DActorRenderState)
signal floating_text_created(data: InkMonBattle2DRenderData.FloatingText)
signal actor_died(actor_id: String)


# ========== 内部状态 ==========

var _actors: Dictionary = {}                  # actor_id -> InkMonBattle2DActorRenderState
var _interpolated_positions: Dictionary = {}  # actor_id -> Vector2 (逻辑 axial)
var _floating_texts: Array[InkMonBattle2DRenderData.FloatingText] = []
var _procedural_effects: Array[InkMonBattle2DRenderData.ProceduralEffect] = []
var _screen_shake: InkMonBattle2DRenderData.ScreenShake = InkMonBattle2DRenderData.ScreenShake.new()
var _animation_config: InkMonBattle2DAnimationConfig
var _world_time_ms: int = 0
var _dirty_actors: Dictionary = {}            # actor_id -> bool（批量触发信号）


# ========== 构造 ==========

func _init(animation_config: InkMonBattle2DAnimationConfig = null) -> void:
	_animation_config = animation_config if animation_config != null else InkMonBattle2DAnimationConfig.create_default()


# ========== 初始化 ==========

## 从回放数据初始化角色状态
func initialize_from_replay(record: ReplayData.BattleRecord) -> void:
	_actors.clear()
	_interpolated_positions.clear()
	_floating_texts.clear()
	_procedural_effects.clear()
	_screen_shake = InkMonBattle2DRenderData.ScreenShake.new()

	for actor_init: ReplayData.ActorInitData in record.initial_actors:
		_initialize_actor_from_init_data(actor_init)

	for actor_id in _actors.keys():
		actor_state_changed.emit(actor_id, _actors[actor_id])


func _initialize_actor_from_init_data(actor_init: ReplayData.ActorInitData) -> void:
	if actor_init.id.is_empty():
		return

	var hex_pos := _extract_hex_position(actor_init.position)

	var actor_state := InkMonBattle2DActorRenderState.new()
	actor_state.id = actor_init.id
	actor_state.type = actor_init.type
	actor_state.config_id = actor_init.config_id
	actor_state.display_name = actor_init.display_name
	actor_state.team = actor_init.team
	actor_state.position = hex_pos
	actor_state.visual_hp = actor_init.attributes.get("hp", 100.0) as float
	actor_state.target_hp = actor_state.visual_hp
	actor_state.max_hp = actor_init.attributes.get("maxHp", actor_init.attributes.get("max_hp", 100.0)) as float
	actor_state.is_alive = true
	actor_state.flash_progress = 0.0
	actor_state.tint_color = Color.WHITE
	actor_state.facing_direction = int(actor_init.attributes.get("facing_direction", 0))

	_actors[actor_init.id] = actor_state
	_interpolated_positions[actor_init.id] = Vector2(hex_pos.q, hex_pos.r)


## 应用 replay 生命周期事件副作用（actorSpawned / actorDestroyed / attributeChanged）。
## inkmon active 路径暂不发这些；保留以支持日后中途 spawn / max_hp 变化。
func apply_event_side_effects(event: Dictionary) -> void:
	var kind := str(event.get("kind", ""))
	match kind:
		GameEvent.ACTOR_SPAWNED_EVENT:
			_apply_actor_spawned_event(event)
		GameEvent.ACTOR_DESTROYED_EVENT:
			_apply_actor_destroyed_event(event)
		GameEvent.ATTRIBUTE_CHANGED_EVENT:
			_apply_attribute_changed_event(event)


func _apply_actor_spawned_event(event: Dictionary) -> void:
	var actor_data_variant: Variant = event.get("actor", {})
	if not (actor_data_variant is Dictionary):
		return
	var actor_data := actor_data_variant as Dictionary
	if actor_data.is_empty():
		return
	var actor_init := ReplayData.ActorInitData.from_dict(actor_data)
	if actor_init.id.is_empty():
		actor_init.id = str(event.get("actorId", ""))
	if actor_init.id.is_empty() or _actors.has(actor_init.id):
		return

	_initialize_actor_from_init_data(actor_init)
	var actor_state: InkMonBattle2DActorRenderState = _actors.get(actor_init.id)
	if actor_state == null:
		return
	actor_spawned.emit(actor_init.id, actor_state)
	actor_state_changed.emit(actor_init.id, actor_state)


func _apply_actor_destroyed_event(event: Dictionary) -> void:
	var actor_id := str(event.get("actorId", ""))
	if actor_id.is_empty():
		return
	var actor: InkMonBattle2DActorRenderState = _actors.get(actor_id)
	if actor == null:
		return
	_set_actor_alive(actor, false)
	actor.visual_hp = 0.0
	actor.target_hp = 0.0
	actor_state_changed.emit(actor_id, actor)


func _apply_attribute_changed_event(event: Dictionary) -> void:
	var attribute := str(event.get("attribute", ""))
	if attribute != "max_hp" and attribute != "maxHp":
		return
	var actor_id := str(event.get("actorId", ""))
	if actor_id.is_empty():
		return
	var actor: InkMonBattle2DActorRenderState = _actors.get(actor_id)
	if actor == null:
		return
	var new_max_hp := float(event.get("newValue", actor.max_hp))
	actor.max_hp = maxf(0.0, new_max_hp)
	actor.visual_hp = clampf(actor.visual_hp, 0.0, actor.max_hp)
	actor.target_hp = clampf(actor.target_hp, 0.0, actor.max_hp)
	_dirty_actors[actor_id] = true


## 从 position 数组提取逻辑 hex（inkmon 战斗 hex-native：position = [q, r, z?]）
func _extract_hex_position(position_arr: Array) -> HexCoord:
	if position_arr.is_empty():
		return HexCoord.zero()
	var q := int(position_arr[0]) if position_arr.size() > 0 else 0
	var r := int(position_arr[1]) if position_arr.size() > 1 else 0
	return HexCoord.new(q, r)


# ========== 动作应用 ==========

func apply_actions(active_actions: Array[InkMonBattle2DActionScheduler.ActiveAction]) -> void:
	for active_action: InkMonBattle2DActionScheduler.ActiveAction in active_actions:
		if active_action.is_delaying:
			continue
		_apply_action(active_action)


func _apply_action(active_action: InkMonBattle2DActionScheduler.ActiveAction) -> void:
	var action: InkMonBattle2DVisualAction = active_action.action
	var progress: float = active_action.progress

	match action.type:
		InkMonBattle2DVisualAction.ActionType.MOVE:
			_apply_move_action(action, progress)
		InkMonBattle2DVisualAction.ActionType.APPLY_HP_DELTA:
			_apply_apply_hp_delta_action(action)
		InkMonBattle2DVisualAction.ActionType.FLOATING_TEXT:
			_apply_floating_text_action(action, active_action.id)
		InkMonBattle2DVisualAction.ActionType.PROCEDURAL_VFX:
			_apply_procedural_vfx_action(action, active_action.id, progress)
		InkMonBattle2DVisualAction.ActionType.DEATH:
			_apply_death_action(action, progress)
		_:
			pass  # dormant 动作类型 handler 待 JIT 补


## 应用移动动作（逻辑 axial 插值）
func _apply_move_action(action: InkMonBattle2DMoveAction, progress: float) -> void:
	_interpolated_positions[action.actor_id] = action.get_interpolated_hex(progress)
	if progress >= 1.0:
		var actor: InkMonBattle2DActorRenderState = _actors.get(action.actor_id)
		if actor != null:
			actor.position = action.to_hex
			actor_state_changed.emit(action.actor_id, actor)


## 应用 hp delta（瞬时）：把 delta 累到 target_hp，visual_hp 由 tick_hp_lerp 追赶。
## 死亡 sticky：只允许 alive→dead transition。
func _apply_apply_hp_delta_action(action: InkMonBattle2DApplyHPDeltaAction) -> void:
	var actor: InkMonBattle2DActorRenderState = _actors.get(action.actor_id)
	if actor == null:
		return
	actor.target_hp = clampf(actor.target_hp + action.delta, 0.0, actor.max_hp)
	if actor.is_alive and actor.target_hp <= 0.0:
		_set_actor_alive(actor, false)
	_dirty_actors[action.actor_id] = true


## 每 tick 把 visual_hp 朝 target_hp 指数收敛
func tick_hp_lerp(delta_ms: float) -> void:
	var dt: float = delta_ms / 1000.0
	var rate: float = _animation_config.hp_lerp_rate
	var t: float = 1.0 - exp(-rate * dt) if rate > 0.0 else 1.0
	for actor_id: String in _actors.keys():
		var actor: InkMonBattle2DActorRenderState = _actors[actor_id]
		if is_equal_approx(actor.visual_hp, actor.target_hp):
			continue
		var diff := actor.target_hp - actor.visual_hp
		if absf(diff) < 0.5:
			actor.visual_hp = actor.target_hp
		else:
			actor.visual_hp += diff * t
		_dirty_actors[actor_id] = true


## 应用飘字动作
func _apply_floating_text_action(action: InkMonBattle2DFloatingTextAction, action_id: String) -> void:
	for text in _floating_texts:
		if text.id == action_id:
			return

	var text_data := InkMonBattle2DRenderData.FloatingText.new()
	text_data.id = action_id
	text_data.actor_id = action.actor_id
	text_data.text = action.text
	text_data.color = action.color
	text_data.position = action.position
	text_data.start_time = _world_time_ms
	text_data.duration = action.duration
	text_data.style = action.style

	_floating_texts.append(text_data)
	floating_text_created.emit(text_data)


## 应用程序化特效动作（active 用 HIT_FLASH；SHAKE / COLOR_TINT 保留）
func _apply_procedural_vfx_action(action: InkMonBattle2DProceduralVFXAction, action_id: String, progress: float) -> void:
	match action.effect:
		InkMonBattle2DProceduralVFXAction.EffectType.HIT_FLASH:
			if not action.actor_id.is_empty():
				var actor: InkMonBattle2DActorRenderState = _actors.get(action.actor_id)
				if actor != null:
					actor.flash_progress = action.get_flash_intensity(progress)
					_dirty_actors[action.actor_id] = true

		InkMonBattle2DProceduralVFXAction.EffectType.SHAKE:
			var offset := action.get_shake_offset(progress)
			_screen_shake = InkMonBattle2DRenderData.ScreenShake.new()
			_screen_shake.offset_x = offset.x
			_screen_shake.offset_y = offset.y

		InkMonBattle2DProceduralVFXAction.EffectType.COLOR_TINT:
			if not action.actor_id.is_empty():
				var actor: InkMonBattle2DActorRenderState = _actors.get(action.actor_id)
				if actor != null:
					actor.tint_color = action.tint_color if progress < 1.0 else Color.WHITE
					_dirty_actors[action.actor_id] = true

	for effect in _procedural_effects:
		if effect.id == action_id:
			return

	var effect_data := InkMonBattle2DRenderData.ProceduralEffect.new()
	effect_data.id = action_id
	effect_data.effect = action.effect
	effect_data.actor_id = action.actor_id
	effect_data.start_time = _world_time_ms
	effect_data.duration = action.duration
	effect_data.intensity = action.intensity
	effect_data.color = action.tint_color
	_procedural_effects.append(effect_data)


## 应用死亡动作
func _apply_death_action(action: InkMonBattle2DDeathAction, progress: float) -> void:
	var actor: InkMonBattle2DActorRenderState = _actors.get(action.actor_id)
	if actor == null:
		return
	_set_actor_alive(actor, false)
	actor.visual_hp = 0.0
	actor.target_hp = 0.0
	actor.death_progress = progress
	actor_state_changed.emit(action.actor_id, actor)


# ========== 清理 ==========

## 清理过期效果
func cleanup(now_ms: int) -> void:
	_floating_texts = _floating_texts.filter(func(text: InkMonBattle2DRenderData.FloatingText) -> bool:
		return now_ms - text.start_time < text.duration
	)

	_procedural_effects = _procedural_effects.filter(func(effect: InkMonBattle2DRenderData.ProceduralEffect) -> bool:
		return now_ms - effect.start_time < effect.duration
	)

	var has_active_shake := _procedural_effects.any(func(e: InkMonBattle2DRenderData.ProceduralEffect) -> bool:
		return e.effect == InkMonBattle2DProceduralVFXAction.EffectType.SHAKE
	)
	if not has_active_shake:
		_screen_shake = InkMonBattle2DRenderData.ScreenShake.new()

	for actor_id: String in _actors.keys():
		var actor: InkMonBattle2DActorRenderState = _actors[actor_id]

		var has_active_flash := _procedural_effects.any(func(e: InkMonBattle2DRenderData.ProceduralEffect) -> bool:
			return e.effect == InkMonBattle2DProceduralVFXAction.EffectType.HIT_FLASH and e.actor_id == actor_id
		)
		if not has_active_flash:
			actor.flash_progress = 0.0

		var has_active_tint := _procedural_effects.any(func(e: InkMonBattle2DRenderData.ProceduralEffect) -> bool:
			return e.effect == InkMonBattle2DProceduralVFXAction.EffectType.COLOR_TINT and e.actor_id == actor_id
		)
		if not has_active_tint:
			actor.tint_color = Color.WHITE


# ========== 状态获取 ==========

## 获取 Actor 状态深拷贝 Map
func get_actors_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	for actor_id: String in _actors.keys():
		var actor: InkMonBattle2DActorRenderState = _actors[actor_id]
		snapshot[actor_id] = actor.duplicate()
	return snapshot


## 创建 VisualizerContext（只读视图）
func as_context() -> InkMonBattle2DVisualizerContext:
	return InkMonBattle2DVisualizerContext.new(
		_actors,
		_interpolated_positions,
		_animation_config
	)


## 获取角色当前逻辑 axial（含 in-flight 插值）；animator 转像素后定位 view
func get_actor_axial(actor_id: String) -> Vector2:
	if _interpolated_positions.has(actor_id):
		return _interpolated_positions[actor_id]
	var actor: InkMonBattle2DActorRenderState = _actors.get(actor_id)
	if actor == null:
		return Vector2.ZERO
	return Vector2(actor.position.q, actor.position.r)


func get_screen_shake_offset() -> Vector2:
	return _screen_shake.to_vector2()


# ========== 重置 / 时间 ==========

func reset_to(record: ReplayData.BattleRecord) -> void:
	_world_time_ms = 0
	initialize_from_replay(record)


func advance_time(delta_ms: int) -> void:
	_world_time_ms += delta_ms


func get_world_time() -> int:
	return _world_time_ms


## 批量触发脏标记 Actor 的 state_changed 信号
func flush_dirty_actors() -> void:
	for actor_id: String in _dirty_actors.keys():
		if _actors.has(actor_id):
			actor_state_changed.emit(actor_id, _actors[actor_id])
	_dirty_actors.clear()


# ========== 直接状态更新 ==========

func set_actor_hp(actor_id: String, hp: float) -> void:
	var actor: InkMonBattle2DActorRenderState = _actors.get(actor_id)
	if actor != null:
		actor.visual_hp = hp
		actor.target_hp = hp
		_set_actor_alive(actor, hp > 0)
		actor_state_changed.emit(actor_id, actor)


func set_actor_position(actor_id: String, hex: HexCoord) -> void:
	var actor: InkMonBattle2DActorRenderState = _actors.get(actor_id)
	if actor != null:
		actor.position = hex
		_interpolated_positions[actor_id] = Vector2(hex.q, hex.r)
		actor_state_changed.emit(actor_id, actor)


func set_actor_dead(actor_id: String) -> void:
	var actor: InkMonBattle2DActorRenderState = _actors.get(actor_id)
	if actor != null:
		_set_actor_alive(actor, false)
		actor.visual_hp = 0.0
		actor.target_hp = 0.0
		actor_state_changed.emit(actor_id, actor)


## 收口 is_alive 写入，在 true→false 那一刻 emit 一次 actor_died（transition-only）
func _set_actor_alive(actor: InkMonBattle2DActorRenderState, alive: bool) -> void:
	var was_alive := actor.is_alive
	actor.is_alive = alive
	if was_alive and not alive:
		actor_died.emit(actor.id)
