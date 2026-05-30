class_name InkMonMainAgentOps
extends "res://addons/lomolib/dev_agent/dev_agent_scene_ops.gd"

## Scene classification: business/data-flow runtime validation.
## Ops use direct calls because the current scene has no player-facing UI path.


func get_supported_ops() -> PackedStringArray:
	return PackedStringArray([
		"state",
		"layout_state",
		"reset_session",
		"run_training_battle",
	])


func run_scene_op(op_name: StringName, args: Dictionary) -> Dictionary:
	var app_root := get_parent() as InkMonAppRoot
	if app_root == null:
		return {
			"ok": false,
			"message": "InkMonMainAgentOps must be a child of InkMonAppRoot",
		}

	match String(op_name):
		"state":
			return {
				"ok": true,
				"message": "InkMonMain state",
				"data": app_root.get_dev_agent_state(),
			}
		"layout_state":
			return {
				"ok": true,
				"message": "InkMonMain layout state",
				"data": app_root.get_dev_agent_layout_state(),
			}
		"reset_session":
			return app_root.reset_session()
		"run_training_battle":
			return app_root.run_training_battle_to_completion(int(args.get("max_ticks", 8)))
		_:
			return super.run_scene_op(op_name, args)
