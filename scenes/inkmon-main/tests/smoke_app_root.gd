extends Node


const InkMonMainScene := preload("res://scenes/inkmon-main/InkMonMain.tscn")


func _ready() -> void:
	var status := await _run()
	if status == "":
		print("SMOKE_TEST_RESULT: PASS - InkMonAppRoot ran a training battle and returned to overworld")
		get_tree().quit(0)
	else:
		print("SMOKE_TEST_RESULT: FAIL - %s" % status)
		get_tree().quit(1)


func _run() -> String:
	var root := InkMonMainScene.instantiate() as InkMonAppRoot
	add_child(root)
	await get_tree().process_frame

	var initial_state := root.get_dev_agent_state()
	if initial_state.get("state", "") != "OVERWORLD":
		return _cleanup(root, "initial state should be OVERWORLD")
	if int(initial_state.get("gold", 0)) != InkMonPlayerState.DEFAULT_GOLD:
		return _cleanup(root, "new game gold should be default")

	var result := root.run_training_battle_to_completion(8)
	if not bool(result.get("ok", false)):
		return _cleanup(root, "training battle failed: %s" % str(result.get("message", "")))

	var final_state := root.get_dev_agent_state()
	if final_state.get("state", "") != "OVERWORLD":
		return _cleanup(root, "state did not return to OVERWORLD")
	if str(final_state.get("active_instance_id", "")) != "":
		return _cleanup(root, "active instance id should be empty after battle")
	if int(final_state.get("gold", 0)) <= InkMonPlayerState.DEFAULT_GOLD:
		return _cleanup(root, "battle result did not award gold")
	var battle_result := final_state.get("last_battle_result", {}) as Dictionary
	if battle_result == null or battle_result.get("winner_team", "") != "left":
		return _cleanup(root, "last battle result should be a left win")

	root.queue_free()
	await get_tree().process_frame
	return ""


func _cleanup(root: InkMonAppRoot, status: String) -> String:
	root.queue_free()
	GameWorld.shutdown()
	return status
