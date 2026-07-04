extends Node
## 出征 Host 级契约 (P1 存档语义 + M1.4 补给钟, 全真实链路, 三段串行):
##   第一段: guild intent(经 command 通道) → 自动写出发档 → 出征态推入 →
##     出征中禁手动 save/load(表演 gate + Host 槽位 guard 双层) →
##     abandon("丢这趟") = load 出发档, 内存污染精确回滚到出发时刻 + 出发档收尾删除。
##   第二段(全灭): 再次出征 → 有粮走步不掉血 → 粮尽行军全队掉真 HP → 全灭 →
##     mission_wiped → Host deferred load 出发档 → HP/出征态精确回滚 + 出发档收尾删除。
##   第二段b(M2.2 野群战败): 出征 → 走图踩野群节点(踩前 roster 归零 → 即时右胜=战败)→
##     回放观看期 → Leave 确认离开 → 丢这趟自动回档 + 出发档收尾删除。
##   第三段(主菜单恢复, real mouse input): 造出发档 → InkMonMain 菜单出 "Return to Departure" →
##     真鼠标点击 → 进游戏 + 出发档被消费删除 (plan 尾项③全链)。
## 各段必须同 smoke 串行: 出发档是共享 user:// 文件, 拆并行 smoke 会互删互读(launcher 并行 race,
## 上轮与本轮各踩一次) —— 凡碰出发档的断言只许住本 smoke。


const MainScene := preload("res://InkMonMain.tscn")

var _host: InkMonWorldHost = null


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	var status: String = await _run()
	if status == "":
		print("SMOKE_TEST_RESULT: PASS - mission departure: auto save + lockout + abandon/wipe rollback + menu recovery (real mouse input)")
		get_tree().quit(0)
	else:
		print("SMOKE_TEST_RESULT: FAIL - %s" % status)
		get_tree().quit(1)


func _run() -> String:
	if FileAccess.file_exists(InkMonWorldHost.DEPARTURE_SAVE_PATH):
		DirAccess.remove_absolute(InkMonWorldHost.DEPARTURE_SAVE_PATH)
	_host = InkMonWorldHost.new()
	add_child(_host)
	await get_tree().process_frame
	await get_tree().process_frame
	var presentation := _host.get_node("Presentation") as InkMonWorldPresentation
	if presentation == null:
		return "presentation node not found under host"
	var gold_before: int = _host.get_player_actor().gold

	# 真实链路: 表演 submit NPC action → tick drain → intent 上抛 → deferred mission flow。
	presentation.run_npc_action_for("guild", InkMonGuildNpcHandler.ACTION_START_MISSION)
	await get_tree().create_timer(0.5).timeout
	if not FileAccess.file_exists(InkMonWorldHost.DEPARTURE_SAVE_PATH):
		return "departure save must be auto-written on mission start"
	if not bool(_host.get_dev_agent_state().get("mission_active", false)):
		return "mission should be active after guild intent"

	# P1: 出征中禁手动 save/load —— 表演菜单 gate。
	if bool(presentation.open_save_load_menu().get("ok", false)):
		return "save/load menu must be disabled during mission"
	# Host 槽位 guard(双保险): 出征中 emit 槽请求不得产生槽文件。
	var slot_path := "user://inkmon_l2_save_slot3.json"
	if FileAccess.file_exists(slot_path):
		DirAccess.remove_absolute(slot_path)
	presentation.save_slot_requested.emit(3)
	await get_tree().process_frame
	if FileAccess.file_exists(slot_path):
		return "host slot save must be guarded during mission"

	# "丢这趟"回滚: 污染内存 gold → abandon → 精确回到出发时刻。
	_host.get_player_actor().gold = gold_before + 999
	var abandon_result := _host.abandon_mission()
	if not bool(abandon_result.get("ok", false)):
		return "abandon_mission should succeed: %s" % str(abandon_result.get("message", ""))
	if _host.get_player_actor().gold != gold_before:
		return "gold must roll back to the departure snapshot (%d != %d)" % [_host.get_player_actor().gold, gold_before]
	if FileAccess.file_exists(InkMonWorldHost.DEPARTURE_SAVE_PATH):
		return "departure save must be deleted after abandon (lifecycle = mission duration)"
	if bool(_host.get_dev_agent_state().get("mission_active", false)):
		return "mission should be inactive after abandon"
	if bool(_host.abandon_mission().get("ok", false)):
		return "second abandon must fail (no active mission)"

	# === 第二段: 补给钟全灭全链 (M1.4) ===
	var hp_before: Array[float] = []
	for actor in (_host._world_gi as InkMonWorldGI).roster:
		hp_before.append(actor.attribute_set.hp)
	# M2.2 后踩野群节点必战 (干扰本段的"干净走步"断言) —— 第一步必须选非战斗出边;
	# guild 路径出征地图随机, 首层全战斗时放弃重开 (期望 ~1.1 次)。
	var gi2: InkMonWorldGI = null
	var step1_id := -1
	for _attempt in range(10):
		presentation.run_npc_action_for("guild", InkMonGuildNpcHandler.ACTION_START_MISSION)
		await get_tree().create_timer(0.5).timeout
		gi2 = _host._world_gi
		if gi2.mission_state == null:
			return "second mission should be active (wipe leg)"
		step1_id = _pick_non_battle_next(gi2)
		if step1_id >= 0:
			break
		_host.abandon_mission()
		await get_tree().process_frame
	if step1_id < 0:
		return "no non-battle first step across 10 mission rolls (wipe leg)"
	var supplies_start := gi2.mission_state.supplies
	gi2.submit(InkMonMissionMoveCommand.new(step1_id))
	await get_tree().create_timer(0.3).timeout
	if gi2.mission_state.supplies != supplies_start - 1:
		return "step with supplies should cost exactly 1 supply"
	for i in range(gi2.roster.size()):
		if gi2.roster[i].attribute_set.hp != hp_before[i]:
			return "step with supplies must not drain HP"
	# 布置粮尽 + 残血 (harness 直捣真相层), 再走一步 → 粮尽行军掉血 → 全灭 → deferred 自动回档。
	# 出边任选皆可: 粮尽全灭判定先于战斗触发, 踩上战斗节点前已回档。
	gi2.mission_state.supplies = 0
	for actor in gi2.roster:
		# 写 HP 走 set_current_hp (attribute_set.hp 是只读投影, 直接赋值被静默丢弃)。
		actor.set_current_hp(1.0)
	var step2 := gi2.mission_state.map.next_node_ids(gi2.mission_state.current_node_id)
	gi2.submit(InkMonMissionMoveCommand.new(step2[0]))
	await get_tree().create_timer(0.6).timeout
	var gi3: InkMonWorldGI = _host._world_gi
	if gi3 == gi2:
		return "world should be rebuilt (load departure) after party wipe"
	if gi3.has_active_mission():
		return "mission should be inactive after wipe rollback"
	if gi3.roster.size() != hp_before.size():
		return "roster size should survive wipe rollback"
	for i in range(gi3.roster.size()):
		if gi3.roster[i].attribute_set.hp != hp_before[i]:
			return "HP must roll back to departure snapshot after wipe (roster[%d]: %f != %f)" % [
				i, gi3.roster[i].attribute_set.hp, hp_before[i]]
	if FileAccess.file_exists(InkMonWorldHost.DEPARTURE_SAVE_PATH):
		return "departure save must be deleted after wipe rollback (lifecycle = mission duration)"

	# === 第二段b: 野群战败 = 全灭 → 回放确认离开 → 回出发档 (M2.2 全真实链路) ===
	# 走图找战斗出边, 踩上前把 roster 打到 0 (踩上必战 → 己方全倒 = 即时右胜 = 战败)。
	var gold_wild: int = _host.get_player_actor().gold
	var hp_wild: Array[float] = []
	for actor in (_host._world_gi as InkMonWorldGI).roster:
		hp_wild.append(actor.attribute_set.hp)
	var gi4: InkMonWorldGI = null
	var battle_reached := false
	for _attempt in range(6):
		presentation.run_npc_action_for("guild", InkMonGuildNpcHandler.ACTION_START_MISSION)
		await get_tree().create_timer(0.5).timeout
		gi4 = _host._world_gi
		if gi4.mission_state == null:
			return "wild-loss leg mission should start"
		var walk_steps := 0
		while gi4.mission_state != null and walk_steps < 8:
			var nexts := gi4.mission_state.map.next_node_ids(gi4.mission_state.current_node_id)
			if nexts.is_empty():
				break
			var battle_next := -1
			for next_id in nexts:
				if str(gi4.mission_state.map.get_node_info(next_id).get("kind", "")) == InkMonMissionMapData.NODE_BATTLE:
					battle_next = next_id
					break
			if battle_next >= 0:
				for actor in gi4.roster:
					actor.set_current_hp(0.0)
				gi4.submit(InkMonMissionMoveCommand.new(battle_next))
				await get_tree().create_timer(0.6).timeout
				battle_reached = true
				break
			gi4.submit(InkMonMissionMoveCommand.new(nexts[0]))
			await get_tree().create_timer(0.3).timeout
			walk_steps += 1
		if battle_reached:
			break
		# 这趟没撞到战斗 (走满 / 意外完赛) → 重开; 完赛会发奖, 基线重取。
		if _host._world_gi.has_active_mission():
			_host.abandon_mission()
			await get_tree().process_frame
		gold_wild = _host.get_player_actor().gold
		hp_wild.clear()
		for actor in (_host._world_gi as InkMonWorldGI).roster:
			hp_wild.append(actor.attribute_set.hp)
	if not battle_reached:
		return "no battle node reachable across 6 mission rolls (wild-loss leg)"
	# 战败 → 回放观看期 (世界冻结): 等 Leave 可用 → 玩家确认离开 → 丢这趟自动回档。
	var battle_view := presentation.get_node_or_null("Battle2DView") as InkMonBattle2DView
	if battle_view == null:
		return "battle 2d view should exist after a wild battle"
	var wait_frames := 0
	while not battle_view.is_leave_available() and wait_frames < 600:
		await get_tree().process_frame
		wait_frames += 1
	if not battle_view.is_leave_available():
		return "battle replay should end and offer Leave after a lost wild battle"
	battle_view.request_leave()
	await get_tree().create_timer(0.4).timeout
	var gi5: InkMonWorldGI = _host._world_gi
	if gi5 == gi4:
		return "world should be rebuilt (load departure) after wild battle defeat"
	if gi5.has_active_mission():
		return "mission should be inactive after wild-defeat rollback"
	if _host.get_player_actor().gold != gold_wild:
		return "gold must roll back after wild-defeat (%d != %d)" % [_host.get_player_actor().gold, gold_wild]
	for i in range(gi5.roster.size()):
		if gi5.roster[i].attribute_set.hp != hp_wild[i]:
			return "HP must roll back to departure snapshot after wild-defeat (roster[%d])" % i
	if FileAccess.file_exists(InkMonWorldHost.DEPARTURE_SAVE_PATH):
		return "departure save must be deleted after wild-defeat rollback"

	# === 第三段: 主菜单出发档恢复全链 (尾项③; real mouse input) ===
	# 造出发档 (真实 save_game 产物 = 合法档), 换 session 层重开 → 菜单该出恢复入口。
	var seed_result := _host.save_game(InkMonWorldHost.DEPARTURE_SAVE_PATH)
	if not bool(seed_result.get("ok", false)):
		return "failed to seed departure save for menu recovery leg"
	_host.free()
	_host = null
	await get_tree().process_frame

	var main := MainScene.instantiate() as InkMonMain
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var recover_button := main.find_child("RecoverButton", true, false) as Button
	if recover_button == null:
		return "RecoverButton should appear when a departure save exists"

	_click_at((recover_button.get_global_rect() as Rect2).get_center())
	await get_tree().process_frame
	await get_tree().process_frame
	if main.get_game_director() == null:
		return "Return to Departure click should enter the game"
	if FileAccess.file_exists(InkMonWorldHost.DEPARTURE_SAVE_PATH):
		return "departure save must be consumed (deleted) after menu recovery"
	main.free()
	return ""


## 当前节点的非战斗出边 (M2.2 必战语义下"干净走步"用); 全是战斗节点返回 -1。
func _pick_non_battle_next(gi: InkMonWorldGI) -> int:
	for next_id in gi.mission_state.map.next_node_ids(gi.mission_state.current_node_id):
		if str(gi.mission_state.map.get_node_info(next_id).get("kind", "")) != InkMonMissionMapData.NODE_BATTLE:
			return next_id
	return -1


func _click_at(screen_pos: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = screen_pos
	press.global_position = screen_pos
	get_viewport().push_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = screen_pos
	release.global_position = screen_pos
	get_viewport().push_input(release)
