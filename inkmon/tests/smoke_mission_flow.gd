extends Node
## 出征 flow GI 级契约 (P1/P2, glossary §4.8):
##   start guard(重复/战斗中拒) / command 通道步进 / 非法移动拒 / 沿图走到目标自动结算(两出口之"完成") /
##   奖励落活 actor / 每步扣粮 / 持久点亮 / mission_ended 恰好一次。


const FIXED_DT := 1.0 / 30.0


var _ended_results: Array[Dictionary] = []


func _ready() -> void:
	var status := _run()
	if status == "":
		print("SMOKE_TEST_RESULT: PASS - mission flow: start guards + command stepping + auto-complete settle + supplies + reveal")
		get_tree().quit(0)
	else:
		print("SMOKE_TEST_RESULT: FAIL - %s" % status)
		get_tree().quit(1)


func _run() -> String:
	GameWorld.init(EventProcessorConfig.new(20, 1))
	TimelineRegistry.reset()
	var gi := _new_gi()
	gi.new_game()
	gi.mission_ended.connect(_on_mission_ended)

	var start_result := gi.start_mission({"seed": 777, "supplies": 40})
	if not bool(start_result.get("ok", false)):
		return _fail("start_mission should succeed: %s" % str(start_result.get("message", "")))
	if not gi.has_active_mission():
		return _fail("mission should be active after start")
	if bool(gi.start_mission({"seed": 778}).get("ok", false)):
		return _fail("second start_mission must be rejected while active")
	var state := gi.mission_state
	if state.current_node_id != state.map.entry_node_id:
		return _fail("mission should start at entry node")
	if not gi.world_map.is_revealed(gi.world_map.entry_coord):
		return _fail("entry cell should be revealed on departure")

	# 非法移动(目标节点不与起点相邻)必须被拒。
	gi.submit(InkMonMissionMoveCommand.new(state.map.target_node_id))
	_drain(gi)
	if state.current_node_id != state.map.entry_node_id:
		return _fail("illegal (non-adjacent) move must be rejected")

	# 沿图走到目标: 每步走第一条出边, 抵达目标自动结算。
	# M2.2 后踩上野群节点 = 必战锁住选路 —— 走图 harness 遇战即打 (秒杀野群) 再继续。
	var gold_before := gi.player_actor.gold
	var supplies_before := state.supplies
	var steps := 0
	while gi.has_active_mission() and steps < 32:
		var nexts := gi.mission_state.map.next_node_ids(gi.mission_state.current_node_id)
		if nexts.is_empty():
			return _fail("non-target node with no outgoing edges")
		gi.submit(InkMonMissionMoveCommand.new(nexts[0]))
		_drain(gi)
		steps += 1
		if gi.has_active_mission() and gi.mission_state.has_pending_battle():
			var battle_status := _resolve_wild_battle(gi)
			if battle_status != "":
				return _fail(battle_status)
	if gi.has_active_mission():
		return _fail("mission should auto-complete within 32 steps")
	if _ended_results.size() != 1:
		return _fail("mission_ended should fire exactly once (got %d)" % _ended_results.size())
	var result := _ended_results[0]
	if str(result.get("outcome", "")) != "complete":
		return _fail("outcome should be complete, got %s" % str(result.get("outcome", "")))
	# Phase 3 后结算 = 主委托 (占位 = MISSION_COMPLETE_GOLD) + 达标副委托 bonus:
	# 按结算摘要对账落金, 且主委托兜底额必达。
	var reported_reward := int(result.get("gold_reward", -999))
	if reported_reward < InkMonMissionSetup.MISSION_COMPLETE_GOLD:
		return _fail("settle must pay at least the main quest reward (got %d)" % reported_reward)
	if gi.player_actor.gold != gold_before + reported_reward:
		return _fail("settled gold must match the reported reward (%d != %d + %d)" % [
			gi.player_actor.gold, gold_before, reported_reward])
	if int(result.get("supplies_left", -999)) != supplies_before - steps:
		return _fail("supplies should decrease by exactly 1 per step (%d - %d != %d)"
			% [supplies_before, steps, int(result.get("supplies_left", -999))])

	# 战斗中禁出征。
	gi.request_training_battle()
	if not gi.has_active_battle():
		return _fail("training battle should be active for the guard check")
	if bool(gi.start_mission({}).get("ok", false)):
		return _fail("start_mission during battle must be rejected")
	GameWorld.shutdown()
	return ""


func _drain(gi: InkMonWorldGI) -> void:
	gi.tick(FIXED_DT)


## 遇战即打 (走图 harness): 起野群战斗 → 秒杀右队 → tick 至收尾 → 不捕直接离场 (resolve)。
## M2.3 后胜局锁保持到离场 —— resolve 即"离开战场", 解锁走图继续。
func _resolve_wild_battle(gi: InkMonWorldGI) -> String:
	gi.request_wild_battle()
	if not gi.has_active_battle():
		return "wild battle should start on a pending battle node"
	for wild_actor in gi.right_team:
		wild_actor.set_current_hp(0.0)
	var guard := 0
	while gi.has_active_battle() and guard < 20:
		gi.tick(FIXED_DT)
		guard += 1
	if gi.has_active_battle():
		return "wild battle should finish after right team is downed"
	gi.resolve_wild_battle_encounter()
	if gi.has_active_mission() and gi.mission_state.has_pending_battle():
		return "pending battle lock should clear after leaving the encounter"
	return ""


func _on_mission_ended(result: Dictionary) -> void:
	_ended_results.append(result)


func _fail(message: String) -> String:
	GameWorld.shutdown()
	return message


func _new_gi() -> InkMonWorldGI:
	return GameWorld.create_instance(func() -> GameplayInstance:
		return InkMonWorldGI.new()
	) as InkMonWorldGI
