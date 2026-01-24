extends Node

class MockModifierTarget:
	extends RefCounted

	func add_modifier(_modifier: Dictionary) -> void:
		pass

	func remove_modifier(_modifier_id: String) -> bool:
		return true

	func remove_modifiers_by_source(_source: String) -> int:
		return 0

	func get_modifiers() -> Array:
		return []

	func has_modifier(_modifier_id: String) -> bool:
		return false

class MockState:
	extends RefCounted

	var ability_set: AbilitySet
	var event_processor: EventProcessor

	func _init(as_value: AbilitySet, ep_value: EventProcessor):
		ability_set = as_value
		event_processor = ep_value

	func get_ability_set_for_actor(_actor_id: String):
		return ability_set

func _init() -> void:
	TestFramework.register_test("PreEventComponent - registers handler when granted", _test_registration)
	TestFramework.register_test("PreEventComponent - unregisters handler when revoked", _test_unregistration)
	TestFramework.register_test("PreEventComponent - modifies event values", _test_modify_event)
	TestFramework.register_test("PreEventComponent - cancels event", _test_cancel_event)

func _build_context(state, event: Dictionary = {}) -> ExecutionContext:
	return ExecutionContext.create_execution_context({
		"eventChain": [event],
		"gameplayState": state,
		"eventCollector": EventCollector.new(),
		"ability": {},
	})

func _test_registration() -> void:
	var owner = ActorRef.new("unit-1")
	var modifier_target = MockModifierTarget.new()
	var ability_set = AbilitySet.create(owner, modifier_target)

	var event_processor = EventProcessor.new({"maxDepth": 10, "traceLevel": 2})
	var state = MockState.new(ability_set, event_processor)

	var component = PreEventComponent.new({
		"eventKind": "pre_damage",
		"filter": func(event, ctx):
			return event.get("targetId") == ctx.owner.id,
		"handler": func(_mutable, ctx):
			return EventPhase.modify_intent(ctx.ability.id, [
				{"field": "damage", "operation": "multiply", "value": 0.7},
			]),
	})

	var ability = Ability.new({"configId": "buff_armor", "components": [component]}, owner)
	ability_set.grant_ability(ability)

	var event = {"kind": "pre_damage", "sourceId": "enemy-1", "targetId": "unit-1", "damage": 100}
	var mutable = event_processor.process_pre_event(event, state)

	TestFramework.assert_true(not mutable.cancelled)
	TestFramework.assert_near(70, float(mutable.get_current_value("damage")))

func _test_unregistration() -> void:
	var owner = ActorRef.new("unit-1")
	var modifier_target = MockModifierTarget.new()
	var ability_set = AbilitySet.create(owner, modifier_target)

	var event_processor = EventProcessor.new({"maxDepth": 10, "traceLevel": 2})
	var state = MockState.new(ability_set, event_processor)

	var component = PreEventComponent.new({
		"eventKind": "pre_damage",
		"handler": func(_mutable, ctx):
			return EventPhase.modify_intent(ctx.ability.id, [
				{"field": "damage", "operation": "multiply", "value": 0.5},
			]),
	})

	var ability = Ability.new({"configId": "buff_armor", "components": [component]}, owner)
	ability_set.grant_ability(ability)
	ability_set.revoke_ability(ability.id)

	var event = {"kind": "pre_damage", "sourceId": "enemy-1", "targetId": "unit-1", "damage": 100}
	var mutable = event_processor.process_pre_event(event, state)

	TestFramework.assert_near(100, float(mutable.get_current_value("damage")))

func _test_modify_event() -> void:
	var owner = ActorRef.new("unit-1")
	var modifier_target = MockModifierTarget.new()
	var ability_set = AbilitySet.create(owner, modifier_target)

	var event_processor = EventProcessor.new({"maxDepth": 10, "traceLevel": 2})
	var state = MockState.new(ability_set, event_processor)

	var component = PreEventComponent.new({
		"eventKind": "pre_damage",
		"handler": func(_mutable, ctx):
			return EventPhase.modify_intent(ctx.ability.id, [
				{"field": "damage", "operation": "multiply", "value": 0.7},
				{"field": "damage", "operation": "add", "value": -10},
			]),
	})

	var ability = Ability.new({"configId": "buff_armor", "components": [component]}, owner)
	ability_set.grant_ability(ability)

	var event = {"kind": "pre_damage", "sourceId": "enemy-1", "targetId": "unit-1", "damage": 100}
	var mutable = event_processor.process_pre_event(event, state)

	# 100 * 0.7 - 10 = 60
	TestFramework.assert_near(60, float(mutable.get_current_value("damage")))

func _test_cancel_event() -> void:
	var owner = ActorRef.new("unit-1")
	var modifier_target = MockModifierTarget.new()
	var ability_set = AbilitySet.create(owner, modifier_target)

	var event_processor = EventProcessor.new({"maxDepth": 10, "traceLevel": 2})
	var state = MockState.new(ability_set, event_processor)

	var component = PreEventComponent.new({
		"eventKind": "pre_damage",
		"handler": func(_mutable, ctx):
			return EventPhase.cancel_intent(ctx.ability.id, "immune"),
	})

	var ability = Ability.new({"configId": "buff_immune", "components": [component]}, owner)
	ability_set.grant_ability(ability)

	var event = {"kind": "pre_damage", "sourceId": "enemy-1", "targetId": "unit-1", "damage": 100}
	var mutable = event_processor.process_pre_event(event, state)

	TestFramework.assert_true(not mutable.cancelled)
	var damage_value = mutable.get_current_value("damage")
	TestFramework.assert_near(70, float(damage_value))
