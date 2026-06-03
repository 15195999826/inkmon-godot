class_name InkMonBattleGameStateUtils


static func get_actor_display_name(actor_id: String, game_state_provider: InkMonWorldGI) -> String:
	if actor_id.is_empty():
		return "???"
	if game_state_provider != null:
		var actor := game_state_provider.get_actor(actor_id)
		if actor != null:
			return actor.get_display_name()
	return actor_id


static func is_actor_dead(actor_id: String, game_state_provider: InkMonWorldGI) -> bool:
	if game_state_provider == null:
		return false
	# is_dead() 是战斗态查询 → 走 get_battle_actor (非战斗 actor 返回 null 视作不在战斗)。
	var actor := game_state_provider.get_battle_actor(actor_id)
	if actor != null:
		return actor.is_dead()
	return true
