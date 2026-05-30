class_name InkMonTrainingNpcHandler
extends InkMonNpcHandler


const ACTION_START_BATTLE := "start_training_battle"


func get_actions(_app_root: InkMonAppRoot) -> Array[Dictionary]:
	return [
		_action(ACTION_START_BATTLE, "Start Training Battle", "4v4 ATB drill, earns Gold", "battle"),
	]


func run_action(action_id: String, app_root: InkMonAppRoot) -> Dictionary:
	match action_id:
		ACTION_START_BATTLE:
			return app_root.complete_training_battle_action()
		_:
			return super.run_action(action_id, app_root)
