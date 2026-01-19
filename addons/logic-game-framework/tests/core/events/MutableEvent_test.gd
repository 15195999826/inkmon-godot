extends Node

func _init() -> void:
	TestFramework.register_test("MutableEvent applies modifications", _test_modifications)
	TestFramework.register_test("MutableEvent collects computation steps", _test_steps)

func _test_modifications() -> void:
	var event := {
		"kind": "damage",
		"damage": 100.0,
	}
	var mutable := MutableEvent.new(event, EventPhase.PHASE_PRE)
	mutable.add_modification({ "field": "damage", "operation": "multiply", "value": 0.7 })
	mutable.add_modification({ "field": "damage", "operation": "add", "value": -10.0 })
	TestFramework.assert_near(60.0, float(mutable.get_current_value("damage")))

	var final_event := mutable.to_final_event()
	TestFramework.assert_near(60.0, float(final_event["damage"]))

func _test_steps() -> void:
	var event := {
		"kind": "damage",
		"damage": 50.0,
	}
	var mutable := MutableEvent.new(event, EventPhase.PHASE_PRE)
	mutable.add_modification({ "field": "damage", "operation": "set", "value": 60.0, "sourceId": "buff" })
	mutable.add_modification({ "field": "damage", "operation": "add", "value": 10.0, "sourceId": "bonus" })
	var record = mutable.get_field_computation_steps("damage")
	TestFramework.assert_true(record != null)
	TestFramework.assert_near(70.0, float(record["finalValue"]))
