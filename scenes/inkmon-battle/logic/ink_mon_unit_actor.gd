class_name InkMonUnitActor
extends InkMonBattleActor


const ATB_FULL := 100.0


var unit_key: String
var species: String
var stage: String
var role: String
var elements: Array[String] = []
var attribute_set: InkMonUnitAttributeSet
var ai_strategy: InkMonAIStrategy

var _move_ability_id := ""
var _basic_attack_ability_id := ""
var _skill_ability_id := ""
var _team_id := -1
var _atb_gauge := 0.0
var _active_skill_config_id := ""


func _init(p_unit_key: String) -> void:
	unit_key = p_unit_key
	type = "InkMonUnit"
	var cfg := InkMonUnitConfig.get_unit_config(unit_key)
	_display_name = cfg.display_name
	species = cfg.species
	stage = cfg.stage
	role = cfg.role
	elements.assign(cfg.elements)
	_active_skill_config_id = cfg.active_skill_id

	attribute_set = InkMonUnitAttributeSet.new(get_id())
	var stats := cfg.stats
	attribute_set.set_max_hp_base(stats["max_hp"])
	attribute_set.set_hp_base(stats["hp"])
	attribute_set.set_ad_base(stats["ad"])
	attribute_set.set_ap_base(stats["ap"])
	attribute_set.set_armor_base(stats["armor"])
	attribute_set.set_mr_base(stats["mr"])
	attribute_set.set_speed_base(stats["speed"])
	ability_set = InkMonBattleAbilitySet.create_battle_ability_set(get_id(), attribute_set)
	ai_strategy = InkMonAIStrategyFactory.get_strategy(role)


func equip_abilities(game_state_provider: Variant = null) -> void:
	var move_ability := Ability.new(InkMonMove.ABILITY, get_id())
	ability_set.grant_ability(move_ability, game_state_provider)
	_move_ability_id = move_ability.id

	var basic_attack := Ability.new(InkMonBasicAttack.ABILITY, get_id())
	ability_set.grant_ability(basic_attack, game_state_provider)
	_basic_attack_ability_id = basic_attack.id

	var skill_config := InkMonAllSkills.get_skill_config(_active_skill_config_id)
	var skill_ability := Ability.new(skill_config, get_id())
	ability_set.grant_ability(skill_ability, game_state_provider)
	_skill_ability_id = skill_ability.id

	var math_passive := Ability.new(InkMonDamageMathPassive.ABILITY, get_id())
	ability_set.grant_ability(math_passive, game_state_provider)


func get_attribute_set() -> InkMonUnitAttributeSet:
	return attribute_set


func set_team_id(id: int) -> void:
	_team_id = id
	_team = str(id)


func get_team_id() -> int:
	return _team_id


func get_primary_element() -> String:
	if elements.is_empty():
		return ""
	return elements[0]


func get_move_ability() -> Ability:
	return ability_set.find_ability_by_id(_move_ability_id)


func get_basic_attack_ability() -> Ability:
	return ability_set.find_ability_by_id(_basic_attack_ability_id)


func get_skill_ability() -> Ability:
	return ability_set.find_ability_by_id(_skill_ability_id)


func get_atb_gauge() -> float:
	return _atb_gauge


func accumulate_atb(dt: float) -> void:
	_atb_gauge += (attribute_set.speed / 1000.0) * dt


func can_act() -> bool:
	if _atb_gauge < ATB_FULL:
		return false
	if ability_set != null and ability_set.has_tag(InkMonActionLockStatus.TAG_CANT_ACT):
		return false
	return true


func reset_atb() -> void:
	_atb_gauge = 0.0


func get_stats() -> Dictionary:
	return {
		"hp": attribute_set.hp,
		"max_hp": attribute_set.max_hp,
		"ad": attribute_set.ad,
		"ap": attribute_set.ap,
		"armor": attribute_set.armor,
		"mr": attribute_set.mr,
		"speed": attribute_set.speed,
	}


func _get_config_id() -> String:
	return unit_key


func _get_team_int() -> int:
	return _team_id


func get_attribute_snapshot() -> Dictionary:
	var snap := get_stats()
	snap["unit_key"] = unit_key
	snap["role"] = role
	snap["elements"] = elements.duplicate()
	return snap


func serialize() -> Dictionary:
	var base := super.serialize()
	base["unit_key"] = unit_key
	base["role"] = role
	base["atb_gauge"] = _atb_gauge
	return base
