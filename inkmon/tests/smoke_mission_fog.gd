extends Node
## Phase 4 迷雾三态 GI 级契约 (不碰 user://, 可并行):
##   出发/每步点亮视野圆 (半径 = player.sight_range, 持久 revealed) / 圆内节点记 seen 快照 (Q4.5) /
##   snapshot 三态域正确 (lit=圆内, seen=快照非圆内, hidden=从未见) / 隐藏下一跳仍可走 (Q4.2 "?" 可点) /
##   sight_range 进玩家持久切片 roundtrip。


const FIXED_DT := 1.0 / 30.0


func _ready() -> void:
	var status := _run()
	if status == "":
		print("SMOKE_TEST_RESULT: PASS - mission fog: sight circle reveal + seen snapshots + tri-state snapshot + hidden next walkable")
		get_tree().quit(0)
	else:
		print("SMOKE_TEST_RESULT: FAIL - %s" % status)
		get_tree().quit(1)


func _run() -> String:
	GameWorld.init(EventProcessorConfig.new(20, 1))
	TimelineRegistry.reset()
	var gi := _new_gi()
	gi.new_game()

	# sight_range 进玩家持久切片。
	gi.player_actor.sight_range = 4
	var player_roundtrip := InkMonPlayerActor.from_dict(gi.player_actor.to_dict())
	if player_roundtrip.sight_range != 4:
		return _fail("sight_range must survive the player persistence slice")
	gi.player_actor.sight_range = InkMonPlayerActor.DEFAULT_SIGHT_RANGE

	if not bool(gi.start_mission({"seed": 7001, "supplies": 40}).get("ok", false)):
		return _fail("mission should start")
	var state := gi.mission_state
	var sight := gi.player_actor.sight_range

	# 出发点亮: 入口视野圆内世界格全 revealed。
	var entry_coord := state.map.get_node_info(state.map.entry_node_id).get("coord", Vector2i.ZERO) as Vector2i
	var circle_cells := _cells_within(gi, entry_coord, sight)
	if circle_cells.is_empty():
		return _fail("sight circle should cover cells")
	for cell in circle_cells:
		if not gi.world_map.is_revealed(cell):
			return _fail("departure must reveal the whole sight circle (missing %s)" % str(cell))

	# 圆内节点已记 seen 快照; snapshot 三态域正确。
	var query := IWorldQuery.new(gi)
	var snapshot := query.get_mission_snapshot()
	var seen_count := 0
	var hidden_count := 0
	var entry_hex := HexCoord.new(entry_coord.x, entry_coord.y)
	for node_value in (snapshot.get("nodes", []) as Array):
		var node := node_value as Dictionary
		var node_coord := node.get("coord", Vector2i.ZERO) as Vector2i
		var in_circle := entry_hex.distance_to(HexCoord.new(node_coord.x, node_coord.y)) <= sight
		var visibility := str(node.get("visibility", ""))
		var node_id := int(node.get("id", -1))
		if in_circle:
			if visibility != "lit":
				return _fail("node %d inside the circle must be lit (got %s)" % [node_id, visibility])
			if not state.seen_node_kinds.has(node_id):
				return _fail("node %d inside the circle must be snapshotted as seen" % node_id)
			if str(node.get("seen_kind", "")) != str(node.get("kind", "")):
				return _fail("seen snapshot must record the node kind")
			seen_count += 1
		elif visibility == "lit":
			return _fail("node %d outside the circle must not be lit" % node_id)
		elif visibility == "hidden":
			if state.seen_node_kinds.has(node_id):
				return _fail("hidden node %d must not be in the seen set" % node_id)
			hidden_count += 1
	if seen_count == 0:
		return _fail("departure circle should cover at least the entry node")
	if hidden_count == 0:
		return _fail("a fresh mission should still have unseen (hidden) nodes")

	# 隐藏下一跳仍可走 (Q4.2 "?" 可点不可知): 可达性不看可见性。
	var revealed_before := gi.world_map.revealed_cells.size()
	var seen_before := state.seen_node_kinds.size()
	var first_next := state.map.next_node_ids(state.current_node_id)[0]
	gi.submit(InkMonMissionMoveCommand.new(first_next))
	gi.tick(FIXED_DT)
	if state.current_node_id != first_next:
		return _fail("moving onto a next node must work regardless of its visibility")
	# 每步点亮: 新圆并入持久 revealed, seen 单调增长。
	if gi.world_map.revealed_cells.size() < revealed_before:
		return _fail("revealed cells must never shrink")
	if state.seen_node_kinds.size() < seen_before:
		return _fail("seen snapshots must never shrink")
	var step_coord := state.map.get_node_info(first_next).get("coord", Vector2i.ZERO) as Vector2i
	for cell in _cells_within(gi, step_coord, sight):
		if not gi.world_map.is_revealed(cell):
			return _fail("each step must reveal its sight circle")
	GameWorld.shutdown()
	return ""


## 世界界内、以 center 为圆心半径 radius 的全部格。
func _cells_within(gi: InkMonWorldGI, center: Vector2i, radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var center_hex := HexCoord.new(center.x, center.y)
	for row in range(gi.world_map.height):
		for col in range(gi.world_map.width):
			var cell := InkMonWorldMapData.offset_to_axial(col, row)
			if center_hex.distance_to(HexCoord.new(cell.x, cell.y)) <= radius:
				result.append(cell)
	return result


func _fail(message: String) -> String:
	GameWorld.shutdown()
	return message


func _new_gi() -> InkMonWorldGI:
	return GameWorld.create_instance(func() -> GameplayInstance:
		return InkMonWorldGI.new()
	) as InkMonWorldGI
