class_name InkMonGameDirector
extends Node


const DevAgentBridgeScript := preload("res://addons/lomolib/dev_agent/dev_agent_bridge.gd")
const InkMonMainAgentOpsScript := preload("res://scenes/inkmon-main/ink_mon_main_agent_ops.gd")
const InkMonOverworldView3DScript := preload("res://scenes/inkmon-main/overworld/ink_mon_overworld_view_3d.gd")

# UI 动态列表组件场景 (§6: 动态列表用 instantiate 组件场景)。
const RosterChipScene := preload("res://scenes/inkmon-main/ui/components/roster_chip.tscn")
const PartyEntryRowScene := preload("res://scenes/inkmon-main/ui/components/party_entry_row.tscn")
const BagItemRowScene := preload("res://scenes/inkmon-main/ui/components/bag_item_row.tscn")
const NpcActionRowScene := preload("res://scenes/inkmon-main/ui/components/npc_action_row.tscn")
const JournalPanelScene := preload("res://scenes/inkmon-main/ui/components/journal_panel.tscn")
const PanelMessageScene := preload("res://scenes/inkmon-main/ui/components/panel_message.tscn")
# 静态 UI 容器场景 (§6: HUD / drawer / modal 全 .tscn)。
const SaveLoadModalScene := preload("res://scenes/inkmon-main/ui/save_load_modal.tscn")
const RightDrawerScene := preload("res://scenes/inkmon-main/ui/right_drawer.tscn")
const HudContentScene := preload("res://scenes/inkmon-main/ui/hud_content.tscn")

enum AppState { OVERWORLD, BATTLE, NPC_MENU }

const DEFAULT_SAVE_PATH := "user://inkmon_l2_save.json"
# 手动存档点 + 可多槽 (§8b); 战斗结果不自动落盘, 玩家开 save 菜单存某槽。
const SAVE_SLOT_COUNT := 3

var session: InkMonGameSession
var app_state: AppState = AppState.OVERWORLD
var last_battle_result: Dictionary = {}

var _active_instance_id := ""
var _world_gi: InkMonWorldGI = null
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

var _overworld_grid: InkMonOverworldGrid
var _move_controller: InkMonOverworldMoveController
var _last_move_result: Dictionary = {}
var _world_layer: InkMonOverworldView3D
var _hud_layer: CanvasLayer
var _hud_root: Control
var _gold_label: Label
var _rank_label: Label
var _roster_box: HBoxContainer
var _tool_buttons: Dictionary = {}
var _prompt_layer: CanvasLayer
var _prompt_button: Button
var _panel_layer: CanvasLayer
var _dim_overlay: ColorRect
var _npc_panel: PanelContainer
var _tab_bar: HBoxContainer
var _tab_buttons: Dictionary = {}
var _panel_title: Label
var _panel_body: VBoxContainer
var _close_button: Button
var _action_buttons: Dictionary = {}
var _shop_buy_buttons: Dictionary = {}
var _trainer_button: Button
var _drawer_mode := ""
var _modal_layer: CanvasLayer
var _modal_overlay: ColorRect
var _save_load_modal: PanelContainer
var _save_slot_buttons: Dictionary = {}
var _load_slot_buttons: Dictionary = {}
var _modal_close_button: Button
var _drawer_transition_tween: Tween
var _modal_transition_tween: Tween
var _drawer_transition_active := false
var _modal_transition_active := false
var _modal_open_requested := false


func _ready() -> void:
	name = "GameDirector"
	session = InkMonGameSession.new()
	session.begin_new_game()
	GameWorld.init(EventProcessorConfig.new(20, 1))
	TimelineRegistry.reset()
	_build_npc_handlers()
	_setup_overworld_runtime()
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

	# 持久 world GI 内起战斗 procedure (不再 per-battle create→destroy)。
	Log.assert_crash(_world_gi != null, "InkMonGameDirector", "world GI not initialized before battle")
	_active_instance_id = _world_gi.id
	app_state = AppState.BATTLE
	_world_gi.start_battle_procedure({
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
	_world_gi = null
	_active_npc_id = ""
	_near_npc_id = ""
	_drawer_mode = ""
	_last_move_result = {}
	_last_ui_message = ""
	app_state = AppState.OVERWORLD
	GameWorld.destroy_all_instances()
	TimelineRegistry.reset()
	_setup_overworld_runtime()
	_cancel_overworld_animation()
	_refresh_near_npc()
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
		"drawer_open": _drawer_mode != "",
		"drawer_mode": _drawer_mode,
		"modal_open": _save_load_modal != null and _save_load_modal.visible,
		"ui_message": _last_ui_message,
		"progression": session.player_state.progression.duplicate(true) if session != null and session.player_state != null else {},
		"roster": _get_roster_snapshot(),
		"bag": _get_bag_snapshot(),
		"overworld_3d": _world_layer.get_debug_state() if _world_layer != null else {},
		"ui_animation": {
			"drawer_transition_active": _drawer_transition_active,
			"modal_transition_active": _modal_transition_active,
			"drawer_visible": _npc_panel != null and _npc_panel.visible,
			"dim_visible": _dim_overlay != null and _dim_overlay.visible,
			"modal_visible": _save_load_modal != null and _save_load_modal.visible,
		},
		"last_move_result": _last_move_result.duplicate(true),
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
	var tool_buttons := {}
	for key in _tool_buttons.keys():
		var tool_button := _tool_buttons[key] as Button
		tool_buttons[str(key)] = _control_rect_dict(tool_button)
	var tab_buttons := {}
	for key in _tab_buttons.keys():
		var tab_button := _tab_buttons[key] as Button
		tab_buttons[str(key)] = _control_rect_dict(tab_button)
	return {
		"viewport": _rect_dict(get_viewport().get_visible_rect()),
		"prompt_button": _control_rect_dict(_prompt_button),
		"npc_panel": _control_rect_dict(_npc_panel),
		"close_button": _control_rect_dict(_close_button),
		"npc_action_buttons": action_buttons,
		"shop_buy_buttons": buy_buttons,
		"trainer_button": _control_rect_dict(_trainer_button),
		"tool_buttons": tool_buttons,
		"tab_buttons": tab_buttons,
		"save_load_modal": _control_rect_dict(_save_load_modal),
		"save_slot_buttons": _slot_button_rects(_save_slot_buttons),
		"load_slot_buttons": _slot_button_rects(_load_slot_buttons),
		"modal_close_button": _control_rect_dict(_modal_close_button),
	}


func _slot_button_rects(slot_buttons: Dictionary) -> Dictionary:
	var result := {}
	for slot in slot_buttons.keys():
		result[str(slot)] = _control_rect_dict(slot_buttons[slot] as Button)
	return result


func move_player(delta_coord: Vector2i) -> Dictionary:
	if app_state != AppState.OVERWORLD:
		return {
			"ok": false,
			"message": "cannot move while state is %s" % _state_name(app_state),
			"data": get_dev_agent_state(),
		}
	return goto_tile(_get_player_coord() + delta_coord)


func goto_tile(target_coord: Vector2i) -> Dictionary:
	if app_state != AppState.OVERWORLD or _is_field_input_blocked():
		return {
			"ok": false,
			"message": "cannot move while UI or battle is active",
			"data": get_dev_agent_state(),
		}
	if _world_layer != null and _world_layer.is_move_animation_active():
		return {
			"ok": false,
			"message": "move animation is still playing",
			"data": get_dev_agent_state(),
		}
	if _move_controller == null:
		return {
			"ok": false,
			"message": "overworld move controller is not ready",
			"data": get_dev_agent_state(),
		}
	var result := _move_controller.move_actor_to(InkMonOverworldGrid.PLAYER_ID, target_coord)
	_last_move_result = result.duplicate(true)
	var data := result.get("data", {}) as Dictionary
	# move_controller 已更新 grid occupant (运行真相); 不再往 session 写位置 (§3 不双写)。
	var final_coord := _coord_from_dict(data.get("final_coord", _get_player_coord_dict()))
	var resolved_coord := _coord_from_dict(data.get("resolved_target", _get_player_coord_dict()))
	var path := _path_from_dicts(data.get("path", []) as Array)
	if bool(result.get("ok", false)):
		_near_npc_id = ""
		if _world_layer != null:
			_world_layer.play_player_path(path, target_coord, resolved_coord)
		if _world_layer == null or not _world_layer.is_move_animation_active():
			_refresh_near_npc()
	else:
		_refresh_near_npc()
	_refresh_ui()
	if bool(result.get("ok", false)):
		_add_event("player move started to %s,%s" % [final_coord.x, final_coord.y])
	else:
		_add_event("move rejected: %s" % str(result.get("message", "")))
	return _scene_result(bool(result.get("ok", false)), str(result.get("message", "")))


func right_click_at(screen_position: Vector2) -> Dictionary:
	if _world_layer == null:
		return _scene_result(false, "3D overworld view is not ready")
	var pick := _world_layer.pick_coord_from_screen(screen_position)
	if not bool(pick.get("ok", false)):
		return _scene_result(false, str(pick.get("message", "right-click did not hit a tile")))
	var coord := pick.get("coord", Vector2i.ZERO) as Vector2i
	return goto_tile(coord)


func get_tile_screen_position(coord: Vector2i) -> Dictionary:
	if _world_layer == null:
		return {
			"ok": false,
			"message": "3D overworld view is not ready",
			"data": {},
		}
	return _world_layer.get_tile_screen_position(coord)


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
	_drawer_mode = "npc"
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
	_drawer_mode = ""
	_last_ui_message = "closed"
	_refresh_ui()
	_add_event("npc menu closed")
	return {
		"ok": true,
		"message": "npc menu closed",
		"data": get_dev_agent_state(),
	}


func open_player_panel(panel_id: String) -> Dictionary:
	if not ["party", "bag", "journal"].has(panel_id):
		return _scene_result(false, "unknown player panel: %s" % panel_id)
	if app_state == AppState.BATTLE:
		return _scene_result(false, "cannot open player panel during battle")
	app_state = AppState.OVERWORLD
	_active_npc_id = ""
	_drawer_mode = panel_id
	_last_ui_message = "%s panel opened" % panel_id
	_refresh_ui()
	_add_event(_last_ui_message)
	return _scene_result(true, _last_ui_message)


func close_drawer() -> Dictionary:
	app_state = AppState.OVERWORLD
	_active_npc_id = ""
	_drawer_mode = ""
	_refresh_ui()
	return _scene_result(true, "drawer closed")


func open_save_load_menu() -> Dictionary:
	if _save_load_modal == null:
		return _scene_result(false, "save/load modal is not ready")
	_drawer_mode = ""
	_active_npc_id = ""
	app_state = AppState.OVERWORLD
	_modal_open_requested = true
	_refresh_panel()
	_animate_modal_open()
	_last_ui_message = "save/load opened"
	_add_event(_last_ui_message)
	return _scene_result(true, _last_ui_message)


func close_save_load_menu() -> Dictionary:
	_modal_open_requested = false
	if _save_load_modal != null:
		_animate_modal_close()
	_last_ui_message = "save/load closed"
	return _scene_result(true, _last_ui_message)


func buy_shop_item(config_id: StringName) -> Dictionary:
	if app_state != AppState.NPC_MENU or _active_npc_id != "shop":
		return {
			"ok": false,
			"message": "shop is not open",
			"data": get_dev_agent_state(),
		}
	# 购买规则住 shop handler (收 session); 导播只转发 + 刷 UI。
	var shop := _npc_handlers["shop"] as InkMonShopNpcHandler
	var result := shop.buy(session, config_id)
	var ok := bool(result.get("ok", false))
	var message := str(result.get("message", ""))
	if message != "":
		_last_ui_message = message
		if ok:
			_add_event(message)
	_refresh_ui()
	return _scene_result(ok, message)


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
	# handler 只收 session 自含规则; 不再反持 app_root (§5)。
	var result := handler.run_action(action_id, session)
	# Command-as-data: handler 返回 flow intent, 导播解释并执行 (起 battle procedure)。
	var intent := result.get(InkMonNpcHandler.RESULT_INTENT, {}) as Dictionary
	if intent != null and str(intent.get(InkMonNpcHandler.INTENT_KIND, "")) == InkMonTrainingNpcHandler.INTENT_START_BATTLE:
		_active_npc_id = ""
		return run_training_battle_to_completion(8)
	var ok := bool(result.get("ok", false))
	var message := str(result.get("message", ""))
	if message != "":
		_last_ui_message = message
		_add_event(message)
	_refresh_ui()
	return _scene_result(ok, message)


func save_game(save_path: String = DEFAULT_SAVE_PATH) -> Dictionary:
	# save 侧: 把运行时 grid 玩家位置写回存档字段一次, 再序列化 (§3 不双写)。
	_sync_player_coord_to_session()
	var save_data := session.to_dict()
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return _scene_result(false, "save open failed: %s" % str(FileAccess.get_open_error()))
	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()
	_add_event("saved game: %s" % save_path)
	return _scene_result(true, "saved game")


## 多槽存档便捷封装 (§8b); 底层仍复用 path-based save_game/load_game。
func save_to_slot(slot: int) -> Dictionary:
	return save_game(_slot_path(slot))


func load_from_slot(slot: int) -> Dictionary:
	return load_game(_slot_path(slot))


func list_save_slots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot in range(1, SAVE_SLOT_COUNT + 1):
		result.append({"slot": slot, "exists": FileAccess.file_exists(_slot_path(slot))})
	return result


func _slot_path(slot: int) -> String:
	return "user://inkmon_l2_save_slot%d.json" % slot


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
	var save_loaded := session.from_dict(data)
	last_battle_result = {}
	_active_instance_id = ""
	_world_gi = null
	_active_npc_id = ""
	_drawer_mode = ""
	app_state = AppState.OVERWORLD
	GameWorld.destroy_all_instances()
	TimelineRegistry.reset()
	_setup_overworld_runtime()
	_cancel_overworld_animation()
	_refresh_near_npc()
	_refresh_ui()
	if not save_loaded:
		_add_event("incompatible save discarded, started new game: %s" % save_path)
		return _scene_result(true, "incompatible save discarded; started new game")
	_add_event("loaded game: %s" % save_path)
	return _scene_result(true, "loaded game")


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_RIGHT and app_state == AppState.OVERWORLD:
			right_click_at(mouse_event.position)
			get_viewport().set_input_as_handled()
		return


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
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
			KEY_E, KEY_ENTER, KEY_SPACE:
				if app_state == AppState.OVERWORLD and _drawer_mode == "":
					open_near_npc_menu()
			KEY_P:
				open_player_panel("party")
			KEY_B:
				open_player_panel("bag")
			KEY_J:
				open_player_panel("journal")
			KEY_ESCAPE:
				if _save_load_modal != null and _save_load_modal.visible:
					close_save_load_menu()
				elif _drawer_mode != "":
					close_drawer()
				else:
					open_save_load_menu()


func _tick_active_instance(dt: float) -> void:
	var instance := GameWorld.get_instance_by_id(_active_instance_id)
	if instance != null and instance.is_running():
		instance.tick(dt)


func _complete_battle_if_ready() -> void:
	if app_state != AppState.BATTLE or _world_gi == null:
		return
	if _world_gi.has_active_battle():
		return

	last_battle_result = _world_gi.get_result_summary()
	session.player_state.apply_battle_result(last_battle_result)
	# 持久 world GI: 不销毁 (战斗结束已切回主世界 grid); 只清 active 标记回到主世界态。
	_active_instance_id = ""
	app_state = AppState.OVERWORLD
	_active_npc_id = ""
	_drawer_mode = ""
	_last_ui_message = "battle completed"
	_refresh_ui()
	_add_event("battle completed: %s" % str(last_battle_result.get("result", "")))


func _setup_overworld_runtime() -> void:
	# 唯一持久 world GI: 承载世界数据 + 主世界 grid + (战斗期) battle procedure (World-owns-Battle)。
	_world_gi = GameWorld.create_instance(func() -> GameplayInstance:
		return InkMonWorldGI.new()
	) as InkMonWorldGI
	Log.assert_crash(_world_gi != null, "InkMonGameDirector", "failed to create InkMonWorldGI")
	# 主世界 grid wrapper 归 main 层所有; 只把底层 GridMapModel bind 给 world GI 做 active 切换。
	_overworld_grid = InkMonOverworldGrid.new()
	_overworld_grid.setup(InkMonOverworldGrid.MAP_RADIUS)
	# load 侧读: 用存档字段把玩家放到 grid (此后 grid occupant 即运行真相)。
	_overworld_grid.sync_occupants(_saved_player_coord(), _npc_defs)
	_world_gi.bind_overworld_grid(_overworld_grid.model)
	_move_controller = InkMonOverworldMoveController.new()
	_move_controller.setup(_overworld_grid)
	# move_completed 不再订阅: grid occupant 即玩家位置真相, 无需回写 session (§3)。
	_move_controller.move_rejected.connect(_on_overworld_move_rejected)


func _on_player_move_animation_finished(final_coord: Vector2i) -> void:
	# grid occupant 已是真相 (move_controller 更新); 动画结束只刷 UI / NPC 邻近, 不写 session。
	_refresh_near_npc()
	_refresh_ui()
	_add_event("player move animation finished at %s,%s" % [final_coord.x, final_coord.y])


func _cancel_overworld_animation() -> void:
	# Kill any in-flight move tween (killing does NOT emit player_move_animation_finished,
	# so it cannot overwrite a freshly reset/loaded coord) and drop stale path/target feedback.
	if _world_layer == null:
		return
	_world_layer.snap_player_coord(_get_player_coord())
	_world_layer.clear_move_feedback()


func _on_overworld_move_rejected(actor_id: String, _from_coord: Vector2i, _target_coord: Vector2i, reason: String) -> void:
	if actor_id == InkMonOverworldGrid.PLAYER_ID:
		_last_ui_message = reason


func _build_world_and_ui() -> void:
	_world_layer = InkMonOverworldView3DScript.new() as InkMonOverworldView3D
	_world_layer.name = "WorldLayer"
	_world_layer.set_npcs(_npc_defs)
	_world_layer.player_move_animation_finished.connect(_on_player_move_animation_finished)
	add_child(_world_layer)

	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "HUDLayer"
	_hud_layer.layer = 2
	add_child(_hud_layer)
	_hud_root = HudContentScene.instantiate() as Control
	_hud_root.name = "HUDRoot"
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

	_modal_layer = CanvasLayer.new()
	_modal_layer.name = "ModalLayer"
	_modal_layer.layer = 3
	add_child(_modal_layer)
	_build_save_load_modal()


func _build_hud() -> void:
	# 结构 / 主题在 hud_content.tscn; 这里取引用 + 连 tool 按钮 signal。
	_gold_label = _hud_root.get_node("TopLeftHud/HudBox/GoldRankRow/GoldLabel") as Label
	_rank_label = _hud_root.get_node("TopLeftHud/HudBox/GoldRankRow/RankLabel") as Label
	_roster_box = _hud_root.get_node("TopLeftHud/HudBox/RosterChips") as HBoxContainer
	var tools := _hud_root.get_node("TopRightTools") as HBoxContainer
	_register_tool_button(tools, "party")
	_register_tool_button(tools, "bag")
	_register_tool_button(tools, "journal")
	_register_tool_button(tools, "menu")


func _register_tool_button(parent: Control, panel_id: String) -> void:
	var button := parent.get_node("Tool_%s" % panel_id.capitalize()) as Button
	button.pressed.connect(func() -> void:
		if panel_id == "menu":
			open_save_load_menu()
		else:
			open_player_panel(panel_id)
	)
	_tool_buttons[panel_id] = button


func _build_panel() -> void:
	# 结构 / 主题 / 初始可见性在 right_drawer.tscn; 这里 instantiate + 取引用 + 连 signal。
	var panel_root := RightDrawerScene.instantiate() as Control
	panel_root.name = "PanelRoot"
	_panel_layer.add_child(panel_root)

	_dim_overlay = panel_root.get_node("DimOverlay") as ColorRect
	_dim_overlay.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mouse_event := event as InputEventMouseButton
			if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
				close_drawer()
	)

	_npc_panel = panel_root.get_node("RightDrawer") as PanelContainer
	_panel_title = panel_root.get_node("RightDrawer/PanelBox/PanelHeader/PanelTitle") as Label
	_close_button = panel_root.get_node("RightDrawer/PanelBox/PanelHeader/PanelCloseButton") as Button
	_close_button.pressed.connect(func() -> void:
		close_drawer()
	)
	_tab_bar = panel_root.get_node("RightDrawer/PanelBox/PanelTabs") as HBoxContainer
	_panel_body = panel_root.get_node("RightDrawer/PanelBox/PanelBody") as VBoxContainer
	_register_tab_button("party")
	_register_tab_button("bag")
	_register_tab_button("journal")


func _register_tab_button(panel_id: String) -> void:
	var button := _tab_bar.get_node("Tab_%s" % panel_id.capitalize()) as Button
	button.pressed.connect(func() -> void:
		open_player_panel(panel_id)
	)
	_tab_buttons[panel_id] = button


func _build_save_load_modal() -> void:
	# 结构 / 主题 / 初始可见性在 save_load_modal.tscn; 这里 instantiate + 取引用 + 连 signal。
	var modal_root := SaveLoadModalScene.instantiate() as Control
	modal_root.name = "ModalRoot"
	_modal_layer.add_child(modal_root)

	_modal_overlay = modal_root.get_node("ModalOverlay") as ColorRect
	_modal_overlay.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mouse_event := event as InputEventMouseButton
			if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
				close_save_load_menu()
	)

	_save_load_modal = modal_root.get_node("SaveLoadModal") as PanelContainer
	_save_slot_buttons.clear()
	_load_slot_buttons.clear()
	for slot in range(1, SAVE_SLOT_COUNT + 1):
		_register_save_slot(modal_root, slot)
	_modal_close_button = modal_root.get_node("SaveLoadModal/SaveLoadBox/ModalCloseButton") as Button
	_modal_close_button.pressed.connect(func() -> void:
		close_save_load_menu()
	)


func _register_save_slot(modal_root: Node, slot: int) -> void:
	var save_button := modal_root.get_node("SaveLoadModal/SaveLoadBox/Slot%dRow/SaveSlot%d" % [slot, slot]) as Button
	save_button.pressed.connect(func() -> void:
		save_to_slot(slot)
		_refresh_ui()
	)
	_save_slot_buttons[slot] = save_button
	var load_button := modal_root.get_node("SaveLoadModal/SaveLoadBox/Slot%dRow/LoadSlot%d" % [slot, slot]) as Button
	load_button.pressed.connect(func() -> void:
		load_from_slot(slot)
		close_save_load_menu()
	)
	_load_slot_buttons[slot] = load_button


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
			"skill_slots": [{"slot_index": 0, "skill_id": skills[i]}],
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
		_prompt_button.text = "[E] Talk"
		_prompt_button.position = _world_layer.coord_to_screen(coord) + Vector2(-54, -82)

	if _npc_panel != null:
		var size := get_viewport().get_visible_rect().size
		var panel_width := maxf(420.0, size.x * 0.40)
		_npc_panel.position = Vector2(size.x - panel_width - 24.0, 104.0)
		_npc_panel.size = Vector2(panel_width, size.y - 148.0)
	if _save_load_modal != null:
		var viewport_size := get_viewport().get_visible_rect().size
		var modal_size := Vector2(380.0, 270.0)
		_save_load_modal.position = (viewport_size - modal_size) * 0.5
		_save_load_modal.size = modal_size
		_save_load_modal.pivot_offset = modal_size * 0.5


func _animate_drawer_open() -> void:
	if _npc_panel == null or _drawer_transition_active:
		return
	var target_position := _npc_panel.position
	var start_position := target_position + Vector2(_npc_panel.size.x + 32.0, 0.0)
	_npc_panel.position = start_position
	_drawer_transition_active = true
	_kill_drawer_tween()
	_drawer_transition_tween = create_tween()
	_drawer_transition_tween.tween_property(_npc_panel, "position", target_position, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_drawer_transition_tween.finished.connect(func() -> void:
		_drawer_transition_active = false
	)


func _animate_drawer_close() -> void:
	if _npc_panel == null or not _npc_panel.visible:
		return
	# Kill any in-flight open/close tween and run the close from the current position,
	# so a close requested mid-open cannot leave a ghost drawer + click-blocking dim.
	_kill_drawer_tween()
	_drawer_transition_active = true
	var target_position := _npc_panel.position + Vector2(_npc_panel.size.x + 32.0, 0.0)
	_drawer_transition_tween = create_tween()
	_drawer_transition_tween.tween_property(_npc_panel, "position", target_position, 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_drawer_transition_tween.finished.connect(func() -> void:
		_drawer_transition_active = false
		# A re-open may have happened during the close tween; do not hide what is now open.
		if _drawer_mode != "":
			return
		_npc_panel.visible = false
		if _dim_overlay != null:
			_dim_overlay.visible = false
	)


func _animate_modal_open() -> void:
	if _save_load_modal == null:
		return
	_kill_modal_tween()
	_layout_ui()
	_save_load_modal.visible = true
	if _modal_overlay != null:
		_modal_overlay.visible = true
	_save_load_modal.scale = Vector2(0.92, 0.92)
	_modal_transition_active = true
	_modal_transition_tween = create_tween()
	_modal_transition_tween.tween_property(_save_load_modal, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_modal_transition_tween.finished.connect(func() -> void:
		_modal_transition_active = false
	)


func _animate_modal_close() -> void:
	if _save_load_modal == null or not _save_load_modal.visible:
		return
	_kill_modal_tween()
	_modal_transition_active = true
	_modal_transition_tween = create_tween()
	_modal_transition_tween.tween_property(_save_load_modal, "scale", Vector2(0.94, 0.94), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_modal_transition_tween.finished.connect(func() -> void:
		_modal_transition_active = false
		# A re-open may have happened during the close tween; keep the full-rect
		# MOUSE_FILTER_STOP overlay in sync with intent to avoid an input blackhole.
		if _modal_open_requested:
			return
		_save_load_modal.visible = false
		_save_load_modal.scale = Vector2.ONE
		if _modal_overlay != null:
			_modal_overlay.visible = false
	)


func _kill_drawer_tween() -> void:
	if _drawer_transition_tween != null and _drawer_transition_tween.is_valid():
		_drawer_transition_tween.kill()
	_drawer_transition_tween = null


func _kill_modal_tween() -> void:
	if _modal_transition_tween != null and _modal_transition_tween.is_valid():
		_modal_transition_tween.kill()
	_modal_transition_tween = null


func _refresh_roster_chips() -> void:
	if _roster_box == null:
		return
	for child in _roster_box.get_children():
		child.queue_free()
	for entry in session.player_state.roster:
		var chip := RosterChipScene.instantiate() as PanelContainer
		chip.name = "RosterChip_%d" % entry.entry_id
		# 样式在 roster_chip.tscn (local-to-scene StyleBox); 代码只填数据驱动的描边色。
		var style := chip.get_theme_stylebox("panel") as StyleBoxFlat
		if style != null:
			style.border_color = _element_color(entry.elements[0] if not entry.elements.is_empty() else "")
		(chip.get_node("ChipLabel") as Label).text = "%s\nLv%d" % [_role_short(entry.role), entry.level]
		_roster_box.add_child(chip)


func _refresh_prompt() -> void:
	if _prompt_button == null:
		return
	_prompt_button.visible = app_state == AppState.OVERWORLD and _near_npc_id != "" and _drawer_mode == "" and not _is_modal_open()
	_layout_ui()


func _refresh_panel() -> void:
	if _dim_overlay == null or _npc_panel == null:
		return
	var open := _drawer_mode != ""
	if not open:
		_animate_drawer_close()
		return
	# Re-opening: cancel any in-flight close tween so its finished callback cannot hide
	# the drawer we are about to show, and play a fresh slide-in.
	var interrupted_transition := _drawer_transition_active
	_kill_drawer_tween()
	_drawer_transition_active = false
	var animate_open := interrupted_transition or not _npc_panel.visible
	_dim_overlay.visible = true
	_npc_panel.visible = true
	if _tab_bar != null:
		_tab_bar.visible = _drawer_mode != "npc"
	if _drawer_mode == "npc":
		var npc_def := _npc_defs[_active_npc_id] as Dictionary
		_panel_title.text = str(npc_def.get("display_name", _active_npc_id))
	else:
		_panel_title.text = _drawer_mode.capitalize()
	_rebuild_panel_body()
	_layout_ui()
	if animate_open:
		_animate_drawer_open()


func _rebuild_panel_body() -> void:
	for child in _panel_body.get_children():
		child.queue_free()
	_action_buttons.clear()
	_shop_buy_buttons.clear()
	_trainer_button = null
	if _drawer_mode == "party":
		_build_party_panel()
		return
	if _drawer_mode == "bag":
		_build_bag_panel()
		return
	if _drawer_mode == "journal":
		_build_journal_panel()
		return

	var handler := _get_active_handler()
	if handler == null:
		var placeholder := PanelMessageScene.instantiate() as Label
		placeholder.text = "System linked"
		_panel_body.add_child(placeholder)
		return

	var actions := handler.get_actions(session)
	for action in actions:
		_add_action_row(action)


func _build_party_panel() -> void:
	for entry in session.player_state.roster:
		var row := PartyEntryRowScene.instantiate() as HBoxContainer
		row.name = "PartyEntry_%d" % entry.entry_id
		(row.get_node("ElementSwatch") as ColorRect).color = _element_color(
			entry.elements[0] if not entry.elements.is_empty() else "")

		var label := row.get_node("PartyEntryLabel") as Label
		label.text = "%s  Lv%d  %s\n%s  EXP %d  Skill %s" % [
			entry.species,
			entry.level,
			entry.role,
			", ".join(entry.elements),
			entry.exp,
			entry.get_primary_skill_id(),
		]
		label.modulate = Color(0.92, 0.88, 0.78)

		var stats := row.get_node("StatsLabel") as Label
		var derived: Dictionary = entry.derive_battle_stats()
		stats.text = "HP %d  AD %d  AP %d\nArmor %d  MR %d  SPD %d" % [
			int(float(derived.get("max_hp", 0.0))),
			int(float(derived.get("ad", 0.0))),
			int(float(derived.get("ap", 0.0))),
			int(float(derived.get("armor", 0.0))),
			int(float(derived.get("mr", 0.0))),
			int(float(derived.get("speed", 0.0))),
		]
		stats.modulate = Color(0.82, 0.78, 0.68)
		_panel_body.add_child(row)


func _build_bag_panel() -> void:
	var bag_items := _get_bag_snapshot()
	if bag_items.is_empty():
		var empty := PanelMessageScene.instantiate() as Label
		empty.name = "BagEmptyLabel"
		empty.text = "Bag is empty."
		_panel_body.add_child(empty)
		return

	for item in bag_items:
		var row := BagItemRowScene.instantiate() as HBoxContainer
		row.name = "BagItem_%s" % str(item.get("config_id", "unknown"))
		var cfg := ItemSystem.get_item_config(StringName(str(item.get("config_id", ""))))
		var label := row.get_node("BagItemLabel") as Label
		label.text = "%s x%d\n%s" % [
			str(cfg.get("display_name", item.get("config_id", ""))),
			int(item.get("count", 1)),
			str(cfg.get("description", "Inventory item")),
		]
		label.modulate = Color(0.92, 0.88, 0.78)
		_panel_body.add_child(row)


func _build_journal_panel() -> void:
	var progression := session.player_state.progression
	var lines := PackedStringArray([
		"Trainer Rank: R%d" % int(progression.get("trainer_rank", 1)),
		"Guild Joined: %s" % ("yes" if bool(progression.get("guild_joined", false)) else "no"),
		"Cultivation Points: %d" % int(progression.get("cultivation_points", 0)),
		"Guild Tasks: %d" % int(progression.get("guild_tasks_completed", 0)),
	])
	if not last_battle_result.is_empty():
		lines.append("Last Battle: %s / winner %s" % [
			str(last_battle_result.get("result", "")),
			str(last_battle_result.get("winner_team", "")),
		])
	var panel := JournalPanelScene.instantiate()
	(panel.get_node("JournalSummary") as Label).text = "\n".join(lines)
	(panel.get_node("OpenSystemMenu") as Button).pressed.connect(func() -> void:
		open_save_load_menu()
	)
	_panel_body.add_child(panel)


func _add_action_row(action: Dictionary) -> void:
	var row := NpcActionRowScene.instantiate() as HBoxContainer
	row.name = "ActionRow_%s" % str(action.get(InkMonNpcHandler.ACTION_ID, "unknown"))
	(row.get_node("ItemLabel") as Label).text = "%s\n%s" % [
		str(action.get(InkMonNpcHandler.ACTION_LABEL, "")),
		str(action.get(InkMonNpcHandler.ACTION_DETAIL, "")),
	]
	var action_id := str(action.get(InkMonNpcHandler.ACTION_ID, ""))
	var button := row.get_node("ActionButton") as Button
	button.name = "Action_%s" % action_id
	button.text = "Buy" if str(action.get(InkMonNpcHandler.ACTION_KIND, "")) == "shop_buy" else "Go"
	button.disabled = not bool(action.get(InkMonNpcHandler.ACTION_ENABLED, true))
	button.pressed.connect(func() -> void:
		run_active_npc_action(action_id)
	)
	_panel_body.add_child(row)
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


## 运行时玩家位置真相 = 主世界 grid 的 occupant (不双写, §3)。grid 未建时回退存档字段。
func _get_player_coord() -> Vector2i:
	if _overworld_grid != null:
		return _overworld_grid.get_player_coord()
	return _saved_player_coord()


## 存档字段里的玩家位置: 只在 load 侧读 (放 occupant) / save 侧写, 中间不双写。
func _saved_player_coord() -> Vector2i:
	var coord := session.player_state.overworld.get("player_coord", {}) as Dictionary
	if coord == null:
		return Vector2i.ZERO
	return Vector2i(int(coord.get("q", 0)), int(coord.get("r", 0)))


## save 侧: 把运行时 grid 位置写回存档字段一次。
func _sync_player_coord_to_session() -> void:
	var coord := _get_player_coord()
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


func _coord_from_dict(value: Variant) -> Vector2i:
	var dict := value as Dictionary
	if dict == null:
		return Vector2i.ZERO
	return Vector2i(int(dict.get("q", 0)), int(dict.get("r", 0)))


func _path_from_dicts(value: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for coord_value in value:
		result.append(_coord_from_dict(coord_value))
	return result


func _is_modal_open() -> bool:
	return _save_load_modal != null and _save_load_modal.visible


func _is_field_input_blocked() -> bool:
	return _drawer_mode != "" or _is_modal_open() or (_world_layer != null and _world_layer.is_move_animation_active())


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
		InkMonElementChart.EARTH:
			return Color(0.65, 0.50, 0.35)
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
