## BattleDirector - 战斗回放核心调度器
##
## 整合 VisualizerRegistry、ActionScheduler、RenderWorld，
## 提供完整的战斗回放控制能力。
##
## 作为 Node 实现，负责：
## - _process(delta) 驱动 tick
## - 引用场景节点（UnitsRoot、EffectsRoot、CameraRig、UI）
## - 接收输入（play/pause）
class_name FrontendBattleDirector
extends Node


# ========== 信号 ==========

## 播放状态变化
signal playback_state_changed(is_playing: bool)

## 帧变化
signal frame_changed(current_frame: int, total_frames: int)

## 播放结束
signal playback_ended()

## 角色状态变化（转发自 RenderWorld）
signal actor_state_changed(actor_id: String, state: Dictionary)

## 飘字创建（转发自 RenderWorld）
signal floating_text_created(data: Dictionary)

## 角色死亡（转发自 RenderWorld）
signal actor_died(actor_id: String)


# ========== 常量 ==========

## 逻辑帧间隔（毫秒）
const LOGIC_TICK_MS: float = 100.0


# ========== 导出属性 ==========

## 初始播放速度
@export var initial_speed: float = 1.0

## 是否自动播放
@export var auto_play: bool = false


# ========== 核心组件 ==========

## Visualizer 注册表
var _registry: FrontendVisualizerRegistry

## 动作调度器
var _scheduler: FrontendActionScheduler

## 渲染世界
var _world: FrontendRenderWorld


# ========== 状态 ==========

## 回放数据
var _replay_data: Dictionary = {}

## 帧数据 Map（frame -> events）
var _frame_data_map: Dictionary = {}

## 是否正在播放
var _is_playing: bool = false

## 当前播放速度
var _speed: float = 1.0

## 当前逻辑帧
var _current_frame: int = 0

## 总帧数
var _total_frames: int = 0

## 逻辑帧累积时间
var _logic_accumulator: float = 0.0


# ========== 生命周期 ==========

func _ready() -> void:
	_speed = initial_speed
	
	# 初始化核心组件
	_registry = FrontendDefaultRegistry.create()
	_scheduler = FrontendActionScheduler.new()
	_world = FrontendRenderWorld.new()
	
	# 连接 RenderWorld 信号
	_world.actor_state_changed.connect(_on_actor_state_changed)
	_world.floating_text_created.connect(_on_floating_text_created)
	_world.actor_died.connect(_on_actor_died)
	
	if auto_play and not _replay_data.is_empty():
		play()


func _exit_tree() -> void:
	# 断开 RenderWorld 信号连接 (修复 C1: 内存泄漏)
	if _world:
		_world.actor_state_changed.disconnect(_on_actor_state_changed)
		_world.floating_text_created.disconnect(_on_floating_text_created)
		_world.actor_died.disconnect(_on_actor_died)
	
	# 清空 RefCounted 引用，打破循环引用
	_world = null
	_scheduler = null
	_registry = null


func _process(delta: float) -> void:
	if not _is_playing:
		return
	
	_tick(delta * 1000.0 * _speed)


# ========== 公共方法 ==========

## 加载回放数据
func load_replay(replay_data: Dictionary) -> void:
	_replay_data = replay_data
	
	# 构建帧数据 Map
	_frame_data_map.clear()
	var timeline: Array = replay_data.get("timeline", [])
	for frame_data in timeline:
		var frame_dict := frame_data as Dictionary
		var frame_num: int = frame_dict.get("frame", 0)
		_frame_data_map[frame_num] = frame_dict
	
	# 获取总帧数
	var meta: Dictionary = replay_data.get("meta", {})
	_total_frames = meta.get("totalFrames", 0) as int
	
	# 初始化渲染世界
	_world.initialize_from_replay(replay_data)
	
	# 重置状态
	_current_frame = 0
	_logic_accumulator = 0.0
	_scheduler.cancel_all()
	
	frame_changed.emit(_current_frame, _total_frames)


## 开始播放
func play() -> void:
	# 自动重置已结束的回放 (修复 C5)
	if _is_ended():
		reset()
	
	_is_playing = true
	playback_state_changed.emit(true)


## 暂停播放
func pause() -> void:
	_is_playing = false
	playback_state_changed.emit(false)


## 切换播放/暂停
func toggle() -> void:
	if _is_ended():
		return
	
	if _is_playing:
		pause()
	else:
		play()


## 重置到初始状态
func reset() -> void:
	# 停止播放
	_is_playing = false
	playback_state_changed.emit(false)
	
	# 重置调度器
	_scheduler.cancel_all()
	
	# 重置世界状态
	_world.reset_to(_replay_data)
	
	# 重置帧状态
	_current_frame = 0
	_logic_accumulator = 0.0
	
	frame_changed.emit(_current_frame, _total_frames)


## 设置播放速度
func set_speed(speed: float) -> void:
	_speed = speed


## 获取当前播放速度
func get_speed() -> float:
	return _speed


## 获取当前帧
func get_current_frame() -> int:
	return _current_frame


## 获取总帧数
func get_total_frames() -> int:
	return _total_frames


## 是否正在播放
func is_playing() -> bool:
	return _is_playing


## 是否已结束
func is_ended() -> bool:
	return _is_ended()


## 获取渲染状态
func get_render_state() -> Dictionary:
	return _world.get_state()


## 获取角色世界坐标
func get_actor_world_position(actor_id: String) -> Vector3:
	return _world.get_actor_world_position(actor_id)


## 获取震屏偏移
func get_screen_shake_offset() -> Vector2:
	return _world.get_screen_shake_offset()


# ========== 内部方法 ==========

## 每帧更新
func _tick(delta_ms: float) -> void:
	# 累积时间
	_logic_accumulator += delta_ms
	
	# 检查是否需要推进逻辑帧
	while _logic_accumulator >= LOGIC_TICK_MS:
		_logic_accumulator -= LOGIC_TICK_MS
		
		# 推进逻辑帧
		var next_frame := _current_frame + 1
		
		# 检查是否已到达最后一帧
		if next_frame > _total_frames:
			# 不要在这里停止播放，让动画继续播放
			break
		
		_current_frame = next_frame
		
		# 查找该帧的事件
		if _frame_data_map.has(next_frame):
			var frame_data: Dictionary = _frame_data_map[next_frame]
			var events: Array = frame_data.get("events", [])
			
			if events.size() > 0:
				print("[Frontend:Director] 帧 %d: %d 个事件" % [next_frame, events.size()])
			
			# 翻译事件为动作
			var context := _world.as_context()
			for event in events:
				var event_dict: Dictionary = event as Dictionary
				var event_kind: String = event_dict.get("kind", "unknown")
				print("[Frontend:Director]   - 事件: %s" % event_kind)
				var actions := _registry.translate(event_dict, context)
				_scheduler.enqueue(actions)
		
		frame_changed.emit(_current_frame, _total_frames)
	
	# 推进内部世界时间 (修复 C4: 暂停时特效失效)
	_world.advance_time(int(delta_ms))
	
	# 调度器 tick（即使逻辑帧结束，也要继续推进动画）
	var result := _scheduler.tick(delta_ms)
	
	# 应用动作到世界状态
	if result.has_changes:
		# 先应用活跃动作
		_world.apply_actions(result.active_actions)
		# 再应用本帧完成的动作（确保最终状态被应用）
		_world.apply_actions(result.completed_this_tick)
		_world.cleanup(_world.get_world_time())
	
	# 批量触发状态变化信号 (修复 M1)
	_world.flush_dirty_actors()
	
	# 检查是否所有动画都已完成
	if _current_frame >= _total_frames and _scheduler.get_action_count() == 0:
		_is_playing = false
		playback_state_changed.emit(false)
		playback_ended.emit()


## 检查是否已结束
func _is_ended() -> bool:
	return _current_frame >= _total_frames and _scheduler.get_action_count() == 0


# ========== 信号处理 ==========

func _on_actor_state_changed(actor_id: String, state: Dictionary) -> void:
	actor_state_changed.emit(actor_id, state)


func _on_floating_text_created(data: Dictionary) -> void:
	floating_text_created.emit(data)


func _on_actor_died(actor_id: String) -> void:
	actor_died.emit(actor_id)
