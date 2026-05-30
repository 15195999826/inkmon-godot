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

	var shop_status := _assert_shop_flow(root)
	if shop_status != "":
		return _cleanup(root, shop_status)

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


func _assert_shop_flow(root: InkMonAppRoot) -> String:
	var move_result := root.move_player(Vector2i(1, 0))
	if not bool(move_result.get("ok", false)):
		return "move to Shop failed"
	var moved_state := root.get_dev_agent_state()
	if moved_state.get("near_npc_id", "") != "shop":
		return "moving right should put player near Shop"

	var open_result := root.open_near_npc_menu()
	if not bool(open_result.get("ok", false)):
		return "open near NPC menu failed"
	if root.get_dev_agent_state().get("active_npc_id", "") != "shop":
		return "active NPC should be Shop"

	var buy_result := root.buy_shop_item(InkMonItemCatalog.MINOR_RUNE)
	if not bool(buy_result.get("ok", false)):
		return "buy Minor Rune failed: %s" % str(buy_result.get("message", ""))
	var bought_state := root.get_dev_agent_state()
	if int(bought_state.get("gold", 0)) != InkMonPlayerState.DEFAULT_GOLD - 10:
		return "buying Minor Rune should spend 10 gold"
	if not _bag_has(bought_state.get("bag", []), "minor_rune"):
		return "bag should contain minor_rune after buy"

	var close_result := root.close_npc_menu()
	if not bool(close_result.get("ok", false)):
		return "close NPC menu failed"
	if bool(root.get_dev_agent_state().get("panel_open", false)):
		return "panel should be closed after close_npc_menu"
	return ""


func _bag_has(value: Variant, config_id: String) -> bool:
	var items := value as Array
	if items == null:
		return false
	for item_value in items:
		var item := item_value as Dictionary
		if item != null and str(item.get("config_id", "")) == config_id:
			return true
	return false


func _cleanup(root: InkMonAppRoot, status: String) -> String:
	root.queue_free()
	GameWorld.shutdown()
	return status
