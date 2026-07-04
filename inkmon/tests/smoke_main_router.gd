extends Node
## P5 外层 screen 路由冒烟: InkMonMain boot 停在主菜单 (不自动进游戏),
## 选 New Game 后 boot 内层游戏导播并落在 OVERWORLD。
## (真鼠标点击链路归 smoke_main_menu; 本 smoke 直调 handler, 只焊路由语义。)


const InkMonMainRouter := preload("res://InkMonMain.tscn")


func _ready() -> void:
	var status := await _run()
	if status == "":
		print("SMOKE_TEST_RESULT: PASS - InkMonMain boots to main menu, New Game starts director at OVERWORLD")
		get_tree().quit(0)
	else:
		print("SMOKE_TEST_RESULT: FAIL - %s" % status)
		get_tree().quit(1)


func _run() -> String:
	var router := InkMonMainRouter.instantiate() as InkMonMain
	if router == null:
		return "InkMonMain.tscn root should be InkMonMain (outer router)"
	add_child(router)
	await get_tree().process_frame

	if router.get_game_director() != null:
		return "router must NOT auto-boot the game (menu first)"
	if router.find_child("MainMenuLayer", true, false) == null:
		return "router should show the main menu on boot"

	router._on_new_game_pressed()
	await get_tree().process_frame

	var director := router.get_game_director()
	if director == null:
		return "New Game should boot an inner game director"
	var state := director.get_dev_agent_state()
	if str(state.get("state", "")) != "OVERWORLD":
		return "router-booted game should start at OVERWORLD, got %s" % str(state.get("state", ""))

	router.queue_free()
	await get_tree().process_frame
	return ""
