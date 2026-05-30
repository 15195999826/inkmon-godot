class_name InkMonAppRoot
extends Node


const DevAgentBridgeScript := preload("res://addons/lomolib/dev_agent/dev_agent_bridge.gd")
const InkMonMainAgentOpsScript := preload("res://scenes/inkmon-main/ink_mon_main_agent_ops.gd")
const InkMonOverworldViewScript := preload("res://scenes/inkmon-main/ui/ink_mon_overworld_view.gd")

enum AppState { OVERWORLD, BATTLE, NPC_MENU }

const DEFAULT_SAVE_PATH := "user://inkmon_l2_save.json"
const CULTIVATION_COST := 25
const ADVANCEMENT_COST := 40
const ADOPT_COST := 15

var session: InkMonGameSession
var app_state: AppState = AppState.OVERWORLD
var last_battle_result: Dictionary = {}

var _active_instance_id := ""
var _battle_instance: InkMonBattleWorldGI = null
var _event_log: Array[String] = []
var _dev_agent_bridge: Node = null
var _active_npc_id := ""
var _near_npc_id := ""
var _last_ui_message := ""
var _npc_defs: Dictionary = {
	"shop": {
		"display_name": "Shop",
		"type": "shop",
		"coord": Vector2i(2, 0),
	},
	"trainer": {
		"display_name": "Training",
		"type": "training",
		"coord": Vector2i(-2, 1),
	},
	"cultivation": {
		"display_name": "Cultivation",
		"type": "cultivation",
		"coord": Vector2i(0, 2),
	},
	"guild": {
		"display_name": "Guild",
		"type": "guild",
		"coord": Vector2i(2, -1),
	},
	"advancement": {
		"display_name": "Trainer Advancement",
		"type": "advancement",
		"coord": Vector2i(-2, 0),
	},
	"release_adopt": {
		"display_name": "Release / Adopt",
		"type": "release_adopt",
		"coord": Vector2i(0, -2),
	},
}
var _npc_handlers: Dictionary = {}

var _world_layer: InkMonOverworldView
var _hud_layer: CanvasLayer
var _hud_root: Control
var _gold_label: Label
var _rank_label: Label
var _roster_box: HBoxContainer
var _prompt_layer: CanvasLayer
var _prompt_button: Button
var _panel_layer: CanvasLayer
var _dim_overlay: ColorRect
var _npc_panel: PanelContainer
var _panel_title: Label
var _panel_body: VBoxContainer
var _close_button: Button
var _action_buttons: Dictionary = {}
var _shop_buy_buttons: Dictionary = {}
var _trainer_button: Button


func _ready() -> void:
	name = "InkMonMain"
	session = InkMonGameSession.new()
	session.begin_new_game()
	GameWorld.init(EventProcessorConfig.new(20, 1))
	TimelineRegistry.reset()
	_build_npc_handlers()
	_build_world_and_ui()
	_refresh_ui()
	_add_event("InkMonMain ready")
	_install_dev_agent()


func _exit_tree() -> void:
	GameWorld.shutdown()


func _process(delta: float) -> void:
	_layout_ui()
	if _active_instance_id == "":
		return
	_tick_active_instance(delta)
	_complete_battle_if_ready()


func start_training_battle() -> Dictionary:
	if app_state == AppState.BATTLE:
		return {
			"ok": false,
			"message": "battle already active",
			"data": get_dev_agent_state(),
		}

	_battle_instance = GameWorld.create_instance(func() -> GameplayInstance:
		return InkMonBattleWorldGI.new()
	) as InkMonBattleWorldGI
	if _battle_instance == null:
		return {
			"ok": false,
			"message": "failed to create InkMonBattleWorldGI",
			"data": get_dev_agent_state(),
		}

	_active_instance_id = _battle_instance.id
	app_state = AppState.BATTLE
	_battle_instance.start({
		"recording": false,
		"left_roster_snapshots": session.project_player_battle_roster(4),
		"right_roster_snapshots": _build_training_enemy_snapshots(),
	})
	_add_event("training battle started")
	return {
		"ok": true,
		"message": "training battle started",
		"data": get_dev_agent_state(),
	}


func run_training_battle_to_completion(max_ticks: int = 8) -> Dictionary:
	var start_result := start_training_battle()
	if not bool(start_result.get("ok", false)):
		return start_result

	var safe_ticks := maxi(1, max_ticks)
	for _i in range(safe_ticks):
		if app_state != AppState.BATTLE:
			break
		_tick_active_instance(BattleProcedure.DEFAULT_TICK_INTERVAL)
		_complete_battle_if_ready()

	if app_state == AppState.BATTLE:
		return {
			"ok": false,
			"message": "training battle did not complete within %d ticks" % safe_ticks,
			"data": get_dev_agent_state(),
		}

	return {
		"ok": true,
		"message": "training battle completed",
		"data": get_dev_agent_state(),
	}


func reset_session() -> Dictionary:
	session = InkMonGameSession.new()
	session.begin_new_game()
	last_battle_result = {}
	_active_instance_id = ""
	_battle_instance = null
	_active_npc_id = ""
	_near_npc_id = ""
	_last_ui_message = ""
	app_state = AppState.OVERWORLD
	GameWorld.destroy_all_instances()
	TimelineRegistry.reset()
	_event_log.clear()
	_add_event("session reset")
	_refresh_ui()
	return {
		"ok": true,
		"message": "session reset",
		"data": get_dev_agent_state(),
	}


func get_dev_agent_state() -> Dictionary:
	return {
		"state": _state_name(app_state),
		"gold": session.player_state.gold if session != null and session.player_state != null else -1,
		"roster_size": session.player_state.roster.size() if session != null and session.player_state != null else 0,
		"player_coord": _get_player_coord_dict(),
		"near_npc_id": _near_npc_id,
		"active_npc_id": _active_npc_id,
		"panel_open": app_state == AppState.NPC_MENU,
		"ui_message": _last_ui_message,
		"progression": session.player_state.progression.duplicate(true) if session != null and session.player_state != null else {},
		"roster": _get_roster_snapshot(),
		"bag": _get_bag_snapshot(),
		"active_instance_id": _active_instance_id,
		"last_battle_result": last_battle_result.duplicate(true),
		"game_world": GameWorld.get_debug_info(),
		"events": _event_log.duplicate(),
	}


func get_dev_agent_layout_state() -> Dictionary:
	_layout_ui()
	var action_buttons := {}
	for action_id in _action_buttons.keys():
		var action_button := _action_buttons[action_id] as Button
		action_buttons[str(action_id)] = _control_rect_dict(action_button)
	var buy_buttons := {}
	for config_id in _shop_buy_buttons.keys():
		var button := _shop_buy_buttons[config_id] as Button
		buy_buttons[str(config_id)] = _control_rect_dict(button)
	return {
		"viewport": _rect_dict(get_viewport().get_visible_rect()),
		"prompt_button": _control_rect_dict(_prompt_button),
		"npc_panel": _control_rect_dict(_npc_panel),
		"close_button": _control_rect_dict(_close_button),
		"npc_action_buttons": action_buttons,
		"shop_buy_buttons": buy_buttons,
		"trainer_button": _control_rect_dict(_trainer_button),
	}


func move_player(delta_coord: Vector2i) -> Dictionary:
	if app_state != AppState.OVERWORLD:
		return {
			"ok": false,
			"message": "cannot move while state is %s" % _state_name(app_state),
			"data": get_dev_agent_state(),
		}
	var coord := _get_player_coord() + delta_coord
	_set_player_coord(coord)
	_refresh_near_npc()
	_refresh_ui()
	_add_event("player moved to %s,%s" % [coord.x, coord.y])
	return {
		"ok": true,
		"message": "player moved",
		"data": get_dev_agent_state(),
	}


func open_near_npc_menu() -> Dictionary:
	if _near_npc_id == "":
		return {
			"ok": false,
			"message": "no nearby NPC",
			"data": get_dev_agent_state(),
		}
	return open_npc_menu(_near_npc_id)


func open_npc_menu(npc_id: String) -> Dictionary:
	if not _npc_defs.has(npc_id):
		return {
			"ok": false,
			"message": "unknown NPC: %s" % npc_id,
			"data": get_dev_agent_state(),
		}
	app_state = AppState.NPC_MENU
	_active_npc_id = npc_id
	_last_ui_message = "%s opened" % str((_npc_defs[npc_id] as Dictionary).get("display_name", npc_id))
	_refresh_ui()
	_add_event("npc menu opened: %s" % npc_id)
	return {
		"ok": true,
		"message": "npc menu opened",
		"data": get_dev_agent_state(),
	}


func close_npc_menu() -> Dictionary:
	app_state = AppState.OVERWORLD
	_active_npc_id = ""
	_last_ui_message = "closed"
	_refresh_ui()
	_add_event("npc menu closed")
	return {
		"ok": true,
		"message": "npc menu closed",
		"data": get_dev_agent_state(),
	}


func buy_shop_item(config_id: StringName) -> Dictionary:
	if app_state != AppState.NPC_MENU or _active_npc_id != "shop":
		return {
			"ok": false,
			"message": "shop is not open",
			"data": get_dev_agent_state(),
		}
	var result := purchase_shop_item(config_id)
	_refresh_ui()
	return _scene_result(bool(result.get("ok", false)), str(result.get("message", "")))


func purchase_shop_item(config_id: StringName) -> Dictionary:
	var config := ItemSystem.get_item_config(config_id)
	if config.is_empty():
		return {
			"ok": false,
			"message": "unknown shop item: %s" % str(config_id),
		}
	var price := int(config.get("price", 0))
	if session.player_state.gold < price:
		_last_ui_message = "not enough gold"
		return {
			"ok": false,
			"message": "not enough gold",
		}
	session.player_state.gold -= price
	var create_result := session.create_bag_item(config_id, 1, -1)
	if not create_result.success:
		session.player_state.gold += price
		_last_ui_message = create_result.error_message
		return {
			"ok": false,
			"message": create_result.error_message,
		}
	_last_ui_message = "bought %s" % str(config.get("display_name", str(config_id)))
	_add_event(_last_ui_message)
	return {
		"ok": true,
		"message": _last_ui_message,
	}


func trigger_trainer_battle_from_ui() -> Dictionary:
	if app_state != AppState.NPC_MENU or _active_npc_id != "trainer":
		return {
			"ok": false,
			"message": "training NPC is not open",
			"data": get_dev_agent_state(),
		}
	return run_active_npc_action(InkMonTrainingNpcHandler.ACTION_START_BATTLE)


func run_active_npc_action(action_id: String) -> Dictionary:
	if app_state != AppState.NPC_MENU or _active_npc_id == "":
		return _scene_result(false, "no active NPC menu")
	return run_npc_action_for(_active_npc_id, action_id)


func run_npc_action_for(npc_id: String, action_id: String) -> Dictionary:
	if not _npc_handlers.has(npc_id):
		return _scene_result(false, "unknown NPC handler: %s" % npc_id)
	var handler := _npc_handlers[npc_id] as InkMonNpcHandler
	var result := handler.run_action(action_id, self)
	var ok := bool(result.get("ok", false))
	var message := str(result.get("message", ""))
	if message != "":
		_last_ui_message = message
		_add_event(message)
	if app_state == AppState.NPC_MENU and _active_npc_id == npc_id:
		_refresh_ui()
	else:
		_refresh_ui()
	return _scene_result(ok, message)


func complete_training_battle_action() -> Dictionary:
	var result := run_training_battle_to_completion(8)
	_active_npc_id = ""
	return {
		"ok": bool(result.get("ok", false)),
		"message": str(result.get("message", "")),
	}


func cultivate_lead_inkmon() -> Dictionary:
	if session.player_state.roster.is_empty():
		return {"ok": false, "message": "no InkMon to cultivate"}
	if not _spend_gold(CULTIVATION_COST):
		return {"ok": false, "message": "not enough gold for cultivation"}

	var entry := session.player_state.roster[0]
	entry.level += 1
	entry.exp = 0
	entry.persistent_stats["max_hp"] = float(entry.persistent_stats.get("max_hp", 0.0)) + 10.0
	entry.persistent_stats["ad"] = float(entry.persistent_stats.get("ad", 0.0)) + 2.0
	entry.persistent_stats["ap"] = float(entry.persistent_stats.get("ap", 0.0)) + 2.0
	session.player_state.progression["cultivation_points"] = int(
		session.player_state.progression.get("cultivation_points", 0)
	) + 1
	return {"ok": true, "message": "cultivated %s to Lv%d" % [entry.species, entry.level]}


func advance_trainer_rank() -> Dictionary:
	if not _spend_gold(ADVANCEMENT_COST):
		return {"ok": false, "message": "not enough gold for trainer advancement"}
	var rank := int(session.player_state.progression.get("trainer_rank", 1)) + 1
	session.player_state.progression["trainer_rank"] = rank
	return {"ok": true, "message": "trainer rank advanced to R%d" % rank}


func advance_guild_task() -> Dictionary:
	session.player_state.progression["guild_joined"] = true
	var tasks := int(session.player_state.progression.get("guild_tasks_completed", 0)) + 1
	session.player_state.progression["guild_tasks_completed"] = tasks
	return {"ok": true, "message": "guild task marker %d" % tasks}


func adopt_stub_inkmon() -> Dictionary:
	if not _spend_gold(ADOPT_COST):
		return {"ok": false, "message": "not enough gold to adopt"}
	var entry_id := session.player_state.get_next_roster_entry_id()
	var unit_key := InkMonUnitConfig.RIGHT_FLEX if entry_id % 2 == 0 else InkMonUnitConfig.LEFT_FLEX
	var entry := InkMonRosterEntry.from_unit_config(entry_id, unit_key)
	session.player_state.add_roster_entry(entry)
	session.sync_roster_containers()
	return {"ok": true, "message": "adopted %s" % entry.species}


func save_game(save_path: String = DEFAULT_SAVE_PATH) -> Dictionary:
	var save_data := session.to_dict()
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return _scene_result(false, "save open failed: %s" % str(FileAccess.get_open_error()))
	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()
	_add_event("saved game: %s" % save_path)
	return _scene_result(true, "saved game")


func load_game(save_path: String = DEFAULT_SAVE_PATH) -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return _scene_result(false, "save not found: %s" % save_path)
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return _scene_result(false, "load open failed: %s" % str(FileAccess.get_open_error()))
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	var data := parsed as Dictionary
	if data == null:
		return _scene_result(false, "save json is not an object")

	session = InkMonGameSession.new()
	session.from_dict(data)
	last_battle_result = {}
	_active_instance_id = ""
	_battle_instance = null
	_active_npc_id = ""
	app_state = AppState.OVERWORLD
	GameWorld.destroy_all_instances()
	TimelineRegistry.reset()
	_refresh_near_npc()
	_refresh_ui()
	_add_event("loaded game: %s" % save_path)
	return _scene_result(true, "loaded game")


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_D, KEY_RIGHT:
			move_player(Vector2i(1, 0))
		KEY_A, KEY_LEFT:
			move_player(Vector2i(-1, 0))
		KEY_W, KEY_UP:
			move_player(Vector2i(0, -1))
		KEY_S, KEY_DOWN:
			move_player(Vector2i(0, 1))
		KEY_ENTER, KEY_SPACE:
			if app_state == AppState.OVERWORLD:
				open_near_npc_menu()
		KEY_ESCAPE:
			if app_state == AppState.NPC_MENU:
				close_npc_menu()


func _tick_active_instance(dt: float) -> void:
	var instance := GameWorld.get_instance_by_id(_active_instance_id)
	if instance != null and instance.is_running():
		instance.tick(dt)


func _complete_battle_if_ready() -> void:
	if app_state != AppState.BATTLE or _battle_instance == null:
		return
	if _battle_instance.has_active_battle():
		return

	last_battle_result = _battle_instance.get_result_summary()
	session.player_state.apply_battle_result(last_battle_result)
	GameWorld.destroy_instance(_battle_instance.id)
	_active_instance_id = ""
	_battle_instance = null
	app_state = AppState.OVERWORLD
	_active_npc_id = ""
	_last_ui_message = "battle completed"
	_refresh_ui()
	_add_event("battle completed: %s" % str(last_battle_result.get("result", "")))


func _build_world_and_ui() -> void:
	_world_layer = InkMonOverworldViewScript.new() as InkMonOverworldView
	_world_layer.name = "WorldLayer"
	_world_layer.set_npcs(_npc_defs)
	add_child(_world_layer)

	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "HUDLayer"
	add_child(_hud_layer)
	_hud_root = Control.new()
	_hud_root.name = "HUDRoot"
	_hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.add_child(_hud_root)
	_build_hud()

	_prompt_layer = CanvasLayer.new()
	_prompt_layer.name = "PromptLayer"
	add_child(_prompt_layer)
	_prompt_button = Button.new()
	_prompt_button.name = "PromptEnterButton"
	_prompt_button.text = "Enter"
	_prompt_button.custom_minimum_size = Vector2(88, 40)
	_prompt_button.pressed.connect(func() -> void:
		open_near_npc_menu()
	)
	_prompt_layer.add_child(_prompt_button)

	_panel_layer = CanvasLayer.new()
	_panel_layer.name = "PanelLayer"
	add_child(_panel_layer)
	_build_panel()


func _build_hud() -> void:
	var hud_panel := PanelContainer.new()
	hud_panel.name = "TopLeftHud"
	hud_panel.position = Vector2(24, 24)
	var hud_style := StyleBoxFlat.new()
	hud_style.bg_color = Color(0.05, 0.045, 0.035, 0.82)
	hud_style.border_color = Color(0.0, 0.0, 0.0, 0.72)
	hud_style.set_border_width_all(2)
	hud_style.corner_radius_top_left = 6
	hud_style.corner_radius_top_right = 6
	hud_style.corner_radius_bottom_left = 6
	hud_style.corner_radius_bottom_right = 6
	hud_panel.add_theme_stylebox_override("panel", hud_style)
	_hud_root.add_child(hud_panel)

	var hud_box := VBoxContainer.new()
	hud_box.name = "HudBox"
	hud_box.add_theme_constant_override("separation", 8)
	hud_panel.add_child(hud_box)

	var top_row := HBoxContainer.new()
	top_row.name = "GoldRankRow"
	top_row.add_theme_constant_override("separation", 18)
	hud_box.add_child(top_row)

	_gold_label = Label.new()
	_gold_label.name = "GoldLabel"
	_gold_label.add_theme_font_size_override("font_size", 24)
	top_row.add_child(_gold_label)

	_rank_label = Label.new()
	_rank_label.name = "RankLabel"
	_rank_label.add_theme_font_size_override("font_size", 24)
	top_row.add_child(_rank_label)

	_roster_box = HBoxContainer.new()
	_roster_box.name = "RosterChips"
	_roster_box.add_theme_constant_override("separation", 6)
	hud_box.add_child(_roster_box)

	var settings := Button.new()
	settings.name = "SettingsButton"
	settings.text = "⚙"
	settings.custom_minimum_size = Vector2(52, 52)
	settings.anchor_left = 1.0
	settings.anchor_right = 1.0
	settings.offset_left = -76.0
	settings.offset_right = -24.0
	settings.offset_top = 24.0
	settings.offset_bottom = 76.0
	_hud_root.add_child(settings)


func _build_panel() -> void:
	var panel_root := Control.new()
	panel_root.name = "PanelRoot"
	panel_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_layer.add_child(panel_root)

	_dim_overlay = ColorRect.new()
	_dim_overlay.name = "DimOverlay"
	_dim_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim_overlay.color = Color(0.05, 0.04, 0.03, 0.25)
	panel_root.add_child(_dim_overlay)

	_npc_panel = PanelContainer.new()
	_npc_panel.name = "NpcSideSheet"
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.78, 0.70, 0.54, 0.94)
	panel_style.border_color = Color(0.07, 0.06, 0.05, 0.96)
	panel_style.set_border_width_all(3)
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	_npc_panel.add_theme_stylebox_override("panel", panel_style)
	panel_root.add_child(_npc_panel)

	var panel_box := VBoxContainer.new()
	panel_box.name = "PanelBox"
	panel_box.add_theme_constant_override("separation", 14)
	_npc_panel.add_child(panel_box)

	var header := HBoxContainer.new()
	header.name = "PanelHeader"
	header.add_theme_constant_override("separation", 12)
	panel_box.add_child(header)
	_panel_title = Label.new()
	_panel_title.name = "PanelTitle"
	_panel_title.add_theme_font_size_override("font_size", 28)
	header.add_child(_panel_title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_close_button = Button.new()
	_close_button.name = "PanelCloseButton"
	_close_button.text = "X"
	_close_button.custom_minimum_size = Vector2(42, 36)
	_close_button.pressed.connect(func() -> void:
		close_npc_menu()
	)
	header.add_child(_close_button)

	_panel_body = VBoxContainer.new()
	_panel_body.name = "PanelBody"
	_panel_body.add_theme_constant_override("separation", 10)
	panel_box.add_child(_panel_body)


func _build_npc_handlers() -> void:
	_npc_handlers = {
		"shop": InkMonShopNpcHandler.new("shop", "Shop"),
		"trainer": InkMonTrainingNpcHandler.new("trainer", "Training"),
		"cultivation": InkMonCultivationNpcHandler.new("cultivation", "Cultivation"),
		"guild": InkMonGuildNpcHandler.new("guild", "Guild"),
		"advancement": InkMonAdvancementNpcHandler.new("advancement", "Trainer Advancement"),
		"release_adopt": InkMonReleaseAdoptNpcHandler.new("release_adopt", "Release / Adopt"),
	}


func _install_dev_agent() -> void:
	var ops := InkMonMainAgentOpsScript.new() as Node
	ops.name = "InkMonMainAgentOps"
	add_child(ops)

	_dev_agent_bridge = DevAgentBridgeScript.new()
	_dev_agent_bridge.name = "DevAgentBridge"
	_dev_agent_bridge.scene_ops_path = NodePath("../InkMonMainAgentOps")
	add_child(_dev_agent_bridge)
	call_deferred("_print_dev_agent_paths")


func _print_dev_agent_paths() -> void:
	if _dev_agent_bridge == null:
		return
	if not _dev_agent_bridge.has_method("get_session_info"):
		return
	var info: Dictionary = _dev_agent_bridge.get_session_info() as Dictionary
	if str(info.get("inbox_global", "")).is_empty():
		return
	print("[InkMonMain] inbox: %s" % str(info.get("inbox_global", "")))
	print("[InkMonMain] outbox: %s" % str(info.get("outbox_global", "")))
	print("[InkMonMain] session_dir: %s" % str(info.get("session_dir_global", "")))


func _build_training_enemy_snapshots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var skills := [
		InkMonStun.CONFIG_ID,
		InkMonFireball.CONFIG_ID,
		InkMonHolyHeal.CONFIG_ID,
		InkMonPoison.CONFIG_ID,
	]
	for i in range(4):
		result.append({
			"source_entry_id": 2000 + i,
			"species": "training_dummy_%d" % i,
			"role": InkMonUnitConfig.ROLE_DPS,
			"elements": [InkMonElementChart.WATER],
			"learned_skill_id": skills[i],
			"battle_stats": {
				"max_hp": 30.0,
				"ad": 6.0,
				"ap": 6.0,
				"armor": 0.0,
				"mr": 0.0,
				"speed": 70.0,
			},
		})
	return result


func _add_event(message: String) -> void:
	_event_log.append(message)
	while _event_log.size() > 16:
		_event_log.pop_front()


func _state_name(state_value: AppState) -> String:
	match state_value:
		AppState.OVERWORLD:
			return "OVERWORLD"
		AppState.BATTLE:
			return "BATTLE"
		AppState.NPC_MENU:
			return "NPC_MENU"
		_:
			return "UNKNOWN"


func _refresh_ui() -> void:
	if _world_layer != null:
		_world_layer.set_player_coord(_get_player_coord())
		_world_layer.set_near_npc_id(_near_npc_id)
	if _gold_label != null:
		_gold_label.text = "● %d" % session.player_state.gold
	if _rank_label != null:
		_rank_label.text = "R%d" % int(session.player_state.progression.get("trainer_rank", 1))
	_refresh_roster_chips()
	_refresh_prompt()
	_refresh_panel()


func _layout_ui() -> void:
	if _prompt_button == null or _world_layer == null:
		return
	if _near_npc_id != "" and _npc_defs.has(_near_npc_id):
		var npc_def := _npc_defs[_near_npc_id] as Dictionary
		var coord := npc_def.get("coord", Vector2i.ZERO) as Vector2i
		_prompt_button.position = _world_layer.coord_to_screen(coord) + Vector2(-44, -72)

	if _npc_panel != null:
		var size := get_viewport().get_visible_rect().size
		var panel_width := maxf(330.0, size.x * 0.32)
		_npc_panel.position = Vector2(size.x - panel_width - 24.0, 84.0)
		_npc_panel.size = Vector2(panel_width, size.y - 144.0)


func _refresh_roster_chips() -> void:
	if _roster_box == null:
		return
	for child in _roster_box.get_children():
		child.queue_free()
	for entry in session.player_state.roster:
		var chip := PanelContainer.new()
		chip.name = "RosterChip_%d" % entry.entry_id
		chip.custom_minimum_size = Vector2(76, 62)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.10, 0.09, 0.07, 0.92)
		style.border_color = _element_color(entry.elements[0] if not entry.elements.is_empty() else "")
		style.set_border_width_all(2)
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		chip.add_theme_stylebox_override("panel", style)
		var label := Label.new()
		label.text = "%s\nLv%d" % [_role_short(entry.role), entry.level]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		chip.add_child(label)
		_roster_box.add_child(chip)


func _refresh_prompt() -> void:
	if _prompt_button == null:
		return
	_prompt_button.visible = app_state == AppState.OVERWORLD and _near_npc_id != ""
	_layout_ui()


func _refresh_panel() -> void:
	if _dim_overlay == null or _npc_panel == null:
		return
	var open := app_state == AppState.NPC_MENU and _active_npc_id != ""
	_dim_overlay.visible = open
	_npc_panel.visible = open
	if not open:
		return
	var npc_def := _npc_defs[_active_npc_id] as Dictionary
	_panel_title.text = str(npc_def.get("display_name", _active_npc_id))
	_rebuild_panel_body(str(npc_def.get("type", "")))
	_layout_ui()


func _rebuild_panel_body(_npc_type: String) -> void:
	for child in _panel_body.get_children():
		child.queue_free()
	_action_buttons.clear()
	_shop_buy_buttons.clear()
	_trainer_button = null
	var handler := _get_active_handler()
	if handler == null:
		var placeholder := Label.new()
		placeholder.text = "System linked"
		_panel_body.add_child(placeholder)
		return

	var actions := handler.get_actions(self)
	for action in actions:
		_add_action_row(action)


func _add_action_row(action: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.name = "ActionRow_%s" % str(action.get(InkMonNpcHandler.ACTION_ID, "unknown"))
	row.add_theme_constant_override("separation", 12)
	_panel_body.add_child(row)
	var icon := ColorRect.new()
	icon.name = "Icon"
	icon.color = Color(0.18, 0.14, 0.10)
	icon.custom_minimum_size = Vector2(54, 54)
	row.add_child(icon)
	var label := Label.new()
	label.name = "ItemLabel"
	label.text = "%s\n%s" % [
		str(action.get(InkMonNpcHandler.ACTION_LABEL, "")),
		str(action.get(InkMonNpcHandler.ACTION_DETAIL, "")),
	]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var button := Button.new()
	var action_id := str(action.get(InkMonNpcHandler.ACTION_ID, ""))
	button.name = "Action_%s" % action_id
	button.text = "Buy" if str(action.get(InkMonNpcHandler.ACTION_KIND, "")) == "shop_buy" else "Go"
	button.custom_minimum_size = Vector2(84, 40)
	button.disabled = not bool(action.get(InkMonNpcHandler.ACTION_ENABLED, true))
	button.pressed.connect(func() -> void:
		run_active_npc_action(action_id)
	)
	row.add_child(button)
	_action_buttons[action_id] = button
	if str(action.get(InkMonNpcHandler.ACTION_KIND, "")) == "shop_buy":
		_shop_buy_buttons[str(action.get("item_config_id", ""))] = button
	if action_id == InkMonTrainingNpcHandler.ACTION_START_BATTLE:
		_trainer_button = button


func _get_active_handler() -> InkMonNpcHandler:
	if _active_npc_id == "" or not _npc_handlers.has(_active_npc_id):
		return null
	return _npc_handlers[_active_npc_id] as InkMonNpcHandler


func _refresh_near_npc() -> void:
	_near_npc_id = ""
	var player_coord := _get_player_coord()
	for npc_id in _npc_defs.keys():
		var npc_def := _npc_defs[npc_id] as Dictionary
		var npc_coord := npc_def.get("coord", Vector2i.ZERO) as Vector2i
		if _axial_distance(player_coord, npc_coord) <= 1:
			_near_npc_id = str(npc_id)
			return


func _get_player_coord() -> Vector2i:
	var overworld := session.player_state.overworld
	var coord := overworld.get("player_coord", {}) as Dictionary
	if coord == null:
		return Vector2i.ZERO
	return Vector2i(int(coord.get("q", 0)), int(coord.get("r", 0)))


func _set_player_coord(coord: Vector2i) -> void:
	session.player_state.overworld["player_coord"] = {
		"q": coord.x,
		"r": coord.y,
	}


func _get_player_coord_dict() -> Dictionary:
	var coord := _get_player_coord()
	return {
		"q": coord.x,
		"r": coord.y,
	}


func _get_bag_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var bag_id := session.get_container_id(InkMonGameSession.BAG_CONTAINER)
	if bag_id <= 0:
		return result
	for item_id in ItemSystem.get_items_in_container(bag_id):
		var snapshot := ItemSystem.get_item_snapshot(item_id)
		result.append({
			"config_id": str(snapshot.get("config_id", "")),
			"count": int(snapshot.get("count", 1)),
			"slot_index": int(snapshot.get("slot_index", -1)),
		})
	return result


func _get_roster_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if session == null or session.player_state == null:
		return result
	for entry in session.player_state.roster:
		result.append({
			"entry_id": entry.entry_id,
			"species": entry.species,
			"role": entry.role,
			"level": entry.level,
			"exp": entry.exp,
		})
	return result


func _spend_gold(amount: int) -> bool:
	if session.player_state.gold < amount:
		return false
	session.player_state.gold -= amount
	return true


func _scene_result(ok: bool, message: String) -> Dictionary:
	return {
		"ok": ok,
		"message": message,
		"data": get_dev_agent_state(),
	}


func _control_rect_dict(control: Control) -> Dictionary:
	if control == null or not control.visible:
		return {}
	return _rect_dict(control.get_global_rect())


func _rect_dict(rect: Rect2) -> Dictionary:
	return {
		"x": rect.position.x,
		"y": rect.position.y,
		"w": rect.size.x,
		"h": rect.size.y,
		"cx": rect.position.x + rect.size.x * 0.5,
		"cy": rect.position.y + rect.size.y * 0.5,
	}


func _axial_distance(a: Vector2i, b: Vector2i) -> int:
	var dq := a.x - b.x
	var dr := a.y - b.y
	return int((abs(dq) + abs(dq + dr) + abs(dr)) / 2)


func _element_color(element: String) -> Color:
	match element:
		InkMonElementChart.FIRE:
			return Color(0.85, 0.30, 0.18)
		InkMonElementChart.WATER:
			return Color(0.18, 0.62, 0.66)
		InkMonElementChart.LIGHT:
			return Color(0.92, 0.74, 0.24)
		InkMonElementChart.DARK:
			return Color(0.44, 0.30, 0.66)
		InkMonElementChart.WIND:
			return Color(0.42, 0.66, 0.34)
		_:
			return Color(0.72, 0.68, 0.56)


func _role_short(role_value: String) -> String:
	match role_value:
		InkMonUnitConfig.ROLE_TANK:
			return "TNK"
		InkMonUnitConfig.ROLE_DPS:
			return "DPS"
		InkMonUnitConfig.ROLE_HEALER:
			return "HLR"
		_:
			return "FLX"
