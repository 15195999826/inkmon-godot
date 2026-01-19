extends Node

var _js_callback: JavaScriptObject
var _js_window: JavaScriptObject


func _ready():
	print("[Godot] Simulation Ready")
	print("[Godot] Platform web: ", OS.has_feature("web"))
	print("[Godot] Platform headless: ", OS.has_feature("headless"))
	
	# 在 Web 环境总是尝试注册 JS Bridge（无论是否 headless）
	_setup_js_bridge()
	
	# 本地测试（非 Web 环境）
	if not OS.has_feature("web"):
		var result = greet("Godot Headless")
		print("[Godot] Local test result: ", result)


func _setup_js_bridge():
	_js_window = JavaScriptBridge.get_interface("window")
	
	# 方案1: 使用 callback（返回值可能有问题）
	_js_callback = JavaScriptBridge.create_callback(_on_js_call)
	_js_window.godot_greet = _js_callback
	
	# 方案2: 创建一个同步调用接口，通过全局变量传递结果
	_js_window.godot_last_result = ""
	
	print("[Godot] JS Bridge registered: window.godot_greet")
	print("[Godot] Tip: Check window.godot_last_result for return value")


func _on_js_call(args: Array) -> String:
	var name_arg = args[0] if args.size() > 0 else "Unknown"
	var result = greet(name_arg)
	print("[Godot] _on_js_call received: ", name_arg)
	print("[Godot] _on_js_call returning: ", result)
	
	# 同时写入全局变量作为备用
	_js_window.godot_last_result = result
	
	return result


func greet(name_arg: String) -> String:
	return JSON.stringify({"message": "Hello, " + name_arg + "!", "from": "Godot"})
