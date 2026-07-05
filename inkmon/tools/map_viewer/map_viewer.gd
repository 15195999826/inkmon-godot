extends Node2D
## 大地图渲染查看器 (dev 工具, 非玩家 UI): 不走主菜单/公会/出征链, 直接生成世界并渲染地图纸。
## 跑法: 编辑器打开本场景 F6; 或 godot --path . inkmon/tools/map_viewer/map_viewer.tscn。
##
## 操作 (顶部控制条 = 鼠标全覆盖; 快捷键等价):
## - Seed 输入框回车 = 按指定 seed 重生成 (复现排查用); Random = 换随机 seed ([Space])
## - Style 药丸组 = 六风格即点即换 ([S] 循环; session 内不写 user:// 偏好)
## - Fit 药丸组 = sheet 全图含海岸 / bleed 可玩区出血=入游观感 ([M] 循环)
## - Fog preview = 伪迷雾态预览 (入口视野圆 + 黑区, 看雾与风格的合成)
## - 滚轮 = 以光标为锚缩放; 左键拖拽 = 平移 (动过即进 manual 视角, 点 Fit 药丸恢复)
## - [Esc] 退出
## 自验参数: --viewer-shot (user args) = 1 秒后截图到 .claude/tmp/shot_map_viewer.png 并退出。
## 文案约定: dev 工具控件用英文 (子集字体只保玩家文案用字); 风格中文名走 CSV (子集已覆盖)。


const SHOT_PATH := "res://.claude/tmp/shot_map_viewer.png"
## 全图无雾: 视野半径喂一个覆盖全图的大数 (view 的迷雾三态语义原样, 全部落 lit)。
const ALL_LIT_SIGHT := 9999
## 迷雾预览: 用玩家默认视野半径量级, 看雾缘与风格合成。
const FOG_PREVIEW_SIGHT := 3
const ZOOM_STEP := 1.15
const ZOOM_MIN := 0.2
const ZOOM_MAX := 8.0

const FIT_SHEET := "sheet"
const FIT_BLEED := "bleed"
const FIT_MANUAL := "manual"


var _view: InkMonMissionMapView = null
var _seed := 0
var _style_id := ""
var _fit_mode := FIT_SHEET
var _fog_preview := false
var _map: InkMonWorldMapData = null
var _dragging := false

var _seed_edit: LineEdit = null
var _style_name_label: Label = null
var _style_buttons: Dictionary = {}
var _fit_buttons: Dictionary = {}


func _ready() -> void:
	get_window().size = Vector2i(1600, 900)
	get_window().title = "InkMon Map Viewer"
	_view = InkMonMissionMapView.new()
	_view.name = "MapView"
	add_child(_view)
	_style_id = InkMonMapStylePresets.load_pref()
	_build_control_bar()
	get_viewport().size_changed.connect(_apply_fit)
	_regenerate(randi() & 0x3FFFFFFF)
	if OS.get_cmdline_user_args().has("--viewer-shot"):
		# 自验双截: shader 版 + Ref CPU 参照 (同 seed 同风格 moss), A/B 定位渲染差异。
		_on_style_pill(InkMonMapStylePresets.STYLE_MOSS)
		await get_tree().create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		var absolute := ProjectSettings.globalize_path(SHOT_PATH)
		get_viewport().get_texture().get_image().save_png(absolute)
		print("SHOT_SAVED: %s" % absolute)
		get_tree().quit(0)


# === 控制条 (顶部一条, 配置切换用药丸组 —— 对齐工具页交互惯例) ===


func _build_control_bar() -> void:
	var hud_layer := CanvasLayer.new()
	hud_layer.name = "HudLayer"
	add_child(hud_layer)
	var panel := PanelContainer.new()
	panel.name = "ControlBar"
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.self_modulate = Color(1, 1, 1, 0.92)
	hud_layer.add_child(panel)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	panel.add_child(bar)

	bar.add_child(_make_caption("Seed"))
	_seed_edit = LineEdit.new()
	_seed_edit.custom_minimum_size = Vector2(120, 0)
	_seed_edit.add_theme_font_size_override("font_size", 14)
	_seed_edit.text_submitted.connect(_on_seed_submitted)
	bar.add_child(_seed_edit)
	var random_button := Button.new()
	random_button.text = "Random"
	random_button.add_theme_font_size_override("font_size", 14)
	random_button.pressed.connect(func() -> void: _regenerate(randi() & 0x3FFFFFFF))
	bar.add_child(random_button)

	bar.add_child(VSeparator.new())
	bar.add_child(_make_caption("Style"))
	var style_group := ButtonGroup.new()
	for style_value in InkMonMapStylePresets.ORDER:
		var style_id := str(style_value)
		var pill := Button.new()
		pill.text = style_id
		pill.toggle_mode = true
		pill.button_group = style_group
		pill.add_theme_font_size_override("font_size", 14)
		pill.pressed.connect(_on_style_pill.bind(style_id))
		bar.add_child(pill)
		_style_buttons[style_id] = pill
	_style_name_label = _make_caption("")
	_style_name_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.6))
	bar.add_child(_style_name_label)

	bar.add_child(VSeparator.new())
	bar.add_child(_make_caption("Fit"))
	var fit_group := ButtonGroup.new()
	for fit_value in [FIT_SHEET, FIT_BLEED]:
		var fit_id := str(fit_value)
		var pill := Button.new()
		pill.text = fit_id
		pill.toggle_mode = true
		pill.button_group = fit_group
		pill.add_theme_font_size_override("font_size", 14)
		pill.pressed.connect(_on_fit_pill.bind(fit_id))
		bar.add_child(pill)
		_fit_buttons[fit_id] = pill

	bar.add_child(VSeparator.new())
	var fog_toggle := CheckButton.new()
	fog_toggle.text = "Fog preview"
	fog_toggle.add_theme_font_size_override("font_size", 14)
	fog_toggle.toggled.connect(_on_fog_toggled)
	bar.add_child(fog_toggle)

	bar.add_child(VSeparator.new())
	var hint := _make_caption("[Wheel] zoom   [Drag] pan   [Space] random   [S] style   [M] fit   [Esc] quit")
	hint.add_theme_color_override("font_color", Color(0.7, 0.72, 0.75))
	bar.add_child(hint)


static func _make_caption(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", 14)
	return label


func _sync_control_states() -> void:
	if _seed_edit != null and not _seed_edit.has_focus():
		_seed_edit.text = str(_seed)
	var style_pill := _style_buttons.get(_style_id, null) as Button
	if style_pill != null:
		style_pill.set_pressed_no_signal(true)
	if _style_name_label != null:
		_style_name_label.text = InkMonText.t(InkMonMapStylePresets.name_key(_style_id))
	for fit_id in _fit_buttons:
		(_fit_buttons[fit_id] as Button).set_pressed_no_signal(str(fit_id) == _fit_mode)


# === 控件回调 ===


func _on_seed_submitted(text_value: String) -> void:
	var trimmed := text_value.strip_edges()
	if trimmed.is_valid_int():
		_regenerate(int(trimmed))
	else:
		_seed_edit.text = str(_seed)
	_seed_edit.release_focus()


func _on_style_pill(style_id: String) -> void:
	_style_id = style_id
	_view.set_map_style(style_id)
	_sync_control_states()


func _on_fit_pill(fit_id: String) -> void:
	_fit_mode = fit_id
	_apply_fit()
	_sync_control_states()


func _on_fog_toggled(enabled: bool) -> void:
	_fog_preview = enabled
	_refresh_view()



# === 输入 (快捷键 + 滚轮缩放 + 拖拽平移) ===


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		match key.keycode:
			KEY_SPACE:
				_regenerate(randi() & 0x3FFFFFFF)
			KEY_S:
				_on_style_pill(InkMonMapStylePresets.next_style(_style_id))
			KEY_M:
				_on_fit_pill(FIT_BLEED if _fit_mode == FIT_SHEET else FIT_SHEET)
			KEY_ESCAPE:
				get_tree().quit(0)
		return
	var mouse_button := event as InputEventMouseButton
	if mouse_button != null:
		if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_button.pressed:
			_zoom_at(mouse_button.position, ZOOM_STEP)
		elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_button.pressed:
			_zoom_at(mouse_button.position, 1.0 / ZOOM_STEP)
		elif mouse_button.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mouse_button.pressed
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _dragging:
		_view.position += motion.relative
		_fit_mode = FIT_MANUAL
		_sync_control_states()


## 以屏幕锚点缩放: 锚点对应的地图点缩放前后钉在光标下。
func _zoom_at(screen_anchor: Vector2, factor: float) -> void:
	var old_scale := _view.scale.x
	var new_scale := clampf(old_scale * factor, ZOOM_MIN, ZOOM_MAX)
	if is_equal_approx(old_scale, new_scale):
		return
	var anchor_local := (screen_anchor - _view.position) / old_scale
	_view.scale = Vector2.ONE * new_scale
	_view.position = screen_anchor - anchor_local * new_scale
	_fit_mode = FIT_MANUAL
	_sync_control_states()


# === 世界生成与视图 ===


## 生成新世界并推给 view (伪 mission 快照: 单个 start 节点站据点位)。
func _regenerate(seed_value: int) -> void:
	_seed = seed_value
	_map = InkMonWorldMapData.generate(seed_value)
	print("[map_viewer] seed=%d rivers=%d" % [seed_value, _map.rivers.size()])
	_view.set_map_style(_style_id)
	_refresh_view()


func _refresh_view() -> void:
	if _map == null:
		return
	var manual_scale := _view.scale
	var manual_position := _view.position
	_view.refresh(_fake_mission_snapshot(), _map.to_dict())
	if _fit_mode == FIT_MANUAL:
		# refresh 内部会自 fit; manual 视角 (用户拖/缩过) 原样还回去。
		_view.scale = manual_scale
		_view.position = manual_position
	else:
		_apply_fit()
	_sync_control_states()


## 让 view 正常走完整渲染链所需的最小 mission 快照: 棋子/起点钉在入口格, 目标旗指向 1 号地标。
## 迷雾预览开 = 入口处玩家量级视野圆 (lit/黑对比); 关 = 全图 lit。
func _fake_mission_snapshot() -> Dictionary:
	var sites := _map.get_target_candidates()
	return {
		"nodes": [{
			"id": 0,
			"coord": _map.entry_coord,
			"kind": InkMonMissionMapData.NODE_START,
			"visited": true,
			"visibility": "lit",
		}],
		"edges": {},
		"next_node_ids": [],
		"current_node_id": 0,
		"sight_range": FOG_PREVIEW_SIGHT if _fog_preview else ALL_LIT_SIGHT,
		"current_coord": _map.entry_coord,
		"target_site_coord": sites[0] if not sites.is_empty() else Vector2i(-999, -999),
	}


## 适配: sheet 全图含海岸 (contain) / bleed 可玩区出血 (view 自带 fit = 入游观感)。
func _apply_fit() -> void:
	if _map == null or _fit_mode == FIT_MANUAL:
		return
	if _fit_mode == FIT_BLEED:
		_refresh_view_fit_only()
		return
	var sheet_rect: Rect2 = _view._sheet_view_rect
	if sheet_rect.size.x <= 0.0 or sheet_rect.size.y <= 0.0:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var fit := minf(viewport_size.x / sheet_rect.size.x, viewport_size.y / sheet_rect.size.y)
	_view.scale = Vector2.ONE * fit
	_view.position = (viewport_size - sheet_rect.size * fit) * 0.5 - sheet_rect.position * fit


## bleed 模式复用 view 自己的 fit (可玩区 ±margin, 海洋出血屏幕外) —— 走一次私有 fit 即可。
func _refresh_view_fit_only() -> void:
	_view._fit_to_viewport()
