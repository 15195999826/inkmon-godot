class_name InkMonAIStrategy
extends RefCounted


func decide(actor: InkMonUnitActor, battle: InkMonWorldGI) -> InkMonAIDecision:
	var skill_decision := _try_primary_skill(actor, battle)
	if not skill_decision.is_skip():
		return skill_decision
	var basic_decision := _try_basic_attack(actor, battle)
	if not basic_decision.is_skip():
		return basic_decision
	return _try_move_toward_enemy(actor, battle)


func _try_primary_skill(actor: InkMonUnitActor, battle: InkMonWorldGI) -> InkMonAIDecision:
	var skill := actor.get_skill_ability()
	if skill == null:
		return InkMonAIDecision.skip()
	if actor.ability_set.is_on_cooldown(skill.config_id):
		return InkMonAIDecision.skip()
	var target := choose_skill_target(actor, skill, battle)
	if target == null:
		return InkMonAIDecision.skip()
	if not InkMonBattleTargeting.can_use_skill_on(actor, skill, target):
		return InkMonAIDecision.skip()
	return InkMonAIDecision.use_skill(skill.id, target.get_id())


func _try_basic_attack(actor: InkMonUnitActor, battle: InkMonWorldGI) -> InkMonAIDecision:
	var basic := actor.get_basic_attack_ability()
	if basic == null:
		return InkMonAIDecision.skip()
	var target := InkMonBattleTargeting.nearest_enemy(battle, actor.get_team_id(), actor.hex_position)
	if target == null or not InkMonBattleTargeting.can_use_skill_on(actor, basic, target):
		return InkMonAIDecision.skip()
	return InkMonAIDecision.use_skill(basic.id, target.get_id())


func _try_move_toward_enemy(actor: InkMonUnitActor, battle: InkMonWorldGI) -> InkMonAIDecision:
	var target := InkMonBattleTargeting.nearest_enemy(battle, actor.get_team_id(), actor.hex_position)
	if target == null:
		return InkMonAIDecision.skip()
	var coord := _best_step_toward(actor, target.hex_position, battle)
	if coord == null:
		return InkMonAIDecision.skip()
	var move := actor.get_move_ability()
	if move == null:
		return InkMonAIDecision.skip()
	return InkMonAIDecision.move_to(move.id, coord)


func choose_skill_target(actor: InkMonUnitActor, skill: Ability, battle: InkMonWorldGI) -> InkMonUnitActor:
	return _lowest_hp_enemy_in_range(actor, skill, battle)


func _lowest_hp_enemy_in_range(actor: InkMonUnitActor, skill: Ability, battle: InkMonWorldGI) -> InkMonUnitActor:
	var best: InkMonUnitActor = null
	var best_hp := INF
	for candidate in battle.get_alive_actors():
		if candidate.get_team_id() == actor.get_team_id():
			continue
		if not InkMonBattleTargeting.can_use_skill_on(actor, skill, candidate):
			continue
		if candidate.attribute_set.hp < best_hp:
			best_hp = candidate.attribute_set.hp
			best = candidate
	return best


func _best_step_toward(actor: InkMonUnitActor, target_pos: HexCoord, battle: InkMonWorldGI) -> HexCoord:
	var best: HexCoord = null
	var best_distance := actor.hex_position.distance_to(target_pos)
	for coord in battle.grid.get_neighbors(actor.hex_position):
		if not battle.grid.has_tile(coord):
			continue
		if not battle.grid.is_passable(coord):
			continue
		if battle.grid.is_reserved(coord):
			continue
		var distance := coord.distance_to(target_pos)
		if distance < best_distance:
			best_distance = distance
			best = coord
	return best
