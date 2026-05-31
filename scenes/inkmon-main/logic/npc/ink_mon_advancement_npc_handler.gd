class_name InkMonAdvancementNpcHandler
extends InkMonNpcHandler


const ACTION_RANK_UP := "rank_up_trainer"
const ADVANCEMENT_COST := 40


func get_actions(_session: InkMonGameSession) -> Array[Dictionary]:
	return [
		_action(ACTION_RANK_UP, "Advance Trainer Rank", "40 Gold, +1 rank", "progression"),
	]


func run_action(action_id: String, session: InkMonGameSession) -> Dictionary:
	match action_id:
		ACTION_RANK_UP:
			return _advance_rank(session)
		_:
			return super.run_action(action_id, session)


func _advance_rank(session: InkMonGameSession) -> Dictionary:
	var player_state := session.player_state
	if not player_state.try_spend_gold(ADVANCEMENT_COST):
		return _result(false, "not enough gold for trainer advancement")
	var rank := int(player_state.progression.get("trainer_rank", 1)) + 1
	player_state.progression["trainer_rank"] = rank
	return _result(true, "trainer rank advanced to R%d" % rank)
