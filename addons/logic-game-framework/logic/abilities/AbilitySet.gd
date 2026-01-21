extends RefCounted
class_name AbilitySet

const REVOKE_REASON_EXPIRED := "expired"
const REVOKE_REASON_DISPELLED := "dispelled"
const REVOKE_REASON_REPLACED := "replaced"
const REVOKE_REASON_MANUAL := "manual"

var owner: ActorRef
var _attributes = null
var _abilities: Array = []
var tag_container: TagContainer
var _on_granted_callbacks: Array = []
var _on_revoked_callbacks: Array = []

func _init(config: Dictionary):
	owner = config.get("owner")
	_attributes = config.get("attributes", null)
	tag_container = TagContainer.create(owner.id)

func get_event_processor() -> EventProcessor:
	return GameWorld.get_instance().event_processor

func add_loose_tag(tag: String, stacks: int = 1) -> void:
	tag_container.add_loose_tag(tag, stacks)

func remove_loose_tag(tag: String, stacks: int = -1) -> bool:
	return tag_container.remove_loose_tag(tag, stacks)

func add_auto_duration_tag(tag: String, duration: float) -> void:
	tag_container.add_auto_duration_tag(tag, duration)

func _add_component_tags(ability_id: String, tags: Dictionary) -> void:
	tag_container.add_component_tags(ability_id, tags)

func _remove_component_tags(ability_id: String) -> void:
	tag_container.remove_component_tags(ability_id)

func has_tag(tag: String) -> bool:
	return tag_container.has_tag(tag)

func get_tag_stacks(tag: String) -> int:
	return tag_container.get_tag_stacks(tag)

func get_all_tags() -> Dictionary:
	return tag_container.get_all_tags()

func get_logic_time() -> float:
	return tag_container.get_logic_time()

func has_loose_tag(tag: String) -> bool:
	return tag_container.has_loose_tag(tag)

func get_loose_tag_stacks(tag: String) -> int:
	return tag_container.get_loose_tag_stacks(tag)

func grant_ability(ability: Ability) -> void:
	for existing in _abilities:
		if existing.id == ability.id:
			Log.warning("AbilitySet", "Ability already granted: %s" % ability.id)
			return
	_abilities.append(ability)
	var context := _create_lifecycle_context(ability)
	ability.apply_effects(context)
	Log.debug("AbilitySet", "获得能力")
	_notify_granted(ability)

func revoke_ability(ability_id: String, reason: String = REVOKE_REASON_MANUAL, expire_reason: String = "") -> bool:
	var index := -1
	for i in range(_abilities.size()):
		if _abilities[i].id == ability_id:
			index = i
			break
	if index == -1:
		return false
	var ability: Ability = _abilities[index]
	if not ability.is_expired():
		var reason_value := expire_reason if expire_reason != "" else reason
		ability.expire(reason_value)
	_abilities.remove_at(index)
	var reason_text := expire_reason if expire_reason != "" else (ability.get_expire_reason() if ability.get_expire_reason() != "" else reason)
	Log.debug("AbilitySet", "失去能力 (%s)" % reason_text)
	_notify_revoked(ability, reason, expire_reason if expire_reason != "" else ability.get_expire_reason())
	return true

func revoke_abilities_by_config_id(config_id: String, reason: String = REVOKE_REASON_MANUAL) -> int:
	var to_revoke := []
	for ability in _abilities:
		if ability.config_id == config_id:
			to_revoke.append(ability)
	for ability in to_revoke:
		revoke_ability(ability.id, reason)
	return to_revoke.size()

func revoke_abilities_by_tag(tag: String, reason: String = REVOKE_REASON_MANUAL) -> int:
	var to_revoke := []
	for ability in _abilities:
		if ability.has_tag(tag):
			to_revoke.append(ability)
	for ability in to_revoke:
		revoke_ability(ability.id, reason)
	return to_revoke.size()

func tick(dt: float, logic_time: float = -1.0) -> void:
	tag_container.tick(dt, logic_time)
	_process_abilities(func(ability: Ability):
		ability.tick(dt)
	)

func tick_executions(dt: float) -> Array:
	var all_triggered := []
	_process_abilities(func(ability: Ability):
		var triggered := ability.tick_executions(dt)
		all_triggered.append_array(triggered)
	)
	return all_triggered

func receive_event(event: Dictionary, gameplay_state) -> void:
	_process_abilities(func(ability: Ability):
		var context := _create_lifecycle_context(ability)
		ability.receive_event(event, context, gameplay_state)
	)

func get_abilities() -> Array:
	return _abilities

func find_ability_by_id(ability_id: String) -> Ability:
	for ability in _abilities:
		if ability.id == ability_id:
			return ability
	return null

func find_ability_by_config_id(config_id: String) -> Ability:
	for ability in _abilities:
		if ability.config_id == config_id:
			return ability
	return null

func find_abilities_by_config_id(config_id: String) -> Array:
	var results := []
	for ability in _abilities:
		if ability.config_id == config_id:
			results.append(ability)
	return results

func find_abilities_by_tag(tag: String) -> Array:
	var results := []
	for ability in _abilities:
		if ability.has_tag(tag):
			results.append(ability)
	return results

func has_ability(config_id: String) -> bool:
	for ability in _abilities:
		if ability.config_id == config_id:
			return true
	return false

func get_ability_count() -> int:
	return _abilities.size()

func on_ability_granted(callback: Callable) -> Callable:
	_on_granted_callbacks.append(callback)
	return func() -> void:
		var index := _on_granted_callbacks.find(callback)
		if index != -1:
			_on_granted_callbacks.remove_at(index)

func on_ability_revoked(callback: Callable) -> Callable:
	_on_revoked_callbacks.append(callback)
	return func() -> void:
		var index := _on_revoked_callbacks.find(callback)
		if index != -1:
			_on_revoked_callbacks.remove_at(index)

func on_tag_changed(callback: Callable) -> Callable:
	return tag_container.on_tag_changed(callback)

func serialize() -> Dictionary:
	var abilities := []
	for ability in _abilities:
		abilities.append(ability.serialize())
	return {
		"owner": owner,
		"abilities": abilities,
	}

func _create_lifecycle_context(ability: Ability) -> Dictionary:
	return {
		"owner": owner,
		"attributes": _attributes,
		"ability": ability,
		"abilitySet": self,
		"eventProcessor": get_event_processor(),
	}

func _process_abilities(processor: Callable) -> void:
	var expired := []
	for ability in _abilities:
		if ability.is_expired():
			expired.append(ability)
			continue
		processor.call(ability)
		if ability.is_expired():
			expired.append(ability)
	for ability in expired:
		revoke_ability(ability.id, REVOKE_REASON_EXPIRED, ability.get_expire_reason())

func _notify_granted(ability: Ability) -> void:
	for callback in _on_granted_callbacks:
		if callback.is_valid():
			callback.call(ability, self)
		else:
			Log.error("AbilitySet", "Error in ability granted callback")

func _notify_revoked(ability: Ability, reason: String, expire_reason: String) -> void:
	for callback in _on_revoked_callbacks:
		if callback.is_valid():
			callback.call(ability, reason, self, expire_reason)
		else:
			Log.error("AbilitySet", "Error in ability revoked callback")

static func create(owner_value: ActorRef, attributes) -> AbilitySet:
	return AbilitySet.new({
		"owner": owner_value,
		"attributes": attributes,
	})

static func is_ability_set_provider(obj) -> bool:
	return obj != null and typeof(obj) == TYPE_OBJECT and obj.has_method("get_ability_set_for_actor")
