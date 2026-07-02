class_name InkMonRightDrawer
extends Control
## right drawer 子场景控制器 (docs §6 下放: UI 行为住子场景脚本, root 只接线)。
## 自管: 骨架节点 / dim 点击与 close 按钮 / tab 点击上抛 / 开关滑动 tween (含两处竞态保护) /
## 右侧停靠布局 (show 时 + viewport resize 驱动, 非每帧)。
## 内容 (party/bag/journal/NPC actions) 是数据驱动的, 由 root 经 get_body() 填充 ——
## 数据源 (query / panel_view / submit 回调) 不进子场景。


signal close_requested
signal tab_selected(panel_id: String)


const TAB_IDS: Array[String] = ["party", "bag", "journal"]
const MIN_WIDTH := 420.0
const WIDTH_RATIO := 0.40
const DOCK_MARGIN_RIGHT := 24.0
const DOCK_TOP := 104.0
const DOCK_BOTTOM_MARGIN := 148.0
const SLIDE_OVERSHOOT := 32.0


var _dim: ColorRect
var _panel: PanelContainer
var _title: Label
var _close_button: Button
var _tab_bar: HBoxContainer
var _tab_buttons: Dictionary = {}
var _body: VBoxContainer
var _transition_tween: Tween
var _transition_active := false
## 关动画期间又请求打开 → 完成回调不隐藏 (同 modal 的竞态语义)。
var _open_requested := false


func _ready() -> void:
	_dim = get_node("DimOverlay") as ColorRect
	_panel = get_node("RightDrawer") as PanelContainer
	_title = get_node("RightDrawer/PanelBox/PanelHeader/PanelTitle") as Label
	_close_button = get_node("RightDrawer/PanelBox/PanelHeader/PanelCloseButton") as Button
	_tab_bar = get_node("RightDrawer/PanelBox/PanelTabs") as HBoxContainer
	_body = get_node("RightDrawer/PanelBox/PanelBody") as VBoxContainer
	_dim.gui_input.connect(_on_dim_gui_input)
	_close_button.pressed.connect(func() -> void:
		close_requested.emit()
	)
	for panel_id in TAB_IDS:
		var button := _tab_bar.get_node("Tab_%s" % panel_id.capitalize()) as Button
		button.pressed.connect(func() -> void:
			tab_selected.emit(panel_id)
		)
		_tab_buttons[panel_id] = button
	get_viewport().size_changed.connect(_dock_right)


## 开侧显示序列 (原 root._refresh_panel 开侧半段)。调用前 root 应已把内容填进 get_body()
## (滑入动画开始时内容就绪)。重复调用 (已开着切 tab) 只换 title/tab 可见性, 不重播滑入。
func show_drawer(title_text: String, tabs_visible: bool) -> void:
	# 打断关闭中的 tween: 其 finished 回调不得把刚要显示的 drawer 藏掉 (ghost + 点击黑洞竞态)。
	var interrupted_transition := _transition_active
	_kill_tween()
	_transition_active = false
	_open_requested = true
	var animate_open := interrupted_transition or not _panel.visible
	_dim.visible = true
	_panel.visible = true
	_tab_bar.visible = tabs_visible
	_title.text = title_text
	_dock_right()
	if animate_open:
		_animate_open()


func hide_drawer() -> void:
	_open_requested = false
	if _panel == null or not _panel.visible:
		return
	# 打断开启中的 tween, 从当前位置起播关闭 (mid-open 关闭不留 ghost)。
	_kill_tween()
	_transition_active = true
	var target_position := _panel.position + Vector2(_panel.size.x + SLIDE_OVERSHOOT, 0.0)
	_transition_tween = create_tween()
	_transition_tween.tween_property(_panel, "position", target_position, 0.14) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_transition_tween.finished.connect(func() -> void:
		_transition_active = false
		if _open_requested:
			return
		_panel.visible = false
		_dim.visible = false
	)


func is_drawer_visible() -> bool:
	return _panel != null and _panel.visible


func is_dim_visible() -> bool:
	return _dim != null and _dim.visible


func is_transition_active() -> bool:
	return _transition_active


## 内容容器 (root 数据驱动填充: panel_view build / NPC action rows)。
func get_body() -> VBoxContainer:
	return _body


## dev-agent layout/debug 组装用 (root 只读 rect, 不接行为)。
func get_debug_controls() -> Dictionary:
	return {
		"panel": _panel,
		"close_button": _close_button,
		"tab_buttons": _tab_buttons,
	}


func _on_dim_gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event != null and mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
		close_requested.emit()


## 右侧停靠 (宽 = max(420, 40% viewport), 顶 104 / 底留 44)。
func _dock_right() -> void:
	if _panel == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var panel_width := maxf(MIN_WIDTH, viewport_size.x * WIDTH_RATIO)
	_panel.position = Vector2(viewport_size.x - panel_width - DOCK_MARGIN_RIGHT, DOCK_TOP)
	_panel.size = Vector2(panel_width, viewport_size.y - DOCK_BOTTOM_MARGIN)


func _animate_open() -> void:
	if _transition_active:
		return
	var target_position := _panel.position
	_panel.position = target_position + Vector2(_panel.size.x + SLIDE_OVERSHOOT, 0.0)
	_transition_active = true
	_kill_tween()
	_transition_tween = create_tween()
	_transition_tween.tween_property(_panel, "position", target_position, 0.18) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_transition_tween.finished.connect(func() -> void:
		_transition_active = false
	)


func _kill_tween() -> void:
	if _transition_tween != null and _transition_tween.is_valid():
		_transition_tween.kill()
	_transition_tween = null
