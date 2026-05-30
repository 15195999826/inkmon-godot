class_name InkMonReleaseAdoptNpcHandler
extends InkMonNpcHandler


const ACTION_ADOPT_STUB := "adopt_stub_inkmon"


func get_actions(_app_root: InkMonAppRoot) -> Array[Dictionary]:
	return [
		_action(ACTION_ADOPT_STUB, "Adopt Field InkMon", "15 Gold, adds roster entry", "roster"),
	]


func run_action(action_id: String, app_root: InkMonAppRoot) -> Dictionary:
	match action_id:
		ACTION_ADOPT_STUB:
			return app_root.adopt_stub_inkmon()
		_:
			return super.run_action(action_id, app_root)
