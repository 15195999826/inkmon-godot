class_name InkMonOverworldMoveController
extends RefCounted


signal move_started(actor_id: String, from_coord: Vector2i, to_coord: Vector2i)
signal move_applied(actor_id: String, from_coord: Vector2i, to_coord: Vector2i)
signal move_completed(actor_id: String, from_coord: Vector2i, to_coord: Vector2i)
signal move_rejected(actor_id: String, from_coord: Vector2i, target_coord: Vector2i, reason: String)


var grid: InkMonOverworldGrid
var last_event_log: Array[Dictionary] = []


func setup(p_grid: InkMonOverworldGrid) -> void:
	Log.assert_crash(p_grid != null, "InkMonOverworldMoveController", "grid cannot be null")
	grid = p_grid
	last_event_log.clear()


func move_actor_to(actor_id: String, requested_target: Vector2i) -> Dictionary:
	Log.assert_crash(grid != null, "InkMonOverworldMoveController", "grid is not configured")
	last_event_log.clear()

	var from_coord := grid.find_actor_coord(actor_id)
	var occupant_before := grid.occupant_count()
	var target_result := grid.resolve_target_for_actor(actor_id, requested_target)
	if not bool(target_result.get("ok", false)):
		var target_message := str(target_result.get("message", "target rejected"))
		_record_event("rejected", actor_id, from_coord, requested_target)
		move_rejected.emit(actor_id, from_coord, requested_target, target_message)
		return _result(false, target_message, requested_target, requested_target, [], false, occupant_before)

	var resolved_target := target_result.get("target", requested_target) as Vector2i
	var path := grid.find_path(actor_id, from_coord, resolved_target)
	if path.is_empty() and from_coord != resolved_target:
		var path_message := "no path to target"
		_record_event("rejected", actor_id, from_coord, resolved_target)
		move_rejected.emit(actor_id, from_coord, resolved_target, path_message)
		return _result(false, path_message, requested_target, resolved_target, [], bool(target_result.get("retargeted", false)), occupant_before)

	var current := from_coord
	for step in path:
		if not grid.reserve_tile(step, actor_id):
			var reserve_message := "failed to reserve move target"
			_record_event("rejected", actor_id, current, step)
			move_rejected.emit(actor_id, current, step, reserve_message)
			return _result(false, reserve_message, requested_target, resolved_target, path, bool(target_result.get("retargeted", false)), occupant_before)
		_record_event("started", actor_id, current, step)
		move_started.emit(actor_id, current, step)

		if not grid.move_occupant(current, step):
			grid.cancel_reservation(step)
			var apply_message := "failed to apply move"
			_record_event("rejected", actor_id, current, step)
			move_rejected.emit(actor_id, current, step, apply_message)
			return _result(false, apply_message, requested_target, resolved_target, path, bool(target_result.get("retargeted", false)), occupant_before)

		_record_event("applied", actor_id, current, step)
		move_applied.emit(actor_id, current, step)
		_record_event("completed", actor_id, current, step)
		move_completed.emit(actor_id, current, step)
		current = step

	var message := "player moved" if actor_id == InkMonOverworldGrid.PLAYER_ID else "actor moved"
	return _result(true, message, requested_target, resolved_target, path, bool(target_result.get("retargeted", false)), occupant_before)


func _result(
	ok: bool,
	message: String,
	requested_target: Vector2i,
	resolved_target: Vector2i,
	path: Array[Vector2i],
	retargeted: bool,
	occupant_before: int
) -> Dictionary:
	return {
		"ok": ok,
		"message": message,
		"data": {
			"requested_target": _coord_dict(requested_target),
			"resolved_target": _coord_dict(resolved_target),
			"final_coord": _coord_dict(grid.get_player_coord()),
			"path": _path_dicts(path),
			"step_count": path.size(),
			"retargeted": retargeted,
			"reservation_count": grid.reservation_count(),
			"occupant_count_before": occupant_before,
			"occupant_count_after": grid.occupant_count(),
			"move_events": last_event_log.duplicate(true),
		},
	}


func _record_event(kind: String, actor_id: String, from_coord: Vector2i, to_coord: Vector2i) -> void:
	last_event_log.append({
		"kind": kind,
		"actor_id": actor_id,
		"from": _coord_dict(from_coord),
		"to": _coord_dict(to_coord),
	})


func _path_dicts(path: Array[Vector2i]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for coord in path:
		result.append(_coord_dict(coord))
	return result


func _coord_dict(coord: Vector2i) -> Dictionary:
	return {
		"q": coord.x,
		"r": coord.y,
	}
