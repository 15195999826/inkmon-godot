extends Node


const InkMonMainScene := preload("res://scenes/inkmon-main/InkMonMain.tscn")


func _ready() -> void:
	var status := await _run()
	if status == "":
		print("SMOKE_TEST_RESULT: PASS - InkMonMain 3D overworld movement and player UI smoke passed")
		get_tree().quit(0)
	else:
		print("SMOKE_TEST_RESULT: FAIL - %s" % status)
		get_tree().quit(1)


func _run() -> String:
	var root := InkMonMainScene.instantiate() as InkMonAppRoot
	add_child(root)
	await get_tree().process_frame
	await get_tree().process_frame

	var visual_status := _assert_3d_visual_state(root)
	if visual_status != "":
		return _cleanup(root, visual_status)

	var path_status := _assert_path_move(root)
	if path_status != "":
		return _cleanup(root, path_status)

	var blocked_status := _assert_blocked_npc_retarget(root)
	if blocked_status != "":
		return _cleanup(root, blocked_status)

	var input_status := await _assert_screen_pick_move(root)
	if input_status != "":
		return _cleanup(root, input_status)

	var ui_status := _assert_player_ui_panels(root)
	if ui_status != "":
		return _cleanup(root, ui_status)

	var save_status := _assert_move_save_load(root)
	if save_status != "":
		return _cleanup(root, save_status)

	root.queue_free()
	await get_tree().process_frame
	return ""


func _assert_3d_visual_state(root: InkMonAppRoot) -> String:
	var state := root.get_dev_agent_state()
	var overworld := state.get("overworld_3d", {}) as Dictionary
	if overworld == null or overworld.get("node_type", "") != "InkMonOverworldView3D":
		return "overworld view should be 3D"
	if int(overworld.get("tile_count", 0)) <= 0:
		return "3D overworld should have tiles"
	if int(overworld.get("env_tile_count", 0)) <= 0:
		return "GridMapRenderer3D should render env tiles"
	if int(overworld.get("npc_count", 0)) < 6:
		return "3D overworld should show NPC markers"
	return ""


func _assert_path_move(root: InkMonAppRoot) -> String:
	var result := root.goto_tile(Vector2i(3, -1))
	if not bool(result.get("ok", false)):
		return "goto_tile path move failed: %s" % str(result.get("message", ""))
	var state := root.get_dev_agent_state()
	if _coord_from_state(state) != Vector2i(3, -1):
		return "player final coord should be clicked target"
	var move_data := _last_move_data(state)
	var step_count := int(move_data.get("step_count", 0))
	if step_count < 3:
		return "path move should take at least three hex steps"
	if int(move_data.get("reservation_count", -1)) != 0:
		return "reservation count should be zero after path move"
	if int(move_data.get("occupant_count_before", 0)) != int(move_data.get("occupant_count_after", -1)):
		return "occupant count should be conserved"
	if _count_events(move_data, "started") != step_count:
		return "move_started count should equal step count"
	if _count_events(move_data, "applied") != step_count:
		return "move_applied count should equal step count"
	if _count_events(move_data, "completed") != step_count:
		return "move_completed count should equal step count"
	return ""


func _assert_blocked_npc_retarget(root: InkMonAppRoot) -> String:
	root.reset_session()
	var result := root.goto_tile(Vector2i(2, 0))
	if not bool(result.get("ok", false)):
		return "right-clicking blocked Shop tile should retarget to an adjacent tile"
	var state := root.get_dev_agent_state()
	var final_coord := _coord_from_state(state)
	if final_coord == Vector2i(2, 0):
		return "player must not land on occupied Shop tile"
	if _axial_distance(final_coord, Vector2i(2, 0)) != 1:
		return "retargeted final coord should be adjacent to Shop"
	if state.get("near_npc_id", "") != "shop":
		return "retargeted move should set near_npc_id to shop"
	var move_data := _last_move_data(state)
	if not bool(move_data.get("retargeted", false)):
		return "blocked NPC target should be marked retargeted"
	return ""


func _assert_screen_pick_move(root: InkMonAppRoot) -> String:
	root.reset_session()
	await get_tree().process_frame
	var pos_result := root.get_tile_screen_position(Vector2i(1, -1))
	if not bool(pos_result.get("ok", false)):
		return "tile_screen_position failed"
	var data := pos_result.get("data", {}) as Dictionary
	var pos := Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))
	var click_result := root.right_click_at(pos)
	if not bool(click_result.get("ok", false)):
		return "screen pick right_click_at failed: %s" % str(click_result.get("message", ""))
	var state := root.get_dev_agent_state()
	if _coord_from_state(state) != Vector2i(1, -1):
		return "screen pick should move to picked hex"
	return ""


func _assert_player_ui_panels(root: InkMonAppRoot) -> String:
	var party := root.open_player_panel("party")
	if not bool(party.get("ok", false)):
		return "opening Party panel failed"
	if root.get_dev_agent_state().get("drawer_mode", "") != "party":
		return "drawer_mode should be party"
	var bag := root.open_player_panel("bag")
	if not bool(bag.get("ok", false)):
		return "opening Bag panel failed"
	if root.get_dev_agent_state().get("drawer_mode", "") != "bag":
		return "drawer_mode should be bag"
	var journal := root.open_player_panel("journal")
	if not bool(journal.get("ok", false)):
		return "opening Journal panel failed"
	if root.get_dev_agent_state().get("drawer_mode", "") != "journal":
		return "drawer_mode should be journal"
	var menu := root.open_save_load_menu()
	if not bool(menu.get("ok", false)):
		return "opening Save/Load modal failed"
	if not bool(root.get_dev_agent_state().get("modal_open", false)):
		return "modal_open should be true"
	root.close_save_load_menu()
	root.close_drawer()
	return ""


func _assert_move_save_load(root: InkMonAppRoot) -> String:
	root.reset_session()
	var move_result := root.goto_tile(Vector2i(-1, 1))
	if not bool(move_result.get("ok", false)):
		return "move before save failed"
	var save_path := "user://inkmon_l2_overworld_3d_save.json"
	var save_result := root.save_game(save_path)
	if not bool(save_result.get("ok", false)):
		return "save after move failed"
	root.reset_session()
	if _coord_from_state(root.get_dev_agent_state()) == Vector2i(-1, 1):
		return "reset should change coord before load"
	var load_result := root.load_game(save_path)
	if not bool(load_result.get("ok", false)):
		return "load after move failed"
	if _coord_from_state(root.get_dev_agent_state()) != Vector2i(-1, 1):
		return "load should restore moved overworld coord"
	return ""


func _last_move_data(state: Dictionary) -> Dictionary:
	var last_move := state.get("last_move_result", {}) as Dictionary
	if last_move == null:
		return {}
	var data := last_move.get("data", {}) as Dictionary
	return data if data != null else {}


func _count_events(move_data: Dictionary, kind: String) -> int:
	var events := move_data.get("move_events", []) as Array
	if events == null:
		return 0
	var count := 0
	for event_value in events:
		var event := event_value as Dictionary
		if event != null and event.get("kind", "") == kind:
			count += 1
	return count


func _coord_from_state(state: Dictionary) -> Vector2i:
	var coord := state.get("player_coord", {}) as Dictionary
	if coord == null:
		return Vector2i.ZERO
	return Vector2i(int(coord.get("q", 0)), int(coord.get("r", 0)))


func _axial_distance(a: Vector2i, b: Vector2i) -> int:
	var dq := a.x - b.x
	var dr := a.y - b.y
	return int((abs(dq) + abs(dq + dr) + abs(dr)) / 2)


func _cleanup(root: InkMonAppRoot, status: String) -> String:
	root.queue_free()
	GameWorld.shutdown()
	return status
