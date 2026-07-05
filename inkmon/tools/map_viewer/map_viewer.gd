extends Node2D
## 大地图渲染查看器 (dev 工具, 非玩家 UI): 不走主菜单/公会/出征链, 直接生成世界并渲染地图纸。
## 跑法: 编辑器打开本场景 F6; 或 godot --path . inkmon/tools/map_viewer/map_viewer.tscn。
## 快捷键: [Space] 换 seed 重生成 / [S] 循环画风 (session 内, 不写 user:// 偏好) /
## [M] 适配切换 (全图含海岸 ↔ 可玩区出血) / [Esc] 退出。
## 自验参数: --viewer-shot (user args) = 1 秒后截图到 .claude/tmp/shot_map_viewer.png 并退出。


const SHOT_PATH := "res://.claude/tmp/shot_map_viewer.png"
## 全图无雾: 视野半径喂一个覆盖全图的大数 (view 的迷雾三态语义原样, 全部落 lit)。
const ALL_LIT_SIGHT := 9999


var _view: InkMonMissionMapView = null
var _hud_label: Label = null
var _seed := 0
var _style_id := ""
var _fit_full_sheet := true
var _map: InkMonWorldMapData = null


func _ready() -> void:
	get_window().size = Vector2i(1600, 900)
	get_window().title = "InkMon Map Viewer"
	_view = InkMonMissionMapView.new()
	_view.name = "MapView"
	add_child(_view)
	var hud_layer := CanvasLayer.new()
	hud_layer.name = "HudLayer"
	add_child(hud_layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	panel.self_modulate = Color(1, 1, 1, 0.85)
	hud_layer.add_child(panel)
	_hud_label = Label.new()
	_hud_label.add_theme_font_size_override("font_size", 15)
	panel.add_child(_hud_label)
	_style_id = InkMonMapStylePresets.load_pref()
	get_viewport().size_changed.connect(_apply_fit)
	_regenerate(randi())
	if OS.get_cmdline_user_args().has("--viewer-shot"):
		await get_tree().create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		var absolute := ProjectSettings.globalize_path(SHOT_PATH)
		get_viewport().get_texture().get_image().save_png(absolute)
		print("SHOT_SAVED: %s" % absolute)
		get_tree().quit(0)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_SPACE:
			_regenerate(randi())
		KEY_S:
			_style_id = InkMonMapStylePresets.next_style(_style_id)
			_view.set_map_style(_style_id)
			_refresh_hud()
		KEY_M:
			_fit_full_sheet = not _fit_full_sheet
			_apply_fit()
			_refresh_hud()
		KEY_ESCAPE:
			get_tree().quit(0)


## 生成新世界并推给 view (伪 mission 快照: 单个 start 节点站据点位 + 全图 lit, 无迷雾遮挡)。
func _regenerate(seed_value: int) -> void:
	_seed = seed_value
	_map = InkMonWorldMapData.generate(seed_value)
	print("[map_viewer] seed=%d rivers=%d" % [seed_value, _map.rivers.size()])
	_view.set_map_style(_style_id)
	_view.refresh(_fake_mission_snapshot(), _map.to_dict())
	_apply_fit()
	_refresh_hud()


## 让 view 正常走完整渲染链所需的最小 mission 快照: 棋子/起点钉在入口格, 目标旗指向 1 号地标。
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
		"sight_range": ALL_LIT_SIGHT,
		"current_coord": _map.entry_coord,
		"target_site_coord": sites[0] if not sites.is_empty() else Vector2i(-999, -999),
	}


## 适配: 全图含海岸 (contain) / 可玩区出血 (view 自带 fit, 海岸出血到屏幕外 = 入游观感)。
func _apply_fit() -> void:
	if _map == null:
		return
	if not _fit_full_sheet:
		_view.refresh(_fake_mission_snapshot(), _map.to_dict())
		return
	var sheet_rect: Rect2 = _view._sheet_view_rect
	if sheet_rect.size.x <= 0.0 or sheet_rect.size.y <= 0.0:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var fit := minf(viewport_size.x / sheet_rect.size.x, viewport_size.y / sheet_rect.size.y)
	_view.scale = Vector2.ONE * fit
	_view.position = (viewport_size - sheet_rect.size * fit) * 0.5 - sheet_rect.position * fit


func _refresh_hud() -> void:
	var style_name := InkMonText.t(InkMonMapStylePresets.name_key(_style_id))
	_hud_label.text = "seed %d   style: %s (%s)   fit: %s\n[Space] new world   [S] style   [M] fit   [Esc] quit" % [
		_seed, _style_id, style_name, "full sheet" if _fit_full_sheet else "playable bleed"]
