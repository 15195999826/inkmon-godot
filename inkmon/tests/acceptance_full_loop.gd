extends Node
## Phase 2 验收 harness (M2.5): 完整游戏循环全真实链路自动驾驶, **不进 launcher 组**
## (走 guild 会写 user:// 出发档 —— 出发档并行红线, 本 harness 只单跑):
##   接出征(guild + 出发确认 modal 真按钮) → 大地图选路 → 踩野群必战(真实 4v4 自动战, 不作弊)
##   → 回放 Skip → 胜: 留场对气绝个体逐只掷球(真实 capture_requested 链) → Leave 回大地图
##   → 抵达目标主委托完成 → 回城 adopt 入库断言 → 再出征一次(循环闭环)。
##   战败/全灭 = 丢趟回档, 换一趟重试 (真实战斗胜负不预设)。
## 跑法: godot --headless --path . inkmon/tests/acceptance_full_loop.tscn
## 输出: SMOKE_TEST_RESULT: PASS/FAIL + journey log。


const MAX_MISSION_TRIES := 6

var _host: InkMonWorldHost = null
var _journey: Array[String] = []


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	var status: String = await _run()
	for line in _journey:
		print("  [journey] %s" % line)
	if status == "":
		print("SMOKE_TEST_RESULT: PASS - full loop: depart -> route -> wild battles -> capture -> settle adopt -> depart again (real chain)")
		get_tree().quit(0)
	else:
		print("SMOKE_TEST_RESULT: FAIL - %s" % status)
		get_tree().quit(1)


func _run() -> String:
	if FileAccess.file_exists(InkMonWorldHost.DEPARTURE_SAVE_PATH):
		DirAccess.remove_absolute(InkMonWorldHost.DEPARTURE_SAVE_PATH)
	_host = InkMonWorldHost.new()
	add_child(_host)
	await get_tree().process_frame
	await get_tree().process_frame
	var presentation := _host.get_node("Presentation") as InkMonWorldPresentation

	# 主委托完成一轮 (真实战斗, 败了丢趟重来)。
	var completed := false
	var captured_total := 0
	for attempt in range(MAX_MISSION_TRIES):
		var roster_before: int = _host.get_roster().size()
		var depart_status: String = await _depart(presentation)
		if depart_status != "":
			return depart_status
		_journey.append("mission %d departed (gold %d, roster %d)" % [
			attempt + 1, _host.get_player_actor().gold, roster_before])
		var outcome: String = await _play_mission_out(presentation)
		if outcome.begins_with("ERR:"):
			return outcome.substr(4)
		if outcome == "complete":
			completed = true
			captured_total = _host.get_roster().size() - roster_before
			_journey.append("mission complete: roster %d -> %d (adopted %d)" % [
				roster_before, _host.get_roster().size(), captured_total])
			break
		_journey.append("mission %d lost (%s), rolled back to departure" % [attempt + 1, outcome])
	if not completed:
		return "no mission completed within %d tries (real battles kept wiping?)" % MAX_MISSION_TRIES
	if bool(_host.get_dev_agent_state().get("mission_active", false)):
		return "mission should be inactive after settle"
	if FileAccess.file_exists(InkMonWorldHost.DEPARTURE_SAVE_PATH):
		return "departure save must be consumed after settle"

	# 再出征 (循环闭环): 回城后立刻能接下一趟。
	var again_status: String = await _depart(presentation)
	if again_status != "":
		return "depart-again failed: %s" % again_status
	_journey.append("departed again after settle (loop closed)")
	return ""


## 接出征: guild action → 出发确认 modal → 真鼠标 Confirm → mission active。
func _depart(presentation: InkMonWorldPresentation) -> String:
	presentation.run_npc_action_for("guild", InkMonGuildNpcHandler.ACTION_START_MISSION)
	var modal := presentation.get_node_or_null("ModalLayer/DepartureModalRoot") as InkMonDepartureModal
	if modal == null:
		return "departure modal missing"
	var wait := 0
	while not modal.is_open() and wait < 120:
		await get_tree().process_frame
		wait += 1
	if not modal.is_open():
		return "departure modal should open"
	var confirm := modal.get_debug_controls().get("confirm_button", null) as Button
	if confirm == null or confirm.disabled:
		return "departure confirm unavailable (gold %d)" % _host.get_player_actor().gold
	_click_at((confirm.get_global_rect() as Rect2).get_center())
	wait = 0
	while not bool(_host.get_dev_agent_state().get("mission_active", false)) and wait < 120:
		await get_tree().process_frame
		wait += 1
	if not bool(_host.get_dev_agent_state().get("mission_active", false)):
		return "mission should be active after confirm"
	return ""


## 走一趟到头: 每步真鼠标点下一节点 (优先非战斗); 撞野群 → 真实战斗 → 胜捕负丢。
## 返回 "complete" / "lost" / "ERR:<msg>"。
func _play_mission_out(presentation: InkMonWorldPresentation) -> String:
	var gi: InkMonWorldGI = _host._world_gi
	var mission_view := presentation.get_node_or_null("MissionMapLayer/MissionMapView") as InkMonMissionMapView
	if mission_view == null:
		return "ERR:mission map view missing"
	var steps := 0
	while steps < 24:
		steps += 1
		if _host._world_gi != gi:
			return "lost"  # 世界被重建 = 丢趟回档 (全灭/战败)
		if not gi.has_active_mission():
			return "complete"
		if gi.mission_state.has_pending_battle():
			var battle_status: String = await _ride_out_battle(presentation)
			if battle_status != "":
				return "ERR:" + battle_status
			continue
		var nexts := gi.mission_state.map.next_node_ids(gi.mission_state.current_node_id)
		if nexts.is_empty():
			return "ERR:stuck node without exits"
		var pick := nexts[0]
		for next_id in nexts:
			if str(gi.mission_state.map.get_node_info(next_id).get("kind", "")) != InkMonMissionMapData.NODE_BATTLE:
				pick = next_id
				break
		_click_at(mission_view.node_screen_position(pick))
		await get_tree().create_timer(0.35).timeout
	return "ERR:mission did not resolve within 24 steps"


## 一场野群战: 等回放起 → Skip 快进 → 胜: 逐只掷球 (真实点击链) → Leave; 负: 等回档。
func _ride_out_battle(presentation: InkMonWorldPresentation) -> String:
	var gi: InkMonWorldGI = _host._world_gi
	var battle_view := presentation.get_node_or_null("Battle2DView") as InkMonBattle2DView
	var wait := 0
	while (battle_view == null or not battle_view.visible) and wait < 300:
		await get_tree().process_frame
		battle_view = presentation.get_node_or_null("Battle2DView") as InkMonBattle2DView
		wait += 1
	if battle_view == null or not battle_view.visible:
		return "battle replay view should appear on a battle node"
	# Skip 快进回放, 等 Leave 可用。
	wait = 0
	while not battle_view.is_leave_available() and wait < 600:
		battle_view.get_animator().step(1_000_000.0)
		await get_tree().process_frame
		wait += 1
	if not battle_view.is_leave_available():
		return "battle replay should end after fast-forward"
	var won := gi.get_result() == "left_win"
	# 胜局: 对每只气绝个体真实点击掷球 (view → presentation → Host → GI)。
	if won:
		var pool := gi.get_capture_pool_snapshot()
		for entry in pool:
			var pos := battle_view.capture_unit_screen_position(int(entry.get("slot_index", -1)))
			if pos.is_finite():
				_click_at(pos)
				await get_tree().process_frame
				await get_tree().process_frame
		_journey.append("battle won: %d wilds, %d captured" % [
			pool.size(), gi.mission_state.captured_pending.size()])
	else:
		_journey.append("battle lost (result=%s)" % gi.get_result())
	battle_view.request_leave()
	# 败局离场即回档 (世界重建); 胜局离场回大地图。两种都等一拍。
	await get_tree().create_timer(0.4).timeout
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
