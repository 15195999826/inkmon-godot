class_name InkMonBattleProcedure
extends BattleProcedure


const MAX_TICKS := 10000


var left_team: Array[InkMonUnitActor] = []
var right_team: Array[InkMonUnitActor] = []

var _world_instance: InkMonWorldGI = null
var _recording_enabled := true
var _result := ""


func _init(
	world: InkMonWorldGI,
	left: Array[InkMonUnitActor],
	right: Array[InkMonUnitActor],
	opts: Dictionary = {}
) -> void:
	var all_actors: Array[Actor] = []
	for actor in left:
		all_actors.append(actor)
	for actor in right:
		all_actors.append(actor)
	super._init(world, all_actors)
	_world_instance = world
	left_team = left
	right_team = right
	_recording_enabled = opts.get("recording", true)


func _start_recorder() -> void:
	if not _recording_enabled or _recorder == null:
		return
	# adr/0005:全量录像(带 initial_actors 快照),让 2D 回放 animator 能从录像独立重建开战阵容。
	_recorder.start_recording(get_all_units(), {}, {})


func tick_once() -> void:
	if _finished:
		return
	_current_tick += 1

	var world := _world_instance
	if world != null:
		world.base_tick(_tick_interval)
	var cur_logic_time := world.get_logic_time() if world != null else float(_current_tick) * _tick_interval

	for actor in get_alive_units():
		if InkMonBattleProcedure.tick_actor_ability_runtime(actor, _tick_interval, cur_logic_time, world):
			continue
		actor.accumulate_atb(_tick_interval)
		if actor.can_act():
			_start_actor_action(actor, cur_logic_time)

	record_current_frame_events()

	if _current_tick >= MAX_TICKS:
		_result = "timeout"
		mark_finished()
	else:
		_check_battle_end()


func finish(result: String = "") -> Dictionary:
	var effective := result if result != "" else _result
	if effective.is_empty():
		effective = "battle_complete"
	if not _recording_enabled:
		for pid in _participant_ids:
			_mark_in_combat(pid, false)
		_finished = true
		return { "result": effective }
	return super.finish(effective)


func _mark_in_combat(actor_id: String, active: bool) -> void:
	var actor := _world_instance.get_unit_actor(actor_id) if _world_instance != null else null
	if actor == null or actor.ability_set == null:
		return
	if active:
		actor.ability_set.add_loose_tag("in_combat")
	else:
		actor.ability_set.remove_loose_tag("in_combat")


func get_all_units() -> Array[InkMonUnitActor]:
	var result: Array[InkMonUnitActor] = []
	result.append_array(left_team)
	result.append_array(right_team)
	return result


func get_alive_units() -> Array[InkMonUnitActor]:
	var result: Array[InkMonUnitActor] = []
	for actor in get_all_units():
		if not actor.is_dead():
			result.append(actor)
	return result


func get_result() -> String:
	return _result


static func actor_has_executing_ability(actor: InkMonUnitActor) -> bool:
	for ability in actor.ability_set.get_abilities():
		if ability.get_executing_instances().size() > 0:
			return true
	return false


static func actor_has_blocking_execution(actor: InkMonUnitActor) -> bool:
	for ability in actor.ability_set.get_abilities():
		if ability.has_ability_tag("intrinsic"):
			continue
		if ability.get_executing_instances().size() > 0:
			return true
	return false


static func tick_actor_ability_runtime(
	actor: InkMonUnitActor,
	tick_interval: float,
	logic_time: float,
	world: InkMonWorldGI
) -> bool:
	actor.ability_set.tick(tick_interval, logic_time)
	var has_any_execution := InkMonBattleProcedure.actor_has_executing_ability(actor)
	var has_blocking_execution := InkMonBattleProcedure.actor_has_blocking_execution(actor)
	if has_any_execution:
		actor.ability_set.tick_executions(tick_interval, world)
	return has_blocking_execution


func _start_actor_action(actor: InkMonUnitActor, logic_time: float) -> void:
	var decision := actor.ai_strategy.decide(actor, _world_instance)
	if decision.is_skip():
		actor.reset_atb()
		return

	var event := _create_action_use_event(
		decision.ability_instance_id,
		actor.get_id(),
		decision.target_actor_id,
		decision.target_coord,
		logic_time
	)

	actor.ability_set.receive_event(event, _world_instance)
	actor.reset_atb()


func _create_action_use_event(
	ability_instance_id: String,
	source_id: String,
	target_actor_id: String,
	target_coord: Variant,
	logic_time: float
) -> Dictionary:
	var event := {
		"kind": GameEvent.ABILITY_ACTIVATE_EVENT,
		"abilityInstanceId": ability_instance_id,
		"sourceId": source_id,
		"logicTime": logic_time,
	}
	if not target_actor_id.is_empty():
		event["target_actor_id"] = target_actor_id
	if target_coord != null and target_coord is HexCoord:
		event["target_coord"] = (target_coord as HexCoord).to_dict()
	return event


func _check_battle_end() -> bool:
	var left_alive := 0
	var right_alive := 0
	for actor in left_team:
		if not actor.is_dead():
			left_alive += 1
	for actor in right_team:
		if not actor.is_dead():
			right_alive += 1

	if left_alive == 0:
		_result = "right_win"
		mark_finished()
		return true
	if right_alive == 0:
		_result = "left_win"
		mark_finished()
		return true
	return false
