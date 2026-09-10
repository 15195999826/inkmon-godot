class_name InkMonBattleAbilitySet
extends AbilitySet


## 内建能力 (常驻 passive / 规则桥) 的 execution 不冻结 ATB —— 它们全程在跑,
## 当成阻塞会让单位永远轮不到行动。
func _is_blocking_execution(ability: Ability) -> bool:
	return not ability.has_ability_tag("intrinsic")


func is_on_cooldown(ability_config_id: String) -> bool:
	return has_tag(_get_cooldown_tag(ability_config_id))


func get_cooldown_remaining(ability_config_id: String) -> float:
	var tag := _get_cooldown_tag(ability_config_id)
	var remaining := 0.0
	var now := tag_container.get_logic_time()
	for entry in tag_container._auto_duration_tags:
		if str(entry.get("tag", "")) != tag:
			continue
		remaining = maxf(remaining, float(entry.get("expiresAt", now)) - now)
	return maxf(remaining, 0.0)


func start_cooldown(ability_config_id: String, duration: float) -> void:
	add_auto_duration_tag(_get_cooldown_tag(ability_config_id), duration)


func reset_cooldown(ability_config_id: String) -> void:
	var tag := _get_cooldown_tag(ability_config_id)
	var kept: Array[Dictionary] = []
	for entry in tag_container._auto_duration_tags:
		if str(entry.get("tag", "")) != tag:
			kept.append(entry)
	tag_container._auto_duration_tags = kept


func _get_cooldown_tag(ability_config_id: String) -> String:
	return "inkmon_cooldown:%s" % ability_config_id


static func create_battle_ability_set(
	p_owner_actor_id: String,
	p_attribute_set: BaseGeneratedAttributeSet = null
) -> InkMonBattleAbilitySet:
	return InkMonBattleAbilitySet.new(p_owner_actor_id, p_attribute_set)
