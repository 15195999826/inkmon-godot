class_name InkMonWorldHost
extends Node
## 主游戏内层导播 = composition root (docs/main-game-architecture.md §1)。
## 只做 composition(建 Logic GI + InkMonWorldPresentation 两孩子 + 接线)+ 控制面
## (lifecycle save/load/new-game/reset = 重建孩子;flow 起/收 battle procedure;tick 泵)。
## **不直接持有 UI 节点 ref**(全在 Presentation);不在 CQRS 调用路径上(Query/Command/Event 走
## Presentation ↔ Logic),只经信号收 Presentation 上抛的 flow/lifecycle 请求。


const DevAgentBridgeScript := preload("res://addons/lomolib/dev_agent/dev_agent_bridge.gd")
const InkMonMainAgentOpsScript := preload("res://scenes/inkmon-main/ink_mon_main_agent_ops.gd")

const DEFAULT_SAVE_PATH := "user://inkmon_l2_save.json"
# 手动存档点 + 可多槽 (§8b); 战斗结果不自动落盘, 玩家开 save 菜单存某槽。
const SAVE_SLOT_COUNT := 3
## 主世界逻辑固定步频(§0.5):Host 每帧按累加器泵 GameWorld.tick_all(FIXED_DT)。
const FIXED_DT := 1.0 / 30.0
const MAX_TICKS_PER_FRAME := 8

## session 真相在 Logic(InkMonWorldGI.session);Host 只读委托(单一所有权,§0.5)。
var session: InkMonGameSession:
	get:
		return _world_gi.session if _world_gi != null else null

## 战斗 flow 真相(_active_instance_id != "" ⇒ 战斗中);Host 控制面持有,推给 Presentation 派生 app_state。
var _active_instance_id := ""
## 训练战 flow 去重锁:从收到 start_battle intent 到 _begin_training_battle_flow 跑完之间为 true,
## 挡掉同帧双击/重复 intent 起多场战斗(方案 A 异步去掉了旧同步路径的隐式单飞保护)。
var _battle_flow_pending := false
## 世界代际:每次(重)建 world GI 自增。deferred 的训练战 flow 带提交时的代际,若 deferred 期间
## reset/load 重建了世界(代际变),旧 intent 作废 —— 不在新 session 上结算旧训练战(Codex P2)。
var _world_generation := 0
var _world_gi: InkMonWorldGI = null
var _presentation: InkMonWorldPresentation = null
## 主世界定步泵的真实时间累加器(满 FIXED_DT 泵一 tick)。
var _tick_accumulator := 0.0
var _dev_agent_bridge: Node = null


func _ready() -> void:
	name = "WorldHost"
	GameWorld.init(EventProcessorConfig.new(20, 1))
	TimelineRegistry.reset()
	_setup_overworld_runtime(_new_game_session())
	_presentation = InkMonWorldPresentation.new()
	add_child(_presentation)
	# Host 收 Presentation 上抛的 flow/lifecycle 请求(单向:Host connect 表演的信号,表演不引用 Host)。
	_presentation.flow_intent_raised.connect(_on_flow_intent_raised)
	_presentation.save_slot_requested.connect(_on_save_slot_requested)
	_presentation.load_slot_requested.connect(_on_load_slot_requested)
	_bind_world_to_presentation()
	_presentation.add_event("InkMonMain ready")
	_install_dev_agent()


func _exit_tree() -> void:
	GameWorld.shutdown()


func _process(delta: float) -> void:
	if _active_instance_id != "":
		_tick_active_instance(delta)
		_complete_battle_if_ready()
		return
	_pump_world_ticks(delta)


## 主世界 30Hz 定步泵(§0.5):累加真实 delta,每满 FIXED_DT 泵一次 GameWorld.tick_all
## → WorldGI.base_tick → CommandDrain/Movement System 逐格推进。封顶防 spiral-of-death。
func _pump_world_ticks(delta: float) -> void:
	if _world_gi == null:
		return
	_tick_accumulator += delta
	var ticks := 0
	while _tick_accumulator >= FIXED_DT and ticks < MAX_TICKS_PER_FRAME:
		_tick_accumulator -= FIXED_DT
		GameWorld.tick_all(FIXED_DT)
		ticks += 1


# === flow:battle 起/收(Host 控制面,非 CQRS)===

## _active_instance_id 单一写入口:更新战斗 flow 真相 + 推给 Presentation 派生 app_state。
func _set_active_instance(instance_id: String) -> void:
	_active_instance_id = instance_id
	if _presentation != null:
		_presentation.set_battle_active(instance_id != "")


func start_training_battle() -> Dictionary:
	if _active_instance_id != "":
		return _scene_result(false, "battle already active")
	# 持久 world GI 内起战斗 procedure (不再 per-battle create→destroy)。
	Log.assert_crash(_world_gi != null, "InkMonWorldHost", "world GI not initialized before battle")
	_set_active_instance(_world_gi.id)
	# 战斗触发内移:GI 自建 config(player roster + 假人)起 procedure;Host 只管 flow(state/tick)。
	_world_gi.request_training_battle()
	_presentation.add_event("training battle started")
	return _scene_result(true, "training battle started")


func run_training_battle_to_completion(max_ticks: int = 8) -> Dictionary:
	var start_result := start_training_battle()
	if not bool(start_result.get("ok", false)):
		return start_result

	var safe_ticks := maxi(1, max_ticks)
	for _i in range(safe_ticks):
		if _active_instance_id == "":
			break
		_tick_active_instance(BattleProcedure.DEFAULT_TICK_INTERVAL)
		_complete_battle_if_ready()

	if _active_instance_id != "":
		return _scene_result(false, "training battle did not complete within %d ticks" % safe_ticks)
	return _scene_result(true, "training battle completed")


## Presentation 上抛 flow intent(training 的 start_battle)→ Host 起 flow。
## call_deferred 脱离 tick_all(intent 经 command_applied 在 drain 内浮现),避免 mid-tick flip grid 的 re-entrancy。
func _on_flow_intent_raised(intent: Dictionary) -> void:
	if str(intent.get(InkMonNpcHandler.INTENT_KIND, "")) != InkMonTrainingNpcHandler.INTENT_START_BATTLE:
		return
	# 去重:方案 A 下同帧双击会 enqueue 两条 start_battle command,同 tick drain → 两次 intent。
	# 旧同步路径靠"第一场跑完即切回主世界态"自然挡掉第二次;async 下两次 deferred 会起两场(双倍奖励)。
	# 故只认第一次 intent,_begin 跑完才解锁。
	if _battle_flow_pending:
		return
	_battle_flow_pending = true
	# 带提交时的世界代际:deferred 跑前若 reset/load 重建世界,代际不匹配 → 作废旧 intent。
	call_deferred("_begin_training_battle_flow", _world_generation)


## 训练战 flow(Host 控制面):由 flow_intent_raised 经 call_deferred 触发。
## 同步跑完(record-then-playback);_complete_battle_if_ready 写回结果 + 经 Presentation 清回主世界态。
## generation = 提交时的世界代际;若已被 reset/load 重建(代际变)则丢弃,绝不在新 session 上结算旧训练战。
func _begin_training_battle_flow(generation: int) -> void:
	_battle_flow_pending = false
	if generation != _world_generation:
		return
	run_training_battle_to_completion(8)


func _tick_active_instance(dt: float) -> void:
	var instance := GameWorld.get_instance_by_id(_active_instance_id)
	if instance != null and instance.is_running():
		instance.tick(dt)


func _complete_battle_if_ready() -> void:
	if _active_instance_id == "" or _world_gi == null:
		return
	if _world_gi.has_active_battle():
		return
	# 战斗结果内移:GI 读自己的 result_summary 并写回它持有的 session;Host 拿摘要交 Presentation 展示。
	var result := _world_gi.apply_battle_result()
	# 持久 world GI: 不销毁 (战斗结束已切回主世界 grid); 只清 active 标记回到主世界态。
	_set_active_instance("")
	_presentation.on_battle_completed(result)


# === lifecycle:save/load/new-game/reset = 重建孩子(Host 控制面,非 command 队列)===

func reset_session() -> Dictionary:
	_set_active_instance("")
	_battle_flow_pending = false
	GameWorld.destroy_all_instances()
	TimelineRegistry.reset()
	_setup_overworld_runtime(_new_game_session())
	_presentation.reset_ui_state(true)
	_bind_world_to_presentation()
	_presentation.cancel_overworld_animation()
	_world_gi.refresh_near_npc()
	_presentation.add_event("session reset")
	return _scene_result(true, "session reset")


func save_game(save_path: String = DEFAULT_SAVE_PATH) -> Dictionary:
	# save = Host 控台操作(非 command):capture(运行时→session 单写)→ InkMonSaveFile 落盘。
	if _world_gi != null:
		_world_gi.capture_to_session()
	var write_result := InkMonSaveFile.write(save_path, session)
	if not bool(write_result.get("ok", false)):
		return _scene_result(false, str(write_result.get("message", "save failed")))
	_presentation.add_event("saved game: %s" % save_path)
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
	# load = Host 控台操作:InkMonSaveFile 读 → from_dict → 重建 world(setup_overworld 内 hydrate)。
	var read_result := InkMonSaveFile.read(save_path)
	if not bool(read_result.get("ok", false)):
		return _scene_result(false, str(read_result.get("message", "load failed")))
	var data := read_result.get("data", {}) as Dictionary

	var loaded_session := InkMonGameSession.new()
	var save_loaded := loaded_session.from_dict(data)
	_set_active_instance("")
	_battle_flow_pending = false
	GameWorld.destroy_all_instances()
	TimelineRegistry.reset()
	_setup_overworld_runtime(loaded_session)
	# load 读档:轻清 UI(保留 move_result/ui_message/events,对齐重构前 load 行为)。
	_presentation.reset_ui_state(false)
	_bind_world_to_presentation()
	_presentation.cancel_overworld_animation()
	_world_gi.refresh_near_npc()
	if not save_loaded:
		_presentation.add_event("incompatible save discarded, started new game: %s" % save_path)
		return _scene_result(true, "incompatible save discarded; started new game")
	_presentation.add_event("loaded game: %s" % save_path)
	return _scene_result(true, "loaded game")


## Host = composition root:建唯一持久 world GI(World-owns-Battle),把 session 交给它装配
## 主世界运行时(grid / world actors / move controller / npc 表 / near-npc 全在 Logic)。
## 信号接线与 refresh 由 Presentation.bind_world 负责(调方在创建/重建 GI 后调用)。
func _setup_overworld_runtime(session_to_use: InkMonGameSession) -> void:
	# 世界(重)建的唯一入口:自增代际 → 作废任何指向旧世界的 in-flight deferred flow(stale-intent guard)。
	_world_generation += 1
	_world_gi = GameWorld.create_instance(func() -> GameplayInstance:
		return InkMonWorldGI.new()
	) as InkMonWorldGI
	Log.assert_crash(_world_gi != null, "InkMonWorldHost", "failed to create InkMonWorldGI")
	_world_gi.setup_overworld(session_to_use)


func _new_game_session() -> InkMonGameSession:
	var new_session := InkMonGameSession.new()
	new_session.begin_new_game()
	return new_session


## 把当前 world GI 接到 Presentation:造 IWorldQuery facade 交给它(read+submit),并由 Host 连 GI 的 3 个
## mutation signal 到 Presentation 的 _on_* handler。Host 合法持 concrete GI 做接线;表演只拿 facade、不持 GI。
## 每次(重)建 GI 后调用;旧 GI 销毁后其信号连接随之消失,故无需显式 disconnect。
func _bind_world_to_presentation() -> void:
	_world_gi.actor_position_changed.connect(_presentation._on_world_actor_position_changed)
	_world_gi.near_npc_changed.connect(_presentation._on_near_npc_changed)
	_world_gi.command_applied.connect(_presentation._on_command_applied)
	_presentation.bind_world(IWorldQuery.new(_world_gi))


# === 存读档槽:Presentation 上抛(UI 在表演,lifecycle 操作在 Host)===

func _on_save_slot_requested(slot: int) -> void:
	save_to_slot(slot)


func _on_load_slot_requested(slot: int) -> void:
	load_from_slot(slot)


# === dev-agent introspection:聚合 Presentation 的 UI debug 表面 + Host flow 状态 ===

func get_dev_agent_state() -> Dictionary:
	var state := _presentation.get_debug_state() if _presentation != null else {}
	state["active_instance_id"] = _active_instance_id
	state["game_world"] = GameWorld.get_debug_info()
	return state


func get_dev_agent_layout_state() -> Dictionary:
	return _presentation.get_layout_state() if _presentation != null else {}


# === 公开 API facade:输入/UI 操作转发给 Presentation(CQRS 写/读在 Presentation ↔ Logic)===
# 转发结果补 data = get_dev_agent_state()(保持 dev-agent op / smoke 的结果形状)。

func move_player(delta_coord: Vector2i) -> Dictionary:
	return _with_state(_presentation.move_player(delta_coord))


func goto_tile(target_coord: Vector2i) -> Dictionary:
	return _with_state(_presentation.goto_tile(target_coord))


func right_click_at(screen_position: Vector2) -> Dictionary:
	return _with_state(_presentation.right_click_at(screen_position))


func get_tile_screen_position(coord: Vector2i) -> Dictionary:
	return _presentation.get_tile_screen_position(coord)


func open_near_npc_menu() -> Dictionary:
	return _with_state(_presentation.open_near_npc_menu())


func open_npc_menu(npc_id: String) -> Dictionary:
	return _with_state(_presentation.open_npc_menu(npc_id))


func close_npc_menu() -> Dictionary:
	return _with_state(_presentation.close_npc_menu())


func open_player_panel(panel_id: String) -> Dictionary:
	return _with_state(_presentation.open_player_panel(panel_id))


func close_drawer() -> Dictionary:
	return _with_state(_presentation.close_drawer())


func open_save_load_menu() -> Dictionary:
	return _with_state(_presentation.open_save_load_menu())


func close_save_load_menu() -> Dictionary:
	return _with_state(_presentation.close_save_load_menu())


func buy_shop_item(config_id: StringName) -> Dictionary:
	return _with_state(_presentation.buy_shop_item(config_id))


func run_active_npc_action(action_id: String) -> Dictionary:
	return _with_state(_presentation.run_active_npc_action(action_id))


func run_npc_action_for(npc_id: String, action_id: String) -> Dictionary:
	return _with_state(_presentation.run_npc_action_for(npc_id, action_id))


# === 接线 / 工具 ===

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


## 转发结果补 data = 完整 dev-agent state(dev-agent op / smoke 读返回值 data 的契约)。
func _with_state(result: Dictionary) -> Dictionary:
	result["data"] = get_dev_agent_state()
	return result


func _scene_result(ok: bool, message: String) -> Dictionary:
	return {
		"ok": ok,
		"message": message,
		"data": get_dev_agent_state(),
	}
