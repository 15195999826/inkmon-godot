class_name InkMonFrontlineStrategy
extends InkMonAIStrategy
## personality=frontline(原 tank 行为):打最近的可达敌人(前压/挡线)。


func choose_skill_target(actor: InkMonUnitActor, skill: Ability, battle: InkMonWorldGI) -> InkMonUnitActor:
	var nearest := _nearest_enemy(actor, battle)
	if nearest != null and battle.can_use_skill_on(actor, skill, nearest):
		return nearest
	return null
