extends Node

class TestComponent:
	extends AbilityComponent

	var applied := false
	var removed := false
	var event_hit := false

	func _init():
		type = "TestComponent"

	func on_apply(_context: Dictionary) -> void:
		applied = true

	func on_remove(_context: Dictionary) -> void:
		removed = true

	func on_event(_event: Dictionary, _context: Dictionary, _gameplay_state) -> bool:
		event_hit = true
		return true

func _init() -> void:
	TestFramework.register_test("Ability applies/removes and expires", _test_lifecycle)
	TestFramework.register_test("Ability triggers component listeners", _test_triggered_listener)
	TestFramework.register_test("Ability ticks execution instances", _test_execution_instances)

func _test_lifecycle() -> void:
	var owner := ActorRef.new("actor-1")
	var component := TestComponent.new()
	var ability := Ability.new({ "configId": "fire", "components": [func(): return component] }, owner)
	var context := { "owner": owner, "ability": ability }

	ability.apply_effects(context)
	TestFramework.assert_equal(Ability.STATE_GRANTED, ability.get_state())
	TestFramework.assert_true(component.applied)

	ability.remove_effects()
	TestFramework.assert_true(component.removed)

	ability.expire("manual")
	TestFramework.assert_equal(Ability.STATE_EXPIRED, ability.get_state())
	TestFramework.assert_equal("manual", ability.get_expire_reason())

func _test_triggered_listener() -> void:
	var owner := ActorRef.new("actor-2")
	var component := TestComponent.new()
	var ability := Ability.new({ "configId": "storm", "components": [func(): return component] }, owner)
	var context := { "owner": owner, "ability": ability }
	ability.apply_effects(context)

	var result := { "event": {}, "components": [] }
	ability.add_triggered_listener(func(event: Dictionary, components: Array) -> void:
		result["event"] = event
		result["components"] = components
	)

	ability.receive_event({ "kind": "hit" }, context, null)

	TestFramework.assert_true(component.event_hit)
	TestFramework.assert_true(not result["event"].is_empty())
	TestFramework.assert_equal("hit", str(result["event"].get("kind", "")))
	TestFramework.assert_equal(1, result["components"].size())
	TestFramework.assert_equal("TestComponent", result["components"][0])

func _test_execution_instances() -> void:
	var registry := TimelineRegistry.new()
	registry.register({ "id": "t-ability", "totalDuration": 1.0, "tags": {} })
	TimelineRegistry.set_timeline_registry(registry)

	var owner := ActorRef.new("actor-3")
	var ability := Ability.new({ "configId": "blink", "components": [] }, owner)

	ability.activate_new_execution_instance({
		"timelineId": "t-ability",
		"tagActions": {},
		"eventChain": [],
		"gameplayState": null,
	})

	TestFramework.assert_equal(1, ability.get_executing_instances().size())
	ability.tick_executions(1.0)
	TestFramework.assert_equal(0, ability.get_executing_instances().size())
