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
	
	# 注册 run_battle 回调
	var battle_callback := JavaScriptBridge.create_callback(_on_run_battle_call)
	_js_window.godot_run_battle = battle_callback
	_js_window.godot_battle_result = ""
	
	print("[Godot] JS Bridge registered: window.godot_greet")
	print("[Godot] JS Bridge registered: window.godot_run_battle")
	print("[Godot] Tip: Check window.godot_last_result for return value")
	print("[Godot] Tip: Check window.godot_battle_result for battle result")


func _on_js_call(args: Array) -> String:
	var name_arg = args[0] if args.size() > 0 else "Unknown"
	var result = greet(name_arg)
	print("[Godot] _on_js_call received: ", name_arg)
	print("[Godot] _on_js_call returning: ", result)
	
	# 同时写入全局变量作为备用
	_js_window.godot_last_result = result
	
	return result


func _on_run_battle_call(_args: Array) -> String:
	var result := run_battle()
	print("[Godot] _on_run_battle_call completed")
	print("[Godot] _on_run_battle_call returning: ", result.substr(0, 100), "...")
	
	# 同时写入全局变量作为备用
	_js_window.godot_battle_result = result
	
	return result


func greet(name_arg: String) -> String:
	return JSON.stringify({"message": "Hello, " + name_arg + "!", "from": "Godot"})


func run_battle() -> String:
	print("\n[Godot] Starting battle simulation...")
	
	# 创建 HexBattle 实例
	var battle := HexBattle.new()
	
	# 使用默认配置开始战斗
	battle.start({})
	
	# 运行战斗循环直到结束
	var dt := 1.0  # 每个 tick 的时间步长
	while battle.tick_count < battle.MAX_TICKS and not battle._ended:
		battle.tick(dt)
	
	print("[Godot] Battle ended. Ticks: %d" % battle.tick_count)
	
	# 获取回放数据
	var replay_data := battle.get_replay_data()
	
	# 转换为 JSON 字符串
	var json_str := JSON.stringify(replay_data)
	
	print("[Godot] Replay JSON length: %d chars" % json_str.length())
	print("[Godot] First 200 chars: ", json_str.substr(0, 200))
	
	return json_str
