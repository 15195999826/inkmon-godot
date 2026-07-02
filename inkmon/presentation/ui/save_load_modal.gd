class_name InkMonSaveLoadModal
extends Control
## save/load modal 子场景控制器 (docs §6 下放: UI 行为住子场景脚本, root 只接线)。
## 自管: overlay 点击关闭 / slot 按钮 / close 按钮 / 开关 tween / 居中布局 (viewport resize 驱动, 非每帧)。
## 存读档 = Host 控制面 lifecycle, 非表演 —— 点槽位只上抛信号, 由 root 转发 Host 执行。


signal save_slot_requested(slot: int)
signal load_slot_requested(slot: int)
## 关闭动画启动时 emit (overlay 点击 / close 按钮 / load 后自闭 / root 委派关闭, 四路同源)。
signal closed


const SLOT_COUNT := 3
const MODAL_SIZE := Vector2(380.0, 270.0)


var _overlay: ColorRect
var _panel: PanelContainer
var _close_button: Button
var _save_buttons: Dictionary = {}
var _load_buttons: Dictionary = {}
var _transition_tween: Tween
var _transition_active := false
## 关动画期间又请求打开 → 完成回调不隐藏 (防开关竞态闪没)。
var _open_requested := false


func _ready() -> void:
	_overlay = get_node("ModalOverlay") as ColorRect
	_panel = get_node("SaveLoadModal") as PanelContainer
	_close_button = get_node("SaveLoadModal/SaveLoadBox/ModalCloseButton") as Button
	_overlay.gui_input.connect(_on_overlay_gui_input)
	_close_button.pressed.connect(close)
	for slot in range(1, SLOT_COUNT + 1):
		var save_button := get_node("SaveLoadModal/SaveLoadBox/Slot%dRow/SaveSlot%d" % [slot, slot]) as Button
		save_button.pressed.connect(func() -> void:
			save_slot_requested.emit(slot)
		)
		_save_buttons[slot] = save_button
		var load_button := get_node("SaveLoadModal/SaveLoadBox/Slot%dRow/LoadSlot%d" % [slot, slot]) as Button
		load_button.pressed.connect(func() -> void:
			load_slot_requested.emit(slot)
			close()
		)
		_load_buttons[slot] = load_button
	get_viewport().size_changed.connect(_center_panel)
	_center_panel()


func open() -> void:
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


## dev-agent layout/debug 组装用 (root 只读 rect, 不接行为)。
func get_debug_controls() -> Dictionary:
	return {
		"panel": _panel,
		"close_button": _close_button,
		"save_buttons": _save_buttons,
		"load_buttons": _load_buttons,
	}


func _on_overlay_gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event != null and mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
		close()


func _center_panel() -> void:
	if _panel == null:
		return
	# autowrap Label 未排版时会把 PanelContainer 的 min height 顶到逐字换行的天高, size 被
	# clamp 上去后不会自动缩回 (旧版靠 root 每帧强压 size 掩盖) —— reset_size() 把 size 收回
	# 当前真实 min, 位置/pivot 沿用旧版常量保持视觉基线不变。
	_panel.reset_size()
	var viewport_size := get_viewport().get_visible_rect().size
	_panel.position = (viewport_size - MODAL_SIZE) * 0.5
	_panel.pivot_offset = MODAL_SIZE * 0.5


func _kill_tween() -> void:
	if _transition_tween != null and _transition_tween.is_valid():
		_transition_tween.kill()
	_transition_tween = null
