class_name InkMonCultivationNpcHandler
extends InkMonNpcHandler


const ACTION_CULTIVATE_LEAD := "cultivate_lead"


func get_actions(_app_root: InkMonAppRoot) -> Array[Dictionary]:
	return [
		_action(ACTION_CULTIVATE_LEAD, "Cultivate Lead InkMon", "25 Gold, +1 level", "progression"),
	]


func run_action(action_id: String, app_root: InkMonAppRoot) -> Dictionary:
	match action_id:
		ACTION_CULTIVATE_LEAD:
			return app_root.cultivate_lead_inkmon()
		_:
			return super.run_action(action_id, app_root)
