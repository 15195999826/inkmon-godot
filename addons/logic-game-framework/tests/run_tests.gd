extends Node

const TEST_FRAMEWORK_PATH := "res://addons/logic-game-framework/tests/test_framework.gd"

func _ready() -> void:
	var framework = load(TEST_FRAMEWORK_PATH)
	var tests := [
		"res://addons/logic-game-framework/tests/core/attributes/AttributeSet_test.gd",
		"res://addons/logic-game-framework/tests/core/attributes/defineAttributes_test.gd",
		"res://addons/logic-game-framework/tests/core/attributes/ExampleGeneratedAttributeSet_test.gd",
		"res://addons/logic-game-framework/tests/core/events/MutableEvent_test.gd",
		"res://addons/logic-game-framework/tests/core/events/EventCollector_test.gd",
		"res://addons/logic-game-framework/tests/core/events/EventProcessor_test.gd",
		"res://addons/logic-game-framework/tests/core/abilities/Ability_test.gd",
		"res://addons/logic-game-framework/tests/core/abilities/ActivateInstanceComponent_test.gd",
		"res://addons/logic-game-framework/tests/core/abilities/AbilityExecutionInstance_test.gd",
		"res://addons/logic-game-framework/tests/core/timeline/Timeline_test.gd",
		"res://addons/logic-game-framework/tests/core/actions/TagAction_test.gd",
		"res://addons/logic-game-framework/tests/core/world/World_test.gd",
	]
	for test_path in tests:
		load(test_path)

	var failures: int = framework.run() as int
	if failures == 0:
		print("All tests passed")
	else:
		push_error("%d tests failed" % failures)
	get_tree().quit(failures)
