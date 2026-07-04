extends Node
## 主菜单 UI 交互 smoke (real mouse input): InkMonMain 起菜单 → 按钮契约 → 真鼠标点 New Game →
## 菜单关闭 + 游戏导播就位。
## ⚠ 本 smoke 刻意不碰 user:// 出发档、不断言 Continue 禁用态 / Recover 按钮存在性 ——
## 那些依赖共享 user:// 文件状态, 并行 launcher 下会与 smoke_mission_departure 互踩 (上轮已踩过的 race);
## 出发档恢复全链归 smoke_mission_departure 段三独占串行。
## UI 交互 smoke 约定: _ready 首行 ensure window size; PASS 输出带 "(real mouse input)"。


const MainScene := preload("res://InkMonMain.tscn")


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	var status: String = await _run()
	if status == "":
		print("SMOKE_TEST_RESULT: PASS - main menu: boots to menu, New Game enters game (real mouse input)")
		get_tree().quit(0)
	else:
		print("SMOKE_TEST_RESULT: FAIL - %s" % status)
		get_tree().quit(1)


func _run() -> String:
	var main := MainScene.instantiate() as InkMonMain
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	var new_game_button := main.find_child("NewGameButton", true, false) as Button
	if new_game_button == null:
		return "main menu should show NewGameButton"
	if main.find_child("ContinueButton", true, false) == null:
		return "main menu should show ContinueButton"
	if main.get_game_director() != null:
		return "game must not start before menu choice"

	_click_at((new_game_button.get_global_rect() as Rect2).get_center())
	await get_tree().process_frame
	await get_tree().process_frame
	if main.get_game_director() == null:
		return "New Game click should enter the game"
	if main.find_child("MainMenuLayer", true, false) != null:
		return "menu layer should be gone after New Game"
	main.free()
	return ""


func _click_at(screen_pos: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = screen_pos
	press.global_position = screen_pos
	get_viewport().push_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = screen_pos
	release.global_position = screen_pos
	get_viewport().push_input(release)
