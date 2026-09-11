extends Node
## 战斗棋盘复用契约：同一常驻 world 连打两场，上一场棋盘上的占用与预订在第二场开打前
## (_reset_battle_state) 必须清干净 —— 幸存者 (活 roster 与临时对手都算) 不能留在旧棋盘上,
## 临时对手整只出 registry。棋盘分工固定: get_battle_grid() 只指战斗棋盘 (战斗外是上一场棋盘),
## 主世界走 overworld_grid, 二者不翻转。


func _ready() -> void:
	var status := _run()
	GameWorld.shutdown()
	if status == "":
		print("SMOKE_TEST_RESULT: PASS - previous battle board is released before the next battle starts")
		get_tree().quit(0)
	else:
		print("SMOKE_TEST_RESULT: FAIL - %s" % status)
		get_tree().quit(1)


func _run() -> String:
	GameWorld.shutdown()
	var gi := GameWorld.create_instance(InkMonWorldGI.new()) as InkMonWorldGI
	gi.new_game()

	gi.request_training_battle()
	var first_board := gi.get_battle_grid()
	if first_board == null:
		return "battle board must be configured once a battle is requested"
	var first_ids := _unit_ids(gi)
	var first_dummy_ids := _team_ids(gi.right_team)
	if _occupied_by(first_board, first_ids) != first_ids.size():
		return "every unit must stand on the first board at battle start"
	GameWorld.tick_all(BattleProcedure.DEFAULT_TICK_INTERVAL)
	if gi.has_active_battle():
		return "first battle did not finish in one world tick"
	if gi.get_battle_grid() != first_board:
		return "the battle board must stay put after the battle (no flip to the overworld model)"
	if _occupied_by(first_board, first_ids) == 0:
		return "test setup: expected at least one survivor still standing on the first board"

	gi.request_training_battle()
	var second_board := gi.get_battle_grid()
	if second_board == null or second_board == first_board:
		return "second battle must configure a fresh board"
	var leftovers := _occupied_by(first_board, first_ids)
	if leftovers != 0:
		return "%d unit(s) of the previous battle still occupy the previous board" % leftovers
	if _reserved_by(first_board, first_ids) != 0:
		return "previous board still carries reservations of the previous battle's units"
	for dummy_id in first_dummy_ids:
		if gi.get_actor(dummy_id) != null:
			return "previous battle's transient opponent %s must leave the registry" % dummy_id
	var second_ids := _unit_ids(gi)
	if _occupied_by(second_board, second_ids) != second_ids.size():
		return "every unit must stand on the second board at battle start"
	return ""


func _unit_ids(gi: InkMonWorldGI) -> Array[String]:
	return _team_ids(gi.get_all_units())


func _team_ids(team: Array[InkMonUnitActor]) -> Array[String]:
	var ids: Array[String] = []
	for actor in team:
		ids.append(actor.get_id())
	return ids


## 棋盘上 occupant 是 ids 中某个战斗单位的格子数。
func _occupied_by(board: GridMapModel, ids: Array[String]) -> int:
	var count := 0
	for coord in board.get_all_coords():
		var occupant: Variant = board.get_occupant(coord)
		if occupant is InkMonBattleActor and ids.has((occupant as InkMonBattleActor).get_id()):
			count += 1
	return count


## 棋盘上被 ids 中某个战斗单位预订的格子数。
func _reserved_by(board: GridMapModel, ids: Array[String]) -> int:
	var count := 0
	for coord in board.get_all_coords():
		if ids.has(board.get_reservation(coord)):
			count += 1
	return count
