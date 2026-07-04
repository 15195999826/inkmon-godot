extends Node
## Phase 3 委托系统 GI 级契约 (不碰 user://, 可并行):
##   板生成域 (3-5 张 / 同 seed 确定 / type 域 / 目标是真地标 / 奖励域) + 进档 roundtrip /
##   接单出征 (摘单 + 主委托定目标 + hunt 型目标节点带野群把守) / reach 完成结算发奖 + 板回城刷新 /
##   hunt 完成 = 清掉把守野群离场即结算 / 副委托计数 (战胜/捕获) 与达标发奖 / 无单出征占位兼容。


const FIXED_DT := 1.0 / 30.0


func _ready() -> void:
	var status := _run()
	if status == "":
		print("SMOKE_TEST_RESULT: PASS - quest board: gen domain + save roundtrip + take-quest missions + reach/hunt completion + side quest counting")
		get_tree().quit(0)
	else:
		print("SMOKE_TEST_RESULT: FAIL - %s" % status)
		get_tree().quit(1)


func _run() -> String:
	GameWorld.init(EventProcessorConfig.new(20, 1))
	TimelineRegistry.reset()
	var gi := _new_gi()
	gi.new_game()

	# === 板生成域 + 确定性 ===
	if gi.quest_board.is_empty():
		return _fail("new game must roll a quest board")
	var board_a := InkMonQuestGen.roll_board(gi.world_map, 999)
	var board_b := InkMonQuestGen.roll_board(gi.world_map, 999)
	if board_a.size() != board_b.size():
		return _fail("same seed must roll the same board size")
	if board_a.size() < InkMonQuestGen.BOARD_MIN or board_a.size() > InkMonQuestGen.BOARD_MAX:
		return _fail("board size must stay in 3..5 (got %d)" % board_a.size())
	var site_ids: Array[String] = []
	for landmark in gi.world_map.landmarks:
		site_ids.append(str(landmark.get("id", "")))
	for i in range(board_a.size()):
		var def := board_a[i]
		if JSON.stringify(def.to_dict()) != JSON.stringify(board_b[i].to_dict()):
			return _fail("same seed must roll identical quests (index %d)" % i)
		if def.type != InkMonQuestDef.TYPE_REACH and def.type != InkMonQuestDef.TYPE_HUNT:
			return _fail("board quest type out of domain: %s" % def.type)
		if not site_ids.has(def.target_site_id):
			return _fail("board quest must target a real landmark (got %s)" % def.target_site_id)
		if def.reward_gold <= 0:
			return _fail("board quest must pay gold")
	var side_quests := InkMonQuestGen.roll_side_quests(4242)
	if side_quests.is_empty() or side_quests.size() > InkMonQuestGen.SIDE_QUEST_MAX:
		return _fail("side quest count must stay in 1..%d" % InkMonQuestGen.SIDE_QUEST_MAX)
	for side in side_quests:
		if not side.is_side_type() or side.goal_count <= 0:
			return _fail("side quest must be a counting type with a positive goal")

	# === 进档 roundtrip ===
	gi.quest_board = board_a.duplicate()
	var save_data := gi.to_dict()
	var gi2 := _new_gi()
	if not gi2.from_dict(save_data):
		return _fail("save with quest board must load back")
	if gi2.quest_board.size() != board_a.size():
		return _fail("quest board must survive save/load")
	for i in range(board_a.size()):
		if JSON.stringify(gi2.quest_board[i].to_dict()) != JSON.stringify(board_a[i].to_dict()):
			return _fail("quest board roundtrip must be lossless (index %d)" % i)

	# === 读档物品预检覆盖委托板: 奖励物品 id 已不被 catalog 识别 → 按世代不符丢弃重开 ===
	var drifted_save := gi2.to_dict()
	(drifted_save.get("quest_board", []) as Array).append({
		"quest_id": "drifted", "type": "reach", "target_site_id": "site_1",
		"reward_gold": 10, "reward_item_id": "item_9999", "goal_count": 0,
	})
	var gi3 := _new_gi()
	if gi3.from_dict(drifted_save):
		return _fail("save referencing an unknown quest reward item must be discarded")

	# === reach 接单出征: 摘单 + 目标锚定 + 完成结算发奖 + 板刷新 ===
	var reach_quest := _find_quest_of_type(gi2, InkMonQuestDef.TYPE_REACH)
	if reach_quest == null:
		return _fail("board seeds should include a reach quest")
	var board_before := gi2.quest_board.size()
	var gold_before := gi2.player_actor.gold
	if not bool(gi2.start_mission({"seed": 6001, "supplies": 40, "quest_id": reach_quest.quest_id}).get("ok", false)):
		return _fail("take-quest start_mission should succeed")
	if gi2.quest_board.size() != board_before - 1:
		return _fail("taking a quest must remove it from the board")
	if gi2.mission_state.target_site_coord != gi2.world_map.landmark_coord(reach_quest.target_site_id):
		return _fail("main quest must anchor the mission target site")
	var main_entry := gi2.mission_state.quests[0] as Dictionary
	if str(main_entry.get("role", "")) != "main" or (main_entry.get("def", null) as InkMonQuestDef).quest_id != reach_quest.quest_id:
		return _fail("taken quest must ride as the main quest")
	if gi2.mission_state.quests.size() - 1 > InkMonQuestGen.SIDE_QUEST_MAX:
		return _fail("side quests must stay within the cap")
	# reach 型: 全图节点无把守 target (target 层无 payload); 走到目标自动结算。
	var reach_target_info := gi2.mission_state.map.get_node_info(gi2.mission_state.map.target_node_id)
	if not (reach_target_info.get("wild", []) as Array).is_empty():
		return _fail("reach quest target must not be guarded")
	var walk_status := _walk_to_completion(gi2)
	if walk_status != "":
		return _fail(walk_status)
	if gi2.has_active_mission():
		return _fail("reach mission should settle on arrival")
	if gi2.player_actor.gold < gold_before + reach_quest.reward_gold:
		return _fail("main quest reward must land on settle (%d < %d + %d)" % [
			gi2.player_actor.gold, gold_before, reach_quest.reward_gold])
	if gi2.quest_board.size() < InkMonQuestGen.BOARD_MIN:
		return _fail("board must refresh to a full batch on settle")

	# === hunt 接单出征: 目标节点带野群把守, 清掉离场即完成 ===
	var hunt_quest := _find_quest_of_type(gi2, InkMonQuestDef.TYPE_HUNT)
	if hunt_quest == null:
		# 刷新板可能没 roll 出 hunt: 注入一张固定 hunt 单 (harness 直捣真相层)。
		hunt_quest = InkMonQuestDef.new()
		hunt_quest.quest_id = "hunt_fixture"
		hunt_quest.type = InkMonQuestDef.TYPE_HUNT
		hunt_quest.target_site_id = site_ids[0]
		hunt_quest.reward_gold = 70
		gi2.quest_board.append(hunt_quest)
	if not bool(gi2.start_mission({"seed": 6002, "supplies": 40, "quest_id": hunt_quest.quest_id}).get("ok", false)):
		return _fail("hunt start_mission should succeed")
	var hunt_target_info := gi2.mission_state.map.get_node_info(gi2.mission_state.map.target_node_id)
	if (hunt_target_info.get("wild", []) as Array).is_empty():
		return _fail("hunt quest target must be guarded by wilds")
	var hunt_walk := _walk_to_completion(gi2)
	if hunt_walk != "":
		return _fail(hunt_walk)
	if gi2.has_active_mission():
		return _fail("hunt mission should settle after clearing the guarded target")

	# === 副委托计数 + 达标发奖 ===
	if not bool(gi2.start_mission({"seed": 6003, "supplies": 40}).get("ok", false)):
		return _fail("side-count mission should start")
	var state := gi2.mission_state
	var hunt_count_before := _side_progress(state, InkMonQuestDef.TYPE_HUNT_COUNT)
	var capture_count_before := _side_progress(state, InkMonQuestDef.TYPE_CAPTURE_COUNT)
	InkMonMissionSetup.record_mission_event(state, InkMonQuestDef.TYPE_HUNT_COUNT)
	InkMonMissionSetup.record_mission_event(state, InkMonQuestDef.TYPE_CAPTURE_COUNT)
	if _side_progress(state, InkMonQuestDef.TYPE_HUNT_COUNT) != hunt_count_before + (1 if _has_side(state, InkMonQuestDef.TYPE_HUNT_COUNT) else 0):
		return _fail("hunt_count progress must advance on wild battle win")
	if _side_progress(state, InkMonQuestDef.TYPE_CAPTURE_COUNT) != capture_count_before + (1 if _has_side(state, InkMonQuestDef.TYPE_CAPTURE_COUNT) else 0):
		return _fail("capture_count progress must advance on capture")
	# 达标发奖判定: 注入一张已达标副委托 + 一张未达标, settle 只发达标者。
	var fulfilled_side := InkMonQuestDef.new()
	fulfilled_side.quest_id = "side_fixture_done"
	fulfilled_side.type = InkMonQuestDef.TYPE_HUNT_COUNT
	fulfilled_side.goal_count = 1
	fulfilled_side.reward_gold = 33
	var unfulfilled_side := InkMonQuestDef.new()
	unfulfilled_side.quest_id = "side_fixture_miss"
	unfulfilled_side.type = InkMonQuestDef.TYPE_CAPTURE_COUNT
	unfulfilled_side.goal_count = 99
	unfulfilled_side.reward_gold = 55
	state.quests = [state.quests[0],
		{"def": fulfilled_side, "role": "side", "progress": 1},
		{"def": unfulfilled_side, "role": "side", "progress": 0}]
	var main_def := (state.quests[0] as Dictionary).get("def", null) as InkMonQuestDef
	var gold_before_settle := gi2.player_actor.gold
	var settle_result := InkMonMissionSetup.settle_complete(gi2)
	gi2.end_mission("aborted")  # settle 直调后收掉出征态 (harness 捷径)
	var expected_reward := main_def.reward_gold + fulfilled_side.reward_gold
	if int(settle_result.get("gold_reward", -1)) != expected_reward:
		return _fail("settle must pay main + fulfilled side only (%d != %d)" % [
			int(settle_result.get("gold_reward", -1)), expected_reward])
	if gi2.player_actor.gold != gold_before_settle + expected_reward:
		return _fail("quest rewards must land on player gold")

	# === 无单出征占位兼容: 板不动 ===
	var board_size := gi2.quest_board.size()
	if not bool(gi2.start_mission({"seed": 6004, "supplies": 40}).get("ok", false)):
		return _fail("questless start_mission should still work")
	if gi2.quest_board.size() != board_size:
		return _fail("questless mission must not touch the board")
	if (gi2.mission_state.quests[0].get("def", null) as InkMonQuestDef).quest_id != "placeholder":
		return _fail("questless mission should carry the placeholder main quest")
	GameWorld.shutdown()
	return ""


## 沿图走到出征结束 (遇战秒杀 + 不捕离场; 对齐 smoke_mission_flow 的 harness 走法)。
func _walk_to_completion(gi: InkMonWorldGI) -> String:
	var steps := 0
	while gi.has_active_mission() and steps < 32:
		if gi.mission_state.has_pending_battle():
			gi.request_wild_battle()
			for wild_actor in gi.right_team:
				wild_actor.set_current_hp(0.0)
			var guard := 0
			while gi.has_active_battle() and guard < 20:
				gi.tick(FIXED_DT)
				guard += 1
			if gi.has_active_battle():
				return "wild battle should finish during quest walk"
			gi.resolve_wild_battle_encounter()
			continue
		var nexts := gi.mission_state.map.next_node_ids(gi.mission_state.current_node_id)
		if nexts.is_empty():
			return "non-target node with no outgoing edges during quest walk"
		gi.submit(InkMonMissionMoveCommand.new(nexts[0]))
		gi.tick(FIXED_DT)
		steps += 1
	if gi.has_active_mission():
		return "quest mission should resolve within 32 steps"
	return ""


func _find_quest_of_type(gi: InkMonWorldGI, quest_type: String) -> InkMonQuestDef:
	for quest in gi.quest_board:
		if quest.type == quest_type:
			return quest
	return null


func _side_progress(state: InkMonMissionState, quest_type: String) -> int:
	for quest_entry in state.quests:
		var def := quest_entry.get("def", null) as InkMonQuestDef
		if def != null and def.type == quest_type:
			return int(quest_entry.get("progress", 0))
	return 0


func _has_side(state: InkMonMissionState, quest_type: String) -> bool:
	for quest_entry in state.quests:
		var def := quest_entry.get("def", null) as InkMonQuestDef
		if def != null and def.type == quest_type:
			return true
	return false


func _fail(message: String) -> String:
	GameWorld.shutdown()
	return message


func _new_gi() -> InkMonWorldGI:
	return GameWorld.create_instance(func() -> GameplayInstance:
		return InkMonWorldGI.new()
	) as InkMonWorldGI
