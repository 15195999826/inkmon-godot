extends Node

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
	
	# 直接暴露 Godot 实例到 window.godot_instance
	_js_window.godot_instance = self
	
	# 使用 eval 创建同步包装函数
	var js_code := """
		window.godot_run_battle_sync = function() {
			return window.godot_instance.run_battle();
		};
		window.godot_greet_sync = function(name) {
			return window.godot_instance.greet(name);
		};
	"""
	
	JavaScriptBridge.eval(js_code)
	
	print("[Godot] JS Bridge registered: window.godot_instance")
	print("[Godot] JS Bridge registered: window.godot_run_battle_sync")
	print("[Godot] JS Bridge registered: window.godot_greet_sync")


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
