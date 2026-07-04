class_name InkMonGuildNpcHandler
extends InkMonNpcHandler


const ACTION_GUILD_TASK := "guild_task"
const ACTION_START_MISSION := "start_mission"
## flow intent kind: 导播读到它就起出征 flow(写出发档 → gi.start_mission; handler 不碰 flow)。
const INTENT_START_MISSION := "start_mission"


func get_actions(world: InkMonWorldGI) -> Array[Dictionary]:
	var joined := bool(world.player_actor.progression.get("guild_joined", false))
	var label := "Claim Guild Errand" if joined else "Join Guild"
	var detail := "+1 task marker, no battle"
	return [
		_action(ACTION_GUILD_TASK, label, detail, "guild"),
		_action(ACTION_START_MISSION, "Set Out on Mission", "expedition: reach the target site", "guild"),
	]


func run_action(action_id: String, world: InkMonWorldGI) -> Dictionary:
	match action_id:
		ACTION_GUILD_TASK:
			return _advance_guild_task(world)
		ACTION_START_MISSION:
			# handler 不起出征; 返回 Command-as-data intent, 由 Host 导播解释执行 (对称 trainer 的 start_battle)。
			var result := _result(true, "mission departure requested")
			result[RESULT_INTENT] = {INTENT_KIND: INTENT_START_MISSION}
			return result
		_:
			return super.run_action(action_id, world)


func _advance_guild_task(world: InkMonWorldGI) -> Dictionary:
	var player := world.player_actor
	player.progression["guild_joined"] = true
	var tasks := int(player.progression.get("guild_tasks_completed", 0)) + 1
	player.progression["guild_tasks_completed"] = tasks
	return _result(true, "guild task marker %d" % tasks)
