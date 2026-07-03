extends Node
## 2D 战斗回放表演框架冒烟(adr/0006）。造假 replay dict 直喂 animator orchestrator，
## 确定性 step() 推帧 + drain 动画，断言走的是新管线（RenderWorld state）：
## 初始 spawn / 移动缓动到位 / 伤害扣血(visual_hp) / 死亡 / 播完触发 playback_ended。
## 纯表演层，不跑真战斗。


func _ready() -> void:
	var status := _run()
	if status == "":
		print("SMOKE_TEST_RESULT: PASS - battle 2D presentation framework drives render-state -> placeholder units from replay timeline")
		get_tree().quit(0)
	else:
		print("SMOKE_TEST_RESULT: FAIL - %s" % status)
		get_tree().quit(1)


func _run() -> String:
	# 坐标层 = baked 地图层（T2 契约）：battle_main 静态地图 + 发布 tile set。
	var grid := InkMonRender2DBakedHexMap.new()
	add_child(grid)
	var bundle := InkMonMapLoader.load_bundle("battle_main")
	if bundle.is_empty() or not grid.setup_from_bundle(bundle, 48.0):
		return "battle_main bundle failed to load for the baked map layer"
	var units_root := Node2D.new()
	add_child(units_root)
	var fx_root := Node2D.new()
	add_child(fx_root)

	var animator := InkMonBattle2DAnimator.new()
	add_child(animator)
	animator.setup(grid, units_root, fx_root)

	var ended := [false]
	animator.playback_ended.connect(func() -> void:
		ended[0] = true
	)

	var record := PlaybackData.BattleRecord.from_dict(_fake_record())
	animator.load_record(record)

	# 初始 spawn：render_world 应有 2 actor，快照读自 render-state
	var snap0 := animator.get_units_snapshot()
	if snap0.size() != 2:
		return "expected 2 units after load, got %d" % snap0.size()
	if not snap0.has("u_l") or not snap0.has("u_r"):
		return "unit ids u_l/u_r missing after load"
	if float((snap0.get("u_r", {}) as Dictionary).get("hp", -1.0)) != 20.0:
		return "u_r initial visual_hp should be 20, got %s" % str((snap0.get("u_r", {}) as Dictionary).get("hp"))

	animator.play()
	# 确定性 drain：tick=100ms 逐步推进，直到帧跑完 + scheduler 排空（move 500ms / death 1000ms
	# 都要 drain 过末帧才结束）。guard 防死循环。
	var guard := 0
	while not animator.is_ended() and guard < 100:
		animator.step(100.0)
		guard += 1
	animator.pause()

	if not ended[0]:
		return "playback_ended should have fired after frames done + scheduler drained (guard=%d)" % guard
	if not animator.is_ended():
		return "animator should report ended"

	var snap := animator.get_units_snapshot()
	var u_r := snap.get("u_r", {}) as Dictionary
	if u_r.is_empty():
		return "u_r missing after playback"
	# 致命伤害 + 死亡：visual_hp 收敛到 0，is_alive 翻转（走 RenderWorld state 路径）
	if float(u_r.get("hp", -1.0)) > 0.0:
		return "u_r visual_hp should be 0 after lethal damage + death, got %s" % str(u_r.get("hp"))
	if bool(u_r.get("alive", true)):
		return "u_r should be dead after death event"

	# 移动：u_r 从 (3,0) 缓动到 (2,0)，drain 完应落在 (2,0)
	var u_r_pos := Vector2(float(u_r.get("x", 0.0)), float(u_r.get("y", 0.0)))
	var to_2_0 := grid.coord_to_world(2, 0)
	var from_3_0 := grid.coord_to_world(3, 0)
	if u_r_pos.distance_to(to_2_0) >= u_r_pos.distance_to(from_3_0):
		return "u_r should have moved toward (2,0) per move_start event"

	# 无事件单位保持存活满血
	var u_l := snap.get("u_l", {}) as Dictionary
	if not bool(u_l.get("alive", false)):
		return "u_l should still be alive (no events targeted it)"
	if float(u_l.get("hp", -1.0)) != 30.0:
		return "u_l visual_hp should stay 30 (untouched), got %s" % str(u_l.get("hp"))

	return ""


func _fake_record() -> Dictionary:
	# events 必须是 Array[Dictionary](FrameData.events 强类型)。
	var move_events: Array[Dictionary] = [
		{"kind": "inkmon_move_start", "actor_id": "u_r", "from_hex": {"q": 3, "r": 0}, "to_hex": {"q": 2, "r": 0}},
	]
	var damage_events: Array[Dictionary] = [
		{"kind": "inkmon_damage", "target_actor_id": "u_r", "damage": 20, "actual_life_damage": 20},
	]
	var death_events: Array[Dictionary] = [
		{"kind": "inkmon_death", "actor_id": "u_r"},
	]
	var no_abilities: Array[Dictionary] = []
	return {
		"meta": {"tickInterval": 100, "totalFrames": 3},
		"initialActors": [
			{"id": "u_l", "team": 0, "displayName": "L", "position": [-3, 0, 0], "attributes": {"hp": 30, "max_hp": 30}, "abilities": no_abilities, "tags": {}},
			{"id": "u_r", "team": 1, "displayName": "R", "position": [3, 0, 0], "attributes": {"hp": 20, "max_hp": 20}, "abilities": no_abilities, "tags": {}},
		],
		"timeline": [
			{"frame": 1, "events": move_events},
			{"frame": 2, "events": damage_events},
			{"frame": 3, "events": death_events},
		],
	}
