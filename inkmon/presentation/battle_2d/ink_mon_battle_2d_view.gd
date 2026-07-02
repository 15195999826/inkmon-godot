class_name InkMonBattle2DView
extends CanvasLayer

## 2D 战斗回放视图(占位，adr/0005）。组装 grid + units + fx + animator + Skip/Leave/结果 UI。
## Presentation 在战斗结束时 play_replay(record_dict);播完亮 Leave 按钮(并转发 playback_ended),
## 玩家确认离开才 emit leave_requested → Presentation 收尾回 overworld(观看期主世界冻结由 Host 负责)。

signal playback_ended()
## 玩家在结果界面点 Leave —— 回放观看期结束的唯一出口(game-vision §2 体验流"确认离开")。
signal leave_requested()

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
	var bundle := InkMonMapLoader.load_bundle(BATTLE_MAP_ID)
	if bundle.is_empty() or not _grid.setup_from_bundle(bundle, DISPLAY_EDGE_PX):
		push_error("battle 2d view: battle map failed to load (%s)" % BATTLE_MAP_ID)

	_units_root = Node2D.new()
	_units_root.name = "UnitsRoot"
	_stage.add_child(_units_root)

	_fx_root = Node2D.new()
	_fx_root.name = "FxRoot"
	_stage.add_child(_fx_root)

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


func play_replay(record_dict: Dictionary, result: Dictionary = {}) -> void:
	if not _built:
		_build()
	visible = true
	if _leave_button != null:
		_leave_button.visible = false
	if _result_label != null:
		_result_label.text = "Battle: %s" % str(result.get("result", ""))
	var record := ReplayData.BattleRecord.from_dict(record_dict)
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
	}


func _on_animator_ended() -> void:
	# 播完不自动离场:亮 Leave 按钮等玩家确认(确认前 Host 维持主世界冻结)。
	if _leave_button != null:
		_leave_button.visible = true
	playback_ended.emit()


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
