## 编译测试脚本 - 验证所有类都能正确加载
extends Node

func _ready() -> void:
	print("\n========== Compilation Test ==========\n")
	
	# 测试 1: HexGridConfig
	print("Test 1: FrontendHexGridConfig...")
	var config = FrontendHexGridConfig.create_default_3d()
	var world_pos = config.hex_to_world(Vector2i(0, 0))
	var hex_pos = config.world_to_hex(world_pos)
	print("  ✓ HexGridConfig works")
	
	# 测试 2: VisualizerRegistry
	print("Test 2: FrontendVisualizerRegistry...")
	var registry = FrontendVisualizerRegistry.new()
	print("  ✓ VisualizerRegistry works")
	
	# 测试 3: DefaultRegistry
	print("Test 3: FrontendDefaultRegistry...")
	var default_registry = FrontendDefaultRegistry.create()
	print("  ✓ DefaultRegistry works")
	
	# 测试 4: ActionScheduler
	print("Test 4: FrontendActionScheduler...")
	var scheduler = FrontendActionScheduler.new()
	print("  ✓ ActionScheduler works")
	
	# 测试 5: RenderWorld
	print("Test 5: FrontendRenderWorld...")
	var world = FrontendRenderWorld.new()
	print("  ✓ RenderWorld works")
	
	# 测试 6: BattleDirector
	print("Test 6: FrontendBattleDirector...")
	var director = FrontendBattleDirector.new()
	print("  ✓ BattleDirector works")
	
	# 测试 7: BattleReplayScene
	print("Test 7: FrontendBattleReplayScene...")
	var scene = FrontendBattleReplayScene.new()
	print("  ✓ BattleReplayScene works")
	
	# 测试 8: ReplayControls
	print("Test 8: FrontendReplayControls...")
	var controls = FrontendReplayControls.new()
	print("  ✓ ReplayControls works")
	
	print("\n========== All Tests Passed! ==========\n")
	get_tree().quit()
