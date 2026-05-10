extends Node

# Probe template: multi-tick motion simulation, World-driven.
#
# Use when behavior depends on motion controller running for many ticks
# (push system, blocked recovery cadence, fm increment, drift accumulation).
# Single-step LOS probes miss this.
#
# Goes through ZeroAdRtsLabWorld.step() — i.e. the same pipeline as the lab
# demo (path queue, apply_path_results, refresh_dynamic_units, dispatch
# motion updates, push adjust, pair-contact diagnostics). Bypassing World
# (calling motion.step_unit + apply_push_adjust directly) skips path queue
# bookkeeping and leaves motion controller state inconsistent — fm stops
# incrementing, no motion updates emit, and unit silently freezes. That is a
# probe artefact, not a lab bug. If you really need raw motion (e.g. unit
# testing a single tick of motion logic), use the addon's repro pattern in
# tests/repro/repro_core_016_arrive_when_blocked_close_to_target.gd instead.
#
# Usage:
#   1. cp probe_motion.{gd,tscn} into .claude/tmp/
#   2. Edit ACTOR_START / TARGET / BLOCKERS / TICK_COUNT below
#   3. godot --headless --path . .claude/tmp/probe_motion.tscn 2>&1 | grep "TICK\|FINAL\|MOTION\|MIN_DIST"


const TICK_COUNT := 120  # 2 seconds at 60 Hz
const DELTA := 1.0 / 60.0

# === EDIT SCENARIO ===
# Actor is the moving unit (default: blue_2 from World's default spawn).
const ACTOR_ID := "blue_2"
const ACTOR_START := Vector2(470.32, 164.96)
const TARGET := Vector2(475.0, 179.0)
# Blockers reuse World's default unit ids so we don't fight the World's
# internal collections. Pick any subset of: blue_0, blue_1, blue_3, blue_4,
# blue_5, red_blocker. Set their position; has_move_order stays false.
const BLOCKERS := [
	# [unit_id, position]
	["blue_3", Vector2(492.0, 185.0)],
]
# Other (unused) blue_X get parked far off so they don't push the actor.
const PARKING_AREA_ORIGIN := Vector2(50.0, 380.0)


func _ready() -> void:
	var world := ZeroAdRtsLabWorld.new()

	# Apply blocker positions.
	var blocker_lookup: Dictionary = {}
	for entry in BLOCKERS:
		var blocker_id: String = entry[0]
		var blocker_pos: Vector2 = entry[1]
		var blocker := world.get_unit(blocker_id)
		if blocker == null:
			print("FATAL setup: blocker '", blocker_id, "' not in default world (try blue_0..blue_5 or red_blocker)")
			get_tree().quit(1)
			return
		blocker.position = blocker_pos
		blocker_lookup[blocker_id] = blocker

	# Park anything else (mobile blue_X that isn't actor and isn't in BLOCKERS).
	var parking_seq := 0
	for unit in world.units:
		if unit.id == ACTOR_ID or blocker_lookup.has(unit.id):
			continue
		if unit.group_id != "blue":
			continue  # red_blocker stays where it is unless explicitly listed
		unit.position = PARKING_AREA_ORIGIN + Vector2(float(parking_seq * 24), 0.0)
		parking_seq += 1

	# Position the actor.
	var actor := world.get_unit(ACTOR_ID)
	if actor == null:
		print("FATAL setup: actor '", ACTOR_ID, "' not in default world")
		get_tree().quit(1)
		return
	actor.position = ACTOR_START

	world.clear_traces()
	world.pathfinder.refresh_dynamic_units(world.units)

	world.set_units_target([ACTOR_ID], TARGET)

	# === SIM LOOP ===
	var pos_log: Array = []
	var min_dist_to_blocker := INF
	var first_blocker_pos: Vector2 = (BLOCKERS[0][1] as Vector2) if BLOCKERS.size() > 0 else Vector2.ZERO
	var update_kinds_seen: Array = []
	var prev_fm := actor.failed_movements
	var prev_has_order := actor.has_move_order

	for i in range(TICK_COUNT):
		var pos_before := actor.position
		world.step(DELTA)
		# World.dispatch already drained motion controller's queue into
		# world.recent_motion_updates — read our snapshot from there.
		while update_kinds_seen.size() < world.recent_motion_updates.size():
			var idx := update_kinds_seen.size()
			var snap: Dictionary = world.recent_motion_updates[idx]
			update_kinds_seen.append({"tick": i, "type": snap.get("type"), "reason": snap.get("reason", "")})
		if first_blocker_pos != Vector2.ZERO:
			min_dist_to_blocker = minf(min_dist_to_blocker, actor.position.distance_to(first_blocker_pos))
		var step_dist := pos_before.distance_to(actor.position)
		var fm_changed := actor.failed_movements != prev_fm
		var order_changed := actor.has_move_order != prev_has_order
		if i % 30 == 0 or fm_changed or order_changed or step_dist > 0.01:
			pos_log.append({
				"tick": i,
				"pos": actor.position,
				"fm": actor.failed_movements,
				"step": step_dist,
				"has_order": actor.has_move_order,
			})
		prev_fm = actor.failed_movements
		prev_has_order = actor.has_move_order

	for entry in pos_log:
		print("TICK ", entry.tick, " pos=", entry.pos, " fm=", entry.fm,
			" step=", entry.step, " has_order=", entry.has_order)
	print()
	print("FINAL pos=", actor.position, " fm=", actor.failed_movements,
		" has_move_order=", actor.has_move_order,
		" total_drift_to_target=", TARGET.distance_to(actor.position))
	print("MOTION_UPDATES count=", update_kinds_seen.size(), " entries=", update_kinds_seen)
	print("MIN_DIST_TO_BLOCKER=", min_dist_to_blocker)

	get_tree().quit(0)
