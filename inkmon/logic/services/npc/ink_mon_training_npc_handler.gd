class_name InkMonTrainingNpcHandler
extends InkMonNpcHandler


const ACTION_START_BATTLE := "start_training_battle"
## flow intent kind: 导播读到它就在持久 world GI 内起一场训练战 (handler 不碰 flow)。
const INTENT_START_BATTLE := "start_battle"


func get_actions(_world: InkMonWorldGI) -> Array[Dictionary]:
	return [
		_action(ACTION_START_BATTLE, "battle"),
	]


func run_action(action_id: String, _world: InkMonWorldGI) -> Dictionary:
	match action_id:
		ACTION_START_BATTLE:
			# handler 不起战斗; 返回 Command-as-data intent, 由薄场景导播解释执行。
			var result := _result(true, "training battle requested")
			result[RESULT_INTENT] = {INTENT_KIND: INTENT_START_BATTLE}
			return result
		_:
			return super.run_action(action_id, _world)
