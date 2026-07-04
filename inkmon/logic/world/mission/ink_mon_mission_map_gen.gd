class_name InkMonMissionMapGen
## 趟内节点图生成器 (static, 确定性): 尖塔式 layered DAG + 最简 hex 皮肤摆放。
##
## 结构保证 (smoke 焊死的硬不变量):
##   - 分层天然无环; 层 0 = 起点单节点, 末层 = 目标单节点。
##   - 每个非目标节点出边 ≥ 1 (正向映射边), 每个非起点节点入边 ≥ 1 (反向补齐)
##     ⇒ 每个节点都在某条 起点→目标 路径上 (无死胡同 / 无不可达岛)。
##   - 出边度 ≤ 3 (选路选项 2-3 个, game-vision "每次三个选项"的参数载体)。
## 皮肤 (v1 最简, Phase 5+ 打磨): 节点 coord = 平面空间 entry→target 插值 + 层内垂直于行进方向展开,
## clamp 进地图界 —— 出征方向任意 (据点居中、目标四散), 摆放对全方向成立。


const LAYER_COUNT := 6
const MIN_LAYER_WIDTH := 2
const MAX_LAYER_WIDTH := 3
const EXTRA_EDGE_CHANCE := 0.4


static func generate(seed_value: int, entry_coord: Vector2i, target_coord: Vector2i, bounds: Rect2i) -> InkMonMissionMapData:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var map := InkMonMissionMapData.new()
	var layers: Array[Array] = []
	var next_id := 0
	for layer_index in range(LAYER_COUNT):
		var width := 1
		if layer_index > 0 and layer_index < LAYER_COUNT - 1:
			width = rng.randi_range(MIN_LAYER_WIDTH, MAX_LAYER_WIDTH)
		var layer_ids: Array = []
		for slot in range(width):
			var node_id := next_id
			next_id += 1
			var kind := InkMonMissionMapData.NODE_EMPTY
			if layer_index == 0:
				kind = InkMonMissionMapData.NODE_START
			elif layer_index == LAYER_COUNT - 1:
				kind = InkMonMissionMapData.NODE_TARGET
			map.nodes.append({
				"id": node_id,
				"layer": layer_index,
				"coord": _node_coord(entry_coord, target_coord, layer_index, slot, width, bounds),
				"kind": kind,
			})
			layer_ids.append(node_id)
		layers.append(layer_ids)
	map.entry_node_id = int((layers[0] as Array)[0])
	map.target_node_id = int((layers[LAYER_COUNT - 1] as Array)[0])
	for layer_index in range(LAYER_COUNT - 1):
		var from_ids: Array = layers[layer_index]
		var to_ids: Array = layers[layer_index + 1]
		# 正向映射边: 每个 from 节点 ≥1 出边; 排序映射天然不交叉 (走廊可读性)。
		for a in range(from_ids.size()):
			var mapped := int(floor(float(a) * to_ids.size() / from_ids.size()))
			_add_edge(map, int(from_ids[a]), int(to_ids[mapped]))
			if rng.randf() < EXTRA_EDGE_CHANCE:
				var extra := mini(mapped + 1, to_ids.size() - 1)
				if extra != mapped:
					_add_edge(map, int(from_ids[a]), int(to_ids[extra]))
		# 反向补齐: 每个 to 节点 ≥1 入边 (无不可达岛)。
		for b in range(to_ids.size()):
			if not _has_incoming(map, from_ids, int(to_ids[b])):
				var src := int(floor(float(b) * from_ids.size() / to_ids.size()))
				_add_edge(map, int(from_ids[src]), int(to_ids[b]))
	map.rebuild_index()
	return map


## 层内展开步长 (平面单位 ≈ hex 间距): 太窄节点挤团, 太宽走廊乱穿。
const SPREAD_STEP := 2.6


## 平面空间摆放: entry→target 插值为主轴, 层内沿主轴的垂直方向展开 ——
## 出征方向任意 (中心出生 + 目标四散) 后, 纯 y 向 spread 会在南北向出征时把整层挤成一条线。
## bounds = odd-r offset 矩形 (与世界边界语义一致), clamp 在 offset 空间做。
static func _node_coord(entry_coord: Vector2i, target_coord: Vector2i, layer_index: int, slot: int, width: int, bounds: Rect2i) -> Vector2i:
	var t := float(layer_index) / float(LAYER_COUNT - 1)
	var entry_plane := InkMonWorldMapData.axial_to_plane(entry_coord)
	var target_plane := InkMonWorldMapData.axial_to_plane(target_coord)
	var axis := target_plane - entry_plane
	var perp := axis.orthogonal().normalized() if axis.length() > 0.01 else Vector2(0.0, 1.0)
	var spread := (float(slot) - float(width - 1) / 2.0) * SPREAD_STEP
	var coord := InkMonWorldMapData.plane_to_axial(entry_plane.lerp(target_plane, t) + perp * spread)
	var offset := InkMonWorldMapData.axial_to_offset(coord)
	offset.x = clampi(offset.x, bounds.position.x, bounds.position.x + bounds.size.x - 1)
	offset.y = clampi(offset.y, bounds.position.y, bounds.position.y + bounds.size.y - 1)
	return InkMonWorldMapData.offset_to_axial(offset.x, offset.y)


static func _add_edge(map: InkMonMissionMapData, from_id: int, to_id: int) -> void:
	var list: Array = map.edges.get(from_id, [])
	if not list.has(to_id):
		list.append(to_id)
	map.edges[from_id] = list


static func _has_incoming(map: InkMonMissionMapData, from_ids: Array, to_id: int) -> bool:
	for from_value in from_ids:
		var list: Array = map.edges.get(int(from_value), [])
		if list.has(to_id):
			return true
	return false
