class_name InkMonRoleHealerStrategy
extends InkMonAIStrategy


func choose_skill_target(actor: InkMonUnitActor, skill: Ability, battle: InkMonBattleWorldGI) -> InkMonUnitActor:
	if not skill.has_ability_tag("heal"):
		return _lowest_hp_enemy_in_range(actor, skill, battle)
	var best: InkMonUnitActor = null
	var best_ratio := 1.0
	for candidate in battle.get_alive_actors():
		if candidate.get_team_id() != actor.get_team_id():
			continue
		if not battle.can_use_skill_on(actor, skill, candidate):
			continue
		var ratio := candidate.attribute_set.hp / candidate.attribute_set.max_hp
		if ratio < best_ratio:
			best_ratio = ratio
			best = candidate
	return best if best_ratio <= 0.72 else null
