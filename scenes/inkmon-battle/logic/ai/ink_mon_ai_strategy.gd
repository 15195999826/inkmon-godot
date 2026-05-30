class_name InkMonAIStrategy
extends RefCounted


func decide(actor: InkMonUnitActor, battle: InkMonBattleWorldGI) -> Dictionary:
	var skill_decision := _try_primary_skill(actor, battle)
	if skill_decision["type"] != "skip":
		return skill_decision
	var basic_decision := _try_basic_attack(actor, battle)
	if basic_decision["type"] != "skip":
		return basic_decision
	return _try_move_toward_enemy(actor, battle)


func _try_primary_skill(actor: InkMonUnitActor, battle: InkMonBattleWorldGI) -> Dictionary:
	var skill := actor.get_skill_ability()
	if skill == null:
		return _skip()
	if actor.ability_set.is_on_cooldown(skill.config_id):
		return _skip()
	var target := choose_skill_target(actor, skill, battle)
	if target == null:
		return _skip()
	if not battle.can_use_skill_on(actor, skill, target):
		return _skip()
	return _use_skill(skill, target.get_id())


func _try_basic_attack(actor: InkMonUnitActor, battle: InkMonBattleWorldGI) -> Dictionary:
	var basic := actor.get_basic_attack_ability()
	if basic == null:
		return _skip()
	var target := _nearest_enemy(actor, battle)
	if target == null or not battle.can_use_skill_on(actor, basic, target):
		return _skip()
	return _use_skill(basic, target.get_id())


func _try_move_toward_enemy(actor: InkMonUnitActor, battle: InkMonBattleWorldGI) -> Dictionary:
	var target := _nearest_enemy(actor, battle)
	if target == null:
		return _skip()
	var coord := _best_step_toward(actor, target.hex_position, battle)
	if coord == null:
		return _skip()
	var move := actor.get_move_ability()
	if move == null:
		return _skip()
	return {
		"type": "move",
		"ability_instance_id": move.id,
		"target_coord": coord,
	}


func choose_skill_target(actor: InkMonUnitActor, skill: Ability, battle: InkMonBattleWorldGI) -> InkMonUnitActor:
	return _lowest_hp_enemy_in_range(actor, skill, battle)


func _lowest_hp_enemy_in_range(actor: InkMonUnitActor, skill: Ability, battle: InkMonBattleWorldGI) -> InkMonUnitActor:
	var best: InkMonUnitActor = null
	var best_hp := INF
	for candidate in battle.get_alive_actors():
		if candidate.get_team_id() == actor.get_team_id():
			continue
		if not battle.can_use_skill_on(actor, skill, candidate):
			continue
		if candidate.attribute_set.hp < best_hp:
			best_hp = candidate.attribute_set.hp
			best = candidate
	return best


func _nearest_enemy(actor: InkMonUnitActor, battle: InkMonBattleWorldGI) -> InkMonUnitActor:
	var best: InkMonUnitActor = null
	var best_distance := 1 << 30
	for candidate in battle.get_alive_actors():
		if candidate.get_team_id() == actor.get_team_id():
			continue
		var distance := actor.hex_position.distance_to(candidate.hex_position)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best


func _best_step_toward(actor: InkMonUnitActor, target_pos: HexCoord, battle: InkMonBattleWorldGI) -> HexCoord:
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


func _use_skill(skill: Ability, target_actor_id: String) -> Dictionary:
	return {
		"type": "skill",
		"ability_instance_id": skill.id,
		"target_actor_id": target_actor_id,
	}


func _skip() -> Dictionary:
	return { "type": "skip" }
