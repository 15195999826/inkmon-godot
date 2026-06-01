extends Node


const InkMonMainScene := preload("res://scenes/inkmon-main/ink_mon_game.tscn")


func _ready() -> void:
	var status := await _run()
	if status == "":
		print("SMOKE_TEST_RESULT: PASS - InkMonWorldHost ran a training battle and returned to overworld")
		get_tree().quit(0)
	else:
		print("SMOKE_TEST_RESULT: FAIL - %s" % status)
		get_tree().quit(1)


func _run() -> String:
	var root := InkMonMainScene.instantiate() as InkMonWorldHost
	add_child(root)
	await get_tree().process_frame

	var initial_state := root.get_dev_agent_state()
	if initial_state.get("state", "") != "OVERWORLD":
		return _cleanup(root, "initial state should be OVERWORLD")
	if int(initial_state.get("gold", 0)) != InkMonPlayerState.DEFAULT_GOLD:
		return _cleanup(root, "new game gold should be default")

	var world_actor_status := _assert_world_actors_registered(root)
	if world_actor_status != "":
		return _cleanup(root, world_actor_status)

	var shop_status := await _assert_shop_flow(root)
	if shop_status != "":
		return _cleanup(root, shop_status)

	var systems_status := _assert_system_npc_flows(root)
	if systems_status != "":
		return _cleanup(root, systems_status)

	var save_status := _assert_save_load(root)
	if save_status != "":
		return _cleanup(root, save_status)

	var slot_status := _assert_multi_slot_save(root)
	if slot_status != "":
		return _cleanup(root, slot_status)

	var final_state := root.get_dev_agent_state()
	if final_state.get("state", "") != "OVERWORLD":
		return _cleanup(root, "state did not return to OVERWORLD")
	if str(final_state.get("active_instance_id", "")) != "":
		return _cleanup(root, "active instance id should be empty after battle")

	root.queue_free()
	await get_tree().process_frame
	return ""


## P2: 玩家 + 6 NPC 注册为 InkMonWorldActor 进唯一 world GI registry,
## hex_position 住基类(玩家 actor 是 base InkMonWorldActor,非 battle actor)。
func _assert_world_actors_registered(root: InkMonWorldHost) -> String:
	var world_gi := root._world_gi
	if world_gi == null:
		return "world GI should exist at boot"
	var actors := world_gi.world_actors as Dictionary
	if actors.size() != 7:
		return "should register 7 world actors (player + 6 NPC), got %d" % actors.size()
	var player_actor := world_gi.get_world_actor("player")
	if player_actor == null:
		return "player world actor should be registered under 'player'"
	if player_actor is InkMonBattleActor:
		return "player world actor must be base InkMonWorldActor, not a battle actor"
	if not player_actor.hex_position.is_valid():
		return "player world actor should hold a valid hex_position on the base class"
	var shop_actor := world_gi.get_world_actor("shop")
	if shop_actor == null or shop_actor.hex_position.to_axial() != Vector2i(2, 0):
		return "shop NPC world actor should sit at its defined coord"
	return ""


func _assert_shop_flow(root: InkMonWorldHost) -> String:
	# P4:goto/move 是异步 command —— 入队即 ok;玩家由 30Hz tick 逐格走向 (1,0)。
	var move_result := root.move_player(Vector2i(1, 0))
	if not bool(move_result.get("ok", false)):
		return "move command to Shop should be accepted (enqueued)"
	var reach_status := await _wait_for_player_to_reach(root, Vector2i(1, 0))
	if reach_status != "":
		return reach_status
	var settle_status := await _wait_for_move_settle(root)
	if settle_status != "":
		return settle_status
	var moved_state := root.get_dev_agent_state()
	if moved_state.get("near_npc_id", "") != "shop":
		return "moving right should put player near Shop"
	if _visual_coord_from_state(moved_state) != _coord_from_state(moved_state):
		return "Shop move visual coord should sync to logic coord after step tween settles"

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


func _assert_system_npc_flows(root: InkMonWorldHost) -> String:
	var training_result := root.run_npc_action_for("trainer", InkMonTrainingNpcHandler.ACTION_START_BATTLE)
	if not bool(training_result.get("ok", false)):
		return "training NPC battle failed: %s" % str(training_result.get("message", ""))

	var after_training := root.get_dev_agent_state()
	if int(after_training.get("gold", 0)) <= InkMonPlayerState.DEFAULT_GOLD:
		return "training NPC should award gold"
	var battle_result := after_training.get("last_battle_result", {}) as Dictionary
	if battle_result == null or battle_result.get("winner_team", "") != "left":
		return "training NPC battle should end as a left win"

	var lead := root.session.player_state.roster[0]
	var level_before := lead.level
	var cultivate_result := root.run_npc_action_for("cultivation", InkMonCultivationNpcHandler.ACTION_CULTIVATE_LEAD)
	if not bool(cultivate_result.get("ok", false)):
		return "cultivation NPC failed: %s" % str(cultivate_result.get("message", ""))
	if lead.level != level_before + 1:
		return "cultivation should level the lead InkMon"
	if int(root.session.player_state.progression.get("cultivation_points", 0)) != 1:
		return "cultivation should increment cultivation_points"

	var rank_result := root.run_npc_action_for("advancement", InkMonAdvancementNpcHandler.ACTION_RANK_UP)
	if not bool(rank_result.get("ok", false)):
		return "trainer advancement failed: %s" % str(rank_result.get("message", ""))
	if int(root.session.player_state.progression.get("trainer_rank", 1)) != 2:
		return "trainer advancement should set rank to 2"

	var guild_result := root.run_npc_action_for("guild", InkMonGuildNpcHandler.ACTION_GUILD_TASK)
	if not bool(guild_result.get("ok", false)):
		return "guild NPC failed: %s" % str(guild_result.get("message", ""))
	if not bool(root.session.player_state.progression.get("guild_joined", false)):
		return "guild NPC should set guild_joined"
	if int(root.session.player_state.progression.get("guild_tasks_completed", 0)) != 1:
		return "guild NPC should increment task marker"

	var roster_before := root.session.player_state.roster.size()
	var adopt_result := root.run_npc_action_for("release_adopt", InkMonReleaseAdoptNpcHandler.ACTION_ADOPT_STUB)
	if not bool(adopt_result.get("ok", false)):
		return "release/adopt NPC failed: %s" % str(adopt_result.get("message", ""))
	if root.session.player_state.roster.size() != roster_before + 1:
		return "adopt should add a roster entry"
	return ""


func _assert_multi_slot_save(root: InkMonWorldHost) -> String:
	# P8: 多槽存档 —— 存到 slot 2, reset, 从 slot 2 读回深相等。
	var slots := root.list_save_slots()
	if slots.size() != InkMonWorldHost.SAVE_SLOT_COUNT:
		return "list_save_slots should report %d slots" % InkMonWorldHost.SAVE_SLOT_COUNT
	var saved_gold := root.session.player_state.gold
	var saved_roster := root.session.player_state.roster.size()
	if not bool(root.save_to_slot(2).get("ok", false)):
		return "save_to_slot(2) failed"
	if not bool((root.list_save_slots()[1] as Dictionary).get("exists", false)):
		return "slot 2 should exist after save_to_slot(2)"

	if not bool(root.reset_session().get("ok", false)):
		return "reset before slot load failed"
	if not bool(root.load_from_slot(2).get("ok", false)):
		return "load_from_slot(2) failed"
	if root.session.player_state.gold != saved_gold:
		return "load_from_slot should restore gold"
	if root.session.player_state.roster.size() != saved_roster:
		return "load_from_slot should restore roster"
	return ""


func _assert_save_load(root: InkMonWorldHost) -> String:
	var save_path := "user://inkmon_l2_smoke_save.json"
	var saved_gold := root.session.player_state.gold
	var saved_roster_size := root.session.player_state.roster.size()
	var saved_rank := int(root.session.player_state.progression.get("trainer_rank", 1))
	var saved_cultivation := int(root.session.player_state.progression.get("cultivation_points", 0))

	var save_result := root.save_game(save_path)
	if not bool(save_result.get("ok", false)):
		return "save_game failed: %s" % str(save_result.get("message", ""))

	var reset_result := root.reset_session()
	if not bool(reset_result.get("ok", false)):
		return "reset before load failed"
	if root.session.player_state.roster.size() == saved_roster_size:
		return "reset should change roster size before load"

	var load_result := root.load_game(save_path)
	if not bool(load_result.get("ok", false)):
		return "load_game failed: %s" % str(load_result.get("message", ""))
	if root.session.player_state.gold != saved_gold:
		return "load should restore gold"
	if root.session.player_state.roster.size() != saved_roster_size:
		return "load should restore roster size"
	if int(root.session.player_state.progression.get("trainer_rank", 1)) != saved_rank:
		return "load should restore trainer rank"
	if int(root.session.player_state.progression.get("cultivation_points", 0)) != saved_cultivation:
		return "load should restore cultivation points"
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
		var overworld := state.get("overworld_3d", {}) as Dictionary
		if not bool(state.get("player_moving", false)) and not bool(overworld.get("move_animation_active", false)):
			return ""
	return "movement did not settle (player still moving or view tween running)"


func _coord_from_state(state: Dictionary) -> Vector2i:
	var coord := state.get("player_coord", {}) as Dictionary
	if coord == null:
		return Vector2i.ZERO
	return Vector2i(int(coord.get("q", 0)), int(coord.get("r", 0)))


func _visual_coord_from_state(state: Dictionary) -> Vector2i:
	var overworld := state.get("overworld_3d", {}) as Dictionary
	if overworld == null:
		return Vector2i.ZERO
	var coord := overworld.get("player_visual_coord", {}) as Dictionary
	if coord == null:
		return Vector2i.ZERO
	return Vector2i(int(coord.get("q", 0)), int(coord.get("r", 0)))


func _cleanup(root: InkMonWorldHost, status: String) -> String:
	root.queue_free()
	GameWorld.shutdown()
	return status
