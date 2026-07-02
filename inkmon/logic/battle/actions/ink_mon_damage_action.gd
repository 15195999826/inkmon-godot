class_name InkMonDamageAction
extends Action.PrimitiveAction


var _damage_resolver: FloatResolver
var _damage_type: InkMonBattleEvents.DamageType
var _element_resolver: StringResolver


func _init(
	target_selector: TargetSelector,
	damage_resolver: FloatResolver,
	damage_type: InkMonBattleEvents.DamageType,
	element_resolver: StringResolver = null
) -> void:
	super._init(target_selector)
	type = "inkmon_damage"
	_damage_resolver = damage_resolver
	_damage_type = damage_type
	_element_resolver = element_resolver if element_resolver != null else Resolvers.str_val("")


func execute(ctx: ExecutionContext) -> ActionResult:
	var source_actor_id := ctx.ability_ref.owner_actor_id if ctx.ability_ref != null else ""
	var battle: InkMonWorldGI = ctx.game_state_provider
	var targets := get_targets(ctx)
	var all_events: Array[Dictionary] = []
	var alive_actor_ids := battle.get_alive_actor_ids() if battle != null else [] as Array[String]
	var base_damage := _damage_resolver.resolve(ctx)
	var element := _element_resolver.resolve(ctx)
	var damage_type_str := InkMonBattleEvents.damage_type_to_string(_damage_type)

	for target_id in targets:
		var target_actor := battle.get_battle_actor(target_id) if battle != null else null
		if target_actor == null or target_actor.is_dead():
			continue

		var pre_event := InkMonBattlePreEvents.PreDamageEvent.create(
			source_actor_id,
			target_id,
			base_damage,
			damage_type_str,
			element
		)
		var mutable: MutableEvent = GameWorld.event_processor.process_pre_event(pre_event.to_dict(), battle)
		if mutable.cancelled:
			continue

		var final_damage: float = mutable.get_current_value("damage")
		var source_name := InkMonBattleGameStateUtils.get_actor_display_name(source_actor_id, battle)
		var target_name := InkMonBattleGameStateUtils.get_actor_display_name(target_id, battle)
		print("  [InkMonDamageCalc] %s -> %s base=%.2f final=%.2f type=%s element=%s" % [
			source_name, target_name, base_damage, final_damage, damage_type_str, element
		])

		var event := InkMonBattleEvents.DamageEvent.create(
			target_id,
			final_damage,
			_damage_type,
			element,
			source_actor_id
		)
		event.actual_life_damage = final_damage
		var damage_result := InkMonBattleDamageUtils.apply_damage(event, alive_actor_ids, ctx, battle)
		all_events.append_array(damage_result.all_events)
		InkMonBattleDamageUtils.broadcast_post_damage(damage_result.damage_event_dict, alive_actor_ids, battle)

	return ActionResult.create_success_result(all_events, { "base_damage": base_damage })
