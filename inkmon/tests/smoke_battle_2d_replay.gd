extends Node
## 2D 战斗回放 animator 冒烟(adr/0005）。造假 replay dict 直喂 animator,确定性 step() 推帧,
## 断言:初始 spawn / 移动朝向 / 伤害扣血 / 死亡 / 播完触发 playback_ended。纯表演层,不跑真战斗。


func _ready() -> void:
	var status := _run()
	if status == "":
		print("SMOKE_TEST_RESULT: PASS - battle 2D replay animator drives placeholder units from replay timeline")
		get_tree().quit(0)
	else:
		print("SMOKE_TEST_RESULT: FAIL - %s" % status)
		get_tree().quit(1)


func _run() -> String:
	var grid := InkMonBattle2DGrid.new()
	add_child(grid)
	grid.setup(5)
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

	var record := ReplayData.BattleRecord.from_dict(_fake_record())
	animator.load_record(record)

	var snap0 := animator.get_units_snapshot()
	if snap0.size() != 2:
		return "expected 2 units after load, got %d" % snap0.size()
	if not snap0.has("u_l") or not snap0.has("u_r"):
		return "unit ids u_l/u_r missing after load"

	animator.play()
	# 确定性步进 3 帧(tick=100ms):frame1 move / frame2 damage / frame3 death+end。
	animator.step(100.0)
	animator.step(100.0)
	animator.step(100.0)
	animator.pause()

	if not ended[0]:
		return "playback_ended should have fired after all frames"
	if not animator.is_ended():
		return "animator should report ended"

	var snap := animator.get_units_snapshot()
	var u_r := snap.get("u_r", {}) as Dictionary
	if u_r.is_empty():
		return "u_r missing after playback"
	if float(u_r.get("hp", -1.0)) > 0.0:
		return "u_r hp should be 0 after lethal damage, got %s" % str(u_r.get("hp"))
	if bool(u_r.get("alive", true)):
		return "u_r should be dead after death event"

	var u_r_pos := Vector2(float(u_r.get("x", 0.0)), float(u_r.get("y", 0.0)))
	var to_2_0 := grid.coord_to_world(2, 0)
	var from_3_0 := grid.coord_to_world(3, 0)
	if u_r_pos.distance_to(to_2_0) >= u_r_pos.distance_to(from_3_0):
		return "u_r should have moved toward (2,0) per move_complete event"

	var u_l := snap.get("u_l", {}) as Dictionary
	if not bool(u_l.get("alive", false)):
		return "u_l should still be alive (no events targeted it)"

	return ""


func _fake_record() -> Dictionary:
	# events 必须是 Array[Dictionary](FrameData.events 强类型;无类型 Array 赋值会报错)。
	# 真实录像本就产 Array[Dictionary],此处手搓需显式标注以匹配。
	var move_events: Array[Dictionary] = [
		{"kind": "inkmon_move_complete", "actor_id": "u_r", "from_hex": {"q": 3, "r": 0}, "to_hex": {"q": 2, "r": 0}},
	]
	var damage_events: Array[Dictionary] = [
		{"kind": "inkmon_damage", "target_actor_id": "u_r", "damage": 20, "actual_life_damage": 20},
	]
	var death_events: Array[Dictionary] = [
		{"kind": "inkmon_death", "actor_id": "u_r"},
	]
	# abilities 也是 Array[Dictionary] 强类型(真实录像来自 get_ability_snapshot);手搓需显式标注空类型数组。
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
