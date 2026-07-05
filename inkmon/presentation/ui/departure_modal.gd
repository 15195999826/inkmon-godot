class_name InkMonDepartureModal
extends Control
## 出发确认 modal 子场景控制器 (M2.4 拍板 B: gold 直接换粮; docs §6 下放: 行为住子场景, root 只接线)。
## 自管: 粮数 +/- 步进 (0..MAX_SUPPLIES) / 总价与余额显示 / gold 不足 Confirm 置灰 /
## overlay 点击与 Cancel 关闭 / 开关 tween / 居中布局。
## Confirm 只上抛 confirmed(supplies) —— 扣款/写档/start 是 Host 顺序契约, 不在表演层。


signal confirmed(supplies: int)
signal closed


const MODAL_SIZE := Vector2(380.0, 250.0)


var _overlay: ColorRect
var _panel: PanelContainer
var _supply_count_label: Label
var _cost_label: Label
var _minus_button: Button
var _plus_button: Button
var _confirm_button: Button
var _cancel_button: Button
var _transition_tween: Tween
var _transition_active := false
var _open_requested := false

var _supplies := InkMonMissionSetup.DEFAULT_SUPPLIES
var _gold_available := 0


func _ready() -> void:
	_overlay = get_node("ModalOverlay") as ColorRect
	_panel = get_node("DepartureModal") as PanelContainer
	_supply_count_label = get_node("DepartureModal/DepartureBox/SupplyRow/SupplyCount") as Label
	_cost_label = get_node("DepartureModal/DepartureBox/CostLabel") as Label
	_minus_button = get_node("DepartureModal/DepartureBox/SupplyRow/SupplyMinus") as Button
	_plus_button = get_node("DepartureModal/DepartureBox/SupplyRow/SupplyPlus") as Button
	_confirm_button = get_node("DepartureModal/DepartureBox/ConfirmButton") as Button
	_cancel_button = get_node("DepartureModal/DepartureBox/CancelButton") as Button
	_overlay.gui_input.connect(_on_overlay_gui_input)
	_minus_button.pressed.connect(func() -> void: _set_supplies(_supplies - 1))
	_plus_button.pressed.connect(func() -> void: _set_supplies(_supplies + 1))
	_cancel_button.pressed.connect(close)
	_confirm_button.pressed.connect(func() -> void:
		var chosen := _supplies
		close()
		confirmed.emit(chosen))
	get_viewport().size_changed.connect(_center_panel)
	_center_panel()


## 打开 (root 在收到 start_mission intent 时调): 带当前 gold 余额快照, 粮数回默认。
func open(gold_available: int) -> void:
	_gold_available = gold_available
	_supplies = InkMonMissionSetup.DEFAULT_SUPPLIES
	_refresh_labels()
	_open_requested = true
	_kill_tween()
	_center_panel()
	_panel.visible = true
	_overlay.visible = true
	_panel.scale = Vector2(0.92, 0.92)
	_transition_active = true
	_transition_tween = create_tween()
	_transition_tween.tween_property(_panel, "scale", Vector2.ONE, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_transition_tween.finished.connect(func() -> void:
		_transition_active = false
	)


func close() -> void:
	_open_requested = false
	if _panel == null or not _panel.visible:
		# 防御自愈: "panel 已隐但 overlay 残留"的死状态会永久吞全屏点击且本函数原样 return
		# 永远关不掉 —— 顺手补隐 overlay (正常流两者同隐, 此行幂等无害)。
		if _overlay != null:
			_overlay.visible = false
		return
	_kill_tween()
	_transition_active = true
	_transition_tween = create_tween()
	_transition_tween.tween_property(_panel, "scale", Vector2(0.94, 0.94), 0.12) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_transition_tween.finished.connect(func() -> void:
		_transition_active = false
		if _open_requested:
			return
		_panel.visible = false
		_panel.scale = Vector2.ONE
		_overlay.visible = false
	)
	closed.emit()


func is_open() -> bool:
	return _panel != null and _panel.visible


func is_transition_active() -> bool:
	return _transition_active


func get_supplies() -> int:
	return _supplies


## dev-agent / smoke 布局读口 (root 只读 rect, 不接行为)。
func get_debug_controls() -> Dictionary:
	return {
		"panel": _panel,
		"minus_button": _minus_button,
		"plus_button": _plus_button,
		"confirm_button": _confirm_button,
		"cancel_button": _cancel_button,
	}


func _set_supplies(value: int) -> void:
	_supplies = clampi(value, 0, InkMonMissionSetup.MAX_SUPPLIES)
	_refresh_labels()


func _refresh_labels() -> void:
	var cost := _supplies * InkMonMissionSetup.SUPPLY_UNIT_COST
	if _supply_count_label != null:
		_supply_count_label.text = InkMonText.tf("UI_SUPPLIES_COUNT", {"n": _supplies})
	if _cost_label != null:
		_cost_label.text = InkMonText.tf("UI_DEPART_COST", {"cost": cost, "gold": _gold_available})
	if _confirm_button != null:
		_confirm_button.disabled = cost > _gold_available


func _on_overlay_gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event != null and mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
		close()


func _kill_tween() -> void:
	if _transition_tween != null and _transition_tween.is_valid():
		_transition_tween.kill()


func _center_panel() -> void:
	if _panel == null:
		return
	_panel.reset_size()
	var viewport_size := get_viewport().get_visible_rect().size
	_panel.position = (viewport_size - MODAL_SIZE) * 0.5
	_panel.pivot_offset = MODAL_SIZE * 0.5
