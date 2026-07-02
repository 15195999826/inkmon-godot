extends Node


const InkMonMainScene := preload("res://inkmon/host/ink_mon_game.tscn")


func _ready() -> void:
	var status := await _run()
	if status == "":
		print("SMOKE_TEST_RESULT: PASS - InkMonMain iso overworld movement and player UI smoke passed")
		get_tree().quit(0)
	else:
		print("SMOKE_TEST_RESULT: FAIL - %s" % status)
		get_tree().quit(1)


func _run() -> String:
	var root := InkMonMainScene.instantiate() as InkMonWorldHost
	add_child(root)
	await get_tree().process_frame
	await get_tree().process_frame

	var visual_status := await _assert_iso_visual_state(root)
	if visual_status != "":
		return _cleanup(root, visual_status)

	var path_status := await _assert_path_move(root)
	if path_status != "":
		return _cleanup(root, path_status)

	var blocked_status := await _assert_blocked_npc_retarget(root)
	if blocked_status != "":
		return _cleanup(root, blocked_status)

	var input_status := await _assert_screen_pick_move(root)
	if input_status != "":
		return _cleanup(root, input_status)

	var ui_status := await _assert_player_ui_panels(root)
	if ui_status != "":
		return _cleanup(root, ui_status)

	var drawer_race_status := await _assert_drawer_quick_toggle(root)
	if drawer_race_status != "":
		return _cleanup(root, drawer_race_status)

	var overlay_status := await _assert_overlay_layering_and_dismiss(root)
	if overlay_status != "":
		return _cleanup(root, overlay_status)

	var load_race_status := await _assert_load_during_move(root)
	if load_race_status != "":
		return _cleanup(root, load_race_status)

	var save_status := await _assert_move_save_load(root)
	if save_status != "":
		return _cleanup(root, save_status)

	root.queue_free()
	await get_tree().process_frame
	return ""


func _assert_iso_visual_state(root: InkMonWorldHost) -> String:
	var state := root.get_dev_agent_state()
	var overworld := state.get("overworld_iso", {}) as Dictionary
	if overworld == null or overworld.get("node_type", "") != "InkMonOverworldView":
		return "overworld view should be the iso overworld view"
	if int(overworld.get("tile_count", 0)) <= 0:
		return "iso overworld should have tiles"
	if int(overworld.get("env_tile_count", 0)) <= 0:
		return "GridMapRenderer2D should render env tiles"
	if int(overworld.get("npc_count", 0)) < 6:
		return "iso overworld should show NPC markers"
	var player_idle_before := float(overworld.get("player_idle_offset_y", 0.0))
	var npc_idle_before := float(overworld.get("npc_idle_sample_y", 0.0))
	await get_tree().create_timer(0.2).timeout
	var after_state := root.get_dev_agent_state()
	var after_overworld := after_state.get("overworld_iso", {}) as Dictionary
	var player_idle_after := float(after_overworld.get("player_idle_offset_y", 0.0))
	var npc_idle_after := float(after_overworld.get("npc_idle_sample_y", 0.0))
	if absf(player_idle_after - player_idle_before) < 0.002 and absf(npc_idle_after - npc_idle_before) < 0.002:
		return "player/NPC idle animation should change visual offsets over time"
	return ""


func _assert_path_move(root: InkMonWorldHost) -> String:
	var camera_before := _camera_position_from_state(root.get_dev_agent_state())
	var result := root.goto_tile(Vector2i(3, -1))
	if not bool(result.get("ok", false)):
		return "goto_tile move command should be accepted (enqueued): %s" % str(result.get("message", ""))
	# 异步:入队后 0 tick 玩家还没到终点(move 跨 tick 推进,不瞬移)。
	if _coord_from_state(root.get_dev_agent_state()) == Vector2i(3, -1):
		return "async move must not teleport: player should not be at target right after enqueue"
	var reach_status := await _wait_for_player_to_reach(root, Vector2i(3, -1))
	if reach_status != "":
		return reach_status
	var settle_status := await _wait_for_move_settle(root)
	if settle_status != "":
		return settle_status
	var synced_state := root.get_dev_agent_state()
	if _coord_from_state(synced_state) != Vector2i(3, -1):
		return "player final coord should be the commanded target"
	if _visual_coord_from_state(synced_state) != _coord_from_state(synced_state):
		return "visual coord should sync to logical coord after step tweens settle"
	var camera_after := _camera_position_from_state(synced_state)
	if camera_after.distance_to(camera_before) < 0.2:
		return "camera should follow after player movement"
	return ""


func _assert_blocked_npc_retarget(root: InkMonWorldHost) -> String:
	root.reset_session()
	await get_tree().process_frame
	var result := root.goto_tile(Vector2i(2, 0))
	if not bool(result.get("ok", false)):
		return "move command toward blocked Shop tile should be accepted"
	# 目标 (2,0) 被 Shop 占;Logic retarget 到相邻空格。终点未知 → 等起步后停稳。
	var settle_status := await _wait_for_move_to_start_then_settle(root)
	if settle_status != "":
		return settle_status
	var state := root.get_dev_agent_state()
	var final_coord := _coord_from_state(state)
	if final_coord == Vector2i(2, 0):
		return "player must not land on occupied Shop tile"
	if _axial_distance(final_coord, Vector2i(2, 0)) != 1:
		return "retargeted final coord should be adjacent to Shop"
	if state.get("near_npc_id", "") != "shop":
		return "retargeted move should set near_npc_id to shop"
	# P1 回归:tick 走到 NPC 邻格后,Logic near_npc_id 变了,表演必须同步 ——
	# prompt 按钮要变可见(layout_state.prompt_button 非空),否则记录的真实点击路径走不通。
	var prompt_rect := root.get_dev_agent_layout_state().get("prompt_button", {}) as Dictionary
	if prompt_rect.is_empty():
		return "walking adjacent to an NPC via tick movement must reveal the Enter prompt (prompt_button stayed hidden)"
	if float(prompt_rect.get("w", 0.0)) <= 0.0 or float(prompt_rect.get("h", 0.0)) <= 0.0:
		return "revealed prompt button must have a non-zero clickable rect"
	var overworld := state.get("overworld_iso", {}) as Dictionary
	if not bool(overworld.get("target_feedback_active", false)):
		return "move command should leave a visible target marker"
	# 高亮另一半:handler 同时把 near 推给 view(set_near_npc_id)。断 view 真高亮了 Shop 节点
	# (放大 scale>1),否则 handler 漏掉高亮也能蒙混过 prompt 断言。
	if str(overworld.get("near_npc_highlight", "")) != "shop":
		return "view must highlight the adjacent NPC after tick movement (near_npc_highlight)"
	if float(overworld.get("near_npc_highlight_scale", 0.0)) <= 1.0:
		return "highlighted NPC node should be visually emphasized (scale > 1) after tick movement"

	# 对称面(离开邻域):走回原点(距所有 NPC ≥2)→ near 真相清空 → prompt 隐藏 + 高亮撤除。
	# 守护"setter 只在非空值 emit"这类回归(那会让 prompt 走开后仍卡可见)。
	var leave_result := root.goto_tile(Vector2i(0, 0))
	if not bool(leave_result.get("ok", false)):
		return "move command back to origin should be accepted"
	var leave_reach := await _wait_for_player_to_reach(root, Vector2i(0, 0))
	if leave_reach != "":
		return leave_reach
	var leave_settle := await _wait_for_move_settle(root)
	if leave_settle != "":
		return leave_settle
	var left_state := root.get_dev_agent_state()
	if str(left_state.get("near_npc_id", "")) != "":
		return "walking away from all NPCs should clear near_npc_id"
	if not (root.get_dev_agent_layout_state().get("prompt_button", {}) as Dictionary).is_empty():
		return "prompt must hide after walking away from the NPC (leave-neighborhood sync)"
	var left_overworld := left_state.get("overworld_iso", {}) as Dictionary
	if str(left_overworld.get("near_npc_highlight", "")) != "":
		return "view highlight must clear after walking away from the NPC"
	return ""


func _assert_screen_pick_move(root: InkMonWorldHost) -> String:
	root.reset_session()
	await get_tree().process_frame
	var pos_result := root.get_tile_screen_position(Vector2i(1, -1))
	if not bool(pos_result.get("ok", false)):
		return "tile_screen_position failed"
	var data := pos_result.get("data", {}) as Dictionary
	var pos := Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))
	var click_result := root.right_click_at(pos)
	if not bool(click_result.get("ok", false)):
		return "screen pick right_click move command failed: %s" % str(click_result.get("message", ""))
	var reach_status := await _wait_for_player_to_reach(root, Vector2i(1, -1))
	if reach_status != "":
		return reach_status
	var settle_status := await _wait_for_move_settle(root)
	if settle_status != "":
		return settle_status
	var state := root.get_dev_agent_state()
	if _visual_coord_from_state(state) != Vector2i(1, -1):
		return "screen pick visual coord should sync after step tweens settle"
	return ""


func _assert_player_ui_panels(root: InkMonWorldHost) -> String:
	var party := root.open_player_panel("party")
	if not bool(party.get("ok", false)):
		return "opening Party panel failed"
	if not bool(root.get_dev_agent_state().get("ui_animation", {}).get("drawer_transition_active", false)):
		return "opening Party panel should start drawer transition"
	var drawer_wait := await _wait_for_ui_transition(root, "drawer_transition_active")
	if drawer_wait != "":
		return drawer_wait
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
	if not bool(root.get_dev_agent_state().get("ui_animation", {}).get("modal_transition_active", false)):
		return "opening Save/Load modal should start modal transition"
	var modal_wait := await _wait_for_ui_transition(root, "modal_transition_active")
	if modal_wait != "":
		return modal_wait
	if not bool(root.get_dev_agent_state().get("modal_open", false)):
		return "modal_open should be true"
	root.close_save_load_menu()
	await _wait_for_ui_transition(root, "modal_transition_active")
	root.close_drawer()
	await _wait_for_ui_transition(root, "drawer_transition_active")
	return ""


func _assert_move_save_load(root: InkMonWorldHost) -> String:
	root.reset_session()
	await get_tree().process_frame
	var move_result := root.goto_tile(Vector2i(-1, 1))
	if not bool(move_result.get("ok", false)):
		return "move command before save should be accepted"
	var reach_status := await _wait_for_player_to_reach(root, Vector2i(-1, 1))
	if reach_status != "":
		return reach_status
	var settle_status := await _wait_for_move_settle(root)
	if settle_status != "":
		return settle_status
	var save_path := "user://inkmon_l2_overworld_iso_save.json"
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
	if _visual_coord_from_state(root.get_dev_agent_state()) != Vector2i(-1, 1):
		return "load should restore visual overworld coord"
	return ""


func _assert_drawer_quick_toggle(root: InkMonWorldHost) -> String:
	root.reset_session()
	await get_tree().process_frame
	# C1: open a drawer then close it within the open-transition window (same frame).
	root.open_player_panel("party")
	root.close_drawer()
	var close_wait := await _wait_for_ui_transition(root, "drawer_transition_active")
	if close_wait != "":
		return close_wait
	var state := root.get_dev_agent_state()
	if state.get("drawer_mode", "x") != "":
		return "drawer_mode should be empty after quick open-then-close"
	var ui := state.get("ui_animation", {}) as Dictionary
	if bool(ui.get("drawer_visible", false)):
		return "drawer panel must hide after quick open-then-close (C1 ghost drawer)"
	if bool(ui.get("dim_visible", false)):
		return "dim overlay must hide after quick open-then-close (C1 input blackhole)"

	# C2: close a drawer then re-open within the close-transition window (same frame).
	root.open_player_panel("bag")
	var open_wait := await _wait_for_ui_transition(root, "drawer_transition_active")
	if open_wait != "":
		return open_wait
	root.close_drawer()
	root.open_player_panel("journal")
	var reopen_wait := await _wait_for_ui_transition(root, "drawer_transition_active")
	if reopen_wait != "":
		return reopen_wait
	var reopened := root.get_dev_agent_state()
	if reopened.get("drawer_mode", "") != "journal":
		return "drawer_mode should be journal after close-then-quick-reopen"
	var reopened_ui := reopened.get("ui_animation", {}) as Dictionary
	if not bool(reopened_ui.get("drawer_visible", false)):
		return "drawer must stay visible after close-then-quick-reopen (C2 ghost drawer)"
	root.close_drawer()
	await _wait_for_ui_transition(root, "drawer_transition_active")
	return ""


func _assert_overlay_layering_and_dismiss(root: InkMonWorldHost) -> String:
	# C5: toolbar (HUD) must draw above the drawer dim; the modal must draw above the HUD.
	# UI 子树 P10 移入 InkMonWorldPresentation;经 root._presentation 访问。
	var pres := root._presentation
	if pres._hud_layer.layer <= pres._panel_layer.layer:
		return "HUD layer must sit above the drawer/panel layer so the toolbar stays clickable"
	if pres._modal_layer.layer <= pres._hud_layer.layer:
		return "modal layer must sit above the HUD layer so the modal is exclusive"

	# C5: clicking the dim overlay (outside the drawer) dismisses the drawer (real mouse input).
	root.reset_session()
	var window := get_viewport() as Window
	if window != null:
		window.size = Vector2i(1280, 720)
	await get_tree().process_frame
	await get_tree().process_frame
	root.open_player_panel("party")
	var open_wait := await _wait_for_ui_transition(root, "drawer_transition_active")
	if open_wait != "":
		return open_wait
	if root.get_dev_agent_state().get("drawer_mode", "") != "party":
		return "drawer should be open before the dim-dismiss click"
	# Click a point inside the dim overlay but clear of the right-side drawer panel,
	# computed from the actual headless layout (hardcoded coords are viewport-size fragile).
	# Wave 3: drawer 下放后 smoke 不再穿透私有节点, 改走 public layout_state (dim = 全屏 = viewport rect)。
	var layout := root.get_dev_agent_layout_state()
	var viewport_rect := layout.get("viewport", {}) as Dictionary
	var panel_rect := layout.get("npc_panel", {}) as Dictionary
	var viewport_x := float(viewport_rect.get("x", 0.0))
	var panel_x := float(panel_rect.get("x", 0.0))
	var click_x := (viewport_x + panel_x) * 0.5
	if click_x >= panel_x:
		click_x = viewport_x + 4.0
	var click_pos := Vector2(click_x, float(viewport_rect.get("cy", 360.0)))
	_click_at(click_pos)
	var dismiss_wait := await _wait_for_ui_transition(root, "drawer_transition_active")
	if dismiss_wait != "":
		return dismiss_wait
	var state := root.get_dev_agent_state()
	if state.get("drawer_mode", "x") != "":
		return "clicking the dim overlay should close the drawer (drawer_mode cleared)"
	var ui := state.get("ui_animation", {}) as Dictionary
	if bool(ui.get("drawer_visible", false)) or bool(ui.get("dim_visible", false)):
		return "clicking the dim overlay should hide drawer and dim (real mouse input)"
	return ""


func _assert_load_during_move(root: InkMonWorldHost) -> String:
	# Save a known position, then load it WHILE a move tween is in flight; the stale
	# tween must not overwrite the loaded coord nor leave the move flag stuck (focus 3).
	root.reset_session()
	await get_tree().process_frame
	root.goto_tile(Vector2i(0, 1))
	var setup_reach := await _wait_for_player_to_reach(root, Vector2i(0, 1))
	if setup_reach != "":
		return "setup move before save failed: %s" % setup_reach
	var setup_settle := await _wait_for_move_settle(root)
	if setup_settle != "":
		return setup_settle
	var save_path := "user://inkmon_l2_load_during_move.json"
	var save_result := root.save_game(save_path)
	if not bool(save_result.get("ok", false)):
		return "save at known coord failed"

	root.reset_session()
	await get_tree().process_frame
	root.goto_tile(Vector2i(3, -1))
	# 等多步移动起步(玩家正逐格移动),再在半途 load。
	var started := false
	for _i in range(60):
		await get_tree().create_timer(0.05).timeout
		if bool(root.get_dev_agent_state().get("player_moving", false)):
			started = true
			break
	if not started:
		return "multi-step move should start before the mid-move load"

	var load_result := root.load_game(save_path)
	if not bool(load_result.get("ok", false)):
		return "load during move failed: %s" % str(load_result.get("message", ""))
	var after := root.get_dev_agent_state()
	if _coord_from_state(after) != Vector2i(0, 1):
		return "load during move should restore the saved coord immediately"
	if bool(after.get("player_moving", false)):
		return "load must stop in-flight movement (fresh world → player idle)"
	if _visual_coord_from_state(after) != Vector2i(0, 1):
		return "visual coord should snap to the loaded coord after load during move"
	var after_ow := after.get("overworld_iso", {}) as Dictionary
	if bool(after_ow.get("move_animation_active", false)):
		return "view tween must clear after load (not stuck)"

	# 让旧移动的残留(latest-wins/重建已结构性消灭)有时间作妖;坐标必须保持。
	await get_tree().create_timer(0.5).timeout
	var settled := root.get_dev_agent_state()
	if _coord_from_state(settled) != Vector2i(0, 1):
		return "stale movement must not overwrite the loaded coord (race regression)"
	if _visual_coord_from_state(settled) != Vector2i(0, 1):
		return "stale tween must not move the avatar after load"

	# load 后 field 输入仍可用。
	root.goto_tile(Vector2i(1, 0))
	var post_reach := await _wait_for_player_to_reach(root, Vector2i(1, 0))
	if post_reach != "":
		return "movement must work after load during move: %s" % post_reach
	return ""


func _click_at(position: Vector2) -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = position
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	viewport.push_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = position
	viewport.push_input(release)
	Input.flush_buffered_events()


func _coord_from_state(state: Dictionary) -> Vector2i:
	var coord := state.get("player_coord", {}) as Dictionary
	if coord == null:
		return Vector2i.ZERO
	return Vector2i(int(coord.get("q", 0)), int(coord.get("r", 0)))


func _visual_coord_from_state(state: Dictionary) -> Vector2i:
	var overworld := state.get("overworld_iso", {}) as Dictionary
	if overworld == null:
		return Vector2i.ZERO
	var coord := overworld.get("player_visual_coord", {}) as Dictionary
	if coord == null:
		return Vector2i.ZERO
	return Vector2i(int(coord.get("q", 0)), int(coord.get("r", 0)))


func _camera_position_from_state(state: Dictionary) -> Vector3:
	var overworld := state.get("overworld_iso", {}) as Dictionary
	if overworld == null:
		return Vector3.ZERO
	var position := overworld.get("camera_position", {}) as Dictionary
	if position == null:
		return Vector3.ZERO
	return Vector3(
		float(position.get("x", 0.0)),
		float(position.get("y", 0.0)),
		float(position.get("z", 0.0))
	)


## 等玩家 tick 逐格走到 target(逻辑 occupant 抵达)。
func _wait_for_player_to_reach(root: InkMonWorldHost, target: Vector2i) -> String:
	for _i in range(200):
		await get_tree().create_timer(0.05).timeout
		if _coord_from_state(root.get_dev_agent_state()) == target:
			return ""
	return "player did not reach target %d,%d via tick movement" % [target.x, target.y]


## 等移动完全停下(逻辑 not moving + view 补间结束)。
func _wait_for_move_settle(root: InkMonWorldHost) -> String:
	for _i in range(200):
		await get_tree().create_timer(0.05).timeout
		var state := root.get_dev_agent_state()
		var overworld := state.get("overworld_iso", {}) as Dictionary
		if not bool(state.get("player_moving", false)) and not bool(overworld.get("move_animation_active", false)):
			return ""
	return "movement did not settle (player still moving or view tween running)"


## 等移动先起步(player_moving 变 true)再停稳;用于 retarget 类(终点未知)。
func _wait_for_move_to_start_then_settle(root: InkMonWorldHost) -> String:
	var started := false
	for _i in range(60):
		await get_tree().create_timer(0.05).timeout
		if bool(root.get_dev_agent_state().get("player_moving", false)):
			started = true
			break
	if not started:
		return "move did not start after enqueue"
	return await _wait_for_move_settle(root)


func _wait_for_ui_transition(root: InkMonWorldHost, key: String) -> String:
	for _i in range(30):
		await get_tree().create_timer(0.03).timeout
		var ui_animation := root.get_dev_agent_state().get("ui_animation", {}) as Dictionary
		if ui_animation != null and not bool(ui_animation.get(key, false)):
			return ""
	return "%s did not finish" % key


func _axial_distance(a: Vector2i, b: Vector2i) -> int:
	var dq := a.x - b.x
	var dr := a.y - b.y
	return int((abs(dq) + abs(dq + dr) + abs(dr)) / 2)


func _cleanup(root: InkMonWorldHost, status: String) -> String:
	root.queue_free()
	GameWorld.shutdown()
	return status
