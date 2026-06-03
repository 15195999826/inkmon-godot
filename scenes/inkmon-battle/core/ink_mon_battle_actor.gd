class_name InkMonBattleActor
extends InkMonWorldActor


var ability_set: InkMonBattleAbilitySet
var _is_dead := false


func get_attribute_set() -> InkMonUnitAttributeSet:
	push_error("InkMonBattleActor.get_attribute_set must be overridden by subclass: %s" % type)
	return null


func _on_id_assigned() -> void:
	ability_set.owner_actor_id = get_id()
	get_attribute_set().actor_id = get_id()


func check_death() -> bool:
	if get_attribute_set().hp <= 0.0 and not _is_dead:
		_is_dead = true
		return true
	return false


func is_dead() -> bool:
	return _is_dead


## 按当前 HP 重建 downed 真相 (adr/0001: 死单位留 registry/HP=0 须跨存档 + 跨战斗保留)。
## 读档 (set_current_hp) / 战斗复用 (reset_battle_runtime) 时调 —— 否则 from_dict 新建的 actor
## _is_dead 默认 false, 一只 0-HP 单位会被 is_dead() 误判为"活着" (与 carryover HP 不一致, 违 P017)。
## 战斗内死亡仍走 check_death 的一次性闩 (触发死亡事件); 本方法只在 battle 外按 HP 对齐标记。
func sync_downed_state() -> void:
	_is_dead = get_attribute_set().hp <= 0.0


func is_pre_event_responsive() -> bool:
	return not _is_dead


func get_ability_set() -> InkMonBattleAbilitySet:
	return ability_set


func get_attribute_snapshot() -> Dictionary:
	var attrs := get_attribute_set()
	return {
		"hp": attrs.hp,
		"max_hp": attrs.max_hp,
		"ad": attrs.ad,
		"ap": attrs.ap,
		"armor": attrs.armor,
		"mr": attrs.mr,
		"speed": attrs.speed,
	}


func get_ability_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for ability in ability_set.get_abilities():
		result.append({
			"instance_id": ability.id,
			"config_id": ability.config_id,
		})
	return result


func get_tag_snapshot() -> Dictionary:
	return ability_set.get_all_tags()


func setup_recording(ctx: RecordingContext) -> Array[Callable]:
	var unsubscribes: Array[Callable] = []
	unsubscribes.append_array(RecordingUtils.record_attribute_changes(get_attribute_set(), ctx))
	unsubscribes.append_array(RecordingUtils.record_ability_set_changes(ability_set, ctx))
	unsubscribes.append_array(RecordingUtils.record_actor_lifecycle(self, ctx))
	return unsubscribes


func serialize() -> Dictionary:
	var base := serialize_base()
	base["hex_position"] = hex_position.to_dict() if hex_position.is_valid() else {}
	base["attribute_set"] = get_attribute_set()._raw.serialize()
	return base
