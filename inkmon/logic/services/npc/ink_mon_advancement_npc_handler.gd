class_name InkMonAdvancementNpcHandler
extends InkMonNpcHandler


const ACTION_RANK_UP := "rank_up_trainer"
const ADVANCEMENT_COST := 40


func get_actions(_world: InkMonWorldGI) -> Array[Dictionary]:
	return [
		_action(ACTION_RANK_UP, "progression"),
	]


func run_action(action_id: String, world: InkMonWorldGI) -> Dictionary:
	match action_id:
		ACTION_RANK_UP:
			return _advance_rank(world)
		_:
			return super.run_action(action_id, world)


func _advance_rank(world: InkMonWorldGI) -> Dictionary:
	var player := world.player_actor
	if not player.try_spend_gold(ADVANCEMENT_COST):
		return _result(false, "not enough gold for trainer advancement")
	var rank := int(player.progression.get("trainer_rank", 1)) + 1
	player.progression["trainer_rank"] = rank
	return _result(true, "trainer rank advanced to R%d" % rank)
