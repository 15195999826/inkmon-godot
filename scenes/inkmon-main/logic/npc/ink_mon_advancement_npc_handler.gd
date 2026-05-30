class_name InkMonAdvancementNpcHandler
extends InkMonNpcHandler


const ACTION_RANK_UP := "rank_up_trainer"


func get_actions(_app_root: InkMonAppRoot) -> Array[Dictionary]:
	return [
		_action(ACTION_RANK_UP, "Advance Trainer Rank", "40 Gold, +1 rank", "progression"),
	]


func run_action(action_id: String, app_root: InkMonAppRoot) -> Dictionary:
	match action_id:
		ACTION_RANK_UP:
			return app_root.advance_trainer_rank()
		_:
			return super.run_action(action_id, app_root)
