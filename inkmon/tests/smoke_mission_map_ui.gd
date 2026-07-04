extends Node
## 出征大地图 UI 交互 smoke (real mouse input):
##   mission view 顶上(overworld 隐) → 真鼠标点击可达节点 = 前进一步 + 扣粮; 点不可达节点 = 不动。
## 出征起动走 **GI 直调 + seed 定死** (纯函数预探 seed, 首步必有非战斗节点):
##   guild 全链会写 user:// 出发档 —— 那是 launcher 并行下与 smoke_mission_departure 互踩的
##   共享文件 (红线: 出发档生命周期只归 departure smoke 串行独占), 本 smoke 绝不触碰。
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
	# 下一节点。节点 kind 序列只由 mission seed 决定 (与世界地理无关): 纯函数预探出
	# "首层有非战斗节点"的 seed, 一次起准, 全程无 guild 流/无出发档写入/无 end_mission。
	var gi: InkMonWorldGI = _host._world_gi
	var probe_bounds := Rect2i(0, 0, gi.world_map.width, gi.world_map.height)
	var probe_target := gi.world_map.get_target_candidates()[0]
	var chosen_seed := -1
	for seed_value in range(5000, 5050):
		var probe := InkMonMissionMapGen.generate(seed_value, gi.world_map.entry_coord, probe_target, probe_bounds)
		for next_id in probe.next_node_ids(probe.entry_node_id):
			if str(probe.get_node_info(next_id).get("kind", "")) != InkMonMissionMapData.NODE_BATTLE:
				chosen_seed = seed_value
				break
		if chosen_seed >= 0:
			break
	if chosen_seed < 0:
		return "no seed in 5000..5049 with a non-battle first step (gen constants drifted?)"
	if not bool(gi.start_mission({"seed": chosen_seed}).get("ok", false)):
		return "start_mission should succeed"
	# GI 直起时 Host flow 不在场, 手动推表演的出征态 (Host._begin_mission_flow 同款调用)。
	presentation.set_mission_active(true)
	var safe_next_id := -1
	for next_id in gi.mission_state.map.next_node_ids(gi.mission_state.current_node_id):
		if str(gi.mission_state.map.get_node_info(next_id).get("kind", "")) != InkMonMissionMapData.NODE_BATTLE:
			safe_next_id = next_id
			break
	if safe_next_id < 0:
		return "probed seed must yield a non-battle first step"
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
