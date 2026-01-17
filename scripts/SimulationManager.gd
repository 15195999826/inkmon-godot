extends Node

var _js_callback: JavaScriptObject


func _ready():
	print("[Godot] Simulation Ready")
	
	if OS.has_feature("web"):
		_setup_js_bridge()
	else:
		# 本地测试：模拟调用
		var result = greet("Godot Headless")
		print("[Godot] Local test result: ", result)


func _setup_js_bridge():
	_js_callback = JavaScriptBridge.create_callback(_on_js_call)
	var window = JavaScriptBridge.get_interface("window")
	window.godot_greet = _js_callback
	print("[Godot] JS Bridge registered: window.godot_greet")


func _on_js_call(args: Array) -> String:
	var name_arg = args[0] if args.size() > 0 else "Unknown"
	return greet(name_arg)


func greet(name_arg: String) -> String:
	return JSON.stringify({"message": "Hello, " + name_arg + "!", "from": "Godot"})
