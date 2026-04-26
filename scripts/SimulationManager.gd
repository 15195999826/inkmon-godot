extends Node

var _js_callback_greet: JavaScriptObject
var _js_callback_battle: JavaScriptObject
var _js_callback_runtime_test: JavaScriptObject
var _js_callback_validate_skill: JavaScriptObject
var _js_callback_preview_skill: JavaScriptObject


func _ready():
	print("[Godot] Simulation Ready")
	print("[Godot] Platform web: ", OS.has_feature("web"))
	print("[Godot] Platform headless: ", OS.has_feature("headless"))
	
	if OS.has_feature("web"):
		_setup_js_bridge()
	else:
		# 本地测试
		var result = greet("Godot Headless")
		print("[Godot] Local test result: ", result)


func _setup_js_bridge():
	var window = JavaScriptBridge.get_interface("window")
	
	# 注册 greet 回调（和你的示例一样）
	_js_callback_greet = JavaScriptBridge.create_callback(_on_greet_call)
	window.godot_greet = _js_callback_greet
	
	# 注册 run_battle 回调（同样的模式）
	_js_callback_battle = JavaScriptBridge.create_callback(_on_battle_call)
	window.godot_run_battle = _js_callback_battle
	
	print("[Godot] JS Bridge registered: window.godot_greet")
	print("[Godot] JS Bridge registered: window.godot_run_battle")
	# 注册 runtime script test 回调
	_js_callback_runtime_test = JavaScriptBridge.create_callback(_on_runtime_test_call)
	window.godot_test_runtime_script = _js_callback_runtime_test
	print("[Godot] JS Bridge registered: window.godot_test_runtime_script")
	
	# 注册 validate_skill 回调
	_js_callback_validate_skill = JavaScriptBridge.create_callback(_on_validate_skill_call)
	window.godot_validate_skill = _js_callback_validate_skill
	print("[Godot] JS Bridge registered: window.godot_validate_skill")
	
	# 注册 preview_skill 回调
	_js_callback_preview_skill = JavaScriptBridge.create_callback(_on_preview_skill_call)
	window.godot_preview_skill = _js_callback_preview_skill
	print("[Godot] JS Bridge registered: window.godot_preview_skill")

func _on_greet_call(args: Array) -> String:
	var name_arg = args[0] if args.size() > 0 else "Unknown"
	return greet(name_arg)


func _on_battle_call(args: Array) -> String:
	var result := run_battle()
	# 同时写入全局变量（多线程 WASM 中回调返回值不可靠）
	var window = JavaScriptBridge.get_interface("window")
	window.godot_battle_result = result
	return result


func greet(name_arg: String) -> String:
	return JSON.stringify({"message": "Hello, " + name_arg + "!", "from": "Godot"})


func run_battle() -> String:
	print("\n[Godot] Starting battle simulation...")
	
	# 初始化 GameWorld
	GameWorld.init()
	
	# 使用 GameWorld 创建 HexDemoWorldGameplayInstance 实例
	var battle := GameWorld.create_instance(func() -> GameplayInstance:
		var b := HexDemoWorldGameplayInstance.new()
		b.start({
			"logging": false,  # 不保存日志文件
			"recording": true,  # 启用录像
		})
		return b
	) as HexDemoWorldGameplayInstance

	# 运行战斗循环直到结束
	var dt := 100.0  # 每个 tick 的时间步长（与 HexBattleProcedure.tick_interval 一致）
	while GameWorld.has_running_instances():
		GameWorld.tick_all(dt)
	
	print("[Godot] Battle ended. Ticks: %d" % battle.tick_count)
	
	# 获取录像数据（战斗正常结束时 _end() 已调用 stop_recording）
	var replay_data := battle.get_replay_data()
	
	# 转换为 JSON 字符串
	var json_str := JSON.stringify(replay_data)
	
	print("[Godot] Replay JSON length: %d chars" % json_str.length())
	print("[Godot] First 200 chars: ", json_str.substr(0, 200))
	
	return json_str


func _on_runtime_test_call(args: Array) -> String:
	var result := run_runtime_script_test()
	# 写入全局变量（多线程 WASM 中回调返回值不可靠）
	var window = JavaScriptBridge.get_interface("window")
	window.godot_runtime_test_result = result
	return result


func run_runtime_script_test() -> String:
	print("\n[Godot] Starting runtime script test...")
	
	var results := RuntimeScriptTest.run_all()
	
	var json_str := JSON.stringify(results, "\t")
	
	print("\n[Godot] Runtime Script Test Results:")
	print(json_str)
	
	if results.get("all_passed", false):
		print("\n[Godot] ALL TESTS PASSED")
	else:
		print("\n[Godot] SOME TESTS FAILED")
	
	return json_str



func _on_validate_skill_call(args: Array) -> String:
	var source_code: String = args[0] if args.size() > 0 else ""
	var result := run_validate_skill(source_code)
	# 写入全局变量（多线程 WASM 中回调返回值不可靠）
	var window = JavaScriptBridge.get_interface("window")
	window.godot_skill_validation_result = result
	return result

func run_validate_skill(source_code: String) -> String:
	print("\n[Godot] Starting skill validation...")
	print("[Godot] Source code length: %d bytes" % source_code.length())
	
	# 创建默认失败结果
	var default_result := {
		"success": false,
		"config_id": null,
		"display_name": null,
		"stages": {
			"compile": { "passed": false, "error": "Unknown error" },
			"interface_check": { "passed": false },
			"runtime": { "passed": false },
			"structure": { "passed": false },
		},
		"ability_config": null,
		"timeline": null,
	}
	
	# 尝试创建 SkillValidator
	var validator = SkillValidator.new()
	if validator == null:
		default_result.stages.compile.error = "Failed to create SkillValidator instance"
		return JSON.stringify(default_result)
	
	# 执行验证
	var result: Dictionary = validator.validate(source_code)
	
	var json_str := JSON.stringify(result, "\t")
	
	print("[Godot] Validation result: success=%s" % result.get("success", false))
	if not result.get("success", false):
		print("[Godot] Failed at stage: %s" % _get_failed_stage(result))
	
	return json_str

func _get_failed_stage(result: Dictionary) -> String:
	var stages: Dictionary = result.stages
	if not stages.compile.passed:
		return "compile: " + str(stages.compile.get("error", "unknown"))
	if not stages.interface_check.passed:
		return "interface_check: " + str(stages.interface_check.get("error", "unknown"))
	if not stages.runtime.passed:
		return "runtime: " + str(stages.runtime.get("error", "unknown"))
	if not stages.structure.passed:
		return "structure: " + str(stages.structure.get("errors", ["unknown"]))
	return "unknown"


func _on_preview_skill_call(args: Array) -> String:
	var input_json: String = args[0] if args.size() > 0 else ""
	var result := run_preview_skill(input_json)
	# 写入全局变量（多线程 WASM 中回调返回值不可靠）
	var window = JavaScriptBridge.get_interface("window")
	window.godot_skill_preview_result = result
	return result


func run_preview_skill(input_json: String) -> String:
	print("\n[Godot] Starting skill preview...")
	print("[Godot] Input JSON length: %d bytes" % input_json.length())
	
	# 解析输入 JSON
	var parsed = JSON.parse_string(input_json)
	if parsed == null or not (parsed is Dictionary):
		var error_result := {
			"success": false,
			"replay": null,
			"errors": ["Failed to parse input JSON"],
		}
		return JSON.stringify(error_result)
	
	var skill_source: String = parsed.get("skill_source", "")
	var scene_config: Dictionary = parsed.get("scene_config", {})
	
	if skill_source.is_empty():
		var error_result := {
			"success": false,
			"replay": null,
			"errors": ["skill_source is empty"],
		}
		return JSON.stringify(error_result)
	
	# 执行预览
	var result: Dictionary = SkillPreviewBattle.run_preview(skill_source, scene_config)
	
	var json_str := JSON.stringify(result)
	
	print("[Godot] Preview result: success=%s" % result.get("success", false))
	var errors: Array = result.get("errors", [])
	if errors.size() > 0:
		print("[Godot] Preview errors: %s" % str(errors))
	else:
		print("[Godot] Preview replay JSON length: %d chars" % json_str.length())
	
	return json_str
