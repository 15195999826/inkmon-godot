extends Node
## lifecycle 契约 (adr/0001 统一 live-actor): gi.to_dict/from_dict round-trip + InkMonSaveFile 纯 IO。
##
## 断言 (纯逻辑, 直接驱动 GI, 无 Host/View):
##   1. gi.to_dict → 新 gi.from_dict → to_dict 深相等 (存档往返幂等)。
##   2. 移动后玩家位置 (avatar = 活 actor, 即运行真相) 被 to_dict 捕获进存档 (无独立 session 字段双写)。
##   3. InkMonSaveFile.write(gi.to_dict()) → read → 新 gi.from_dict → 玩家位置还原。


const FIXED_DT := 1.0 / 30.0
const TARGET := Vector2i(3, -1)
const TICKS := 80
const SAVE_PATH := "user://inkmon_l2_lifecycle_test.json"


func _ready() -> void:
	var status := _run()
	if status == "":
		print("SMOKE_TEST_RESULT: PASS - gi.to_dict/from_dict round-trip + InkMonSaveFile IO, player position survives save/load")
		get_tree().quit(0)
	else:
		print("SMOKE_TEST_RESULT: FAIL - %s" % status)
		get_tree().quit(1)


func _run() -> String:
	GameWorld.init(EventProcessorConfig.new(20, 1))
	TimelineRegistry.reset()

	# 1. to_dict 幂等。
	var gi := _new_gi()
	gi.new_game()
	var d1 := gi.to_dict()
	GameWorld.destroy_all_instances()
	var gi_rt := _new_gi()
	gi_rt.from_dict(d1)
	var d2 := gi_rt.to_dict()
	if JSON.stringify(d1) != JSON.stringify(d2):
		GameWorld.shutdown()
		return "gi.to_dict→from_dict→to_dict must be deep-equal (idempotent round-trip)"

	# 2. 移动 → 玩家位置 (运行真相 = avatar/grid occupant) 进 to_dict。
	GameWorld.destroy_all_instances()
	var gi2 := _new_gi()
	gi2.new_game()
	var start := gi2.get_player_coord()
	if _save_coord(gi2.to_dict()) != start:
		GameWorld.shutdown()
		return "new-game save coord should equal start coord %s" % str(start)
	gi2.submit(InkMonMoveCommand.new(TARGET))
	for _i in range(TICKS):
		gi2.tick(FIXED_DT)
	if gi2.get_player_coord() != TARGET:
		GameWorld.shutdown()
		return "tick movement should reach target before save"
	if _save_coord(gi2.to_dict()) != TARGET:
		GameWorld.shutdown()
		return "to_dict must capture the runtime player coord %s (avatar is the position truth)" % str(TARGET)

	# 3. InkMonSaveFile 往返:write(to_dict) → read → 新 gi.from_dict → 位置还原。
	var write_result := InkMonSaveFile.write(SAVE_PATH, gi2.to_dict())
	if not bool(write_result.get("ok", false)):
		GameWorld.shutdown()
		return "InkMonSaveFile.write should succeed: %s" % str(write_result.get("message", ""))
	GameWorld.destroy_all_instances()

	var read_result := InkMonSaveFile.read(SAVE_PATH)
	if not bool(read_result.get("ok", false)):
		GameWorld.shutdown()
		return "InkMonSaveFile.read should succeed: %s" % str(read_result.get("message", ""))
	var gi3 := _new_gi()
	gi3.from_dict(read_result.get("data", {}) as Dictionary)
	if gi3.get_player_coord() != TARGET:
		GameWorld.shutdown()
		return "load (from_dict) should restore the saved player coord (%s)" % str(TARGET)
	var player := gi3.get_world_actor("player")
	if player == null or player.hex_position.to_axial() != TARGET:
		GameWorld.shutdown()
		return "loaded player avatar hex_position should match saved coord"

	GameWorld.shutdown()
	return ""


func _new_gi() -> InkMonWorldGI:
	return GameWorld.create_instance(func() -> GameplayInstance:
		return InkMonWorldGI.new()
	) as InkMonWorldGI


func _save_coord(data: Dictionary) -> Vector2i:
	var player := data.get("player", {}) as Dictionary
	var coord := player.get("coord", {}) as Dictionary
	return Vector2i(int(coord.get("q", 0)), int(coord.get("r", 0)))
