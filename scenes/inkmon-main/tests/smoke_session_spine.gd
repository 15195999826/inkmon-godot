extends Node


func _ready() -> void:
	var status := _run()
	if status == "":
		print("SMOKE_TEST_RESULT: PASS - InkMon session spine round-tripped and battle snapshot injection worked")
		get_tree().quit(0)
	else:
		print("SMOKE_TEST_RESULT: FAIL - %s" % status)
		get_tree().quit(1)


func _run() -> String:
	var session := InkMonGameSession.new()
	session.begin_new_game()

	var data_status := _assert_session_round_trip(session)
	if data_status != "":
		return data_status

	var projection_status := _assert_projection_is_deterministic(session)
	if projection_status != "":
		return projection_status

	var battle_status := _assert_battle_snapshot_injection(session)
	if battle_status != "":
		return battle_status

	return ""


func _assert_session_round_trip(session: InkMonGameSession) -> String:
	if session.player_state.roster.size() != 4:
		return "new game roster should seed 4 InkMon"
	if session.get_container_id(InkMonGameSession.BAG_CONTAINER) <= 0:
		return "bag container not registered"

	var create_result := session.create_bag_item(InkMonItemCatalog.MINOR_RUNE, 3, 0)
	if not create_result.success:
		return "failed to create bag item: %s" % create_result.error_message

	var before := session.to_dict()
	if _has_key_recursive(before, "container_id") or _has_key_recursive(before, "item_id"):
		return "save data leaked runtime item/container ids"

	var loaded := InkMonGameSession.new()
	loaded.from_dict(before)
	var after := loaded.to_dict()
	if JSON.stringify(before) != JSON.stringify(after):
		return "session save/load is not idempotent\nbefore=%s\nafter=%s" % [JSON.stringify(before), JSON.stringify(after)]
	return ""


func _assert_projection_is_deterministic(session: InkMonGameSession) -> String:
	var entry := session.player_state.roster[0]
	var first := entry.project_to_battle_snapshot()
	var second := entry.project_to_battle_snapshot()
	if JSON.stringify(first) != JSON.stringify(second):
		return "roster projection is not deterministic"
	var stats := first.get("battle_stats", {}) as Dictionary
	if stats == null or not stats.has("max_hp") or stats.has("hp"):
		return "battle snapshot should contain max_hp and not persist hp"
	return ""


func _assert_battle_snapshot_injection(session: InkMonGameSession) -> String:
	GameWorld.init(EventProcessorConfig.new(20, 1))
	TimelineRegistry.reset()

	var left_snapshots := session.project_player_battle_roster(4)
	left_snapshots[0] = left_snapshots[0].duplicate(true)
	var tuned_stats := (left_snapshots[0]["battle_stats"] as Dictionary).duplicate(true)
	tuned_stats["max_hp"] = 777.0
	tuned_stats["ad"] = 180.0
	tuned_stats["ap"] = 180.0
	tuned_stats["armor"] = 90.0
	tuned_stats["mr"] = 90.0
	tuned_stats["speed"] = 140.0
	left_snapshots[0]["battle_stats"] = tuned_stats

	var right_snapshots := _build_weak_enemy_snapshots()
	var battle := GameWorld.create_instance(func() -> GameplayInstance:
		return InkMonBattleWorldGI.new()
	) as InkMonBattleWorldGI
	if battle == null:
		return "failed to create battle instance"

	battle.start({
		"recording": false,
		"left_roster_snapshots": left_snapshots,
		"right_roster_snapshots": right_snapshots,
	})

	var actor := battle.left_team[0]
	if absf(actor.attribute_set.max_hp - 777.0) > 0.01:
		return _shutdown_with_status("snapshot max_hp did not inject into actor")
	if absf(actor.attribute_set.hp - 777.0) > 0.01:
		return _shutdown_with_status("snapshot actor hp should start at max_hp")
	if actor.source_entry_id != int(left_snapshots[0]["source_entry_id"]):
		return _shutdown_with_status("actor lost source_entry_id")

	GameWorld.tick_all(BattleProcedure.DEFAULT_TICK_INTERVAL)
	if battle.has_active_battle():
		return _shutdown_with_status("snapshot battle did not finish in one world tick")

	var result := battle.get_result_summary()
	if result.get("winner_team", "") != "left":
		return _shutdown_with_status("snapshot battle expected left winner, got %s" % str(result.get("winner_team", "")))
	for source_entry_id in result.get("survivors", []):
		if session.player_state.get_roster_entry(int(source_entry_id)) == null:
			return _shutdown_with_status("result source_entry_id did not map to player roster")

	var gold_before := session.player_state.gold
	session.player_state.apply_battle_result(result)
	if session.player_state.gold <= gold_before:
		return _shutdown_with_status("battle result did not award gold")

	GameWorld.shutdown()
	return ""


func _build_weak_enemy_snapshots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var skills := [
		InkMonStun.CONFIG_ID,
		InkMonFireball.CONFIG_ID,
		InkMonHolyHeal.CONFIG_ID,
		InkMonPoison.CONFIG_ID,
	]
	for i in range(4):
		result.append({
			"source_entry_id": 1000 + i,
			"species": "training_dummy_%d" % i,
			"role": InkMonUnitConfig.ROLE_DPS,
			"elements": [InkMonElementChart.WATER],
			"learned_skill_id": skills[i],
			"battle_stats": {
				"max_hp": 32.0,
				"ad": 8.0,
				"ap": 8.0,
				"armor": 0.0,
				"mr": 0.0,
				"speed": 70.0,
			},
		})
	return result


func _has_key_recursive(value: Variant, key: String) -> bool:
	var dict_value := value as Dictionary
	if dict_value != null:
		if dict_value.has(key):
			return true
		for child in dict_value.values():
			if _has_key_recursive(child, key):
				return true
		return false
	var array_value := value as Array
	if array_value != null:
		for child in array_value:
			if _has_key_recursive(child, key):
				return true
	return false


func _shutdown_with_status(status: String) -> String:
	GameWorld.shutdown()
	return status
