class_name InkMonAggressiveStrategy
extends InkMonAIStrategy
## personality=aggressive:集火血量最低的可达敌人(锁杀)。也是 default 行为。


func choose_skill_target(actor: InkMonUnitActor, skill: Ability, battle: InkMonWorldGI) -> InkMonUnitActor:
	return _lowest_hp_enemy_in_range(actor, skill, battle)
