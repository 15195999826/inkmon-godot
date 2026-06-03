class_name InkMonReleaseAdoptNpcHandler
extends InkMonNpcHandler


const ACTION_ADOPT_STUB := "adopt_stub_inkmon"
const ADOPT_COST := 15


func get_actions(_world: InkMonWorldGI) -> Array[Dictionary]:
	return [
		_action(ACTION_ADOPT_STUB, "Adopt Field InkMon", "15 Gold, adds roster entry", "roster"),
	]


func run_action(action_id: String, world: InkMonWorldGI) -> Dictionary:
	match action_id:
		ACTION_ADOPT_STUB:
			return _adopt(world)
		_:
			return super.run_action(action_id, world)


## 领养 = 程序化出生 (GI.adopt_unit 确定性 roll 技能槽建活 actor); seed = 当前 roster 序号 (= 旧 next entry_id)。
func _adopt(world: InkMonWorldGI) -> Dictionary:
	if not world.player_actor.try_spend_gold(ADOPT_COST):
		return _result(false, "not enough gold to adopt")
	var roll_seed := world.roster.size() + 1
	var unit_key := InkMonUnitConfig.RIGHT_UMBRAL_PIN if roll_seed % 2 == 0 else InkMonUnitConfig.LEFT_GALE_MOTE
	var species_id := InkMonUnitConfig.get_unit_config(unit_key).species
	var actor := world.adopt_unit(species_id, roll_seed)
	return _result(true, "adopted %s" % actor.get_display_name())
