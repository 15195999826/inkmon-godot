extends Node
## 趟内节点图生成器硬不变量 (多 seed × 多方向扫描):
##   分层 DAG 无环(结构天然) / 起点可达全部 / 全部可达目标(无死胡同·无孤岛) /
##   出边度 ≤3 且非目标节点 ≥1 / coord 在界内 / 同 seed 确定性。
##   方向组合覆盖东/北/西南/东北短距 —— 中心出生 + 目标四散后出征可朝任意方向, 摆放几何须全向成立。


const SEED_COUNT := 20
## bounds = odd-r offset 矩形 (与世界边界语义一致); ROUTES 的 axial 坐标均在此矩形内。
const BOUNDS := Rect2i(0, 0, 28, 22)
## [entry, target] axial 组合: 东(长) / 北(纵向, 旧纯 y-spread 摆放在此退化成线) / 西南(反向斜) / 东北(MIN 距离下限 9)。
const ROUTES: Array = [
	[Vector2i(9, 11), Vector2i(22, 9)],
	[Vector2i(9, 11), Vector2i(15, 1)],
	[Vector2i(9, 11), Vector2i(-6, 19)],
	[Vector2i(8, 10), Vector2i(17, 4)],
]


func _ready() -> void:
	var status := _run()
	if status == "":
		print("SMOKE_TEST_RESULT: PASS - mission map gen invariants hold across %d seeds x %d routes" % [SEED_COUNT, ROUTES.size()])
		get_tree().quit(0)
	else:
		print("SMOKE_TEST_RESULT: FAIL - %s" % status)
		get_tree().quit(1)


func _run() -> String:
	for route_value in ROUTES:
		var route := route_value as Array
		var entry := route[0] as Vector2i
		var target := route[1] as Vector2i
		for seed_index in range(SEED_COUNT):
			var seed_value := 1000 + seed_index * 37
			var map := InkMonMissionMapGen.generate(seed_value, entry, target, BOUNDS)
			var check := _check_map(map, seed_value)
			if check != "":
				return "route %s->%s: %s" % [str(entry), str(target), check]
	var first_route := ROUTES[0] as Array
	var d1 := InkMonMissionMapGen.generate(4242, first_route[0] as Vector2i, first_route[1] as Vector2i, BOUNDS).to_debug_dict()
	var d2 := InkMonMissionMapGen.generate(4242, first_route[0] as Vector2i, first_route[1] as Vector2i, BOUNDS).to_debug_dict()
	if JSON.stringify(d1) != JSON.stringify(d2):
		return "same seed must generate identical mission map"
	return ""


func _check_map(map: InkMonMissionMapData, seed_value: int) -> String:
	if map.node_count() < InkMonMissionMapGen.LAYER_COUNT:
		return "seed %d: too few nodes (%d)" % [seed_value, map.node_count()]
	if str(map.get_node_info(map.entry_node_id).get("kind", "")) != InkMonMissionMapData.NODE_START:
		return "seed %d: entry node kind wrong" % seed_value
	if str(map.get_node_info(map.target_node_id).get("kind", "")) != InkMonMissionMapData.NODE_TARGET:
		return "seed %d: target node kind wrong" % seed_value
	for node in map.nodes:
		var node_id := int(node.get("id", -1))
		var outs := map.next_node_ids(node_id)
		if node_id != map.target_node_id and outs.is_empty():
			return "seed %d: node %d has no outgoing edge (dead end)" % [seed_value, node_id]
		if node_id == map.target_node_id and not outs.is_empty():
			return "seed %d: target node must have no outgoing edge" % seed_value
		if outs.size() > 3:
			return "seed %d: node %d out-degree %d > 3" % [seed_value, node_id, outs.size()]
		var coord := node.get("coord", Vector2i(-1, -1)) as Vector2i
		if not BOUNDS.has_point(InkMonWorldMapData.axial_to_offset(coord)):
			return "seed %d: node %d coord %s out of offset bounds" % [seed_value, node_id, str(coord)]
	var forward := _reachable_from(map, map.entry_node_id, false)
	if forward.size() != map.node_count():
		return "seed %d: only %d/%d nodes reachable from entry" % [seed_value, forward.size(), map.node_count()]
	var backward := _reachable_from(map, map.target_node_id, true)
	if backward.size() != map.node_count():
		return "seed %d: only %d/%d nodes can reach target" % [seed_value, backward.size(), map.node_count()]
	return ""


func _reachable_from(map: InkMonMissionMapData, start_id: int, reverse: bool) -> Dictionary:
	var visited: Dictionary = {start_id: true}
	var queue: Array[int] = [start_id]
	while not queue.is_empty():
		var current := queue.pop_front() as int
		var neighbors: Array[int] = []
		if reverse:
			for node in map.nodes:
				var from_id := int(node.get("id", -1))
				if map.has_edge(from_id, current):
					neighbors.append(from_id)
		else:
			neighbors = map.next_node_ids(current)
		for neighbor in neighbors:
			if not visited.has(neighbor):
				visited[neighbor] = true
				queue.append(neighbor)
	return visited
