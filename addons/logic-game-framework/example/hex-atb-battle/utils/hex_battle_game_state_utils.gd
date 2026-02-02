## HexBattleGameStateUtils - 项目层的 GameState 辅助函数
##
## 提供类型安全的 game_state_provider 访问方法。
## 所有函数都是静态的，不保存任何状态。
##
## 使用示例：
## ```gdscript
## var name := HexBattleGameStateUtils.get_actor_display_name(actor_ref, battle)
## var actors := HexBattleGameStateUtils.get_actors_for_event_processor(battle)
## ```
class_name HexBattleGameStateUtils


## 获取角色显示名称
## @param actor_ref: 角色引用
## @param game_state_provider: HexBattle 实例
## @return: 角色显示名称，如果无法获取则返回 actor_ref.id 或 "???"
static func get_actor_display_name(actor_ref: ActorRef, game_state_provider: HexBattle) -> String:
	if actor_ref == null:
		return "???"
	if game_state_provider != null:
		var actor := game_state_provider.get_actor(actor_ref.id)
		if actor != null:
			return actor.get_display_name()
	return actor_ref.id


## 获取用于 EventProcessor 的角色列表
## 将 HexBattle 中的角色转换为 EventProcessor 兼容的字典格式
## @param game_state_provider: HexBattle 实例
## @return: 角色字典数组，用于 EventProcessor.process_post_event()
static func get_actors_for_event_processor(game_state_provider: HexBattle) -> Array[Dictionary]:
	if game_state_provider == null:
		return []
	
	var actors: Array[CharacterActor] = game_state_provider.get_alive_actors()
	var result: Array[Dictionary] = []
	
	for actor: CharacterActor in actors:
		result.append(actor.to_event_processor_dict())
	
	return result


## 检查角色是否已死亡
## @param actor_id: 角色 ID
## @param game_state_provider: HexBattle 实例
## @return: 角色是否已死亡，如果无法获取角色则返回 false
static func is_actor_dead(actor_id: String, game_state_provider: HexBattle) -> bool:
	if game_state_provider == null:
		return false
	var actor := game_state_provider.get_actor(actor_id)
	if actor != null:
		return actor.get_hp() <= 0
	return true
