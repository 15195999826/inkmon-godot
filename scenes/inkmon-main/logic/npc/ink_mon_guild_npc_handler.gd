class_name InkMonGuildNpcHandler
extends InkMonNpcHandler


const ACTION_GUILD_TASK := "guild_task"


func get_actions(app_root: InkMonAppRoot) -> Array[Dictionary]:
	var joined := bool(app_root.session.player_state.progression.get("guild_joined", false))
	var label := "Claim Guild Errand" if joined else "Join Guild"
	var detail := "+1 task marker, no battle"
	return [
		_action(ACTION_GUILD_TASK, label, detail, "guild"),
	]


func run_action(action_id: String, app_root: InkMonAppRoot) -> Dictionary:
	match action_id:
		ACTION_GUILD_TASK:
			return app_root.advance_guild_task()
		_:
			return super.run_action(action_id, app_root)
