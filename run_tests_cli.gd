extends SceneTree

## 命令行测试运行器

func _init() -> void:
	# 加载测试框架
	var test_framework = load("res://addons/logic-game-framework/tests/test_framework.gd").new()

	# 加载测试文件
	var test_scripts = [
		"res://addons/logic-game-framework/tests/core/attributes/AttributeSet_test.gd",
		"res://addons/logic-game-framework/tests/core/attributes/defineAttributes_test.gd",
		"res://addons/logic-game-framework/tests/core/events/EventProcessor_test.gd",
		"res://addons/logic-game-framework/tests/core/events/PreEventComponent_test.gd",
		"res://addons/logic-game-framework/tests/core/abilities/Ability_test.gd",
		"res://addons/logic-game-framework/tests/core/abilities/AbilityExecutionInstance_test.gd",
		"res://addons/logic-game-framework/tests/core/abilities/ActivateInstanceComponent_test.gd",
		"res://addons/logic-game-framework/tests/core/actions/TagAction_test.gd",
	]

	for test_path in test_scripts:
		var script = load(test_path)
		if script:
			script.new()

	# 运行测试
	var result = test_framework.run_all_tests()

	# 退出
	quit(result.failed)
