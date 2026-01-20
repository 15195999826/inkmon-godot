extends Node

const TEST_PATHS := [
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

func _ready() -> void:
	_load_test_scripts()
	var failures := TestFramework.run()
	if failures == 0:
		print("All tests passed")
	else:
		push_error("%d tests failed" % failures)
	get_tree().quit(failures)

func _load_test_scripts() -> void:
	for test_path in TEST_PATHS:
		var script = load(test_path)
		if not script:
			push_error("Failed to load test script: %s" % test_path)
			continue
		script.new()
