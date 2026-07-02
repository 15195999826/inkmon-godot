class_name InkMonWorldPresentation
extends Node
## 主世界表演层根节点 (docs/main-game-architecture.md §1)。持全部 UI 子树
## (iso overworld view / HUD / drawer / modal / InkMonWorldPanelView) + 其 layout/animation/build/refresh,
## 以及 dev-agent 的 UI debug 表面。
##
## CQRS 三通道:① Query 经 _world_query(IWorldQuery facade)只读读 (roster/gold/near-npc/npc actions);
## ② Command 经 _world_query.submit(InkMonWorldCommand) 写;③ Event 由 Host 连 gi.mutation signal 到本节点
## 的 _on_* handler(表演不持 GI,故 signal 也不经表演连)被动刷新。
## **_world_query 是 IWorldQuery facade(私有持 gi),表演物理上够不到 concrete GI / flow / lifecycle**
## —— 不再是约定级,而是结构隔离(无 get_gi 逃逸口)。flow/lifecycle 归 Host 控制面。
##
## 需要 Host 做 flow/lifecycle 的(起战斗 / 存读档槽)经信号上抛给 Host —— 表演不依赖 Host(单向 DAG)。


const InkMonOverworldViewScript := preload("res://inkmon/presentation/overworld/ink_mon_overworld_view.gd")
# UI 动态列表组件场景 (§6: 动态列表用 instantiate 组件场景)。
const NpcActionRowScene := preload("res://inkmon/presentation/ui/components/npc_action_row.tscn")
const PanelMessageScene := preload("res://inkmon/presentation/ui/components/panel_message.tscn")
# 静态 UI 容器场景 (§6: HUD / drawer / modal 全 .tscn)。
const SaveLoadModalScene := preload("res://inkmon/presentation/ui/save_load_modal.tscn")
const RightDrawerScene := preload("res://inkmon/presentation/ui/right_drawer.tscn")
const HudContentScene := preload("res://inkmon/presentation/ui/hud_content.tscn")

const SAVE_SLOT_COUNT := 3

## app_state 派生:BATTLE 由 Host 推入的 _battle_active(_active_instance_id 真相在 Host),
## NPC_MENU 由 _drawer_mode == "npc",否则 OVERWORLD。单一真相,无独立状态机。
enum AppState { OVERWORLD, BATTLE, NPC_MENU }

## 表演需要 Host 做 flow/lifecycle 时上抛(单向 DAG:表演不引用 Host,Host connect 这些信号)。
signal flow_intent_raised(intent: Dictionary)
signal save_slot_requested(slot: int)
signal load_slot_requested(slot: int)
## 玩家在战斗结果界面确认离开(回放观看期结束)→ Host 据此解冻世界泵。
signal battle_view_left()

## CQRS 读+写句柄 = IWorldQuery facade(私有持 gi,只暴露 read+submit)。表演物理上够不到 concrete GI / flow / lifecycle。
var _world_query: IWorldQuery = null
## 战斗 flow 状态由 Host 推入(set_battle_active);表演据此派生 app_state,不自持 _active_instance_id。
var _battle_active := false
## 最近一场战斗结果由 Host 经 on_battle_completed 推入,用于 journal 面板 + debug 表面。
var _last_battle_result: Dictionary = {}
## adr/0005:战斗 2D 回放视图(占位,懒建)+ 回放中标志 + 待收尾结果。回放期 _replaying 接管 BATTLE 态。
var _battle_2d_view: InkMonBattle2DView = null
var _replaying := false
var _pending_battle_result: Dictionary = {}

## 数据驱动 panel 内容构建器(纯表演,据数据建 Control 行)。
var _panel_view := InkMonWorldPanelView.new()

var _active_npc_id := ""
var _last_ui_message := ""
var _last_move_result: Dictionary = {}
var _event_log: Array[String] = []

var _world_layer: InkMonOverworldView
var _hud_layer: CanvasLayer
var _hud_root: Control
var _gold_label: Label
var _rank_label: Label
var _roster_box: HBoxContainer
var _tool_buttons: Dictionary = {}
var _prompt_layer: CanvasLayer
var _prompt_button: Button
var _panel_layer: CanvasLayer
## right drawer 子场景控制器 (§6 已下放: 骨架/动画/停靠布局在 InkMonRightDrawer, root 只填内容+接线)。
var _drawer_view: InkMonRightDrawer
## drawer 内容容器缓存 (= _drawer_view.get_body(); 数据驱动填充仍归 root)。
var _panel_body: VBoxContainer
var _action_buttons: Dictionary = {}
var _shop_buy_buttons: Dictionary = {}
var _trainer_button: Button
var _drawer_mode := ""
var _modal_layer: CanvasLayer
## save/load modal 子场景控制器 (§6 已下放: 行为/动画/布局全在 InkMonSaveLoadModal, root 只接线)。
var _save_load_modal_view: InkMonSaveLoadModal
## NPC 视觉节点据 npc_defs(常量 stub)建一次即可;set_npcs 会 queue_free+重建,故不放进每帧 _refresh_ui。
var _npcs_initialized := false


## near-npc 真相在 Logic;表演只读委托。
var _near_npc_id: String:
	get:
		return _world_query.near_npc_id if _world_query != null else ""
## npc 表快照 (bind_world 取一次; NPC 是常量 stub, 跨 world 重建不变)。Wave 3: 读通道全 snapshot,
## 表演不再持任何活 actor / 逻辑层 Dict 引用 (玩家/roster/bag 数据均按需经 query 取投影)。
var _npc_defs: Dictionary = {}
## app_state 派生:战斗 > NPC 菜单 > 主世界。
var app_state: AppState:
	get:
		if _battle_active or _replaying:
			return AppState.BATTLE
		if _drawer_mode == "npc":
			return AppState.NPC_MENU
		return AppState.OVERWORLD


func _ready() -> void:
	name = "Presentation"
	_build_world_and_ui()


func _process(_delta: float) -> void:
	_layout_ui()


# === Host 接线 / 控制面推入 (Host → Presentation, 单向) ===

## 绑定 IWorldQuery facade(read+submit 句柄)。Host 每次(重)建 GI 后调用,并由 Host 另行连 mutation signal
## 到本节点的 _on_* handler(Host 持 concrete GI 做接线;表演不持 GI,故 signal 也不经表演连)。
func bind_world(query: IWorldQuery) -> void:
	_world_query = query
	_npc_defs = query.get_npc_defs_snapshot()
	# NPC 视觉节点建一次(npc_defs 是常量 stub,跨 world 重建不变);避免每帧 refresh 重建。
	if _world_layer != null and not _npcs_initialized:
		_world_layer.set_npcs(_npc_defs)
		_npcs_initialized = true
	_refresh_ui()


## Host 推入战斗 flow 状态(_active_instance_id 真相在 Host;表演据此派生 app_state)。
func set_battle_active(active: bool) -> void:
	_battle_active = active


## Host 在战斗结束后调:回到主世界态 + 展示结果 + 刷新。
func on_battle_completed(result: Dictionary) -> void:
	_last_battle_result = result
	_active_npc_id = ""
	_drawer_mode = ""
	_last_ui_message = "battle completed"
	_refresh_ui()
	add_event("battle completed: %s" % str(result.get("result", "")))


## Host 在战斗结束(有录像)时调:隐藏 overworld,起 2D 回放;_replaying 接管 BATTLE 态,
## 直到玩家在结果界面确认离开(leave_requested),非播完即回(game-vision §2 体验流)。
func play_battle_replay(replay_data: Dictionary, result: Dictionary) -> void:
	_pending_battle_result = result
	if _battle_2d_view == null:
		_battle_2d_view = InkMonBattle2DView.new()
		_battle_2d_view.name = "Battle2DView"
		add_child(_battle_2d_view)
		_battle_2d_view.leave_requested.connect(_on_battle_leave_requested)
	_replaying = true
	if _world_layer != null:
		_world_layer.visible = false
	_battle_2d_view.visible = true
	_battle_2d_view.play_replay(replay_data, result)
	_refresh_prompt()


## 玩家确认离开战斗观看:恢复 overworld,清 _replaying,复用 on_battle_completed 收尾(刷 UI / journal),
## 并上抛 battle_view_left 让 Host 解冻世界泵(单向 DAG:表演不引用 Host)。
func _on_battle_leave_requested() -> void:
	_replaying = false
	if _battle_2d_view != null:
		_battle_2d_view.visible = false
	if _world_layer != null:
		_world_layer.visible = true
	var pending := _pending_battle_result
	_pending_battle_result = {}
	on_battle_completed(pending)
	battle_view_left.emit()


## Host 在 reset/load 时调:清表演侧瞬时 UI 态(不含已由 bind_world 重连的 query)。
## full=true(reset 新游戏)连 move_result/ui_message/event_log 一起清;false(load 读档)只清抽屉/npc/战斗结果,
## 保留 move_result/ui_message/events(对齐重构前 load 不清这些的行为)。
func reset_ui_state(full: bool = true) -> void:
	_active_npc_id = ""
	_drawer_mode = ""
	_last_battle_result = {}
	# reset/load 可能发生在回放观看期:拆回放态,否则战斗视图滞留、overworld 永久隐藏。
	_replaying = false
	_pending_battle_result = {}
	if _battle_2d_view != null:
		_battle_2d_view.visible = false
	if _world_layer != null:
		_world_layer.visible = true
	if full:
		_last_move_result = {}
		_last_ui_message = ""
		_event_log.clear()


## 事件日志(debug 表面 events)。Host 也经此记 flow 事件(saved game / battle started 等)。
func add_event(message: String) -> void:
	_event_log.append(message)
	while _event_log.size() > 16:
		_event_log.pop_front()


func cancel_overworld_animation() -> void:
	# Kill any in-flight move tween (killing does NOT emit player_move_animation_finished,
	# so it cannot overwrite a freshly reset/loaded coord) and drop stale path/target feedback.
	if _world_layer == null:
		return
	_world_layer.snap_player_coord(_get_player_coord())
	_world_layer.clear_move_feedback()


# === 输入 → command (CQRS 写; 表演 submit, 不读返回值) ===

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
				if _is_modal_open():
					close_save_load_menu()
				elif _drawer_mode != "":
					close_drawer()
				else:
					open_save_load_menu()


func move_player(delta_coord: Vector2i) -> Dictionary:
	if app_state != AppState.OVERWORLD:
		return _result(false, "cannot move while state is %s" % _state_name(app_state))
	return goto_tile(_get_player_coord() + delta_coord)


func goto_tile(target_coord: Vector2i) -> Dictionary:
	if app_state != AppState.OVERWORLD or _is_field_input_blocked():
		return _result(false, "cannot move while UI or battle is active")
	if _world_query == null:
		return _result(false, "world is not ready")
	# Command(写)= 异步唯一入口:submit(InkMonMoveCommand);tick drain 逐格应用,经 actor_position_changed 回流刷表演。
	# latest-wins(方案 A):连点不打断当前格,故无"动画播放中"拦截。不读返回值。
	_world_query.submit(InkMonMoveCommand.new(target_coord))
	_last_move_result = {
		"target": {"q": target_coord.x, "r": target_coord.y},
		"enqueued": true,
	}
	if _world_layer != null:
		_world_layer.show_move_target(target_coord)
	add_event("move command enqueued to %s,%s" % [target_coord.x, target_coord.y])
	_refresh_ui()
	return _result(true, "move command enqueued")


func right_click_at(screen_position: Vector2) -> Dictionary:
	if _world_layer == null:
		return _result(false, "iso overworld view is not ready")
	var pick := _world_layer.pick_coord_from_screen(screen_position)
	if not bool(pick.get("ok", false)):
		return _result(false, str(pick.get("message", "right-click did not hit a tile")))
	var coord := pick.get("coord", Vector2i.ZERO) as Vector2i
	return goto_tile(coord)


func get_tile_screen_position(coord: Vector2i) -> Dictionary:
	if _world_layer == null:
		return {"ok": false, "message": "iso overworld view is not ready", "data": {}}
	return _world_layer.get_tile_screen_position(coord)


func open_near_npc_menu() -> Dictionary:
	if _near_npc_id == "":
		return _result(false, "no nearby NPC")
	return open_npc_menu(_near_npc_id)


func open_npc_menu(npc_id: String) -> Dictionary:
	if not _npc_defs.has(npc_id):
		return _result(false, "unknown NPC: %s" % npc_id)
	_active_npc_id = npc_id
	_drawer_mode = "npc"
	_last_ui_message = "%s opened" % str((_npc_defs[npc_id] as Dictionary).get("display_name", npc_id))
	_refresh_ui()
	add_event("npc menu opened: %s" % npc_id)
	return _result(true, "npc menu opened")


func close_npc_menu() -> Dictionary:
	_active_npc_id = ""
	_drawer_mode = ""
	_last_ui_message = "closed"
	_refresh_ui()
	add_event("npc menu closed")
	return _result(true, "npc menu closed")


func open_player_panel(panel_id: String) -> Dictionary:
	if not ["party", "bag", "journal"].has(panel_id):
		return _result(false, "unknown player panel: %s" % panel_id)
	if app_state == AppState.BATTLE:
		return _result(false, "cannot open player panel during battle")
	_active_npc_id = ""
	_drawer_mode = panel_id
	_last_ui_message = "%s panel opened" % panel_id
	_refresh_ui()
	add_event(_last_ui_message)
	return _result(true, _last_ui_message)


func close_drawer() -> Dictionary:
	_active_npc_id = ""
	_drawer_mode = ""
	_refresh_ui()
	return _result(true, "drawer closed")


func open_save_load_menu() -> Dictionary:
	if _save_load_modal_view == null:
		return _result(false, "save/load modal is not ready")
	_drawer_mode = ""
	_active_npc_id = ""
	_refresh_panel()
	_save_load_modal_view.open()
	_last_ui_message = "save/load opened"
	add_event(_last_ui_message)
	return _result(true, _last_ui_message)


func close_save_load_menu() -> Dictionary:
	if _save_load_modal_view != null:
		_save_load_modal_view.close()
	_last_ui_message = "save/load closed"
	return _result(true, _last_ui_message)


func buy_shop_item(config_id: StringName) -> Dictionary:
	if app_state != AppState.NPC_MENU or _active_npc_id != "shop":
		return _result(false, "shop is not open")
	# 方案 A:购买写入队(InkMonBuyCommand),tick drain 才扣金币 + 入袋;结果经 command_applied
	# 回流到 _on_command_applied 刷 UI。不读返回值 —— 这里只回 enqueue ack。
	_world_query.submit(InkMonBuyCommand.new(config_id))
	add_event("buy command enqueued: %s" % str(config_id))
	return _result(true, "buy command enqueued")


func run_active_npc_action(action_id: String) -> Dictionary:
	if app_state != AppState.NPC_MENU or _active_npc_id == "":
		return _result(false, "no active NPC menu")
	return run_npc_action_for(_active_npc_id, action_id)


func run_npc_action_for(npc_id: String, action_id: String) -> Dictionary:
	if _world_query == null or not _world_query.has_npc_handler(npc_id):
		return _result(false, "unknown NPC handler: %s" % npc_id)
	# 方案 A:NPC action 写入队(InkMonNpcActionCommand),tick drain 才执行 handler 规则;结果
	# (含 flow intent)经 command_applied 回流到 _on_command_applied 刷 UI / 上抛 flow。不读返回值。
	_world_query.submit(InkMonNpcActionCommand.new(npc_id, action_id))
	add_event("npc action enqueued: %s/%s" % [npc_id, action_id])
	return _result(true, "npc action enqueued")


# === 上行 signal handler (Event 通道; 表演被动刷新) ===

## 玩家逐格跨越 → 表演在相邻两格间补间(≤ STEP_DURATION),非整路 tween。
func _on_world_actor_position_changed(actor_id: String, old_coord: HexCoord, new_coord: HexCoord) -> void:
	if _world_layer == null or _world_query == null:
		return
	if actor_id != "" and actor_id == _world_query.get_player_actor_id():
		_world_layer.step_player(old_coord.to_axial(), new_coord.to_axial())


## Logic near-npc 真相变 → scoped UI sync(只刷 NPC 高亮 + prompt,不整屏 refresh)。
## 走独立 signal 而非位置 handler:refresh_near_npc 在 actor_position_changed 之后才跑,
## 故位置 handler 读 near_npc_id 会陈旧一步。
func _on_near_npc_changed(_npc_id: String) -> void:
	if _world_layer == null or _world_query == null:
		return
	_world_layer.set_near_npc_id(_near_npc_id)
	_refresh_prompt()


## 方案 A 结果回流:buy/npc-action command drain 生效后据结果刷 UI message;若含 start_battle flow intent,
## 上抛 flow_intent_raised 给 Host(flow 归 Host,不归表演/command/handler)。
func _on_command_applied(result: Dictionary) -> void:
	var intent := result.get(InkMonNpcHandler.RESULT_INTENT, {}) as Dictionary
	if intent != null and str(intent.get(InkMonNpcHandler.INTENT_KIND, "")) == InkMonTrainingNpcHandler.INTENT_START_BATTLE:
		# 进战斗即关 NPC 抽屉:清 _active_npc_id + _drawer_mode 并刷新,避免 _drawer_mode=="npc" 与
		# _active_npc_id=="" 的不一致态残留(否则 _refresh_panel 的 _npc_defs[_active_npc_id] 会索引 "" 崩溃)。
		_active_npc_id = ""
		_drawer_mode = ""
		_refresh_ui()
		flow_intent_raised.emit(intent)
		return
	var message := str(result.get("message", ""))
	if message != "":
		_last_ui_message = message
		# 无条件记事件(含失败消息),对齐重构前 run_npc_action_for 的行为(它不按 ok 门控日志)。
		add_event(message)
	_refresh_ui()


# === UI 构建 (§6: 全 .tscn, 代码取引用 + 连 signal) ===

func _build_world_and_ui() -> void:
	_world_layer = InkMonOverworldViewScript.new() as InkMonOverworldView
	_world_layer.name = "WorldLayer"
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


## §6 下放后 root 只接线: instantiate 子场景 + connect 上抛信号 + 缓存内容容器;
## 骨架/动画/停靠/关闭与 tab 交互归 InkMonRightDrawer。
func _build_panel() -> void:
	_drawer_view = RightDrawerScene.instantiate() as InkMonRightDrawer
	_drawer_view.name = "PanelRoot"
	_panel_layer.add_child(_drawer_view)
	_panel_body = _drawer_view.get_body()
	_drawer_view.close_requested.connect(func() -> void:
		close_drawer()
	)
	_drawer_view.tab_selected.connect(func(panel_id: String) -> void:
		open_player_panel(panel_id)
	)


## §6 下放后 root 只接线: instantiate 子场景 + connect 上抛信号; 行为/动画/布局归 InkMonSaveLoadModal。
func _build_save_load_modal() -> void:
	_save_load_modal_view = SaveLoadModalScene.instantiate() as InkMonSaveLoadModal
	_save_load_modal_view.name = "ModalRoot"
	_modal_layer.add_child(_save_load_modal_view)
	# 存读档 = Host 控制面 lifecycle: 槽位点击 → root 转发既有上抛信号给 Host 执行。
	_save_load_modal_view.save_slot_requested.connect(func(slot: int) -> void:
		save_slot_requested.emit(slot)
		_refresh_ui()
	)
	_save_load_modal_view.load_slot_requested.connect(func(slot: int) -> void:
		load_slot_requested.emit(slot)
	)
	_save_load_modal_view.closed.connect(func() -> void:
		_last_ui_message = "save/load closed"
	)


# === 刷新 / 布局 / 动画 ===

func _refresh_ui() -> void:
	if _world_layer != null:
		_world_layer.set_player_coord(_get_player_coord())
		_world_layer.set_near_npc_id(_near_npc_id)
	if _world_query != null:
		var hud_summary := _world_query.get_player_hud_summary()
		if _gold_label != null:
			_gold_label.text = "● %d" % int(hud_summary.get("gold", -1))
		if _rank_label != null:
			_rank_label.text = "R%d" % int((hud_summary.get("progression", {}) as Dictionary).get("trainer_rank", 1))
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

func _refresh_roster_chips() -> void:
	if _roster_box == null or _world_query == null:
		return
	_panel_view.build_roster_chips(_roster_box, _world_query.get_roster_snapshot())


func _refresh_prompt() -> void:
	if _prompt_button == null:
		return
	_prompt_button.visible = app_state == AppState.OVERWORLD and _near_npc_id != "" and _drawer_mode == "" and not _is_modal_open()
	_layout_ui()


func _refresh_panel() -> void:
	if _drawer_view == null:
		return
	if _drawer_mode == "":
		_drawer_view.hide_drawer()
		return
	# 滑入动画开始前内容就绪: 先填 body 再 show (开/关 tween 竞态在 InkMonRightDrawer 内处理)。
	_rebuild_panel_body()
	var title_text := _drawer_mode.capitalize()
	if _drawer_mode == "npc":
		var npc_def := _npc_defs[_active_npc_id] as Dictionary
		title_text = str(npc_def.get("display_name", _active_npc_id))
	_drawer_view.show_drawer(title_text, _drawer_mode != "npc")


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

	if _world_query == null or not _world_query.has_npc_handler(_active_npc_id):
		var placeholder := PanelMessageScene.instantiate() as Label
		placeholder.text = "System linked"
		_panel_body.add_child(placeholder)
		return

	# Query(读):表演据 GI 暴露的 NPC action 列表建按钮(纯只读)。
	var actions := _world_query.get_npc_actions(_active_npc_id)
	for action in actions:
		_add_action_row(action)


func _build_party_panel() -> void:
	_panel_view.build_party_panel(_panel_body, _world_query.get_roster_snapshot())


func _build_bag_panel() -> void:
	_panel_view.build_bag_panel(_panel_body, _world_query.get_bag_snapshot())


func _build_journal_panel() -> void:
	var progression: Dictionary = _world_query.get_player_hud_summary().get("progression", {}) if _world_query != null else {}
	_panel_view.build_journal_panel(
		_panel_body, progression, _last_battle_result, open_save_load_menu)


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


# === dev-agent debug 表面 (UI introspection re-home 自 Host) ===

## UI debug 状态(Host 聚合时补 active_instance_id / game_world)。
func get_debug_state() -> Dictionary:
	var hud_summary := _world_query.get_player_hud_summary() if _world_query != null else {"gold": -1, "progression": {}}
	var roster_snapshot := _world_query.get_roster_snapshot() if _world_query != null else [] as Array[Dictionary]
	return {
		"state": _state_name(app_state),
		"gold": int(hud_summary.get("gold", -1)),
		"roster_size": roster_snapshot.size(),
		"player_coord": _get_player_coord_dict(),
		"player_moving": _is_player_moving(),
		"near_npc_id": _near_npc_id,
		"active_npc_id": _active_npc_id,
		"panel_open": app_state == AppState.NPC_MENU,
		"drawer_open": _drawer_mode != "",
		"drawer_mode": _drawer_mode,
		"modal_open": _is_modal_open(),
		"ui_message": _last_ui_message,
		"progression": hud_summary.get("progression", {}),
		"roster": roster_snapshot,
		"bag": _world_query.get_bag_snapshot() if _world_query != null else [] as Array[Dictionary],
		"overworld_iso": _world_layer.get_debug_state() if _world_layer != null else {},
		"replaying": _replaying,
		"battle_2d": _battle_2d_view.get_debug_state() if _battle_2d_view != null else {},
		"ui_animation": {
			"drawer_transition_active": _drawer_view != null and _drawer_view.is_transition_active(),
			"modal_transition_active": _save_load_modal_view != null and _save_load_modal_view.is_transition_active(),
			"drawer_visible": _drawer_view != null and _drawer_view.is_drawer_visible(),
			"dim_visible": _drawer_view != null and _drawer_view.is_dim_visible(),
			"modal_visible": _is_modal_open(),
		},
		"last_move_result": _last_move_result.duplicate(true),
		"last_battle_result": _last_battle_result.duplicate(true),
		"events": _event_log.duplicate(),
	}


func get_layout_state() -> Dictionary:
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
	return {
		"viewport": _rect_dict(get_viewport().get_visible_rect()),
		"prompt_button": _control_rect_dict(_prompt_button),
		"npc_panel": _control_rect_dict(_drawer_controls.get("panel", null) as Control),
		"close_button": _control_rect_dict(_drawer_controls.get("close_button", null) as Control),
		"npc_action_buttons": action_buttons,
		"shop_buy_buttons": buy_buttons,
		"trainer_button": _control_rect_dict(_trainer_button),
		"tool_buttons": tool_buttons,
		"tab_buttons": _slot_button_rects(_drawer_controls.get("tab_buttons", {}) as Dictionary),
		"save_load_modal": _control_rect_dict(_modal_controls.get("panel", null) as Control),
		"save_slot_buttons": _slot_button_rects(_modal_controls.get("save_buttons", {}) as Dictionary),
		"load_slot_buttons": _slot_button_rects(_modal_controls.get("load_buttons", {}) as Dictionary),
		"modal_close_button": _control_rect_dict(_modal_controls.get("close_button", null) as Control),
	}


## modal 子场景的 debug 控件表 (仅 layout/debug 组装读 rect 用, 行为不经此)。
var _modal_controls: Dictionary:
	get:
		return _save_load_modal_view.get_debug_controls() if _save_load_modal_view != null else {}


## drawer 子场景的 debug 控件表 (仅 layout/debug 组装读 rect 用, 行为不经此)。
var _drawer_controls: Dictionary:
	get:
		return _drawer_view.get_debug_controls() if _drawer_view != null else {}


func _slot_button_rects(slot_buttons: Dictionary) -> Dictionary:
	var result := {}
	for slot in slot_buttons.keys():
		result[str(slot)] = _control_rect_dict(slot_buttons[slot] as Button)
	return result


# === query 读助手 ===

## 运行时玩家位置真相 = Logic 的 grid occupant(§3 不双写)。表演只读委托。
func _get_player_coord() -> Vector2i:
	return _world_query.get_player_coord() if _world_query != null else Vector2i.ZERO


func _is_player_moving() -> bool:
	return _world_query != null and _world_query.is_player_moving()


func _get_player_coord_dict() -> Dictionary:
	var coord := _get_player_coord()
	return {"q": coord.x, "r": coord.y}


func _is_modal_open() -> bool:
	return _save_load_modal_view != null and _save_load_modal_view.is_open()


func _is_field_input_blocked() -> bool:
	# latest-wins:移动中也接受新 move command(不拦截);只有 UI 抽屉/弹窗挡 field 输入。
	return _drawer_mode != "" or _is_modal_open()


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


func _result(ok: bool, message: String) -> Dictionary:
	return {"ok": ok, "message": message}


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
