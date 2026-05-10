extends Node

# Probe template: single-segment LOS test.
#
# Use when you need to verify whether a specific segment is blocked by a
# specific shape, end-to-end through the lab pathfinder + facade. Faster than
# running the full lab simulation.
#
# Usage:
#   1. cp probe_los.{gd,tscn} into .claude/tmp/ (or project tmp/)
#   2. Edit the BLOCKERS, START, TARGET below
#   3. godot --headless --path . .claude/tmp/probe_los.tscn 2>&1 | grep "LOS\|FACADE\|LAB_PF"


func _ready() -> void:
	var blockers: Array[SimNavObstructionShapeUnit] = []
	# === EDIT BLOCKERS ===
	for entry in [
		# [entity_id, position, has_move_order]
		["blue_3", Vector2(491.0, 207.0), false],
		# Add more here.
	]:
		var s := SimNavObstructionShapeUnit.new()
		s.entity_id = entry[0]
		s.center = entry[1]
		s.clearance = 11.0
		s.flags = SimNavObstructionFlags.BLOCK_MOVEMENT
		if bool(entry[2]):
			s.flags |= SimNavObstructionFlags.MOVING
			s.moving = true
		blockers.append(s)

	# === EDIT START / TARGET / IGNORED ===
	var start := Vector2(530.53, 201.05)
	var target := Vector2(528.5, 119.5)
	var ignored_id := "blue_1"

	# === SETUP ===
	var cell_size := 16.0
	var nav_map := SimNavMap.new(int(ceil(720.0 / cell_size)), int(ceil(420.0 / cell_size)), cell_size, Vector2.ZERO, 1)
	var ground := SimNavPassabilityClassConfig.new()
	ground.class_name_id = "ground"
	ground.clearance = 12.0
	ground.affects_pathfinding = true
	var pass_mask := nav_map.register_passability_class(ground)
	nav_map.rebuild_dirty()
	nav_map.replace_dynamic_obstructions(blockers)

	# === DIRECT LOS (per-shape) ===
	for shape in blockers:
		var blocked := SimNavLineOfSight.shape_blocks_segment(start, target, shape, 11.0)
		var sd := start.distance_to(shape.center)
		var td := target.distance_to(shape.center)
		print("LOS vs ", shape.entity_id, ": blocked=", blocked, "  start_dist=%.2f target_dist=%.2f" % [sd, td])

	# === FACADE (passability + LOS combined) ===
	var facade := SimNavPathfinderFacade.new(nav_map)
	var filter := SimNavObstructionFilter.for_short_path(false, "")
	filter.ignored_entity_id = ignored_id
	var fr := facade.validate_movement_line(start, target, 11.0, pass_mask, filter)
	print("FACADE status=", fr.status, " reason=", fr.failure_reason, " blocker=", fr.blocked_obstruction_entity_id)

	# === LAB PATHFINDER (full pipeline) ===
	var lab_pf := ZeroAdRtsLabPathfinder.new(Vector2(720.0, 420.0), 16.0, 12.0)
	lab_pf.rebuild_context([])
	var probe_unit := ZeroAdRtsLabUnit.new(ignored_id, "blue", start, 11.0, 96.0, true)
	probe_unit.has_move_order = true
	var lab_units: Array[ZeroAdRtsLabUnit] = [probe_unit]
	for shape in blockers:
		var u := ZeroAdRtsLabUnit.new(shape.entity_id, "blue", shape.center, shape.clearance, 96.0, true)
		u.has_move_order = (shape.flags & SimNavObstructionFlags.MOVING) != 0
		lab_units.append(u)
	lab_pf.refresh_dynamic_units(lab_units)
	var lr := lab_pf.validate_movement_line(probe_unit, start, target, lab_units, false)
	print("LAB_PF status=", lr.status, " reason=", lr.failure_reason, " blocker=", lr.blocked_obstruction_entity_id)

	get_tree().quit(0)
