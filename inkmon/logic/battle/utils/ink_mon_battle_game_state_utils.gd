class_name InkMonBattleGameStateUtils


static func get_actor_display_name(actor_id: String, battle: InkMonWorldGI) -> String:
	if actor_id.is_empty():
		return "???"
	if battle != null:
		var actor := battle.get_actor(actor_id)
		if actor != null:
			return actor.get_display_name()
	return actor_id
