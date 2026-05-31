class_name InkMonBattleDamageUtils


class DamageResult:
	var damage_event_dict: Dictionary = {}
	var all_events: Array[Dictionary] = []
	var target_killed := false


static func apply_damage(
	damage_event: InkMonBattleEvents.DamageEvent,
	alive_actor_ids: Array[String],
	ctx: ExecutionContext,
	battle: InkMonWorldGI
) -> DamageResult:
	var result := DamageResult.new()
	var target_id := damage_event.target_actor_id
	var source_actor_id := damage_event.source_actor_id
	var target_actor := battle.get_actor(target_id) if battle != null else null

	var damage_dict: Dictionary = ctx.event_collector.push(damage_event.to_dict())
	result.damage_event_dict = damage_dict
	result.all_events.append(damage_dict)

	if target_actor == null or target_actor.is_dead():
		return result

	var target_attrs := target_actor.get_attribute_set()
	var old_hp := target_attrs.hp
	target_attrs.set_hp_base(old_hp - damage_event.actual_life_damage)

	var target_name := InkMonBattleGameStateUtils.get_actor_display_name(target_id, battle)
	print("  [InkMonDamage] %s HP %.1f -> %.1f" % [target_name, old_hp, target_attrs.hp])

	if target_actor.check_death():
		print("  [InkMonDeath] %s defeated" % target_name)
		var death_event := InkMonBattleEvents.DeathEvent.create(target_id, source_actor_id)
		var death_dict: Dictionary = ctx.event_collector.push(death_event.to_dict())
		result.all_events.append(death_dict)
		result.target_killed = true
		if alive_actor_ids.size() > 0:
			GameWorld.event_processor.process_post_event(death_dict, alive_actor_ids, battle)
		_clear_grid_footprint(battle, target_actor)

	return result


static func broadcast_post_damage(
	damage_event_dict: Dictionary,
	alive_actor_ids: Array[String],
	battle: InkMonWorldGI
) -> void:
	if alive_actor_ids.size() > 0:
		GameWorld.event_processor.process_post_event(damage_event_dict, alive_actor_ids, battle)


static func _clear_grid_footprint(battle: InkMonWorldGI, dead_actor: InkMonBattleActor) -> void:
	if battle == null or battle.grid == null or dead_actor == null:
		return
	var pos := dead_actor.hex_position
	if pos != null and pos.is_valid():
		battle.grid.remove_occupant(pos)
	for coord in battle.grid.get_all_coords():
		if battle.grid.get_reservation(coord) == dead_actor.get_id():
			battle.grid.cancel_reservation(coord)
