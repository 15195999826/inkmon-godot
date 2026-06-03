class_name InkMonGuildNpcHandler
extends InkMonNpcHandler


const ACTION_GUILD_TASK := "guild_task"


func get_actions(world: InkMonWorldGI) -> Array[Dictionary]:
	var joined := bool(world.player_actor.progression.get("guild_joined", false))
	var label := "Claim Guild Errand" if joined else "Join Guild"
	var detail := "+1 task marker, no battle"
	return [
		_action(ACTION_GUILD_TASK, label, detail, "guild"),
	]


func run_action(action_id: String, world: InkMonWorldGI) -> Dictionary:
	match action_id:
		ACTION_GUILD_TASK:
			return _advance_guild_task(world)
		_:
			return super.run_action(action_id, world)


func _advance_guild_task(world: InkMonWorldGI) -> Dictionary:
	var player := world.player_actor
	player.progression["guild_joined"] = true
	var tasks := int(player.progression.get("guild_tasks_completed", 0)) + 1
	player.progression["guild_tasks_completed"] = tasks
	return _result(true, "guild task marker %d" % tasks)
