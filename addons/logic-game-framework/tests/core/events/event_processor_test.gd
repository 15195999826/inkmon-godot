extends Node

func _init() -> void:
	TestFramework.register_test("EventProcessor pre modifies event", _test_pre_modify)
	TestFramework.register_test("EventProcessor pre cancels event", _test_pre_cancel)

func _test_pre_modify() -> void:
	var processor := EventProcessor.new({ "maxDepth": 5, "traceLevel": 2 })
	processor.register_pre_handler({
		"id": "h1",
		"eventKind": "damage",
		"ownerId": "actor-1",
		"abilityId": "ability-1",
		"configId": "config-1",
		"handler": func(mutable, _context):
			return EventPhase.modify_intent("h1", [
				{ "field": "damage", "operation": "multiply", "value": 0.5 },
			])
	})

	var mutable := processor.process_pre_event({ "kind": "damage", "damage": 100.0 }, null)
	TestFramework.assert_near(50.0, float(mutable.get_current_value("damage")))
	TestFramework.assert_true(not mutable.cancelled)

func _test_pre_cancel() -> void:
	var processor := EventProcessor.new({ "maxDepth": 5, "traceLevel": 2 })
	processor.register_pre_handler({
		"id": "h2",
		"eventKind": "damage",
		"ownerId": "actor-1",
		"abilityId": "ability-1",
		"configId": "config-1",
		"handler": func(_mutable, _context):
			return EventPhase.cancel_intent("h2", "immune")
	})

	var mutable := processor.process_pre_event({ "kind": "damage", "damage": 100.0 }, null)
	TestFramework.assert_true(mutable.cancelled)
	TestFramework.assert_equal("immune", mutable.cancel_reason)
