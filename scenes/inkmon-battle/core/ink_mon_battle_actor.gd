class_name InkMonBattleActor
extends Actor


var ability_set: InkMonBattleAbilitySet
var hex_position: HexCoord = HexCoord.invalid()
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


func is_pre_event_responsive() -> bool:
	return not _is_dead


func get_ability_set() -> InkMonBattleAbilitySet:
	return ability_set


func _get_position() -> Vector3:
	if not hex_position.is_valid():
		return Vector3.ZERO
	return Vector3(hex_position.q, hex_position.r, 0.0)


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
