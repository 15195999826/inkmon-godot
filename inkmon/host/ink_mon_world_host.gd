class_name InkMonWorldHost
extends Node
## 主游戏内层导播 = composition root (docs/main-game-architecture.md §1)。
## 只做 composition(建 Logic GI + InkMonWorldPresentation 两孩子 + 接线)+ 控制面
## (lifecycle save/load/new-game/reset = 重建孩子;flow 起/收 battle procedure;tick 泵)。
## **不直接持有 UI 节点 ref**(全在 Presentation);不在 CQRS 调用路径上(Query/Command/Event 走
## Presentation ↔ Logic),只经信号收 Presentation 上抛的 flow/lifecycle 请求。


const DevAgentBridgeScript := preload("res://addons/lomolib/dev_agent/dev_agent_bridge.gd")
const InkMonMainAgentOpsScript := preload("res://inkmon/host/ink_mon_main_agent_ops.gd")

const DEFAULT_SAVE_PATH := "user://inkmon_l2_save.json"
# 手动存档点 + 可多槽 (§8b); 战斗结果不自动落盘, 玩家开 save 菜单存某槽。
const SAVE_SLOT_COUNT := 3
## 出发档(P1):出征起点快照, 独立预留路径(不占手动多槽)。"丢这趟"= load 此档精确回到出发时刻。
const DEPARTURE_SAVE_PATH := "user://inkmon_l2_mission_departure.json"
## 主世界逻辑固定步频(§1 tick/移动模型):Host 每帧按累加器泵 GameWorld.tick_all(FIXED_DT)。
const FIXED_DT := 1.0 / 30.0
const MAX_TICKS_PER_FRAME := 8

## 战斗 flow 真相(_active_instance_id != "" ⇒ 战斗中);Host 控制面持有,推给 Presentation 派生 app_state。
var _active_instance_id := ""
## 训练战 flow 去重锁:从收到 start_battle intent 到 _begin_training_battle_flow 跑完之间为 true,
## 挡掉同帧双击/重复 intent 起多场战斗(方案 A 异步去掉了旧同步路径的隐式单飞保护)。
var _battle_flow_pending := false
## mission flow 去重位(对称 _battle_flow_pending, 独立互不挡)。
var _mission_flow_pending := false
## 回放观看期标志:battle sim 已结束但玩家还在看回放/结果。世界泵冻结,直到表演上抛 battle_view_left
## 解冻(game-vision §2 体验流:进战斗→冻结→观看→确认离开→恢复)。
var _replay_active := false
## M2.2 野群战斗失利标志(出征中战败 = 全灭): 回放看完确认离开(battle_view_left)才走"丢这趟"出口
## —— 先让玩家看清怎么输的, 再回档。
var _mission_battle_lost := false
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
	_create_world_gi()
	_world_gi.new_game()
	_presentation = InkMonWorldPresentation.new()
	add_child(_presentation)
	# Host 收 Presentation 上抛的 flow/lifecycle 请求(单向:Host connect 表演的信号,表演不引用 Host)。
	_presentation.flow_intent_raised.connect(_on_flow_intent_raised)
	_presentation.save_slot_requested.connect(_on_save_slot_requested)
	_presentation.load_slot_requested.connect(_on_load_slot_requested)
	_presentation.battle_view_left.connect(_on_battle_view_left)
	_presentation.capture_requested.connect(_on_capture_requested)
	_bind_world_to_presentation()
	_presentation.add_event("InkMonMain ready")
	_install_dev_agent()


func _exit_tree() -> void:
	GameWorld.shutdown()


func _process(delta: float) -> void:
	if _active_instance_id != "":
		_advance_active_battle(delta)
		return
	if _replay_active:
		return  # 回放观看期:主世界 tick 冻结,玩家确认离开(battle_view_left)才恢复
	_pump_world_ticks(delta)


## battle 推进单一微序列 (tick 一步 + 结算检查)。异步 _process 与同步 run_to_completion 都走此,
## 防两路各自手排产生行为分叉; dt 来源由调用方显式给 (真实帧 delta / 固定 tick interval)。
func _advance_active_battle(dt: float) -> void:
	_tick_active_instance(dt)
	_complete_battle_if_ready()


## 主世界 30Hz 定步泵(§1 tick/移动模型):累加真实 delta,每满 FIXED_DT 泵一次 GameWorld.tick_all
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
	if _active_instance_id != "" or _replay_active:
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
		_advance_active_battle(BattleProcedure.DEFAULT_TICK_INTERVAL)

	if _active_instance_id != "":
		return _scene_result(false, "training battle did not complete within %d ticks" % safe_ticks)
	return _scene_result(true, "training battle completed")


## Presentation 上抛 flow intent(training 的 start_battle)→ Host 起 flow。
## call_deferred 脱离 tick_all(intent 经 command_applied 在 drain 内浮现),避免 mid-tick flip grid 的 re-entrancy。
func _on_flow_intent_raised(intent: Dictionary) -> void:
	match str(intent.get(InkMonNpcHandler.INTENT_KIND, "")):
		InkMonTrainingNpcHandler.INTENT_START_BATTLE:
			# 去重:方案 A 下同帧双击会 enqueue 两条 command,同 tick drain → 两次 intent。
			# 旧同步路径靠"第一场跑完即切回主世界态"自然挡掉第二次;async 下两次 deferred 会起两场(双倍奖励)。
			# 故只认第一次 intent,_begin 跑完才解锁。带提交时的世界代际:deferred 跑前若 reset/load
			# 重建世界,代际不匹配 → 作废旧 intent。
			if _battle_flow_pending:
				return
			_battle_flow_pending = true
			call_deferred("_begin_training_battle_flow", _world_generation)
		InkMonGuildNpcHandler.INTENT_START_MISSION:
			# 同款去重 + 代际 guard(独立 pending 位:battle 与 mission flow 互不挡)。
			if _mission_flow_pending:
				return
			_mission_flow_pending = true
			call_deferred("_begin_mission_flow", _world_generation)


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
	# adr/0001:GI 战斗结束直接把奖励落活 actor (gold→player_actor, exp→roster);Host 拿摘要交 Presentation 展示。
	var replay := _world_gi.get_replay_data()
	var result := _world_gi.finalize_battle_rewards()
	# M2.2: 野群战败(right_win = 己方全倒)= 全灭 → 丢这趟; 先看回放再回档(见 _on_battle_view_left)。
	# 只认野群战 (is_wild_battle): 出征中混入的训练战失利 (dev-agent 路径无 mission guard) 不触丢趟。
	_mission_battle_lost = _world_gi.is_wild_battle() and _world_gi.has_active_mission() \
		and str(result.get("result", "")) == "right_win"
	# 持久 world GI: 不销毁 (战斗结束已切回主世界 grid); 只清 active 标记回到主世界态。
	# adr/0005:有录像 → 先交 Presentation 播 2D 回放(_replaying 接管 BATTLE 态),播完再收尾;无录像直接收尾(降级)。
	if replay.is_empty():
		_set_active_instance("")
		_presentation.on_battle_completed(result)
		if _mission_battle_lost:
			# 无录像降级路径: 没有回放可看, 直接走丢趟(deferred: 本方法可能在 tick 推进链内)。
			_mission_battle_lost = false
			_presentation.add_event("party defeated in wild battle: mission lost")
			call_deferred("_finish_mission_wipe", _world_generation)
		else:
			# 降级路径无战场可留 → 捕捉窗口不存在, 直接收尾遭遇 (幂等 no-op 若非野群胜局)。
			_world_gi.resolve_wild_battle_encounter()
	else:
		# 回放观看期开始:battle 实例已收,但世界保持冻结(_replay_active),玩家确认离开才解冻。
		# M2.3: 捕捉池随回放推入 —— 胜局播完后玩家在战场上点气绝野生个体掷球。
		_replay_active = true
		_presentation.play_battle_replay(
			replay, result, _world_gi.get_battle_map_doc(), _world_gi.get_capture_pool_snapshot())
		_set_active_instance("")


## 表演上抛:玩家在战斗结果界面确认离开 → 解冻世界泵,回主世界节奏。
## M2.2: 出征野群战败时, 观看期结束即走"丢这趟"(load 出发档, 与全灭/放弃同一条路)。
## M2.3: 非败离场 = 野群遭遇收尾 (清必战锁 + 作废未掷的捕捉机会; 非野群/无出征时幂等 no-op)。
func _on_battle_view_left() -> void:
	_replay_active = false
	if _mission_battle_lost:
		_mission_battle_lost = false
		_presentation.add_event("party defeated in wild battle: mission lost")
		_finish_mission_wipe(_world_generation)
		return
	if _world_gi != null:
		_world_gi.resolve_wild_battle_encounter()


## 掷球捕捉上抛 (M2.3): 回放观看期世界泵冻结 (command 不 drain), 捕捉走 Host 控制面直调
## (对称 save/load 槽位路由), 结果同步推回表演做反馈。
func _on_capture_requested(slot_index: int) -> void:
	if _world_gi == null:
		return
	_presentation.on_capture_attempted(_world_gi.attempt_wild_capture(slot_index))


# === flow:mission 出征 起/收(Host 控制面; P1/P2 拍板, 术语 glossary §4.8)===

## 出征 flow:guild intent 经 call_deferred 触发。
## P1 顺序契约(钉死, 防呆):①(将来)带粮等据点资源扣除 → ②写出发档 → ③gi.start_mission。
## 扣任何据点资源必须在写档**之前** —— 否则"丢这趟"回档会把已消耗资源退回来(出征零成本)。
func _begin_mission_flow(generation: int) -> void:
	_mission_flow_pending = false
	if generation != _world_generation:
		return
	if _world_gi == null or _active_instance_id != "" or _replay_active:
		return
	if _world_gi.has_active_mission():
		return
	# ② 出发档 = "丢这趟"的锚点(P1):全灭/退出/崩溃都精确回到此刻。
	var save_result := save_game(DEPARTURE_SAVE_PATH)
	if not bool(save_result.get("ok", false)):
		_presentation.add_event("mission aborted: departure save failed")
		return
	# ③ 起出征(选目标地标 + 蔓延生成趟内节点图)。
	var start_result := _world_gi.start_mission()
	if bool(start_result.get("ok", false)):
		_presentation.set_mission_active(true)
		_presentation.add_event("mission started (departure saved)")
	else:
		_presentation.add_event("mission start failed: %s" % str(start_result.get("message", "")))


## GI 出征结束(主委托完成出口)→ 收 flow:退出出征态 + 交表演展示结算。
func _on_mission_ended(result: Dictionary) -> void:
	_clear_departure_save()
	_presentation.set_mission_active(false)
	_presentation.on_mission_completed(result)
	_presentation.add_event("mission ended: %s" % str(result.get("outcome", "")))


## 踩上野群节点上行(M2.2): signal 从 tick drain 内 emit → deferred 起 wild battle flow
## (对称 mission_wiped 的 deferred 理由), 复用训练战的去重锁 + 代际 guard。
func _on_mission_battle_triggered(_node_id: int) -> void:
	if _battle_flow_pending:
		return
	_battle_flow_pending = true
	call_deferred("_begin_wild_battle_flow", _world_generation)


## 野群战斗 flow(M2.2, 对称 _begin_training_battle_flow): 同步跑完(record-then-playback),
## 结果经 _complete_battle_if_ready 收 —— 胜负出口都在那里分派(回放观看 → 离开时按胜负收尾)。
func _begin_wild_battle_flow(generation: int) -> void:
	_battle_flow_pending = false
	if generation != _world_generation:
		return
	if _world_gi == null or _active_instance_id != "" or _replay_active:
		return
	if not _world_gi.has_active_mission() or not _world_gi.mission_state.has_pending_battle():
		return
	_set_active_instance(_world_gi.id)
	_world_gi.request_wild_battle()
	_presentation.add_event("wild battle started")
	for _i in range(8):
		if _active_instance_id == "":
			break
		_advance_active_battle(BattleProcedure.DEFAULT_TICK_INTERVAL)


## 全灭上行: signal 从 tick drain 内 emit, mid-tick 销毁世界会炸正在 tick 的 GI —— deferred 到帧尾
## 再走"丢这趟"(对称 flow intent 的 deferred 理由), 带代际 guard 防 reset/load 竞态。
func _on_mission_wiped() -> void:
	_presentation.add_event("party wiped: mission lost")
	call_deferred("_finish_mission_wipe", _world_generation)


func _finish_mission_wipe(generation: int) -> void:
	if generation != _world_generation:
		return
	if _world_gi == null or not _world_gi.has_active_mission():
		return
	abandon_mission()


## "丢这趟"出口(P1 两出口之二):玩家放弃 / 全灭(M1.4)统一走此 —— load 出发档, 精确回到出发时刻。
## 与手动 load 同一条代码路径(load_game 重建世界, transient 出征态随旧 GI 整体销毁 = 天然回滚)。
func abandon_mission() -> Dictionary:
	if _world_gi == null or not _world_gi.has_active_mission():
		return _scene_result(false, "no active mission")
	var load_result := load_game(DEPARTURE_SAVE_PATH)
	_clear_departure_save()
	_presentation.set_mission_active(false)
	_presentation.add_event("mission abandoned: returned to departure save")
	return load_result


## 出发档生命周期 = 出征期间(出发写 → 两出口收尾删)。
## ⇒ 启动时档存在 ⇔ 上次出征未正常收尾(崩溃/强退), 外层 session 菜单据此给"回到出发时刻"入口(尾项③)。
func _clear_departure_save() -> void:
	if FileAccess.file_exists(DEPARTURE_SAVE_PATH):
		DirAccess.remove_absolute(DEPARTURE_SAVE_PATH)


# === lifecycle:save/load/new-game/reset = 重建孩子(Host 控制面,非 command 队列)===

func reset_session() -> Dictionary:
	_set_active_instance("")
	_battle_flow_pending = false
	_mission_flow_pending = false
	_replay_active = false
	_mission_battle_lost = false
	GameWorld.destroy_all_instances()
	TimelineRegistry.reset()
	_create_world_gi()
	_world_gi.new_game()
	_presentation.reset_ui_state(true)
	_bind_world_to_presentation()
	_presentation.cancel_overworld_animation()
	_world_gi.refresh_near_npc()
	_presentation.add_event("session reset")
	return _scene_result(true, "session reset")


func save_game(save_path: String = DEFAULT_SAVE_PATH) -> Dictionary:
	# save = Host 控台操作(非 command):gi.to_dict()(遍历活 actor 序列化)→ InkMonSaveFile 纯 IO 落盘。
	if _world_gi == null:
		return _scene_result(false, "world not initialized")
	var write_result := InkMonSaveFile.write(save_path, _world_gi.to_dict())
	if not bool(write_result.get("ok", false)):
		return _scene_result(false, str(write_result.get("message", "save failed")))
	_presentation.add_event("saved game: %s" % save_path)
	return _scene_result(true, "saved game")


## 多槽存档便捷封装 (§8b); 底层仍复用 path-based save_game/load_game。
func save_to_slot(slot: int) -> Dictionary:
	return save_game(slot_save_path(slot))


func load_from_slot(slot: int) -> Dictionary:
	return load_game(slot_save_path(slot))


func list_save_slots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot in range(1, SAVE_SLOT_COUNT + 1):
		result.append({"slot": slot, "exists": FileAccess.file_exists(slot_save_path(slot))})
	return result


## static 公开: 外层 session 菜单(InkMonMain "Continue" 找最近档)也要按槽位扫文件。
static func slot_save_path(slot: int) -> String:
	return "user://inkmon_l2_save_slot%d.json" % slot


func load_game(save_path: String = DEFAULT_SAVE_PATH) -> Dictionary:
	# load = Host 控台操作:InkMonSaveFile 读 → 重建 GI → gi.from_dict(data) 据存档建活 actor。
	var read_result := InkMonSaveFile.read(save_path)
	if not bool(read_result.get("ok", false)):
		return _scene_result(false, str(read_result.get("message", "load failed")))
	var data := read_result.get("data", {}) as Dictionary

	_set_active_instance("")
	_battle_flow_pending = false
	_mission_flow_pending = false
	_replay_active = false
	_mission_battle_lost = false
	GameWorld.destroy_all_instances()
	TimelineRegistry.reset()
	_create_world_gi()
	var save_loaded := _world_gi.from_dict(data if data != null else {})
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


## Host = composition root:建唯一持久 world GI(World-owns-Battle)。装配 (new_game / from_dict) 由调方
## 在本方法后调 GI 方法完成。信号接线与 refresh 由 Presentation.bind_world 负责。
func _create_world_gi() -> void:
	# 世界(重)建的唯一入口:自增代际 → 作废任何指向旧世界的 in-flight deferred flow(stale-intent guard)。
	_world_generation += 1
	_world_gi = GameWorld.create_instance(func() -> GameplayInstance:
		return InkMonWorldGI.new()
	) as InkMonWorldGI
	Log.assert_crash(_world_gi != null, "InkMonWorldHost", "failed to create InkMonWorldGI")


## 把当前 world GI 接到 Presentation:造 IWorldQuery facade 交给它(read+submit),并由 Host 连 GI 的 3 个
## mutation signal 到 Presentation 的 _on_* handler。Host 合法持 concrete GI 做接线;表演只拿 facade、不持 GI。
## 每次(重)建 GI 后调用;旧 GI 销毁后其信号连接随之消失,故无需显式 disconnect。
func _bind_world_to_presentation() -> void:
	_world_gi.actor_position_changed.connect(_presentation._on_world_actor_position_changed)
	_world_gi.near_npc_changed.connect(_presentation._on_near_npc_changed)
	_world_gi.command_applied.connect(_presentation._on_command_applied)
	# mission_ended 是 flow 事件 → Host 收(退出出征态), 再转推表演展示。
	_world_gi.mission_ended.connect(_on_mission_ended)
	# mission_progressed 是 mutation signal → 直连表演刷大地图 view(对称 actor_position_changed)。
	_world_gi.mission_progressed.connect(_presentation._on_mission_progressed)
	_world_gi.mission_wiped.connect(_on_mission_wiped)
	# 踩野群节点 → Host 起 wild battle flow(M2.2; flow 事件归 Host, 对称 mission_ended)。
	_world_gi.mission_battle_triggered.connect(_on_mission_battle_triggered)
	_presentation.bind_world(IWorldQuery.new(_world_gi))


# === 存读档槽:Presentation 上抛(UI 在表演,lifecycle 操作在 Host)===

func _on_save_slot_requested(slot: int) -> void:
	# P1:出征中禁手动存档(防 scum + 防"半态存档" —— 出征 transient 态不进档, 半存出精神分裂档)。
	if _world_gi != null and _world_gi.has_active_mission():
		_presentation.add_event("save disabled during mission")
		return
	save_to_slot(slot)


func _on_load_slot_requested(slot: int) -> void:
	# P1:出征中禁手动读档(丢这趟只走 abandon_mission → 出发档, 不给任意档口子)。
	if _world_gi != null and _world_gi.has_active_mission():
		_presentation.add_event("load disabled during mission")
		return
	load_from_slot(slot)


# === dev-agent introspection:聚合 Presentation 的 UI debug 表面 + Host flow 状态 ===

func get_dev_agent_state() -> Dictionary:
	var state := _presentation.get_debug_state() if _presentation != null else {}
	state["active_instance_id"] = _active_instance_id
	state["replay_active"] = _replay_active
	state["mission_active"] = _world_gi != null and _world_gi.has_active_mission()
	state["game_world"] = GameWorld.get_debug_info()
	return state


func get_dev_agent_layout_state() -> Dictionary:
	return _presentation.get_layout_state() if _presentation != null else {}


# === 活 actor 只读访问 (adr/0001; session getter 已删, 玩家/roster 真相在 Logic GI) ===

func get_player_actor() -> InkMonPlayerActor:
	return _world_gi.player_actor if _world_gi != null else null


func get_roster() -> Array[InkMonUnitActor]:
	return _world_gi.roster if _world_gi != null else []


# === 公开 API facade:输入/UI 操作转发给 Presentation(CQRS 写/读在 Presentation ↔ Logic)===
# Wave 3: 返回值不再寄生 dev-agent 全量快照 (introspection 走显式 get_dev_agent_state / "state" op),
# 转发原样透传 Presentation 结果 —— 消掉"每次调用全量序列化调试态"的税。

func move_player(delta_coord: Vector2i) -> Dictionary:
	return _presentation.move_player(delta_coord)


func goto_tile(target_coord: Vector2i) -> Dictionary:
	return _presentation.goto_tile(target_coord)


func right_click_at(screen_position: Vector2) -> Dictionary:
	return _presentation.right_click_at(screen_position)


func get_tile_screen_position(coord: Vector2i) -> Dictionary:
	return _presentation.get_tile_screen_position(coord)


func open_near_npc_menu() -> Dictionary:
	return _presentation.open_near_npc_menu()


func open_npc_menu(npc_id: String) -> Dictionary:
	return _presentation.open_npc_menu(npc_id)


func close_npc_menu() -> Dictionary:
	return _presentation.close_npc_menu()


func open_player_panel(panel_id: String) -> Dictionary:
	return _presentation.open_player_panel(panel_id)


func close_drawer() -> Dictionary:
	return _presentation.close_drawer()


func open_save_load_menu() -> Dictionary:
	return _presentation.open_save_load_menu()


func close_save_load_menu() -> Dictionary:
	return _presentation.close_save_load_menu()


func buy_shop_item(config_id: StringName) -> Dictionary:
	return _presentation.buy_shop_item(config_id)


func run_active_npc_action(action_id: String) -> Dictionary:
	return _presentation.run_active_npc_action(action_id)


func run_npc_action_for(npc_id: String, action_id: String) -> Dictionary:
	return _presentation.run_npc_action_for(npc_id, action_id)


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


## 控制面结果 = 纯 {ok, message} (Wave 3: 不再塞 dev-agent 快照, introspection 走显式读口)。
func _scene_result(ok: bool, message: String) -> Dictionary:
	return {
		"ok": ok,
		"message": message,
	}
