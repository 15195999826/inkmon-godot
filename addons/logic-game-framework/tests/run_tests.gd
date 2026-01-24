extends Node
class_name RunTests

## 测试运行器

# 测试文件路径
const TEST_PATHS := [
	"res://addons/logic-game-framework/tests/core/attributes/AttributeSet_test.gd",
	"res://addons/logic-game-framework/tests/core/attributes/defineAttributes_test.gd",
	"res://addons/logic-game-framework/tests/core/events/EventProcessor_test.gd",
	"res://addons/logic-game-framework/tests/core/events/PreEventComponent_test.gd",
	"res://addons/logic-game-framework/tests/core/abilities/Ability_test.gd",
	"res://addons/logic-game-framework/tests/core/abilities/AbilityExecutionInstance_test.gd",
	"res://addons/logic-game-framework/tests/core/abilities/ActivateInstanceComponent_test.gd",
	"res://addons/logic-game-framework/tests/core/actions/TagAction_test.gd",
]

# 测试框架实例
var _test_framework

func _ready() -> void:
	# 初始化测试框架
	_test_framework = load("res://addons/logic-game-framework/tests/test_framework.gd").new()

	# 加载所有测试脚本
	_load_test_scripts()

	# 运行所有测试
	var result = _test_framework.run_all_tests()

	# 退出并返回失败数
	get_tree().quit(result.failed)

func _load_test_scripts() -> void:
	for test_path in TEST_PATHS:
		var script = load(test_path)
		if not script:
			push_error("Failed to load test script: %s" % test_path)
			continue
		script.new()

## 自动发现测试

func discover_tests() -> Array:
	var test_paths := []
	var dir = DirAccess.open("res://addons/logic-game-framework/tests/")
	if not dir:
		push_error("Failed to open tests directory")
		return test_paths

	_collect_test_files_recursive(dir, "res://addons/logic-game-framework/tests/", test_paths)
	return test_paths

func _collect_test_files_recursive(dir: DirAccess, base_path: String, paths: Array) -> void:
	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		var full_path = base_path + file_name

		if dir.current_is_dir():
			if file_name != "." and file_name != "..":
				var sub_dir = DirAccess.open(full_path + "/")
				if sub_dir:
					_collect_test_files_recursive(sub_dir, full_path + "/", paths)
		else:
			if file_name.ends_with("_test.gd"):
				paths.append(full_path)

		file_name = dir.get_next()

	dir.list_dir_end()
