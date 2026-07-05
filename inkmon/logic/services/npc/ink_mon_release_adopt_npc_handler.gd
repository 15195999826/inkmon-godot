class_name InkMonReleaseAdoptNpcHandler
extends InkMonNpcHandler


const ACTION_ADOPT := "adopt_inkmon"
const ADOPT_COST := 15


func get_actions(_world: InkMonWorldGI) -> Array[Dictionary]:
	return [
		_action(ACTION_ADOPT, "roster"),
	]


func run_action(action_id: String, world: InkMonWorldGI) -> Dictionary:
	match action_id:
		ACTION_ADOPT:
			return _adopt(world)
		_:
			return super.run_action(action_id, world)


## 领养 = 程序化出生 (GI.adopt_unit 确定性 roll 技能槽建活 actor); seed = 当前 roster 序号 (= 旧 next entry_id)。
## 物种从 SpeciesCatalog 可领养池确定性取 (seed % 池大小), 不再硬编码 2 个 stub key。
func _adopt(world: InkMonWorldGI) -> Dictionary:
	var pool := InkMonSpeciesCatalog.list_adoptable_species()
	if pool.is_empty():
		return _result(false, "no adoptable species available")
	if not world.player_actor.try_spend_gold(ADOPT_COST):
		return _result(false, "not enough gold to adopt")
	var roll_seed := world.roster.size() + 1
	var species_id := pool[roll_seed % pool.size()]
	var actor := world.adopt_unit(species_id, roll_seed)
	return _result(true, "adopted %s" % actor.get_display_name())
