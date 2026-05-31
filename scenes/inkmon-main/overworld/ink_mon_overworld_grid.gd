class_name InkMonOverworldGrid
extends RefCounted


const PLAYER_ID := "player"
const MAP_RADIUS := 4


var model: GridMapModel

var _npc_ids_by_coord: Dictionary = {}


func setup(radius: int = MAP_RADIUS) -> void:
	var cfg := GridMapConfig.new()
	cfg.grid_type = GridMapConfig.GridType.HEX
	cfg.orientation = GridMapConfig.Orientation.POINTY
	cfg.draw_mode = GridMapConfig.DrawMode.RADIUS
	cfg.radius = radius
	cfg.size = 2.0 / sqrt(3.0)

	model = GridMapModel.new()
	model.initialize(cfg)
	_npc_ids_by_coord.clear()


func sync_occupants(player_coord: Vector2i, npc_defs: Dictionary) -> void:
	Log.assert_crash(model != null, "InkMonOverworldGrid", "grid model is not initialized")
	for coord in model.get_all_coords():
		model.remove_occupant(coord)
		model.cancel_reservation(coord)
		model.set_tile_blocking(coord, false)
	_npc_ids_by_coord.clear()

	for npc_id_value in npc_defs.keys():
		var npc_id := str(npc_id_value)
		var npc_def := npc_defs[npc_id] as Dictionary
		if npc_def == null:
			continue
		var npc_coord := npc_def.get("coord", Vector2i.ZERO) as Vector2i
		if has_coord(npc_coord):
			var placed := model.place_occupant(_to_hex(npc_coord), "npc:%s" % npc_id)
			Log.assert_crash(placed, "InkMonOverworldGrid", "failed to place NPC occupant: %s" % npc_id)
			_npc_ids_by_coord[_coord_key(npc_coord)] = npc_id

	if has_coord(player_coord):
		var placed_player := model.place_occupant(_to_hex(player_coord), PLAYER_ID)
		Log.assert_crash(placed_player, "InkMonOverworldGrid", "failed to place player occupant")


func get_player_coord() -> Vector2i:
	var found: Variant = model.find_occupant_position(PLAYER_ID)
	var coord := found as HexCoord
	if coord == null:
		return Vector2i.ZERO
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


func get_npc_id_at(coord: Vector2i) -> String:
	return str(_npc_ids_by_coord.get(_coord_key(coord), ""))


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


func find_path(actor_id: String, from_coord: Vector2i, to_coord: Vector2i) -> Array[Vector2i]:
	if not has_coord(from_coord) or not has_coord(to_coord):
		return []
	if from_coord == to_coord:
		return []
	if not is_passable_for_actor(to_coord, actor_id):
		return []

	var frontier: Array[Vector2i] = [from_coord]
	var came_from: Dictionary = {_coord_key(from_coord): ""}
	var head := 0
	while head < frontier.size():
		var current := frontier[head]
		head += 1
		if current == to_coord:
			break
		for neighbor in _sorted_neighbors(current):
			var key := _coord_key(neighbor)
			if came_from.has(key):
				continue
			if neighbor != to_coord and not is_passable_for_actor(neighbor, actor_id):
				continue
			if neighbor == to_coord and not is_passable_for_actor(neighbor, actor_id):
				continue
			came_from[key] = _coord_key(current)
			frontier.append(neighbor)

	if not came_from.has(_coord_key(to_coord)):
		return []

	var reversed_path: Array[Vector2i] = []
	var cursor := to_coord
	while cursor != from_coord:
		reversed_path.append(cursor)
		var previous_key := str(came_from[_coord_key(cursor)])
		cursor = _coord_from_key(previous_key)

	var path: Array[Vector2i] = []
	for i in range(reversed_path.size() - 1, -1, -1):
		path.append(reversed_path[i])
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


func _coord_key(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]


func _coord_from_key(key: String) -> Vector2i:
	var parts := key.split(",")
	if parts.size() < 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))


func _to_hex(coord: Vector2i) -> HexCoord:
	return HexCoord.new(coord.x, coord.y)
