class_name InkMonBattle2DView
extends CanvasLayer

## 2D 战斗回放视图(占位，adr/0005）。组装 grid + units + fx + animator + Skip/结果 UI;转发 playback_ended。
## Presentation 在战斗结束时 play_replay(record_dict);播完 emit playback_ended,Presentation 收尾回 overworld。

signal playback_ended()

const BATTLE_GRID_RADIUS := 5

var _stage: Node2D
var _grid: InkMonRender2DIsoHexGrid
var _units_root: Node2D
var _fx_root: Node2D
var _animator: InkMonBattle2DAnimator
var _backdrop: ColorRect
var _result_label: Label
var _skip_button: Button
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

	_grid = InkMonRender2DIsoHexGrid.new()
	_grid.name = "BattleGrid"
	_stage.add_child(_grid)
	_grid.setup(BATTLE_GRID_RADIUS, 48.0)
	_grid.paint_tiles(_grid.get_all_coords(), Color(0.16, 0.18, 0.24, 1.0))
	_grid.render()

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

	_layout()


func _layout() -> void:
	if _stage == null:
		return
	var view_size := get_viewport().get_visible_rect().size
	_stage.position = view_size * 0.5
	if _skip_button != null:
		_skip_button.position = Vector2(view_size.x - 120.0, 18.0)


func play_replay(record_dict: Dictionary, result: Dictionary = {}) -> void:
	if not _built:
		_build()
	visible = true
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
	}


func _on_animator_ended() -> void:
	playback_ended.emit()


func _on_skip_pressed() -> void:
	if _animator != null and not _animator.is_ended():
		_animator.step(1_000_000.0)
