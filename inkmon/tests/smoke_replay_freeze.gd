extends Node

## 回放观看期主世界冻结 smoke(game-vision §2 体验流):
## 战斗结束 → 回放/结果观看期间世界泵停(入队的 move 命令不被 drain、玩家坐标不动)→
## 玩家确认离开(Leave)后解冻(命令恢复 drain、玩家动起来)。

const InkMonGameScene := preload("res://inkmon/host/ink_mon_game.tscn")


func _ready() -> void:
	var status := await _run()
	if status == "":
		print("SMOKE_TEST_RESULT: PASS - world freezes during replay viewing and resumes after leave")
		get_tree().quit(0)
	else:
		print("SMOKE_TEST_RESULT: FAIL - %s" % status)
		get_tree().quit(1)


func _run() -> String:
	var root := InkMonGameScene.instantiate() as InkMonWorldHost
	add_child(root)
	await get_tree().process_frame

	# 起训练战(Host flow):sim 瞬间算完 → 回放观看期开始,世界进入冻结。
	var start := root.run_training_battle_to_completion(8)
	if not bool(start.get("ok", false)):
		return _cleanup(root, "training battle failed to run: %s" % str(start.get("message", "")))
	if not bool(root.get_dev_agent_state().get("replay_active", false)):
		return _cleanup(root, "replay_active should be true right after battle (viewing period)")
	if str(root.get_dev_agent_state().get("state", "")) != "BATTLE":
		return _cleanup(root, "app state should be BATTLE during replay viewing")

	# 冻结断言:观看期直接向 GI 入队 move 命令(绕过 UI 输入屏蔽,专测 tick 泵停),坐标必须不动。
	var coord_before := _player_coord(root)
	root._world_gi.submit(InkMonMoveCommand.new(coord_before + Vector2i(1, 0)))
	await get_tree().create_timer(0.5).timeout  # 未冻结的话 ~15 个 FIXED_DT 早就 drain + 起步了
	if _player_coord(root) != coord_before:
		return _cleanup(root, "world must stay frozen during replay viewing (player moved)")

	# 跳过回放 → Leave 出现;确认离开前仍冻结。
	var view := root._presentation._battle_2d_view
	if view == null:
		return _cleanup(root, "battle 2d view should exist during replay viewing")
	view._on_skip_pressed()
	var leave_ready := false
	for _i in range(120):
		await get_tree().process_frame
		if view.is_leave_available():
			leave_ready = true
			break
	if not leave_ready:
		return _cleanup(root, "Leave button should appear after playback ends")
	if _player_coord(root) != coord_before:
		return _cleanup(root, "world must stay frozen until player confirms leave")

	# 确认离开 → 解冻:replay_active 清掉、回 OVERWORLD,排队的 move 开始 drain。
	view.request_leave()
	await get_tree().process_frame
	if bool(root.get_dev_agent_state().get("replay_active", false)):
		return _cleanup(root, "replay_active should clear after leave")
	if str(root.get_dev_agent_state().get("state", "")) != "OVERWORLD":
		return _cleanup(root, "state should return to OVERWORLD after leave")
	var moved := false
	for _i in range(100):
		await get_tree().create_timer(0.05).timeout
		if _player_coord(root) != coord_before:
			moved = true
			break
	if not moved:
		return _cleanup(root, "world should resume ticking after leave (queued move should drain)")

	root.queue_free()
	await get_tree().process_frame
	return ""


func _player_coord(root: InkMonWorldHost) -> Vector2i:
	var coord := root.get_dev_agent_state().get("player_coord", {}) as Dictionary
	if coord == null:
		return Vector2i.ZERO
	return Vector2i(int(coord.get("q", 0)), int(coord.get("r", 0)))


func _cleanup(root: InkMonWorldHost, status: String) -> String:
	root.queue_free()
	GameWorld.shutdown()
	return status
