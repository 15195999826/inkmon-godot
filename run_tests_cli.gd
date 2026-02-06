extends SceneTree

## 命令行测试运行器

func _init() -> void:
	# 加载测试框架
	var test_framework = load("res://addons/logic-game-framework/tests/test_framework.gd").new()

	# 加载测试文件
	var test_scripts = [
		"res://addons/logic-game-framework/tests/core/attributes/attribute_set_test.gd",
		"res://addons/logic-game-framework/tests/core/attributes/define_attributes_test.gd",
		"res://addons/logic-game-framework/tests/core/events/event_processor_test.gd",
		"res://addons/logic-game-framework/tests/core/events/pre_event_component_test.gd",
		"res://addons/logic-game-framework/tests/core/abilities/ability_test.gd",
		"res://addons/logic-game-framework/tests/core/abilities/ability_execution_instance_test.gd",
		"res://addons/logic-game-framework/tests/core/abilities/activate_instance_component_test.gd",
		"res://addons/logic-game-framework/tests/core/actions/tag_action_test.gd",
	]

	for test_path in test_scripts:
		var script = load(test_path)
		if script:
			script.new()

	# 运行测试
	var result = test_framework.run_all_tests()

	# 退出
	quit(result.failed)
