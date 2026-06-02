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

	var model_status := _assert_roster_model(session)
	if model_status != "":
		return model_status

	var equip_status := _assert_equipment_stat_fold(session)
	if equip_status != "":
		return equip_status

	var data_status := _assert_session_round_trip(session)
	if data_status != "":
		return data_status

	var projection_status := _assert_projection_is_deterministic(session)
	if projection_status != "":
		return projection_status

	var battle_status := _assert_battle_snapshot_injection(session)
	if battle_status != "":
		return battle_status

	var discard_status := _assert_old_save_discarded()
	if discard_status != "":
		return discard_status

	return ""


func _assert_roster_model(session: InkMonGameSession) -> String:
	if session.player_state.roster.is_empty():
		return "new game roster should not be empty"
	var lead := session.player_state.roster[0]
	var entry_dict := lead.to_dict()

	# New shape: skill_slots + engravings present.
	if not entry_dict.has("skill_slots"):
		return "roster entry must expose skill_slots"
	var slots := entry_dict["skill_slots"] as Array
	if slots == null or slots.is_empty():
		return "seeded roster entry should have at least one skill slot"
	var slot0 := slots[0] as Dictionary
	if slot0 == null or not slot0.has("slot_index") or not slot0.has("skill_id"):
		return "skill slot must carry slot_index and skill_id"
	if str(slot0.get("skill_id", "")) == "":
		return "seeded skill slot should reference a skill_id"
	if not entry_dict.has("engravings"):
		return "roster entry must expose engravings"

	# Removed fields must be gone from the entry.
	if entry_dict.has("persistent_stats") or entry_dict.has("learned_skill_id") or entry_dict.has("medals"):
		return "roster entry should no longer carry persistent_stats/learned_skill_id/medals"

	# medals moved to player-level state.
	if not session.player_state.to_dict().has("medals"):
		return "medals should live on player state"

	# Stats are derived f(species, level): level-1 derive must equal species base (battle balance unchanged).
	if lead.level != 1:
		return "seeded lead should start at level 1"
	var base_max_hp := float(InkMonUnitConfig.get_unit_config(InkMonUnitConfig.LEFT_AEGIS_PUP).stats["max_hp"])
	var projected := lead.project_to_battle_snapshot().get("battle_stats", {}) as Dictionary
	if projected == null:
		return "projection must still emit battle_stats"
	if absf(float(projected.get("max_hp", -1.0)) - base_max_hp) > 0.01:
		return "level-1 derived max_hp must equal species base (battle balance unchanged)"
	return ""


func _assert_equipment_stat_fold(session: InkMonGameSession) -> String:
	# P8: 装备的 stat_mods 折叠进投影的 battle_stats (项目本地, lomolib inventoryKit)。
	var lead := session.player_state.roster[0]
	var base_ad := float(lead.derive_battle_stats().get("ad", 0.0))
	var container_id := session.get_container_id(lead.equipment_container)
	if container_id <= 0:
		return "equipment container should be registered for lead"
	var equip_result := ItemSystem.create_item(container_id, InkMonItemCatalog.TRAINING_SWORD, 1)
	if not equip_result.success:
		return "failed to equip training sword: %s" % equip_result.error_message
	var sword_ad := float((ItemSystem.get_item_config(InkMonItemCatalog.TRAINING_SWORD).get("stat_mods", {}) as Dictionary).get("ad", 0.0))
	if sword_ad <= 0.0:
		return "training sword should define an ad stat_mod"
	var snapshot := session.project_player_battle_roster(4)[0]
	var folded_ad := float((snapshot.get("battle_stats", {}) as Dictionary).get("ad", 0.0))
	if absf(folded_ad - (base_ad + sword_ad)) > 0.01:
		return "equipped sword ad should fold into projected battle_stats (got %.1f want %.1f)" % [folded_ad, base_ad + sword_ad]
	# 清理: 移除装备避免污染后续往返断言。
	for item_id in ItemSystem.get_items_in_container(container_id):
		ItemSystem.destroy_item(item_id)
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

	# P3: snapshot projects skill_slots (array), no longer the single learned_skill_id.
	if first.has("learned_skill_id"):
		return "battle snapshot should project skill_slots, not learned_skill_id"
	if not first.has("skill_slots"):
		return "battle snapshot must carry skill_slots"
	var snap_slots := first["skill_slots"] as Array
	if snap_slots == null or snap_slots.is_empty():
		return "snapshot skill_slots should be non-empty for a seeded entry"
	var primary := snap_slots[0] as Dictionary
	if primary == null or str(primary.get("skill_id", "")) == "":
		return "snapshot primary skill slot must carry a skill_id"
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
	# P8: 给 left[0] 挂刻印, 验证刻印被动 grant + hook 不破坏战斗 (集成)。
	left_snapshots[0]["engravings"] = [{"engraving_id": "amp", "target_slot": 0}]

	var right_snapshots := _build_weak_enemy_snapshots()
	var battle := GameWorld.create_instance(func() -> GameplayInstance:
		return InkMonWorldGI.new()
	) as InkMonWorldGI
	if battle == null:
		return "failed to create battle instance"

	battle.start_battle_procedure({
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

	# P4: 同一持久 world GI 复用跑第二场战斗 (reset-on-start) 应再次正常结束 (无独立 battle GI)。
	battle.start_battle_procedure({
		"recording": false,
		"left_roster_snapshots": session.project_player_battle_roster(4),
		"right_roster_snapshots": _build_weak_enemy_snapshots(),
	})
	GameWorld.tick_all(BattleProcedure.DEFAULT_TICK_INTERVAL)
	if battle.has_active_battle():
		return _shutdown_with_status("reused world GI: second battle did not finish")
	if battle.get_result_summary().get("winner_team", "") != "left":
		return _shutdown_with_status("reused world GI: second battle expected left winner")

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
			"personality": InkMonUnitConfig.PERSONALITY_AGGRESSIVE,
			"elements": [InkMonElementChart.WATER],
			"skill_slots": [{"slot_index": 0, "skill_id": skills[i]}],
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


func _assert_old_save_discarded() -> String:
	# F2: 存档永不向后兼容 — 缺 version / 旧版档 from_dict 丢弃重开新游戏, 不读旧形状、不崩。
	# 旧格式 (无 version, roster entry 缺 skill_slots): 旧逻辑会读成空 slot 再于注入侧 assert 崩。
	var legacy_save := {
		"player": {"gold": 99999, "roster": [{"entry_id": 1, "species": "legacy_mon", "level": 7}]},
		"inventory": {},
	}
	var loaded := InkMonGameSession.new()
	if loaded.from_dict(legacy_save):
		return "legacy save (missing version) should be discarded, not loaded"
	if loaded.player_state == null:
		return "discarded legacy save should restart a fresh new game (player_state is null)"
	if loaded.player_state.roster.size() != 4:
		return "discarded legacy save should reseed new-game roster (4), got %d" % loaded.player_state.roster.size()
	if loaded.player_state.gold == 99999:
		return "discarded legacy save must not retain old gold"

	# 显式 (未来) 版本号同样丢弃重开。
	var future_save := loaded.to_dict()
	future_save["version"] = InkMonGameSession.SAVE_VERSION + 1
	var loaded2 := InkMonGameSession.new()
	if loaded2.from_dict(future_save):
		return "save with future version should be discarded, not loaded"
	return ""
