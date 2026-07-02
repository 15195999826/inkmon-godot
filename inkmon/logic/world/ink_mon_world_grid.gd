class_name InkMonWorldGrid
extends RefCounted


const PLAYER_ID := "player"
## 主世界地图 = 静态手写 JSON（T2 契约，content/maps/）；不再程序化生成。
const WORLD_MAP_ID := "world_main"
## 逻辑几何尺寸沿用历史值（相邻格世界距离 = size·√3 = 2.0）。
const LOGIC_HEX_SIZE := 2.0 / sqrt(3.0)


var model: GridMapModel


func setup(map_id: String = WORLD_MAP_ID) -> void:
	var bundle := InkMonMapLoader.load_bundle(map_id, LOGIC_HEX_SIZE)
	Log.assert_crash(not bundle.is_empty(), "InkMonWorldGrid", "world map bundle failed to load: %s" % map_id)
	model = bundle["model"] as GridMapModel


func sync_occupants(player_coord: Vector2i, npc_defs: Dictionary) -> void:
	Log.assert_crash(model != null, "InkMonWorldGrid", "grid model is not initialized")
	# 只重置运行时态（occupant / reservation）；is_blocking 是地形静态性质
	# （terrains.json → 加载器写入），不能在 sync 时清掉。
	for coord in model.get_all_coords():
		model.remove_occupant(coord)
		model.cancel_reservation(coord)

	for npc_id_value in npc_defs.keys():
		var npc_id := str(npc_id_value)
		var npc_def := npc_defs[npc_id] as Dictionary
		if npc_def == null:
			continue
		var npc_coord := npc_def.get("coord", Vector2i.ZERO) as Vector2i
		if has_coord(npc_coord):
			var placed := model.place_occupant(_to_hex(npc_coord), "npc:%s" % npc_id)
			Log.assert_crash(placed, "InkMonWorldGrid", "failed to place NPC occupant: %s" % npc_id)

	if has_coord(player_coord):
		var placed_player := model.place_occupant(_to_hex(player_coord), PLAYER_ID)
		Log.assert_crash(placed_player, "InkMonWorldGrid", "failed to place player occupant")


func get_player_coord() -> Vector2i:
	var found: Variant = model.find_occupant_position(PLAYER_ID)
	var coord := found as HexCoord
	# fail-fast: player occupant 是 grid 不变量 (sync_occupants 起手放置)。缺失即 invariant 破 ——
	# 静默返 (0,0) 会被 to_dict 回写存档把玩家钳到原点 (静默污染), 故响亮崩。
	Log.assert_crash(coord != null, "InkMonWorldGrid", "player occupant missing from overworld grid")
	return coord.to_axial()


func has_coord(coord: Vector2i) -> bool:
	return model != null and model.has_tile(_to_hex(coord))


func is_occupied(coord: Vector2i) -> bool:
	return model != null and model.is_occupied(_to_hex(coord))


func is_passable_for_actor(coord: Vector2i, actor_id: String) -> bool:
	if not has_coord(coord):
		return false
	var occupant: Variant = model.get_occupant(_to_hex(coord))
	if occupant != null and str(occupant) != actor_id:
		return false
	return not model.is_tile_blocking(_to_hex(coord)) and not model.is_reserved(_to_hex(coord))


func get_occupant(coord: Vector2i) -> String:
	if model == null:
		return ""
	var occupant: Variant = model.get_occupant(_to_hex(coord))
	return str(occupant) if occupant != null else ""


func reserve_tile(coord: Vector2i, actor_id: String) -> bool:
	if model == null:
		return false
	return model.reserve_tile(_to_hex(coord), actor_id)


func cancel_reservation(coord: Vector2i) -> void:
	if model != null:
		model.cancel_reservation(_to_hex(coord))


func move_occupant(from_coord: Vector2i, to_coord: Vector2i) -> bool:
	if model == null:
		return false
	return model.move_occupant(_to_hex(from_coord), _to_hex(to_coord))


func reservation_count() -> int:
	if model == null:
		return 0
	var count := 0
	for coord in model.get_all_coords():
		if model.is_reserved(coord):
			count += 1
	return count


func occupant_count() -> int:
	if model == null:
		return 0
	var count := 0
	for coord in model.get_all_coords():
		if model.is_occupied(coord):
			count += 1
	return count


func resolve_target_for_actor(actor_id: String, requested_target: Vector2i) -> Dictionary:
	if not has_coord(requested_target):
		return {
			"ok": false,
			"message": "target is outside overworld grid",
			"target": Vector2i.ZERO,
			"retargeted": false,
		}

	if is_passable_for_actor(requested_target, actor_id):
		return {
			"ok": true,
			"message": "target resolved",
			"target": requested_target,
			"retargeted": false,
		}

	var from_coord := get_player_coord() if actor_id == PLAYER_ID else find_actor_coord(actor_id)
	var best_target := Vector2i(999999, 999999)
	var best_path: Array[Vector2i] = []
	var found_candidate := false
	for neighbor in _sorted_neighbors(requested_target):
		if not is_passable_for_actor(neighbor, actor_id):
			continue
		var path := find_path(actor_id, from_coord, neighbor)
		if path.is_empty() and from_coord != neighbor:
			continue
		if not found_candidate or path.size() < best_path.size() or (path.size() == best_path.size() and _coord_less(neighbor, best_target)):
			best_target = neighbor
			best_path = path
			found_candidate = true

	if not found_candidate:
		return {
			"ok": false,
			"message": "blocked target has no reachable adjacent tile",
			"target": requested_target,
			"retargeted": false,
		}

	return {
		"ok": true,
		"message": "target retargeted to adjacent tile",
		"target": best_target,
		"retargeted": true,
	}


func find_actor_coord(actor_id: String) -> Vector2i:
	if model == null:
		return Vector2i.ZERO
	var found: Variant = model.find_occupant_position(actor_id)
	var coord := found as HexCoord
	if coord == null:
		return Vector2i.ZERO
	return coord.to_axial()


## 寻路走 ultra-grid-map 插件 astar (替换自写 BFS)。
## 输出契约不变: 返回不含起点的逐步 axial 坐标; 无路 / 起==终 / 终点不可通行 → []。
func find_path(actor_id: String, from_coord: Vector2i, to_coord: Vector2i) -> Array[Vector2i]:
	if model == null or not has_coord(from_coord) or not has_coord(to_coord):
		return []
	if from_coord == to_coord:
		return []
	if not is_passable_for_actor(to_coord, actor_id):
		return []

	var passable := func(coord: HexCoord) -> bool:
		return is_passable_for_actor(coord.to_axial(), actor_id)
	var result := GridPathfinding.astar(model, _to_hex(from_coord), _to_hex(to_coord), passable)
	if not result.found:
		return []

	# astar 路径含起点 (index 0); 本契约去掉起点。
	var path: Array[Vector2i] = []
	for i in range(1, result.path.size()):
		path.append(result.path[i].to_axial())
	return path


func get_all_coords() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if model == null:
		return result
	for coord in model.get_all_coords():
		result.append(coord.to_axial())
	return result


func _sorted_neighbors(coord: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if model == null:
		return result
	for neighbor in model.get_neighbors(_to_hex(coord)):
		var axial := neighbor.to_axial()
		if has_coord(axial):
			result.append(axial)
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _coord_less(a, b)
	)
	return result


func _coord_less(a: Vector2i, b: Vector2i) -> bool:
	if a.x == b.x:
		return a.y < b.y
	return a.x < b.x


func _to_hex(coord: Vector2i) -> HexCoord:
	return HexCoord.new(coord.x, coord.y)
