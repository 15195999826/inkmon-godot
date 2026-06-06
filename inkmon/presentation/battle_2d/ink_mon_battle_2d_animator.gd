class_name InkMonBattle2DAnimator
extends Node

## 2D 战斗回放核心(adr/0005）。读 ReplayData.BattleRecord,按 meta.tick_interval 推帧,逐 event 驱动 2D 占位节点。
## 与渲染解耦的逻辑录像消费者(参照 hex-atb battle_director 的"按帧 drain event"流程,只换成 2D 节点)。
## 只吃 ReplayData/Dictionary,不引用 InkMon*Actor / GI。

signal playback_ended()
signal frame_changed(current_frame: int, total_frames: int)

const DEFAULT_TICK_MS := 100.0

var _grid: InkMonBattle2DGrid = null
var _units_root: Node2D = null
var _fx_root: Node2D = null

var _record: ReplayData.BattleRecord = null
var _frame_map: Dictionary = {}            # frame:int -> ReplayData.FrameData
var _total_frames := 0
var _tick_ms := DEFAULT_TICK_MS
var _current_frame := 0
var _accum_ms := 0.0
var _speed := 1.0
var _playing := false
var _ended := false
var _unit_views: Dictionary = {}           # actor_id:String -> InkMonUnit2DView


func setup(grid: InkMonBattle2DGrid, units_root: Node2D, fx_root: Node2D) -> void:
	_grid = grid
	_units_root = units_root
	_fx_root = fx_root


func load_record(record: ReplayData.BattleRecord) -> void:
	Log.assert_crash(_grid != null and _units_root != null, "InkMonBattle2DAnimator", "setup() must run before load_record()")
	_record = record
	var meta := record.meta if record != null else null
	_tick_ms = float(meta.tick_interval) if meta != null and meta.tick_interval > 0 else DEFAULT_TICK_MS
	_total_frames = meta.total_frames if meta != null else 0
	_frame_map.clear()
	for fd in record.timeline:
		_frame_map[fd.frame] = fd
	_clear_units()
	_spawn_initial_units(record)
	_current_frame = 0
	_accum_ms = 0.0
	_playing = false
	_ended = false
	frame_changed.emit(0, _total_frames)


func play() -> void:
	if _record == null or _ended:
		return
	_playing = true


func pause() -> void:
	_playing = false


func reset() -> void:
	_current_frame = 0
	_accum_ms = 0.0
	_ended = false
	_playing = false
	for value in _unit_views.values():
		var view := value as InkMonUnit2DView
		if view != null:
			view.revive()
	if _record != null:
		_snap_initial_positions(_record)
	if _fx_root != null:
		for child in _fx_root.get_children():
			child.queue_free()
	frame_changed.emit(0, _total_frames)


func set_speed(speed: float) -> void:
	_speed = maxf(0.01, speed)


func is_playing() -> bool:
	return _playing


func is_ended() -> bool:
	return _ended


func get_units_snapshot() -> Dictionary:
	var result := {}
	for actor_id in _unit_views.keys():
		var view := _unit_views[actor_id] as InkMonUnit2DView
		if view == null:
			continue
		result[actor_id] = {
			"x": view.position.x,
			"y": view.position.y,
			"hp": view.get_hp(),
			"alive": view.is_alive(),
		}
	return result


func _process(delta: float) -> void:
	if not _playing:
		return
	_tick(delta * 1000.0 * _speed)


## 确定性步进(测试/截图):按毫秒推进,不依赖真实帧时。
func step(delta_ms: float) -> void:
	_tick(delta_ms)


func _tick(delta_ms: float) -> void:
	if _ended:
		return
	_accum_ms += delta_ms
	while _accum_ms >= _tick_ms:
		_accum_ms -= _tick_ms
		if _current_frame >= _total_frames:
			break
		_current_frame += 1
		if _frame_map.has(_current_frame):
			var fd := _frame_map[_current_frame] as ReplayData.FrameData
			for ev in fd.events:
				_apply_event(ev as Dictionary)
		frame_changed.emit(_current_frame, _total_frames)
	for value in _unit_views.values():
		var view := value as InkMonUnit2DView
		if view != null:
			view.tick_visual(delta_ms)
	if _current_frame >= _total_frames and not _ended:
		_ended = true
		_playing = false
		playback_ended.emit()


func _spawn_initial_units(record: ReplayData.BattleRecord) -> void:
	for init_data in record.initial_actors:
		var view := InkMonUnit2DView.new()
		view.name = "Unit_%s" % init_data.id
		_units_root.add_child(view)
		var attrs := init_data.attributes
		var max_hp := float(attrs.get("max_hp", attrs.get("hp", 1.0)))
		var hp := float(attrs.get("hp", max_hp))
		view.initialize(init_data.id, init_data.display_name, init_data.team, max_hp, hp)
		view.snap_world_pos(_pos_from_array(init_data.position))
		_unit_views[init_data.id] = view


func _snap_initial_positions(record: ReplayData.BattleRecord) -> void:
	for init_data in record.initial_actors:
		var view := _unit_views.get(init_data.id, null) as InkMonUnit2DView
		if view != null:
			view.snap_world_pos(_pos_from_array(init_data.position))
			var attrs := init_data.attributes
			view.set_hp(float(attrs.get("hp", attrs.get("max_hp", 1.0))))


func _apply_event(ev: Dictionary) -> void:
	match str(ev.get("kind", "")):
		"inkmon_move_complete":
			var view := _unit_views.get(str(ev.get("actor_id", "")), null) as InkMonUnit2DView
			if view != null:
				view.set_target_world_pos(_pos_from_hex(ev.get("to_hex", {}) as Dictionary))
		"inkmon_damage":
			var view := _unit_views.get(str(ev.get("target_actor_id", "")), null) as InkMonUnit2DView
			if view != null:
				var dmg := float(ev.get("actual_life_damage", ev.get("damage", 0.0)))
				view.set_hp(view.get_hp() - dmg)
				view.flash_hit()
				_spawn_float("-%d" % int(round(dmg)), Color(1.0, 0.42, 0.36), view.position)
		"inkmon_heal":
			var view := _unit_views.get(str(ev.get("target_actor_id", "")), null) as InkMonUnit2DView
			if view != null:
				var amount := float(ev.get("heal_amount", 0.0))
				view.set_hp(view.get_hp() + amount)
				_spawn_float("+%d" % int(round(amount)), Color(0.46, 0.92, 0.50), view.position)
		"inkmon_death":
			var view := _unit_views.get(str(ev.get("actor_id", "")), null) as InkMonUnit2DView
			if view != null:
				view.play_death()
		_:
			pass


func _spawn_float(text: String, color: Color, world_pos: Vector2) -> void:
	if _fx_root == null:
		return
	var float_node := InkMonFloatingText2D.new()
	_fx_root.add_child(float_node)
	float_node.initialize(text, color, world_pos)


func _pos_from_array(arr: Array) -> Vector2:
	if arr.size() < 2 or _grid == null:
		return Vector2.ZERO
	return _grid.coord_to_world(int(round(float(arr[0]))), int(round(float(arr[1]))))


func _pos_from_hex(hex: Dictionary) -> Vector2:
	if _grid == null:
		return Vector2.ZERO
	return _grid.coord_to_world(int(hex.get("q", 0)), int(hex.get("r", 0)))


func _clear_units() -> void:
	for value in _unit_views.values():
		var node := value as Node
		if node != null:
			node.queue_free()
	_unit_views.clear()
