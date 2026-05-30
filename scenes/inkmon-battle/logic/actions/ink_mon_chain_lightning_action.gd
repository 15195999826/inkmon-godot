class_name InkMonChainLightningAction
extends Action.PrimitiveAction


var _base_damage: FloatResolver
var _max_hits: int
var _falloff: float


func _init(
	target_selector: TargetSelector,
	base_damage: FloatResolver,
	max_hits: int,
	falloff: float
) -> void:
	super._init(target_selector)
	type = "inkmon_chain_lightning"
	_base_damage = base_damage
	_max_hits = max_hits
	_falloff = falloff


func execute(ctx: ExecutionContext) -> ActionResult:
	var battle: InkMonBattleWorldGI = ctx.game_state_provider
	var caster := battle.get_unit_actor(ctx.ability_ref.owner_actor_id) if battle != null and ctx.ability_ref != null else null
	if battle == null or caster == null:
		return ActionResult.create_success_result([])

	var current_targets := get_targets(ctx)
	if current_targets.is_empty():
		return ActionResult.create_success_result([])

	var all_events: Array[Dictionary] = []
	var visited: Array[String] = []
	var current_id := current_targets[0]
	var current_damage := _base_damage.resolve(ctx)

	for _i in range(_max_hits):
		if current_id.is_empty() or current_id in visited:
			break
		var current_actor := battle.get_unit_actor(current_id)
		if current_actor == null or current_actor.is_dead():
			break
		visited.append(current_id)

		var action := InkMonDamageAction.new(
			InkMonTargetSelectors.fixed([current_id]),
			Resolvers.float_val(current_damage),
			InkMonBattleEvents.DamageType.MAGICAL,
			Resolvers.str_val(InkMonElementChart.WIND)
		)
		var result := Action.execute_child(self, action, ctx)
		if result != null and result.event_dicts:
			all_events.append_array(result.event_dicts)

		current_damage *= _falloff
		current_id = _nearest_unvisited_enemy(caster.get_team_id(), current_actor.hex_position, visited, battle)

	return ActionResult.create_success_result(all_events)


func _nearest_unvisited_enemy(
	team_id: int,
	from_pos: HexCoord,
	visited: Array[String],
	battle: InkMonBattleWorldGI
) -> String:
	var best := ""
	var best_distance := 1 << 30
	for actor in battle.get_alive_actors():
		if actor.get_team_id() == team_id or actor.get_id() in visited:
			continue
		var distance := from_pos.distance_to(actor.hex_position)
		if distance < best_distance:
			best_distance = distance
			best = actor.get_id()
	return best
