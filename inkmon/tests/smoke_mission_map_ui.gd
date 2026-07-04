extends Node
## 出征大地图 UI 交互 smoke (real mouse input):
##   Host 全链 → guild 出征 → mission view 顶上(overworld 隐) →
##   真鼠标点击可达节点 = 前进一步 + 扣粮; 点不可达节点 = 不动。
## UI 交互 smoke 约定: _ready 首行 ensure window size(headless 默认 64×64 点击全落空);
## PASS 输出带 "(real mouse input)" 标记。


var _host: InkMonWorldHost = null


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	var status: String = await _run()
	if status == "":
		print("SMOKE_TEST_RESULT: PASS - mission map view: click reachable node advances, unreachable ignored (real mouse input)")
		get_tree().quit(0)
	else:
		print("SMOKE_TEST_RESULT: FAIL - %s" % status)
		get_tree().quit(1)


func _run() -> String:
	_host = InkMonWorldHost.new()
	add_child(_host)
	await get_tree().process_frame
	await get_tree().process_frame
	var presentation := _host.get_node("Presentation") as InkMonWorldPresentation
	if presentation == null:
		return "presentation not found"

	# M2.2 后踩野群节点必战 (会切进战斗回放) —— 本 smoke 只验选路交互, 点击目标选**非战斗**
	# 下一节点; 出征地图随机 (guild 路径无 seed), 首层全是战斗节点时放弃重开 (期望 ~1.1 次)。
	var gi: InkMonWorldGI = null
	var safe_next_id := -1
	for _attempt in range(10):
		presentation.run_npc_action_for("guild", InkMonGuildNpcHandler.ACTION_START_MISSION)
		await get_tree().create_timer(0.5).timeout
		if not bool(_host.get_dev_agent_state().get("mission_active", false)):
			return "mission should be active after guild intent"
		gi = _host._world_gi
		var candidate_ids := gi.mission_state.map.next_node_ids(gi.mission_state.current_node_id)
		if candidate_ids.is_empty():
			return "entry node should have reachable next nodes"
		for next_id in candidate_ids:
			if str(gi.mission_state.map.get_node_info(next_id).get("kind", "")) != InkMonMissionMapData.NODE_BATTLE:
				safe_next_id = next_id
				break
		if safe_next_id >= 0:
			break
		_host.abandon_mission()
		await get_tree().process_frame
	if safe_next_id < 0:
		return "no non-battle first step across 10 mission rolls (gen constants drifted?)"
	var mission_view := presentation.get_node_or_null("MissionMapLayer/MissionMapView") as InkMonMissionMapView
	if mission_view == null or not mission_view.visible:
		return "mission map view should be visible during mission"
	var world_view := presentation.get_node_or_null("WorldLayer") as Node2D
	if world_view != null and world_view.visible:
		return "overworld view should be hidden during mission"

	# smoke 是 harness, 直读逻辑真相(GI)拿节点/坐标; 玩家路径仍走真鼠标 → view → command。
	var before_supplies := gi.mission_state.supplies

	_click_at(mission_view.node_screen_position(safe_next_id))
	await get_tree().create_timer(0.4).timeout
	if gi.mission_state == null:
		return "mission should still be active after one step"
	if gi.mission_state.current_node_id != safe_next_id:
		return "click on reachable node should advance current node"
	if gi.mission_state.supplies != before_supplies - 1:
		return "one step should cost exactly 1 supply"

	# 点不可达节点(目标节点距当前还有多层)必须不动。
	var node_before := gi.mission_state.current_node_id
	_click_at(mission_view.node_screen_position(gi.mission_state.map.target_node_id))
	await get_tree().create_timer(0.3).timeout
	if gi.mission_state == null or gi.mission_state.current_node_id != node_before:
		return "click on unreachable node must not move"
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
