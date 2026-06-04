extends Node
## P5 外层 screen 路由冒烟: InkMonMain (薄路由) 应 boot 内层游戏导播并落在 OVERWORLD。


const InkMonMainRouter := preload("res://InkMonMain.tscn")


func _ready() -> void:
	var status := await _run()
	if status == "":
		print("SMOKE_TEST_RESULT: PASS - InkMonMain outer router boots the game director at OVERWORLD")
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

	var director := router.get_game_director()
	if director == null:
		return "router should boot an inner game director"
	var state := director.get_dev_agent_state()
	if str(state.get("state", "")) != "OVERWORLD":
		return "router-booted game should start at OVERWORLD, got %s" % str(state.get("state", ""))

	router.queue_free()
	await get_tree().process_frame
	return ""
