extends Node
## M2.2/M2.3 野群战斗+捕捉 GI 级契约 (不碰 user://, 可并行):
##   模板地图生成 (seed 确定性 / radius-4 盘 61 格 / 皮肤映射 / 障碍 ≤3 限中带不压布阵点) /
##   踩 battle 节点 → 必战锁 + mission_battle_triggered / 锁定期选路拒 /
##   request_wild_battle 队伍契约 (payload 物种逐只对应 + 出生 roll 同源 + 等级 = 出战队均值) /
##   胜 → 捕捉窗口 (锁保持, 逐只掷球一次, 结果按规则确定) → resolve 离场清锁续走 →
##   完赛结算 adopt 落袋 (战场个体 ↔ 入库个体技能同源闭环) /
##   败 (right_win) → 锁保留无捕捉池 (Host 层丢趟出口在 smoke_mission_departure 串行覆盖)。


const FIXED_DT := 1.0 / 30.0
## 布阵点 (与 InkMonWorldGI._begin_battle_with_current_teams 的 preferred coords 同源)。
const SPAWN_COORDS: Array[Vector2i] = [
	Vector2i(-3, -1), Vector2i(-3, 0), Vector2i(-3, 1), Vector2i(-2, 0),
	Vector2i(3, -1), Vector2i(3, 0), Vector2i(3, 1), Vector2i(2, 0),
]

var _triggered_node_ids: Array[int] = []


func _ready() -> void:
	var status := _run()
	if status == "":
		print("SMOKE_TEST_RESULT: PASS - wild battle: map template gen + battle node trigger + wild team contract + win/lose lock semantics")
		get_tree().quit(0)
	else:
		print("SMOKE_TEST_RESULT: FAIL - %s" % status)
		get_tree().quit(1)


func _run() -> String:
	var gen_status := _check_map_gen_contract()
	if gen_status != "":
		return gen_status

	GameWorld.init(EventProcessorConfig.new(20, 1))
	TimelineRegistry.reset()
	var gi := _new_gi()
	gi.new_game()
	gi.mission_battle_triggered.connect(func(node_id: int) -> void:
		_triggered_node_ids.append(node_id))

	# === 踩 battle 节点触发 + 必战锁 (要求预测捕捉结果混合, 给后面捕捉段两分支覆盖) ===
	if not _start_mission_and_walk_to_battle(gi, true):
		return _fail("no battle node with mixed capture odds across candidate mission seeds (gen constants drifted?)")
	if _triggered_node_ids.size() != 1:
		return _fail("mission_battle_triggered should fire exactly once (got %d)" % _triggered_node_ids.size())
	var state := gi.mission_state
	if not state.has_pending_battle() or state.pending_battle_node_id != _triggered_node_ids[0]:
		return _fail("pending battle node should be set to the triggered node")
	if state.pending_battle_node_id != state.current_node_id:
		return _fail("battle triggers on the node just stepped onto")

	# 必战锁: 战斗未打, 选路一律拒。
	var locked_node := state.current_node_id
	var escape_ids := state.map.next_node_ids(locked_node)
	if not escape_ids.is_empty():
		gi.submit(InkMonMissionMoveCommand.new(escape_ids[0]))
		gi.tick(FIXED_DT)
		if gi.mission_state.current_node_id != locked_node:
			return _fail("moves must be refused while a battle is pending")

	# === request_wild_battle 队伍契约 ===
	var node_info := state.map.get_node_info(state.pending_battle_node_id)
	var wild_payload := (node_info.get("wild", []) as Array).duplicate(true)
	gi.request_wild_battle()
	if not gi.has_active_battle():
		return _fail("wild battle should be active after request_wild_battle")
	if gi.get_battle_map_doc().is_empty():
		return _fail("wild battle must carry a generated map doc")
	if gi.grid.get_all_coords().size() != 61:
		return _fail("wild battle grid should be the radius-4 template board (61 tiles)")
	if gi.right_team.size() != wild_payload.size():
		return _fail("wild team size must match node payload (%d != %d)" % [gi.right_team.size(), wild_payload.size()])
	var expected_level := InkMonBattleSetup.party_battle_level(gi)
	for i in range(gi.right_team.size()):
		var wild_actor := gi.right_team[i]
		var payload_entry := wild_payload[i] as Dictionary
		var species := str(payload_entry.get("species_id", ""))
		if wild_actor.species != species:
			return _fail("wild actor %d species mismatch (%s != %s)" % [i, wild_actor.species, species])
		if wild_actor.level != expected_level:
			return _fail("wild actor level must be party battle average (%d != %d)" % [wild_actor.level, expected_level])
		if wild_actor.get_team_id() != 1:
			return _fail("wild actor must be on team 1")
		if gi.roster.has(wild_actor):
			return _fail("wild actor must not be a roster member (transient combat unit)")
		# 出生 roll 同源: 场上技能 = 捕获后 adopt 会 roll 出的技能 (roll_seed 复用语义)。
		var expected_slots := InkMonSpeciesCatalog.roll_birth_skill_slots(species, int(payload_entry.get("roll_seed", 0)))
		if JSON.stringify(wild_actor.skill_slots) != JSON.stringify(expected_slots):
			return _fail("wild actor %d skill roll must match adopt birth roll for the same seed" % i)

	# === 胜: 捕捉窗口开启 (M2.3 锁保持到离场), 逐只掷球一次 ===
	for wild_actor in gi.right_team:
		wild_actor.set_current_hp(0.0)
	var guard := 0
	while gi.has_active_battle() and guard < 20:
		gi.tick(FIXED_DT)
		guard += 1
	if gi.has_active_battle():
		return _fail("wild battle should finish after right team is downed")
	if gi.get_result() != "left_win":
		return _fail("downed right team should yield left_win (got %s)" % gi.get_result())
	if not gi.has_active_mission():
		return _fail("mission must survive a won wild battle")
	if not gi.mission_state.has_pending_battle():
		return _fail("pending lock must persist through the capture window (cleared only on leave)")
	if gi.mission_state.capture_pool.size() != wild_payload.size():
		return _fail("capture pool must cover every downed wild (%d != %d)"
			% [gi.mission_state.capture_pool.size(), wild_payload.size()])
	# 捕捉窗口期移动仍拒 (还没离开战场)。
	var locked_capture_node := gi.mission_state.current_node_id
	var capture_escape := gi.mission_state.map.next_node_ids(locked_capture_node)
	if not capture_escape.is_empty():
		gi.submit(InkMonMissionMoveCommand.new(capture_escape[0]))
		gi.tick(FIXED_DT)
		if gi.mission_state.current_node_id != locked_capture_node:
			return _fail("moves must stay refused during the capture window")
	# 逐只掷球: 结果 == 规则掷点 (roll < chance); 同只二掷拒; captured_pending 精确累计。
	var mission_seed := gi.mission_state.mission_seed
	var battle_node_id := gi.mission_state.pending_battle_node_id
	var expected_captures := 0
	var captured_battle_slots: Array = []
	for entry in gi.mission_state.capture_pool.duplicate():
		var slot_index := int(entry.get("slot_index", -1))
		var capture_result := gi.attempt_wild_capture(slot_index)
		if not bool(capture_result.get("ok", false)):
			return _fail("capture attempt %d should be accepted" % slot_index)
		var species := str(entry.get("species_id", ""))
		var predicted := InkMonCaptureRules.capture_roll(mission_seed, battle_node_id, slot_index) \
			< InkMonCaptureRules.capture_chance(species)
		if bool(capture_result.get("captured", false)) != predicted:
			return _fail("capture outcome must follow InkMonCaptureRules wiring (slot %d)" % slot_index)
		if predicted:
			expected_captures += 1
			captured_battle_slots.append({
				"species_id": species,
				"skill_slots": gi.right_team[slot_index].skill_slots.duplicate(true),
			})
		if bool(gi.attempt_wild_capture(slot_index).get("ok", false)):
			return _fail("second throw on the same wild must be refused (slot %d)" % slot_index)
	if gi.mission_state.captured_pending.size() != expected_captures:
		return _fail("captured_pending must accumulate exactly the successful throws (%d != %d)"
			% [gi.mission_state.captured_pending.size(), expected_captures])
	if expected_captures == 0 or expected_captures == gi.mission_state.capture_pool.size():
		return _fail("seed search should have produced mixed capture outcomes (got %d/%d)"
			% [expected_captures, gi.mission_state.capture_pool.size()])

	# === resolve 离场: 清锁清池, 选路恢复 ===
	gi.resolve_wild_battle_encounter()
	if gi.mission_state.has_pending_battle():
		return _fail("leaving the encounter must clear the pending battle lock")
	if not gi.mission_state.capture_pool.is_empty():
		return _fail("leaving the encounter must forfeit the capture pool")

	# === 走到目标完赛: settle adopt 落袋, 战场个体 ↔ 入库个体技能同源闭环 ===
	var roster_before := gi.roster.size()
	var walk_guard := 0
	while gi.has_active_mission() and walk_guard < 32:
		var onward := gi.mission_state.map.next_node_ids(gi.mission_state.current_node_id)
		if onward.is_empty():
			return _fail("non-target node with no outgoing edges during settle walk")
		gi.submit(InkMonMissionMoveCommand.new(onward[0]))
		gi.tick(FIXED_DT)
		walk_guard += 1
		if gi.has_active_mission() and gi.mission_state.has_pending_battle():
			# 途中再撞野群: 秒杀 + 不捕直接离场 (captured_pending 保持精确)。
			gi.request_wild_battle()
			for wild_actor in gi.right_team:
				wild_actor.set_current_hp(0.0)
			var inner_guard := 0
			while gi.has_active_battle() and inner_guard < 20:
				gi.tick(FIXED_DT)
				inner_guard += 1
			if gi.has_active_battle():
				return _fail("settle-walk wild battle should finish")
			gi.resolve_wild_battle_encounter()
	if gi.has_active_mission():
		return _fail("mission should complete within the settle walk")
	if gi.roster.size() != roster_before + expected_captures:
		return _fail("settle must adopt exactly the captured wilds (%d != %d + %d)"
			% [gi.roster.size(), roster_before, expected_captures])
	for i in range(expected_captures):
		var adopted := gi.roster[roster_before + i]
		var captured_slot := captured_battle_slots[i] as Dictionary
		if adopted.species != str(captured_slot.get("species_id", "")):
			return _fail("adopted %d species must match the captured wild" % i)
		if JSON.stringify(adopted.skill_slots) != JSON.stringify(captured_slot.get("skill_slots", [])):
			return _fail("adopted %d skills must equal the wild individual seen in battle (roll_seed reuse)" % i)

	# === 败 (right_win): 必战锁保留 + 无捕捉池, GI 不自灭 (丢趟出口归 Host) ===
	_triggered_node_ids.clear()
	for actor in gi.roster:
		actor.set_current_hp(-1.0)
	if not _start_mission_and_walk_to_battle(gi):
		return _fail("no battle node reachable for the loss leg")
	for actor in gi.roster:
		actor.set_current_hp(0.0)
	gi.request_wild_battle()
	guard = 0
	while gi.has_active_battle() and guard < 20:
		gi.tick(FIXED_DT)
		guard += 1
	if gi.has_active_battle():
		return _fail("wild battle should finish after roster is downed")
	if gi.get_result() != "right_win":
		return _fail("downed roster should yield right_win (got %s)" % gi.get_result())
	if not gi.has_active_mission():
		return _fail("GI must not self-terminate the mission on defeat (wipe exit is Host's)")
	if not gi.mission_state.has_pending_battle():
		return _fail("pending battle lock must stay set after defeat")
	if not gi.mission_state.capture_pool.is_empty():
		return _fail("defeat must not open a capture window")
	if bool(gi.attempt_wild_capture(0).get("ok", false)):
		return _fail("capture attempts must be rejected without a capture pool")

	# === 必战锁只认野群战: 出征中混入训练战 (dev-agent 路径), 胜负都不碰锁 ===
	for actor in gi.roster:
		actor.set_current_hp(-1.0)
	gi.request_training_battle()
	if gi.is_wild_battle():
		return _fail("training battle must not be flagged as wild battle")
	for dummy in gi.right_team:
		dummy.set_current_hp(0.0)
	guard = 0
	while gi.has_active_battle() and guard < 20:
		gi.tick(FIXED_DT)
		guard += 1
	if gi.has_active_battle():
		return _fail("training battle should finish after dummies are downed")
	if not gi.mission_state.has_pending_battle():
		return _fail("a won training battle must not clear the wild battle lock")
	# Host 对任何战斗离场都会调 resolve —— 训练战后的 resolve 必须是 no-op (锁属于还没打的野群战)。
	gi.resolve_wild_battle_encounter()
	if not gi.mission_state.has_pending_battle():
		return _fail("leaving a training battle view must not resolve the pending wild encounter")
	GameWorld.shutdown()
	return ""


## 起一趟出征并沿图走到 battle 节点 (走法偏好 battle 出边)。require_mixed_captures = 要求该节点
## 预测捕捉结果同时含成功与失败 (捕捉契约两分支都要吃到)。整趟没撞到/不满足则换 seed 重试。
## 每次 seed 尝试前清触发记录 → 成功返回后 _triggered_node_ids 只含最终这趟 (exactly-once 断言成立)。
func _start_mission_and_walk_to_battle(gi: InkMonWorldGI, require_mixed_captures := false) -> bool:
	for seed_value in range(4000, 4040):
		_triggered_node_ids.clear()
		var start_result := gi.start_mission({"seed": seed_value, "supplies": 40})
		if not bool(start_result.get("ok", false)):
			return false
		var steps := 0
		while gi.has_active_mission() and not gi.mission_state.has_pending_battle() and steps < 16:
			var nexts := gi.mission_state.map.next_node_ids(gi.mission_state.current_node_id)
			if nexts.is_empty():
				break
			var pick := nexts[0]
			for next_id in nexts:
				if str(gi.mission_state.map.get_node_info(next_id).get("kind", "")) == InkMonMissionMapData.NODE_BATTLE:
					pick = next_id
					break
			gi.submit(InkMonMissionMoveCommand.new(pick))
			gi.tick(FIXED_DT)
			steps += 1
		if gi.has_active_mission() and gi.mission_state.has_pending_battle() \
				and (not require_mixed_captures or _predicted_captures_mixed(gi)):
			return true
		if gi.has_active_mission():
			gi.end_mission("aborted")
	return false


## 该 pending 节点的预测捕捉结果是否混合 (≥1 成 且 ≥1 败) —— 复用生产规则函数做预测。
func _predicted_captures_mixed(gi: InkMonWorldGI) -> bool:
	var node_id := gi.mission_state.pending_battle_node_id
	var wild_pack := gi.mission_state.map.get_node_info(node_id).get("wild", []) as Array
	var successes := 0
	for i in range(wild_pack.size()):
		var species := str((wild_pack[i] as Dictionary).get("species_id", ""))
		if InkMonCaptureRules.capture_roll(gi.mission_state.mission_seed, node_id, i) \
				< InkMonCaptureRules.capture_chance(species):
			successes += 1
	return successes > 0 and successes < wild_pack.size()


## 模板地图生成契约 (纯 static, 不动世界)。
func _check_map_gen_contract() -> String:
	var doc := InkMonWildBattleMapGen.generate_doc(4242, InkMonWorldMapData.TERRAIN_FOREST)
	if JSON.stringify(doc) != JSON.stringify(InkMonWildBattleMapGen.generate_doc(4242, InkMonWorldMapData.TERRAIN_FOREST)):
		return "same seed must generate the identical map doc"
	var tiles := doc.get("tiles", []) as Array
	if tiles.size() != 61:
		return "radius-4 board must have 61 tiles (got %d)" % tiles.size()
	var seen_obstacles := false
	var seen_clean := false
	for seed_value in range(1, 21):
		var seeded := InkMonWildBattleMapGen.generate_doc(seed_value, InkMonWorldMapData.TERRAIN_PLAIN)
		var water_count := 0
		for tile_value in (seeded.get("tiles", []) as Array):
			var tile := tile_value as Dictionary
			var coord := Vector2i(int(tile.get("q", 0)), int(tile.get("r", 0)))
			var terrain := str(tile.get("terrain", ""))
			if terrain == InkMonWildBattleMapGen.OBSTACLE_TERRAIN:
				water_count += 1
				if absi(coord.x) > InkMonWildBattleMapGen.OBSTACLE_ZONE_Q:
					return "obstacles must stay inside the middle band (|q| <= %d)" % InkMonWildBattleMapGen.OBSTACLE_ZONE_Q
			elif terrain != "grass":
				return "plain skin board must be grass (got %s)" % terrain
			if SPAWN_COORDS.has(coord) and terrain == InkMonWildBattleMapGen.OBSTACLE_TERRAIN:
				return "obstacles must never cover spawn coords"
		if water_count > InkMonWildBattleMapGen.OBSTACLE_MAX:
			return "obstacle count must be <= %d (seed %d got %d)" % [InkMonWildBattleMapGen.OBSTACLE_MAX, seed_value, water_count]
		seen_obstacles = seen_obstacles or water_count > 0
		seen_clean = seen_clean or water_count == 0
	if not seen_obstacles:
		return "expected at least one seed in 1..20 to roll obstacles"
	if not seen_clean:
		return "expected at least one seed in 1..20 to roll a clean board"
	# 皮肤映射: forest → dirt / hill → stone (plain → grass 已在上面覆盖)。
	var forest_tiles := InkMonWildBattleMapGen.generate_doc(7, InkMonWorldMapData.TERRAIN_FOREST).get("tiles", []) as Array
	if str((forest_tiles[0] as Dictionary).get("terrain", "")) != "dirt":
		return "forest skin must map to dirt"
	var hill_tiles := InkMonWildBattleMapGen.generate_doc(7, InkMonWorldMapData.TERRAIN_HILL).get("tiles", []) as Array
	if str((hill_tiles[0] as Dictionary).get("terrain", "")) != "stone":
		return "hill skin must map to stone"
	return ""


func _fail(message: String) -> String:
	GameWorld.shutdown()
	return message


func _new_gi() -> InkMonWorldGI:
	return GameWorld.create_instance(func() -> GameplayInstance:
		return InkMonWorldGI.new()
	) as InkMonWorldGI
