class_name InkMonGuildNpcHandler
extends InkMonNpcHandler


const ACTION_GUILD_TASK := "guild_task"


func get_actions(session: InkMonGameSession) -> Array[Dictionary]:
	var joined := bool(session.player_state.progression.get("guild_joined", false))
	var label := "Claim Guild Errand" if joined else "Join Guild"
	var detail := "+1 task marker, no battle"
	return [
		_action(ACTION_GUILD_TASK, label, detail, "guild"),
	]


func run_action(action_id: String, session: InkMonGameSession) -> Dictionary:
	match action_id:
		ACTION_GUILD_TASK:
			return _advance_guild_task(session)
		_:
			return super.run_action(action_id, session)


func _advance_guild_task(session: InkMonGameSession) -> Dictionary:
	var player_state := session.player_state
	player_state.progression["guild_joined"] = true
	var tasks := int(player_state.progression.get("guild_tasks_completed", 0)) + 1
	player_state.progression["guild_tasks_completed"] = tasks
	return _result(true, "guild task marker %d" % tasks)
