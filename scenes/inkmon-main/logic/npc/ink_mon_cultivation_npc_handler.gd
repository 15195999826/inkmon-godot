class_name InkMonCultivationNpcHandler
extends InkMonNpcHandler


const ACTION_CULTIVATE_LEAD := "cultivate_lead"
const CULTIVATION_COST := 25


func get_actions(_session: InkMonGameSession) -> Array[Dictionary]:
	return [
		_action(ACTION_CULTIVATE_LEAD, "Cultivate Lead InkMon", "25 Gold, +1 level", "progression"),
	]


func run_action(action_id: String, session: InkMonGameSession) -> Dictionary:
	match action_id:
		ACTION_CULTIVATE_LEAD:
			return _cultivate_lead(session)
		_:
			return super.run_action(action_id, session)


## 培养 = +level (六维由 f(species, level) 派生, 不直接写数值); 跨阈值触发进化 (entry_id 不变)。
func _cultivate_lead(session: InkMonGameSession) -> Dictionary:
	var player_state := session.player_state
	if player_state.roster.is_empty():
		return _result(false, "no InkMon to cultivate")
	if not player_state.try_spend_gold(CULTIVATION_COST):
		return _result(false, "not enough gold for cultivation")
	var entry := player_state.roster[0]
	entry.level += 1
	entry.exp = 0
	var evolved := InkMonSpeciesCatalog.evolve_entry(entry)
	player_state.progression["cultivation_points"] = int(
		player_state.progression.get("cultivation_points", 0)
	) + 1
	var message := "cultivated %s to Lv%d" % [entry.name_en, entry.level]
	if evolved:
		message += " — evolved!"
	return _result(true, message)
