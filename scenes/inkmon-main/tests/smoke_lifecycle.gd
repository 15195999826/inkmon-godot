extends Node
## P7 lifecycle 契约:capture/hydrate 往返 + InkMonSaveFile IO + 单写不双写。
##
## 断言(纯逻辑,直接驱动 GI + session,无 Host/View):
##   1. session.to_dict → from_dict → to_dict 深相等(存档往返幂等)。
##   2. capture_to_session:runtime(grid occupant)→ session 存档字段(save 侧单写)。
##   3. hydrate_from_session:session 存档字段 → runtime(load 侧单读,玩家 occupant + actor 同步)。
##   4. InkMonSaveFile.write → read → from_dict → 新 GI setup_overworld(hydrate)→ 位置还原。


const FIXED_DT := 1.0 / 30.0
const TARGET := Vector2i(3, -1)
const TICKS := 80
const SAVE_PATH := "user://inkmon_l2_lifecycle_test.json"


func _ready() -> void:
	var status := _run()
	if status == "":
		print("SMOKE_TEST_RESULT: PASS - capture/hydrate round-trip + InkMonSaveFile, single-write no double-write")
		get_tree().quit(0)
	else:
		print("SMOKE_TEST_RESULT: FAIL - %s" % status)
		get_tree().quit(1)


func _run() -> String:
	GameWorld.init(EventProcessorConfig.new(20, 1))
	TimelineRegistry.reset()

	# 1. session to_dict 幂等。
	var s := InkMonGameSession.new()
	s.begin_new_game()
	var d1 := s.to_dict()
	var s2 := InkMonGameSession.new()
	s2.from_dict(d1)
	var d2 := s2.to_dict()
	if JSON.stringify(d1) != JSON.stringify(d2):
		GameWorld.shutdown()
		return "session to_dict→from_dict→to_dict must be deep-equal (idempotent round-trip)"

	# 2/3. capture/hydrate 双向。
	var gi := GameWorld.create_instance(func() -> GameplayInstance:
		return InkMonWorldGI.new()
	) as InkMonWorldGI
	var session := InkMonGameSession.new()
	session.begin_new_game()
	gi.setup_overworld(session)
	var start := gi.get_player_coord()

	# 走到 TARGET(运行时改,session 存档字段未动 —— 单写不双写)。
	gi.enqueue_move_player(TARGET)
	for _i in range(TICKS):
		gi.tick(FIXED_DT)
	if gi.get_player_coord() != TARGET:
		GameWorld.shutdown()
		return "tick movement should reach target before lifecycle checks"
	if _session_coord(session) != start:
		GameWorld.shutdown()
		return "movement must not write session (capture is the only writer); session must still hold start"

	# hydrate:把 session(仍 start)灌回 runtime → 玩家退回 start(occupant + actor 同步)。
	gi.hydrate_from_session()
	if gi.get_player_coord() != start:
		GameWorld.shutdown()
		return "hydrate_from_session must restore runtime player occupant to the session coord (%s)" % str(start)
	var player := gi.get_world_actor("player")
	if player == null or player.hex_position.to_axial() != start:
		GameWorld.shutdown()
		return "hydrate must also sync the player actor hex_position to the session coord"
	if player.is_moving():
		GameWorld.shutdown()
		return "hydrate must clear in-flight movement state"

	# capture:走到 TARGET 再 capture → session 存档字段 = runtime。
	gi.enqueue_move_player(TARGET)
	for _i in range(TICKS):
		gi.tick(FIXED_DT)
	gi.capture_to_session()
	if _session_coord(session) != TARGET:
		GameWorld.shutdown()
		return "capture_to_session must write the runtime player coord into the session (%s)" % str(TARGET)

	# 4. InkMonSaveFile 往返:write → read → from_dict → 新 GI setup(hydrate)→ 位置还原。
	var write_result := InkMonSaveFile.write(SAVE_PATH, session)
	if not bool(write_result.get("ok", false)):
		GameWorld.shutdown()
		return "InkMonSaveFile.write should succeed: %s" % str(write_result.get("message", ""))
	GameWorld.destroy_all_instances()

	var read_result := InkMonSaveFile.read(SAVE_PATH)
	if not bool(read_result.get("ok", false)):
		GameWorld.shutdown()
		return "InkMonSaveFile.read should succeed: %s" % str(read_result.get("message", ""))
	var loaded := InkMonGameSession.new()
	loaded.from_dict(read_result.get("data", {}) as Dictionary)
	var gi2 := GameWorld.create_instance(func() -> GameplayInstance:
		return InkMonWorldGI.new()
	) as InkMonWorldGI
	gi2.setup_overworld(loaded)
	if gi2.get_player_coord() != TARGET:
		GameWorld.shutdown()
		return "load (setup_overworld hydrates) should restore the saved player coord (%s)" % str(TARGET)

	GameWorld.shutdown()
	return ""


func _session_coord(session: InkMonGameSession) -> Vector2i:
	var coord := session.player_state.overworld.get("player_coord", {}) as Dictionary
	return Vector2i(int(coord.get("q", 0)), int(coord.get("r", 0)))
