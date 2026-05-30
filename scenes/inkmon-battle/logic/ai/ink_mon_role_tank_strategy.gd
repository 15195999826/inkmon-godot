class_name InkMonRoleTankStrategy
extends InkMonAIStrategy


func choose_skill_target(actor: InkMonUnitActor, skill: Ability, battle: InkMonBattleWorldGI) -> InkMonUnitActor:
	var nearest := _nearest_enemy(actor, battle)
	if nearest != null and battle.can_use_skill_on(actor, skill, nearest):
		return nearest
	return null
