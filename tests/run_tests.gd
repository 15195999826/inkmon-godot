extends Node

const TEST_FRAMEWORK_PATH := "res://tests/test_framework.gd"

func _ready() -> void:
	var framework = load(TEST_FRAMEWORK_PATH)
	var tests := [
		"res://tests/core/attributes/AttributeSet_test.gd",
		"res://tests/core/attributes/defineAttributes_test.gd",
		"res://tests/core/events/MutableEvent_test.gd",
		"res://tests/core/events/EventCollector_test.gd",
		"res://tests/core/events/EventProcessor_test.gd",
		"res://tests/core/abilities/Ability_test.gd",
		"res://tests/core/abilities/ActivateInstanceComponent_test.gd",
		"res://tests/core/abilities/AbilityExecutionInstance_test.gd",
		"res://tests/core/timeline/Timeline_test.gd",
		"res://tests/core/actions/TagAction_test.gd",
		"res://tests/core/world/World_test.gd",
	]
	for test_path in tests:
		load(test_path)

	var failures := framework.run()
	if failures == 0:
		print("All tests passed")
	else:
		push_error("%d tests failed" % failures)
	get_tree().quit(failures)
