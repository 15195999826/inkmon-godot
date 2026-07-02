class_name InkMonFrontlineStrategy
extends InkMonAIStrategy
## personality=frontline:打最近的可达敌人(前压/挡线)。


func choose_skill_target(actor: InkMonUnitActor, skill: Ability, battle: InkMonWorldGI) -> InkMonUnitActor:
	var nearest := InkMonBattleTargeting.nearest_enemy(battle, actor.get_team_id(), actor.hex_position)
	if nearest != null and InkMonBattleTargeting.can_use_skill_on(actor, skill, nearest):
		return nearest
	return null
