class_name InkMonHealAction
extends Action.PrimitiveAction


var _heal_amount: FloatResolver


func _init(target_selector: TargetSelector, heal_amount: FloatResolver) -> void:
	super._init(target_selector)
	type = "inkmon_heal"
	_heal_amount = heal_amount


func execute(ctx: ExecutionContext) -> ActionResult:
	var source_actor_id := ctx.ability_ref.owner_actor_id if ctx.ability_ref != null else ""
	var battle: InkMonWorldGI = ctx.game_state_provider
	var heal_amount := _heal_amount.resolve(ctx)
	var all_events: Array[Dictionary] = []
	var alive_actor_ids := battle.get_alive_actor_ids() if battle != null else [] as Array[String]

	for target_id in get_targets(ctx):
		var target_actor := battle.get_unit_actor(target_id) if battle != null else null
		if target_actor == null or target_actor.is_dead():
			continue
		var old_hp := target_actor.attribute_set.hp
		var new_hp := minf(old_hp + heal_amount, target_actor.attribute_set.max_hp)
		target_actor.attribute_set.set_hp_base(new_hp)
		var event := InkMonBattleEvents.HealEvent.create(target_id, new_hp - old_hp, source_actor_id)
		var event_dict: Dictionary = ctx.event_collector.push(event.to_dict())
		all_events.append(event_dict)
		print("  [InkMonHeal] %s HP %.1f -> %.1f" % [target_actor.get_display_name(), old_hp, new_hp])
		if alive_actor_ids.size() > 0:
			GameWorld.event_processor.process_post_event(event_dict, alive_actor_ids, battle)

	return ActionResult.create_success_result(all_events, { "heal_amount": heal_amount })
