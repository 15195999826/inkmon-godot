class_name InkMonRoleDpsStrategy
extends InkMonAIStrategy


func choose_skill_target(actor: InkMonUnitActor, skill: Ability, battle: InkMonWorldGI) -> InkMonUnitActor:
	return _lowest_hp_enemy_in_range(actor, skill, battle)
