class_name InkMonSkillHelpers


static func target_coord_from_event() -> DictResolver:
	return Resolvers.dict_fn(func(ctx: ExecutionContext) -> Dictionary:
		var event := ctx.get_current_event()
		if event.has("target_coord") and event["target_coord"] is Dictionary:
			return event["target_coord"]
		return {}
	)


static func caster_ad_damage(scale: float = 1.0, flat: float = 0.0) -> FloatResolver:
	return Resolvers.float_fn(func(ctx: ExecutionContext) -> float:
		var actor := GameWorld.get_actor(ctx.ability_ref.owner_actor_id) if ctx.ability_ref != null else null
		if actor is InkMonUnitActor:
			return (actor as InkMonUnitActor).attribute_set.ad * scale + flat
		return flat
	)


static func caster_ap_damage(scale: float = 1.0, flat: float = 0.0) -> FloatResolver:
	return Resolvers.float_fn(func(ctx: ExecutionContext) -> float:
		var actor := GameWorld.get_actor(ctx.ability_ref.owner_actor_id) if ctx.ability_ref != null else null
		if actor is InkMonUnitActor:
			return (actor as InkMonUnitActor).attribute_set.ap * scale + flat
		return flat
	)


static func caster_ap_heal(scale: float = 1.0, flat: float = 0.0) -> FloatResolver:
	return caster_ap_damage(scale, flat)
