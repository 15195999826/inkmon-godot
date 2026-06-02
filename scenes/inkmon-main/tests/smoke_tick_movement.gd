extends Node
## P4 核心反转契约:主世界移动 = command → 30Hz tick 逐格推进 → actor_position_changed 由 tick 产。
##
## 纯逻辑层(直接驱动 InkMonWorldGI,无 Host/View):断言
##   1. 确定性:同一 move command 序列两跑 → 位级一致世界态(final cell + 逐格 visited 序列)。
##   2. move 跨 tick:enqueue 后 0 tick 仍在起点;1 tick 未跨格(progress<步时);足够 tick 到终点。
##   3. 事件由 tick 产:enqueue 时零 actor_position_changed;事件在 tick 期逐格 emit,末格 == 终点。
##   4. 无双写:移动只改 grid occupant / actor.hex_position,不写 session(save 才同步)。


const FIXED_DT := 1.0 / 30.0
const TARGET := Vector2i(3, -1)
const TICKS_TO_COMPLETE := 80


func _ready() -> void:
	var status := _run()
	if status == "":
		print("SMOKE_TEST_RESULT: PASS - tick-driven overworld movement is deterministic and tick-paced")
		get_tree().quit(0)
	else:
		print("SMOKE_TEST_RESULT: FAIL - %s" % status)
		get_tree().quit(1)


func _run() -> String:
	GameWorld.init(EventProcessorConfig.new(20, 1))
	TimelineRegistry.reset()

	var run_a := _run_scenario()
	var run_b := _run_scenario()

	GameWorld.shutdown()

	# 2. move 跨 tick:0 tick 在起点;1 tick 未跨格;足够 tick 到终点;且确实移动了。
	if run_a["start"] != Vector2i(0, 0):
		return "new game player should start at (0,0), got %s" % str(run_a["start"])
	if run_a["before_tick"] != run_a["start"]:
		return "0 tick after enqueue: player must still be at start (move spans ticks)"
	if run_a["after_one_tick"] != run_a["start"]:
		return "1 tick: progress < step duration, occupant must not have crossed a cell yet"
	if run_a["final"] != TARGET:
		return "after enough ticks player must reach the target cell, got %s" % str(run_a["final"])
	if run_a["final"] == run_a["start"]:
		return "player must have moved away from start"

	# 3. 事件由 tick 产,不由 enqueue 产。
	if int(run_a["events_at_enqueue"]) != 0:
		return "enqueue must not emit actor_position_changed (event is produced by tick)"
	var visited_a := run_a["visited"] as Array
	if visited_a.is_empty():
		return "tick must emit actor_position_changed per crossed cell"
	if (visited_a[visited_a.size() - 1]) != TARGET:
		return "last tick-emitted position must be the target cell"
	# 逐格相邻(每个 emit 是相邻一格跨越,不是整路跳)。
	var prev := run_a["start"] as Vector2i
	for step_value in visited_a:
		var step := step_value as Vector2i
		if _axial_distance(prev, step) != 1:
			return "each tick crossing must advance exactly one adjacent cell (got %s -> %s)" % [str(prev), str(step)]
		prev = step

	# 1. 确定性:两跑位级一致。
	if run_a["final"] != run_b["final"]:
		return "non-deterministic final cell: %s vs %s" % [str(run_a["final"]), str(run_b["final"])]
	if str(visited_a) != str(run_b["visited"]):
		return "non-deterministic visited cell sequence across two identical command runs"

	# 4. 无双写:移动只改运行时(grid occupant),session 存档字段保持旧值 → 与运行时背离(save 才 sync)。
	if run_a["session_coord_after"] != run_a["session_coord_before"]:
		return "movement must not write player coord into session (field must stay until save)"
	if run_a["session_coord_after"] == run_a["final"]:
		return "session stored coord must stay stale vs runtime during move (proves no double-write)"

	# 5. near-npc 同步信号:TARGET(3,-1)与 Shop 邻接 → tick 期间 near 真相变,emit near_npc_changed。
	#    与 actor_position_changed 同源契约:由 tick 产(非 enqueue)、携新值、可位级重放。
	if str(run_a["near_final"]) == "":
		return "TARGET should leave the player adjacent to an NPC (near_npc_id must be set), else this assertion is vacuous"
	if int(run_a["near_events_at_enqueue"]) != 0:
		return "enqueue must not emit near_npc_changed (near sync is produced by tick movement, not the command)"
	var near_events_a := run_a["near_events"] as Array
	if near_events_a.is_empty():
		return "walking adjacent to an NPC must emit near_npc_changed during tick movement"
	if str(near_events_a[near_events_a.size() - 1]) != str(run_a["near_final"]):
		return "last near_npc_changed payload must equal the final near_npc_id truth"
	if str(near_events_a) != str(run_b["near_events"]):
		return "non-deterministic near_npc_changed sequence across two identical command runs"

	return ""


func _run_scenario() -> Dictionary:
	var gi := GameWorld.create_instance(func() -> GameplayInstance:
		return InkMonWorldGI.new()
	) as InkMonWorldGI
	var session := InkMonGameSession.new()
	session.begin_new_game()
	gi.setup_overworld(session)

	var start_cell := gi.get_player_coord()
	var session_coord_before := _session_player_coord(session)
	var player_id := gi.get_world_actor("player").get_id()
	var visited: Array[Vector2i] = []
	gi.actor_position_changed.connect(func(actor_id: String, _old_coord: HexCoord, new_coord: HexCoord) -> void:
		if actor_id == player_id:
			visited.append(new_coord.to_axial())
	)
	# near-npc 同步契约:真相变化时 emit(空 = 离开邻域)。表演挂此信号刷 prompt/高亮,
	# 故"由 tick 产、携新值、可确定重放"必须成立。
	var near_events: Array[String] = []
	gi.near_npc_changed.connect(func(npc_id: String) -> void:
		near_events.append(npc_id)
	)

	gi.submit(InkMonMoveCommand.new(TARGET))
	var events_at_enqueue := visited.size()
	var near_events_at_enqueue := near_events.size()
	var before_tick := gi.get_player_coord()

	gi.tick(FIXED_DT)
	var after_one_tick := gi.get_player_coord()

	for _i in range(TICKS_TO_COMPLETE):
		gi.tick(FIXED_DT)
	var final_cell := gi.get_player_coord()
	var near_final := gi.near_npc_id

	var session_coord_after := _session_player_coord(session)

	var result := {
		"start": start_cell,
		"before_tick": before_tick,
		"after_one_tick": after_one_tick,
		"final": final_cell,
		"events_at_enqueue": events_at_enqueue,
		"visited": visited,
		"near_events_at_enqueue": near_events_at_enqueue,
		"near_events": near_events,
		"near_final": near_final,
		"session_coord_before": session_coord_before,
		"session_coord_after": session_coord_after,
	}
	GameWorld.destroy_all_instances()
	return result


func _axial_distance(a: Vector2i, b: Vector2i) -> int:
	var dq := a.x - b.x
	var dr := a.y - b.y
	return int((abs(dq) + abs(dq + dr) + abs(dr)) / 2)


func _session_player_coord(session: InkMonGameSession) -> Vector2i:
	var coord := session.player_state.overworld.get("player_coord", {}) as Dictionary
	return Vector2i(int(coord.get("q", 0)), int(coord.get("r", 0)))
