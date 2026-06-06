class_name InkMonBattle2DAnimator
extends Node

## 2D 战斗回放 orchestrator（表演框架平移版，adr/0006）。
##
## 持有平移自 hex frontend 的三件套——RenderWorld（状态）/ ActionScheduler（时序）/
## VisualizerRegistry（事件→VisualAction）——按 meta.tick_interval 逐帧 drain 事件、翻译、
## 调度、应用到 render-state，再把 state 投影到 2D 占位节点（InkMonRender2DAvatar 哑投影）。
##
## 坐标边界：RenderWorld 全用逻辑 axial，本类是唯一 hex→像素转换点（_axial_to_pixel → grid）。
## 只吃 ReplayData/Dictionary，不引用 InkMon*Actor / GI。

signal playback_ended()
signal frame_changed(current_frame: int, total_frames: int)

const DEFAULT_TICK_MS := 100.0

# ---- 场景节点（setup 注入）----
var _grid: InkMonRender2DIsoHexGrid = null
var _units_root: Node2D = null
var _fx_root: Node2D = null

# ---- 回放数据 / 播放状态 ----
var _record: ReplayData.BattleRecord = null
var _frame_map: Dictionary = {}            # frame:int -> ReplayData.FrameData
var _total_frames := 0
var _tick_ms := DEFAULT_TICK_MS
var _current_frame := 0
var _accum_ms := 0.0
var _speed := 1.0
var _playing := false
var _ended := false

# ---- 表演框架三件套 ----
var _render_world: InkMonRender2DRenderWorld = null
var _scheduler: InkMonRender2DActionScheduler = null
var _registry: InkMonRender2DVisualizerRegistry = null

# ---- 视图 ----
var _unit_views: Dictionary = {}           # actor_id:String -> InkMonRender2DAvatar


func setup(grid: InkMonRender2DIsoHexGrid, units_root: Node2D, fx_root: Node2D) -> void:
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

	# 框架三件套：每次 load 全新构建（无向后兼容/无 fallback）
	var anim_cfg := InkMonRender2DAnimationConfig.from_dict(record.configs.get("animation", {}))
	_render_world = InkMonRender2DRenderWorld.new(anim_cfg)
	_scheduler = InkMonRender2DActionScheduler.new()
	_registry = InkMonBattle2DDefaultRegistry.create()
	_render_world.actor_state_changed.connect(_on_actor_state_changed)
	_render_world.floating_text_created.connect(_on_floating_text_created)

	# initialize_from_replay 会逐 actor emit actor_state_changed → 懒建 unit view
	_render_world.initialize_from_replay(record)
	_sync_positions()

	_current_frame = 0
	_accum_ms = 0.0
	_playing = false
	_ended = false
	frame_changed.emit(0, _total_frames)


func play() -> void:
	if _record == null:
		return
	if _ended:
		reset()
	_playing = true


func pause() -> void:
	_playing = false


func reset() -> void:
	if _record == null:
		return
	if _scheduler != null:
		_scheduler.cancel_all()
	if _render_world != null:
		_render_world.reset_to(_record)  # 重建 actors → emit state_changed → 视图复位
	_current_frame = 0
	_accum_ms = 0.0
	_ended = false
	_playing = false
	if _fx_root != null:
		for child in _fx_root.get_children():
			child.queue_free()
	_sync_positions()
	frame_changed.emit(0, _total_frames)


func set_speed(speed: float) -> void:
	_speed = maxf(0.01, speed)


func is_playing() -> bool:
	return _playing


func is_ended() -> bool:
	return _ended


## 单位快照（契约形状 {id:{x,y,hp,alive}}）。从 RenderWorld 读，x/y = 当前像素位置。
func get_units_snapshot() -> Dictionary:
	var result := {}
	if _render_world == null:
		return result
	var snapshot := _render_world.get_actors_snapshot()
	for actor_id in snapshot.keys():
		var state := snapshot[actor_id] as InkMonRender2DActorRenderState
		var px := _axial_to_pixel(_render_world.get_actor_axial(actor_id))
		result[actor_id] = {
			"x": px.x,
			"y": px.y,
			"hp": state.visual_hp,
			"alive": state.is_alive,
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
	if _ended or _record == null:
		return

	# 逻辑帧时钟：drain 到点的帧，翻译事件入调度器
	_accum_ms += delta_ms
	while _accum_ms >= _tick_ms:
		_accum_ms -= _tick_ms
		var next_frame := _current_frame + 1
		if next_frame > _total_frames:
			break
		_current_frame = next_frame
		if _frame_map.has(next_frame):
			var fd := _frame_map[next_frame] as ReplayData.FrameData
			for ev in fd.events:
				var e := ev as Dictionary
				_render_world.apply_event_side_effects(e)
				var actions := _registry.translate(e, _render_world.as_context())
				_scheduler.enqueue(actions)
		frame_changed.emit(_current_frame, _total_frames)

	# 动画时钟：每 tick 推进调度器 + 应用动作 + hp lerp（即便逻辑帧已停也要 drain 动画）
	_render_world.advance_time(int(delta_ms))
	var result := _scheduler.tick(delta_ms)
	if result.has_changes:
		# 先 active 再 completed —— duration=0 的瞬时动作(如 ApplyHPDelta)只在 completed 里
		_render_world.apply_actions(result.active_actions)
		_render_world.apply_actions(result.completed_this_tick)
		_render_world.cleanup(_render_world.get_world_time())
	_render_world.tick_hp_lerp(delta_ms)
	_render_world.flush_dirty_actors()
	_sync_positions()

	# 结束 = 帧跑完 且 调度器空（动画 drain 过末帧）
	if _current_frame >= _total_frames and _scheduler.get_action_count() == 0 and not _ended:
		_ended = true
		_playing = false
		playback_ended.emit()


# ========== RenderWorld 信号 → 2D 视图 ==========

## state 投影：懒建 unit view（首次）+ 投影视觉状态。位置由 _sync_positions 每帧拉。
func _on_actor_state_changed(actor_id: String, state: InkMonRender2DActorRenderState) -> void:
	var view := _unit_views.get(actor_id, null) as InkMonRender2DAvatar
	if view == null:
		if _units_root == null:
			return
		view = InkMonRender2DAvatar.new()
		view.name = "Unit_%s" % actor_id
		_units_root.add_child(view)
		view.initialize(actor_id, state.display_name, state.max_hp, InkMonRender2DAvatar.Style.battle_unit(state.team))
		view.set_world_pos(_axial_to_pixel(_render_world.get_actor_axial(actor_id)))
		_unit_views[actor_id] = view
	view.update_from_state(state)


func _on_floating_text_created(data: InkMonRender2DRenderData.FloatingText) -> void:
	if _fx_root == null:
		return
	var node := InkMonRender2DFloatingText2D.new()
	_fx_root.add_child(node)
	node.initialize(data.text, data.color, _axial_to_pixel(data.position), data.duration / 1000.0)


# ========== 坐标 / 同步 ==========

## 唯一 hex→像素转换点：逻辑 axial（含 in-flight 插值）→ grid 像素
func _axial_to_pixel(axial: Vector2) -> Vector2:
	if _grid == null:
		return Vector2.ZERO
	return _grid.coord_to_world_f(axial.x, axial.y)


## 每帧把所有 unit view 的像素位置同步到 RenderWorld 的当前逻辑坐标（含移动插值）
func _sync_positions() -> void:
	if _render_world == null:
		return
	for actor_id in _unit_views.keys():
		var view := _unit_views[actor_id] as InkMonRender2DAvatar
		if view != null:
			view.set_world_pos(_axial_to_pixel(_render_world.get_actor_axial(actor_id)))


func _clear_units() -> void:
	for value in _unit_views.values():
		var node := value as Node
		if node != null:
			node.queue_free()
	_unit_views.clear()
