extends Node
## M2.2 野群战斗 GI 级契约 (不碰 user://, 可并行):
##   模板地图生成 (seed 确定性 / radius-4 盘 61 格 / 皮肤映射 / 障碍 ≤3 限中带不压布阵点) /
##   踩 battle 节点 → 必战锁 + mission_battle_triggered / 锁定期选路拒 /
##   request_wild_battle 队伍契约 (payload 物种逐只对应 + 出生 roll 同源 + 等级 = 出战队均值) /
##   胜 → 清锁续走; 败 (right_win) → 锁保留 (Host 层丢趟出口在 smoke_mission_departure 串行覆盖)。


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

	# === 踩 battle 节点触发 + 必战锁 ===
	if not _start_mission_and_walk_to_battle(gi):
		return _fail("no battle node reachable across candidate mission seeds (gen constants drifted?)")
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

	# === 胜: 清必战锁 + 选路恢复 ===
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
	if gi.mission_state.has_pending_battle():
		return _fail("pending battle lock must clear after victory")
	var before_move := gi.mission_state.current_node_id
	var onward_ids := gi.mission_state.map.next_node_ids(before_move)
	if onward_ids.is_empty():
		return _fail("battle node should have onward edges (never target layer)")
	gi.submit(InkMonMissionMoveCommand.new(onward_ids[0]))
	gi.tick(FIXED_DT)
	# 战斗节点可坐落最后一个中间层 → 续走一步恰好抵达目标自动结算也是合法结果。
	if gi.mission_state != null and gi.mission_state.current_node_id == before_move:
		return _fail("moves must be accepted again after victory")

	# === 败 (right_win): 必战锁保留, GI 不自灭 (丢趟出口归 Host) ===
	if gi.has_active_mission():
		gi.end_mission("aborted")
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
	GameWorld.shutdown()
	return ""


## 起一趟出征并沿图走到 battle 节点 (走法偏好 battle 出边)。整趟没撞到则换 seed 重试。
## 返回是否成功触发 (成功时 gi.mission_state 停在 battle 节点, 必战锁已置)。
func _start_mission_and_walk_to_battle(gi: InkMonWorldGI) -> bool:
	for seed_value in range(4000, 4020):
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
		if gi.has_active_mission() and gi.mission_state.has_pending_battle():
			return true
		if gi.has_active_mission():
			gi.end_mission("aborted")
	return false


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
