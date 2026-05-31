class_name InkMonApplyMoveAction
extends Action.PrimitiveAction


var _target_coord: DictResolver


func _init(target_selector: TargetSelector, target_coord: DictResolver) -> void:
	super._init(target_selector)
	type = "inkmon_apply_move"
	_target_coord = target_coord


func execute(ctx: ExecutionContext) -> ActionResult:
	var target_coord_dict := _target_coord.resolve(ctx)
	if target_coord_dict.is_empty():
		return ActionResult.create_success_result([])
	var target_coord := HexCoord.from_dict(target_coord_dict)
	var battle: InkMonWorldGI = ctx.game_state_provider
	var all_events: Array[Dictionary] = []

	for target_id in get_targets(ctx):
		var actor := battle.get_actor(target_id) if battle != null else null
		if actor == null or actor.is_dead() or not actor.hex_position.is_valid():
			continue
		var from_hex := actor.hex_position
		if not battle.grid.move_occupant(from_hex, target_coord):
			continue
		actor.hex_position = target_coord.duplicate()
		var event := InkMonBattleEvents.MoveCompleteEvent.create(
			target_id,
			from_hex.to_dict(),
			target_coord.to_dict()
		)
		all_events.append(ctx.event_collector.push(event.to_dict()))

	return ActionResult.create_success_result(all_events, { "target_coord": target_coord_dict })
