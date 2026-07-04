class_name InkMonBattle2DView
extends CanvasLayer

## 2D 战斗回放视图(占位，adr/0005）。组装 grid + units + fx + animator + Skip/Leave/结果 UI。
## Presentation 在战斗结束时 play_replay(record_dict);播完亮 Leave 按钮(并转发 playback_ended),
## 玩家确认离开才 emit leave_requested → Presentation 收尾回 overworld(观看期主世界冻结由 Host 负责)。

signal playback_ended()
## 玩家在结果界面点 Leave —— 回放观看期结束的唯一出口(game-vision §2 体验流"确认离开")。
signal leave_requested()
## 掷球捕捉 (M2.3): 播完后战场点气绝野生个体 → 报 slot; 结果由 root 经 apply_capture_result 推回。
signal capture_requested(slot_index: int)

## 战斗地图 = content/maps/battle_main.map.json + 发布 tile set（T2 契约）。
const BATTLE_MAP_ID := "battle_main"
## 视图显示密度（px/边），与旧 48px pointy 网格的画面尺度对齐。
const DISPLAY_EDGE_PX := 56.0

var _stage: Node2D
var _grid: InkMonRender2DBakedHexMap
var _units_root: Node2D
var _fx_root: Node2D
var _animator: InkMonBattle2DAnimator
var _backdrop: ColorRect
var _result_label: Label
var _skip_button: Button
var _leave_button: Button
var _built := false
## 当前棋盘对应的 map_id (默认 battle_main; M2.2 野群生成图逐场换)。换图才重建, 同图复用烘焙。
var _loaded_map_id := ""
## 战后捕捉池 (M2.3): play_replay 随场推入, 播完 (_ended) 才可点。条目形状同 GI 捕捉池快照。
var _capture_pool: Array[Dictionary] = []
## 捕捉落标层 (待掷 marker + Caught/Broke free 常驻标记), 挂 stage 内单位层之上。
var _capture_marks_root: Node2D = null
## 待掷 marker: slot_index -> Label (掷球后移除换落标)。
var _capture_target_marks: Dictionary = {}
## 单位点击命中半径 (px, avatar 尺度)。
const CAPTURE_HIT_RADIUS := 40.0
## 气绝待捕个体的展示透明度: 死亡淡出会把 avatar 隐形, 捕捉目标必须拉回可见 (躺尸半透明)。
const CAPTURE_TARGET_ALPHA := 0.6


func _ready() -> void:
	layer = 1
	_build()


func _process(_delta: float) -> void:
	_layout()


func _build() -> void:
	if _built:
		return
	_built = true

	_backdrop = ColorRect.new()
	_backdrop.name = "Backdrop"
	_backdrop.color = Color(0.05, 0.06, 0.09, 1.0)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)

	_stage = Node2D.new()
	_stage.name = "Stage"
	add_child(_stage)

	_grid = InkMonRender2DBakedHexMap.new()
	_grid.name = "BattleMap"
	_stage.add_child(_grid)
	_apply_map_doc({})

	_units_root = Node2D.new()
	_units_root.name = "UnitsRoot"
	_stage.add_child(_units_root)

	_fx_root = Node2D.new()
	_fx_root.name = "FxRoot"
	_stage.add_child(_fx_root)

	_capture_marks_root = Node2D.new()
	_capture_marks_root.name = "CaptureMarksRoot"
	_stage.add_child(_capture_marks_root)

	_animator = InkMonBattle2DAnimator.new()
	_animator.name = "Animator"
	add_child(_animator)
	_animator.setup(_grid, _units_root, _fx_root)
	_animator.playback_ended.connect(_on_animator_ended)

	_result_label = Label.new()
	_result_label.name = "ResultLabel"
	_result_label.position = Vector2(24.0, 18.0)
	_result_label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95))
	add_child(_result_label)

	_skip_button = Button.new()
	_skip_button.name = "SkipButton"
	_skip_button.text = "Skip ▶"
	_skip_button.pressed.connect(_on_skip_pressed)
	add_child(_skip_button)

	_leave_button = Button.new()
	_leave_button.name = "LeaveButton"
	_leave_button.text = "Leave ◀"
	_leave_button.visible = false
	_leave_button.pressed.connect(_on_leave_pressed)
	add_child(_leave_button)

	_layout()


func _layout() -> void:
	if _stage == null:
		return
	var view_size := get_viewport().get_visible_rect().size
	_stage.position = view_size * 0.5
	if _skip_button != null:
		_skip_button.position = Vector2(view_size.x - 120.0, 18.0)
	if _leave_button != null:
		_leave_button.position = Vector2(view_size.x * 0.5 - 60.0, view_size.y - 64.0)


## 换装本场棋盘: map_doc 非空 = 生成图 (M2.2 野群模板, 逻辑侧同一 doc); 空 = 默认 battle_main。
## 按 map_id 判同, 同图不重烘。
func _apply_map_doc(map_doc: Dictionary) -> void:
	var target_id := str(map_doc.get("map_id", "")) if not map_doc.is_empty() else BATTLE_MAP_ID
	if target_id == _loaded_map_id:
		return
	var bundle := InkMonMapLoader.build_bundle_from_doc(map_doc) if not map_doc.is_empty() \
		else InkMonMapLoader.load_bundle(BATTLE_MAP_ID)
	if bundle.is_empty() or not _grid.setup_from_bundle(bundle, DISPLAY_EDGE_PX):
		push_error("battle 2d view: battle map failed to load (%s)" % target_id)
		return
	_loaded_map_id = target_id


func play_replay(record_dict: Dictionary, result: Dictionary = {},
		map_doc: Dictionary = {}, capture_pool: Array[Dictionary] = []) -> void:
	if not _built:
		_build()
	_apply_map_doc(map_doc)
	visible = true
	if _leave_button != null:
		_leave_button.visible = false
	if _result_label != null:
		_result_label.text = "Battle: %s" % str(result.get("result", ""))
	_capture_pool = capture_pool.duplicate(true)
	_clear_capture_marks()
	var record := PlaybackData.BattleRecord.from_dict(record_dict)
	_animator.load_record(record)
	_animator.play()


func get_animator() -> InkMonBattle2DAnimator:
	return _animator


func get_debug_state() -> Dictionary:
	return {
		"visible": visible,
		"playing": _animator.is_playing() if _animator != null else false,
		"ended": _animator.is_ended() if _animator != null else false,
		"unit_count": _animator.get_units_snapshot().size() if _animator != null else 0,
		"leave_visible": is_leave_available(),
		"capture_window_open": _capture_window_open(),
		"capture_pool_size": _capture_pool.size(),
	}


func _on_animator_ended() -> void:
	# 播完不自动离场:亮 Leave 按钮等玩家确认(确认前 Host 维持主世界冻结)。
	if _leave_button != null:
		_leave_button.visible = true
	# M2.3 捕捉窗口开启: 死亡淡出把气绝个体隐形了 —— 点选目标拉回半透明可见 + 画待掷 marker。
	if not _capture_pool.is_empty():
		if _result_label != null:
			_result_label.text += "\nClick a fainted wild to throw a ball (one try each)"
		for entry in _capture_pool:
			if bool(entry.get("attempted", false)):
				continue
			var actor_id := str(entry.get("actor_id", ""))
			_animator.override_unit_alpha(actor_id, CAPTURE_TARGET_ALPHA)
			var unit := _animator.get_units_snapshot().get(actor_id, {}) as Dictionary
			if not unit.is_empty():
				var slot_index := int(entry.get("slot_index", -1))
				var mark := Label.new()
				mark.text = "◎ throw"
				mark.add_theme_color_override("font_color", Color(0.98, 0.88, 0.5))
				mark.add_theme_font_size_override("font_size", 13)
				mark.position = Vector2(float(unit.get("x", 0.0)), float(unit.get("y", 0.0))) + Vector2(-24.0, 26.0)
				_capture_marks_root.add_child(mark)
				_capture_target_marks[slot_index] = mark
	playback_ended.emit()


# === 战后捕捉交互 (M2.3): 播完后点气绝野生个体 → capture_requested; 结果经 apply_capture_result 推回 ===

## 捕捉点击窗口 = 播完后到离场前, 且池里还有未尝试条目。
func _capture_window_open() -> bool:
	if _animator == null or not _animator.is_ended():
		return false
	for entry in _capture_pool:
		if not bool(entry.get("attempted", false)):
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not _capture_window_open():
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	var slot_index := _capture_slot_at_screen(mouse_event.position)
	if slot_index < 0:
		return
	capture_requested.emit(slot_index)
	get_viewport().set_input_as_handled()


## 屏幕点 → 未尝试捕捉条目的 slot (按单位命中半径); 未命中返回 -1。
func _capture_slot_at_screen(screen_pos: Vector2) -> int:
	var units := _animator.get_units_snapshot()
	for entry in _capture_pool:
		if bool(entry.get("attempted", false)):
			continue
		var unit := units.get(str(entry.get("actor_id", "")), {}) as Dictionary
		if unit.is_empty():
			continue
		var unit_screen := _stage.position + Vector2(float(unit.get("x", 0.0)), float(unit.get("y", 0.0)))
		if unit_screen.distance_to(screen_pos) <= CAPTURE_HIT_RADIUS:
			return int(entry.get("slot_index", -1))
	return -1


## Host 推回掷球结果: 更新池条目 (去重锁) + 撤待掷 marker + 单位处浮字 + 常驻落标。
## 捕获成功 = 个体被收走 (淡出); 逃走 = 留在原地躺尸 (保持半透明)。
func apply_capture_result(result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		return
	var slot_index := int(result.get("slot_index", -1))
	var captured := bool(result.get("captured", false))
	for entry in _capture_pool:
		if int(entry.get("slot_index", -1)) != slot_index:
			continue
		entry["attempted"] = true
		entry["captured"] = captured
		var target_mark := _capture_target_marks.get(slot_index, null) as Label
		if target_mark != null:
			target_mark.queue_free()
			_capture_target_marks.erase(slot_index)
		var actor_id := str(entry.get("actor_id", ""))
		if captured and _animator != null:
			_animator.override_unit_alpha(actor_id, 0.12)
		var units := _animator.get_units_snapshot() if _animator != null else {}
		var unit := units.get(actor_id, {}) as Dictionary
		if not unit.is_empty():
			var unit_pos := Vector2(float(unit.get("x", 0.0)), float(unit.get("y", 0.0)))
			var float_text := InkMonRender2DFloatingText2D.new()
			_fx_root.add_child(float_text)
			float_text.initialize("Caught!" if captured else "Broke free!",
				Color(0.45, 0.9, 0.5) if captured else Color(0.95, 0.55, 0.45), unit_pos, 1.2)
			_add_capture_mark(unit_pos, captured)
		return


## 常驻落标 (单位脚下一行小字): 离场前一直可见, 标记该个体已掷过。
func _add_capture_mark(unit_pos: Vector2, captured: bool) -> void:
	var mark := Label.new()
	mark.text = "● caught" if captured else "✗ fled"
	mark.add_theme_color_override("font_color",
		Color(0.45, 0.9, 0.5) if captured else Color(0.7, 0.6, 0.55))
	mark.add_theme_font_size_override("font_size", 13)
	mark.position = unit_pos + Vector2(-26.0, 26.0)
	_capture_marks_root.add_child(mark)


func _clear_capture_marks() -> void:
	_capture_target_marks.clear()
	if _capture_marks_root == null:
		return
	for child in _capture_marks_root.get_children():
		child.queue_free()


## smoke 入口: 某捕捉条目对应单位的屏幕坐标 (真鼠标点击用); 无效 slot 返回 Vector2.INF。
func capture_unit_screen_position(slot_index: int) -> Vector2:
	var units := _animator.get_units_snapshot() if _animator != null else {}
	for entry in _capture_pool:
		if int(entry.get("slot_index", -1)) != slot_index:
			continue
		var unit := units.get(str(entry.get("actor_id", "")), {}) as Dictionary
		if unit.is_empty():
			return Vector2.INF
		return _stage.position + Vector2(float(unit.get("x", 0.0)), float(unit.get("y", 0.0)))
	return Vector2.INF


func _on_skip_pressed() -> void:
	if _animator != null and not _animator.is_ended():
		_animator.step(1_000_000.0)


func is_leave_available() -> bool:
	return _leave_button != null and _leave_button.visible


## smoke / dev-agent 入口:等价点击 Leave(仅播完后有效)。
func request_leave() -> void:
	if is_leave_available():
		_on_leave_pressed()


func _on_leave_pressed() -> void:
	_leave_button.visible = false
	leave_requested.emit()
