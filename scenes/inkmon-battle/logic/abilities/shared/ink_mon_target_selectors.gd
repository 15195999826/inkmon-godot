class_name InkMonTargetSelectors


class CurrentTarget:
	extends TargetSelector

	func select(ctx: ExecutionContext) -> Array[String]:
		var event := ctx.get_current_event()
		if event.is_empty():
			return []
		if event.has("target_actor_ids") and event["target_actor_ids"] is Array:
			var result: Array[String] = []
			for target in event["target_actor_ids"]:
				if target is String:
					result.append(target)
			return result
		if event.has("target_actor_id") and event["target_actor_id"] is String:
			return [event["target_actor_id"]]
		return []


class AbilityOwner:
	extends TargetSelector

	func select(ctx: ExecutionContext) -> Array[String]:
		if ctx.ability_ref != null and not ctx.ability_ref.owner_actor_id.is_empty():
			return [ctx.ability_ref.owner_actor_id]
		return []


class AllEnemies:
	extends TargetSelector

	func select(ctx: ExecutionContext) -> Array[String]:
		if ctx.ability_ref == null or ctx.ability_ref.owner_actor_id.is_empty():
			return []
		var battle: InkMonBattleWorldGI = ctx.game_state_provider
		if battle == null:
			return []
		var owner := battle.get_unit_actor(ctx.ability_ref.owner_actor_id)
		if owner == null:
			return []
		var result: Array[String] = []
		for actor in battle.get_alive_actors():
			if actor.get_team_id() != owner.get_team_id():
				result.append(actor.get_id())
		return result


class Fixed:
	extends TargetSelector

	var _targets: Array[String]

	func _init(targets: Array[String]) -> void:
		_targets = targets

	func select(_ctx: ExecutionContext) -> Array[String]:
		return _targets


static func current_target() -> CurrentTarget:
	return CurrentTarget.new()


static func ability_owner() -> AbilityOwner:
	return AbilityOwner.new()


static func all_enemies() -> AllEnemies:
	return AllEnemies.new()


static func fixed(targets: Array[String]) -> Fixed:
	return Fixed.new(targets)
