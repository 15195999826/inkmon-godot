class_name InkMonMain
extends Node
## 外层 screen 路由 (ngnl inner_main 式): 标题菜单 → 进游戏 的大场景切换层 (docs/main-game-architecture.md §6b)。
##
## 主菜单 = session 层职责: New Game / Continue(读最近存档) / 出发档恢复(plan 尾项③)。
## 出发档存在 ⇔ 上次出征未正常收尾(崩溃/强退, Host 两出口收尾会删档), 此处给"回到出发时刻"入口
## —— 崩溃 = "丢这趟"(glossary §4.8), load 出发档后档即消费删除。
## 内层游戏导播 (inkmon/host/ink_mon_game.tscn) 只管游戏内 (主世界 ↔ 战斗 ↔ NPC ↔ save);
## Host._ready 恒 new_game(smoke 依赖此契约), continue/recover 由本层进游戏后再 load 覆盖,
## 不塞 Host 自动 recover(会消费共享出发档, 引爆并行 smoke race)。


const GameScene := preload("res://inkmon/host/ink_mon_game.tscn")

const COLOR_MENU_BG := Color(0.08, 0.09, 0.11)
const COLOR_TITLE := Color(0.92, 0.90, 0.84)
const COLOR_SUBTITLE := Color(0.55, 0.56, 0.52)
const COLOR_RECOVER_HINT := Color(0.85, 0.68, 0.35)

var _game_director: InkMonWorldHost = null
var _menu_layer: CanvasLayer = null


func _ready() -> void:
	# dev-agent 无头驾驶 (host/DEV_AGENT.md): 树路径契约 = /root/InkMonMain/WorldHost/...,
	# agent 不会点菜单 —— 跳过主菜单直接进游戏。
	if OS.get_cmdline_user_args().has("--dev-agent"):
		_enter_game()
		return
	_show_main_menu()


# === 主菜单 (代码建 UI, 项目自绘风格) ===

func _show_main_menu() -> void:
	_menu_layer = CanvasLayer.new()
	_menu_layer.name = "MainMenuLayer"
	add_child(_menu_layer)

	var backdrop := ColorRect.new()
	backdrop.name = "MenuBackdrop"
	backdrop.color = COLOR_MENU_BG
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_layer.add_child(backdrop)

	var centered := CenterContainer.new()
	centered.name = "MenuCenter"
	centered.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(centered)

	var column := VBoxContainer.new()
	column.name = "MenuColumn"
	column.add_theme_constant_override("separation", 14)
	centered.add_child(column)

	var title := Label.new()
	title.text = "INKMON"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", COLOR_TITLE)
	column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "hex expedition prototype"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", COLOR_SUBTITLE)
	column.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 18.0)
	column.add_child(spacer)

	var new_game_button := _make_menu_button("NewGameButton", "New Game")
	new_game_button.pressed.connect(_on_new_game_pressed)
	column.add_child(new_game_button)

	var continue_button := _make_menu_button("ContinueButton", "Continue")
	continue_button.disabled = _latest_save_path() == ""
	continue_button.pressed.connect(_on_continue_pressed)
	column.add_child(continue_button)

	# 尾项③: 出发档存在 = 上次出征未归 (崩溃/强退), 给"回到出发时刻"恢复入口。
	if FileAccess.file_exists(InkMonWorldHost.DEPARTURE_SAVE_PATH):
		var hint := Label.new()
		hint.name = "RecoverHint"
		hint.text = "Last mission never returned."
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.add_theme_font_size_override("font_size", 14)
		hint.add_theme_color_override("font_color", COLOR_RECOVER_HINT)
		column.add_child(hint)
		var recover_button := _make_menu_button("RecoverButton", "Return to Departure")
		recover_button.pressed.connect(_on_recover_pressed)
		column.add_child(recover_button)


func _make_menu_button(node_name: String, text: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size = Vector2(260.0, 46.0)
	button.add_theme_font_size_override("font_size", 20)
	return button


func _close_menu() -> void:
	if _menu_layer == null:
		return
	# 先隐再 queue_free: 释放在帧尾, 隐掉挡住同帧重复点击。
	_menu_layer.visible = false
	_menu_layer.queue_free()
	_menu_layer = null


## Continue 语义 v1: 最近修改的存档 (3 手动槽 + 快捷档) 直接进。无档返回 ""(按钮已禁用, 防御性)。
func _latest_save_path() -> String:
	var paths: Array[String] = [InkMonWorldHost.DEFAULT_SAVE_PATH]
	for slot in range(1, InkMonWorldHost.SAVE_SLOT_COUNT + 1):
		paths.append(InkMonWorldHost.slot_save_path(slot))
	var best_path := ""
	var best_time := 0
	for path in paths:
		if not FileAccess.file_exists(path):
			continue
		var modified := FileAccess.get_modified_time(path)
		if modified > best_time:
			best_time = modified
			best_path = path
	return best_path


func _on_new_game_pressed() -> void:
	_close_menu()
	_enter_game()


func _on_continue_pressed() -> void:
	var path := _latest_save_path()
	_close_menu()
	_enter_game()
	if path != "":
		_game_director.load_game(path)


func _on_recover_pressed() -> void:
	_close_menu()
	_enter_game()
	_game_director.load_game(InkMonWorldHost.DEPARTURE_SAVE_PATH)
	# 出发档已消费 (崩溃恢复 = 回到出发时刻重新来), 收尾删除 —— 与 Host 两出口的生命周期语义对齐。
	if FileAccess.file_exists(InkMonWorldHost.DEPARTURE_SAVE_PATH):
		DirAccess.remove_absolute(InkMonWorldHost.DEPARTURE_SAVE_PATH)


# === 进游戏 ===

## add_child 时 Host._ready 同步执行 (new_game + presentation 装配完毕), 返回后可直接 load 覆盖。
func _enter_game() -> void:
	if _game_director != null:
		return
	_game_director = GameScene.instantiate() as InkMonWorldHost
	add_child(_game_director)


func get_game_director() -> InkMonWorldHost:
	return _game_director
