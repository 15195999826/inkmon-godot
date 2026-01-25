extends Node

var _js_callback_greet: JavaScriptObject
var _js_callback_battle: JavaScriptObject


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


func _on_greet_call(args: Array) -> String:
	var name_arg = args[0] if args.size() > 0 else "Unknown"
	return greet(name_arg)


func _on_battle_call(args: Array) -> String:
	return run_battle()


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
	
	# 获取回放数据（必须在 _end_battle() 之前调用，因为 _end_battle 会 stop_recording）
	var replay_data: Dictionary = battle.recorder.get_replay_data() if battle.recorder != null else {}
	
	# 转换为 JSON 字符串
	var json_str := JSON.stringify(replay_data)
	
	print("[Godot] Replay JSON length: %d chars" % json_str.length())
	print("[Godot] First 200 chars: ", json_str.substr(0, 200))
	
	return json_str
