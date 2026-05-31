class_name InkMonReleaseAdoptNpcHandler
extends InkMonNpcHandler


const ACTION_ADOPT_STUB := "adopt_stub_inkmon"
const ADOPT_COST := 15


func get_actions(_session: InkMonGameSession) -> Array[Dictionary]:
	return [
		_action(ACTION_ADOPT_STUB, "Adopt Field InkMon", "15 Gold, adds roster entry", "roster"),
	]


func run_action(action_id: String, session: InkMonGameSession) -> Dictionary:
	match action_id:
		ACTION_ADOPT_STUB:
			return _adopt(session)
		_:
			return super.run_action(action_id, session)


## 领养 = 新出生 (from_birth 确定性 roll 技能槽); seed = entry_id。
func _adopt(session: InkMonGameSession) -> Dictionary:
	var player_state := session.player_state
	if not player_state.try_spend_gold(ADOPT_COST):
		return _result(false, "not enough gold to adopt")
	var entry_id := player_state.get_next_roster_entry_id()
	var unit_key := InkMonUnitConfig.RIGHT_FLEX if entry_id % 2 == 0 else InkMonUnitConfig.LEFT_FLEX
	var species := InkMonUnitConfig.get_unit_config(unit_key).species
	var entry := InkMonRosterEntry.from_birth(entry_id, species, entry_id)
	player_state.add_roster_entry(entry)
	session.sync_roster_containers()
	return _result(true, "adopted %s" % entry.species)
