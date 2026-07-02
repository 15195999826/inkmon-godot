extends Node
## UI 状态截图 harness (非断言型, 不进 launcher): 驱动 app 到各 UI 状态并逐张截图存盘,
## 供 AI / 人工肉眼比对 (如 presentation 下放前后的视觉一致性)。
## 跑法: godot --path . inkmon/tests/shot_ui_states.tscn  —— **不带 --headless** (需真渲染出像素)。
## 可选参数: --shot-dir=<相对 user:// 或绝对路径>; 默认输出 .claude/tmp/ui-shots/。


const InkMonMainScene := preload("res://inkmon/host/ink_mon_game.tscn")
const FIXTURE_PATH := "res://inkmon/tests/fixtures/sample_creature_contract.json"
const DEFAULT_SHOT_DIR := "res://.claude/tmp/ui-shots"

var _host: InkMonWorldHost
var _shot_dir_global := ""


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	get_window().position = Vector2i(80, 60)
	_shot_dir_global = ProjectSettings.globalize_path(DEFAULT_SHOT_DIR)
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--shot-dir="):
			_shot_dir_global = str(arg).trim_prefix("--shot-dir=")
	DirAccess.make_dir_recursive_absolute(_shot_dir_global)

	_host = InkMonMainScene.instantiate() as InkMonWorldHost
	add_child(_host)
	await get_tree().process_frame
	InkMonItemCatalog.reload_static_items_for_tests(FIXTURE_PATH)
	await _run()
	print("SHOT_HARNESS_RESULT: DONE - shots in %s" % _shot_dir_global)
	get_tree().quit(0)


func _run() -> void:
	await _settle(15)
	await _shot("01_overworld_hud")

	_host.open_npc_menu("shop")
	await _settle(30)
	await _shot("02_npc_menu_shop")
	_host.close_npc_menu()
	await _settle(30)

	_host.open_player_panel("party")
	await _settle(30)
	await _shot("03_drawer_party")

	_host.open_player_panel("bag")
	await _settle(20)
	await _shot("04_drawer_bag")

	_host.open_player_panel("journal")
	await _settle(20)
	await _shot("05_drawer_journal")

	_host.open_save_load_menu()
	await _settle(30)
	await _shot("06_save_load_modal")
	_host.close_save_load_menu()
	await _settle(30)
	_host.close_drawer()
	await _settle(30)
	await _shot("07_back_to_overworld")


func _settle(frames: int) -> void:
	for _i in range(frames):
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [_shot_dir_global, shot_name]
	var err := image.save_png(path)
	print("  [shot] %s -> %s (err=%d)" % [shot_name, path, err])
