class_name InkMonGuildNpcHandler
extends InkMonNpcHandler


const ACTION_GUILD_TASK := "guild_task"
const ACTION_START_MISSION := "start_mission"
## 委托板接单 action 前缀 (Phase 3): "quest:<quest_id>" → 以该单为主委托出征。
const ACTION_QUEST_PREFIX := "quest:"
## flow intent kind: 导播读到它就起出征 flow(写出发档 → gi.start_mission; handler 不碰 flow)。
const INTENT_START_MISSION := "start_mission"


## 委托板 (Phase 3, Q3.3): 每张单一个 action, 点选 = 以该单出征 (经出发确认 modal)。
## ACTION_START_MISSION 保留为"无单出征"兼容入口 (占位 reach 单), 板空时也兜底。
func get_actions(world: InkMonWorldGI) -> Array[Dictionary]:
	var joined := bool(world.player_actor.progression.get("guild_joined", false))
	var label := "Claim Guild Errand" if joined else "Join Guild"
	var detail := "+1 task marker, no battle"
	var actions: Array[Dictionary] = [
		_action(ACTION_GUILD_TASK, label, detail, "guild"),
	]
	for quest in world.quest_board:
		actions.append(_action(ACTION_QUEST_PREFIX + quest.quest_id,
			quest.title(), "quest board | reward: %s" % quest.reward_label(), "guild"))
	if world.quest_board.is_empty():
		actions.append(_action(ACTION_START_MISSION, "Set Out on Mission",
			"freelance expedition: reach a target site", "guild"))
	return actions


func run_action(action_id: String, world: InkMonWorldGI) -> Dictionary:
	if action_id.begins_with(ACTION_QUEST_PREFIX):
		# 接单出征 (Phase 3): intent 携 quest_id, Host flow → build_state 从板上摘单。
		var quest_result := _result(true, "mission departure requested (quest)")
		quest_result[RESULT_INTENT] = {
			INTENT_KIND: INTENT_START_MISSION,
			"quest_id": action_id.substr(ACTION_QUEST_PREFIX.length()),
		}
		return quest_result
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
