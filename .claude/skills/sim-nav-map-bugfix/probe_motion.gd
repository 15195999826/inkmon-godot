extends Node

# Probe template: multi-tick motion simulation.
#
# Use when behavior depends on motion controller running for many ticks
# (push system, blocked recovery cadence, fm increment, drift accumulation).
# Single-step LOS probes miss this.
#
# Usage:
#   1. cp probe_motion.{gd,tscn} into .claude/tmp/
#   2. Edit BLOCKERS / unit setup / TICK_COUNT / DELTA below
#   3. godot --headless --path . .claude/tmp/probe_motion.tscn 2>&1 | grep "TICK\|FINAL\|MOTION"


const TICK_COUNT := 120  # 2 seconds at 60 Hz
const DELTA := 1.0 / 60.0


func _ready() -> void:
	var lab_pf := ZeroAdRtsLabPathfinder.new(Vector2(720.0, 420.0), 16.0, 12.0)
	lab_pf.rebuild_context([])

	# === EDIT BLOCKERS ===
	var stationary_units: Array[ZeroAdRtsLabUnit] = []
	for entry in [
		# [entity_id, position]
		["blue_3", Vector2(491.0, 207.0)],
		# Add more here.
	]:
		var u := ZeroAdRtsLabUnit.new(entry[0], "blue", entry[1], 11.0, 96.0, true)
		u.has_move_order = false
		stationary_units.append(u)

	# === EDIT MOVING UNIT ===
	var start := Vector2(530.53, 201.05)
	var target := Vector2(528.5, 119.5)
	var actor := ZeroAdRtsLabUnit.new("actor", "blue", start, 11.0, 96.0, true)
	actor.has_move_order = true
	actor.target = target
	actor.path_target = target
	actor.long_path = SimNavWaypointPath.new()
	actor.long_path.push_back(target)

	var units: Array[ZeroAdRtsLabUnit] = [actor]
	for u in stationary_units:
		units.append(u)
	lab_pf.refresh_dynamic_units(units)

	# === SIM LOOP ===
	var motion := ZeroAdRtsLabMotionController.new()
	var min_dist_to_blocker := INF
	var pos_log: Array = []
	var blocker_pos := stationary_units[0].position if not stationary_units.is_empty() else Vector2.ZERO

	for i in range(TICK_COUNT):
		var pos_before := actor.position
		motion.step_unit(actor, DELTA, lab_pf, units, i)
		var prev_positions := {actor.id: pos_before}
		var prev_orders := {actor.id: actor.has_move_order}
		motion.apply_push_adjust(units, lab_pf, prev_positions, prev_orders, i, DELTA)
		if blocker_pos != Vector2.ZERO:
			min_dist_to_blocker = minf(min_dist_to_blocker, actor.position.distance_to(blocker_pos))
		if i % 30 == 0 or actor.failed_movements > 0:
			pos_log.append({"tick": i, "pos": actor.position, "fm": actor.failed_movements, "moved_total": pos_before.distance_to(actor.position)})

	# === DRAIN MOTION UPDATES ===
	var updates := motion.drain_motion_updates()
	var update_kinds: Array = []
	for u in updates:
		update_kinds.append(u.to_snapshot().get("type"))

	for entry in pos_log:
		print("TICK ", entry.tick, " pos=", entry.pos, " fm=", entry.fm, " step=", entry.moved_total)
	print()
	print("FINAL pos=", actor.position, " fm=", actor.failed_movements,
		" has_move_order=", actor.has_move_order,
		" total_drift_to_target=", target.distance_to(actor.position))
	print("MOTION_UPDATES kinds=", update_kinds)
	print("MIN_DIST_TO_BLOCKER=", min_dist_to_blocker)

	get_tree().quit(0)
