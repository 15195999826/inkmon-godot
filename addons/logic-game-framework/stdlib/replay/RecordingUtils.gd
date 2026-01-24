extends RefCounted
class_name RecordingUtils

static func record_attribute_changes(attr_set, ctx) -> Array:
	var original_values := {}
	var unsubscribes := []

	for attr_name in attr_set.get_defined_attributes():
		var initial_value = attr_set[attr_name]
		original_values[attr_name] = initial_value

		var listener_func = func(event):
			var change_data = {
				"actorId": ctx.actorId,
				"attributeName": attr_name,
				"oldValue": original_values.get(attr_name),
				"newValue": event.newValue,
			}
			ctx.pushEvent.call(change_data)

		if attr_set.has_method("addChangeListener"):
			var unsub = attr_set.addChangeListener(attr_name, listener_func)
			unsubscribes.append(unsub)

	return unsubscribes

static func record_ability_set_changes(ability_set, ctx) -> Array:
	var unsubscribes := []

	var abilities = []
	if ability_set.has_method("getAbilities"):
		abilities = ability_set.getAbilities()

	for ability_id in abilities:
		var ability = ability_set.get_ability(ability_id)
		if not ability:
			continue

		if ability.has_method("getComponents"):
			for component in ability.getComponents():
				if component and component.has_method("onEvent"):
					var unsub = ability_set.register_event_handler(
						"onAbility%s" % [ability.config_id.capitalize_left()],
						func(event, game_state):
							component.onEvent.call(event, null, game_state)
					)
					if unsub:
						unsubscribes.append(unsub)

	return unsubscribes

static func record_tag_changes(tag_source, ctx) -> Callable:
	if not tag_source.has_method("onTagChanged"):
		return func(): pass

	var listener_func = func(tag: String, old_count: int, new_count: int, _container):
		var change_data = GameEvent.create_tag_changed_event(
			ctx.actorId,
			tag,
			old_count,
			new_count
		)
		ctx.pushEvent.call(change_data)

	return tag_source.onTagChanged(listener_func)

static func record_actor_lifecycle(actor: Actor, ctx) -> Array:
	var unsubscribes := []

	var spawn_listener = func():
		var event = GameEvent.create_actor_spawned_event(actor)
		ctx.pushEvent.call(event)
	unsubscribes.append(actor.add_spawn_listener(spawn_listener))

	var despawn_listener = func():
		var event = GameEvent.create_actor_destroyed_event(ctx.actorId)
		ctx.pushEvent.call(event)
	unsubscribes.append(actor.add_despawn_listener(despawn_listener))

	return unsubscribes
