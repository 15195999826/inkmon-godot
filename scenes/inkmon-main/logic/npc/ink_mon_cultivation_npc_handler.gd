class_name InkMonCultivationNpcHandler
extends InkMonNpcHandler


const ACTION_CULTIVATE_LEAD := "cultivate_lead"
const CULTIVATION_COST := 25


func get_actions(_world: InkMonWorldGI) -> Array[Dictionary]:
	return [
		_action(ACTION_CULTIVATE_LEAD, "Cultivate Lead InkMon", "25 Gold, +1 level", "progression"),
	]


func run_action(action_id: String, world: InkMonWorldGI) -> Dictionary:
	match action_id:
		ACTION_CULTIVATE_LEAD:
			return _cultivate_lead(world)
		_:
			return super.run_action(action_id, world)


## 培养 = 活 roster[0] +level (六维由 f(species, level) 重算, 不直接写数值); 跨阈值触发进化 (原地变身)。
func _cultivate_lead(world: InkMonWorldGI) -> Dictionary:
	if world.roster.is_empty():
		return _result(false, "no InkMon to cultivate")
	if not world.player_actor.try_spend_gold(CULTIVATION_COST):
		return _result(false, "not enough gold for cultivation")
	var actor := world.roster[0]
	actor.level += 1
	actor.exp = 0
	var evolved := InkMonSpeciesCatalog.evolve_actor(actor)
	# 升级 / 进化后按新 species+level 重算派生六维 (HP carryover 保留, max_hp 涨)。
	world.refresh_unit_stats(actor)
	world.player_actor.progression["cultivation_points"] = int(
		world.player_actor.progression.get("cultivation_points", 0)
	) + 1
	var message := "cultivated %s to Lv%d" % [actor.get_display_name(), actor.level]
	if evolved:
		message += " — evolved!"
	return _result(true, message)
