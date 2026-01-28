extends RefCounted
class_name GameEvent

const ABILITY_ACTIVATE_EVENT := "abilityActivate"
const ACTOR_SPAWNED_EVENT := "actorSpawned"
const ACTOR_DESTROYED_EVENT := "actorDestroyed"
const ATTRIBUTE_CHANGED_EVENT := "attributeChanged"
const ABILITY_GRANTED_EVENT := "abilityGranted"
const ABILITY_REMOVED_EVENT := "abilityRemoved"
const ABILITY_ACTIVATED_EVENT := "abilityActivated"
const ABILITY_TRIGGERED_EVENT := "abilityTriggered"
const EXECUTION_ACTIVATED_EVENT := "executionActivated"
const TAG_CHANGED_EVENT := "tagChanged"
const STAGE_CUE_EVENT := "stageCue"


# ========== 事件基类 ==========

class Base:
	var kind: String = ""
	
	func to_dict() -> Dictionary:
		return { "kind": kind }
	
	static func is_match(_d: Dictionary) -> bool:
		return false  # 子类覆盖


# ========== 强类型事件类 ==========

class ActorSpawned extends Base:
	var actor_id: String = ""
	var actor_data: Dictionary = {}
	
	func _init() -> void:
		kind = ACTOR_SPAWNED_EVENT
	
	static func create(p_actor_id: String, p_actor_data: Dictionary) -> ActorSpawned:
		var e := ActorSpawned.new()
		e.actor_id = p_actor_id
		e.actor_data = p_actor_data
		return e
	
	func to_dict() -> Dictionary:
		return { "kind": kind, "actorId": actor_id, "actor": actor_data }
	
	static func from_dict(d: Dictionary) -> ActorSpawned:
		var e := ActorSpawned.new()
		e.actor_id = d.get("actorId", "")
		e.actor_data = d.get("actor", {})
		return e
	
	static func is_match(d: Dictionary) -> bool:
		return d.get("kind") == ACTOR_SPAWNED_EVENT


class ActorDestroyed extends Base:
	var actor_id: String = ""
	var reason: String = ""
	
	func _init() -> void:
		kind = ACTOR_DESTROYED_EVENT
	
	static func create(p_actor_id: String, p_reason: String = "") -> ActorDestroyed:
		var e := ActorDestroyed.new()
		e.actor_id = p_actor_id
		e.reason = p_reason
		return e
	
	func to_dict() -> Dictionary:
		var d := { "kind": kind, "actorId": actor_id }
		if reason != "":
			d["reason"] = reason
		return d
	
	static func from_dict(d: Dictionary) -> ActorDestroyed:
		var e := ActorDestroyed.new()
		e.actor_id = d.get("actorId", "")
		e.reason = d.get("reason", "")
		return e
	
	static func is_match(d: Dictionary) -> bool:
		return d.get("kind") == ACTOR_DESTROYED_EVENT


class AttributeChanged extends Base:
	var actor_id: String = ""
	var attribute: String = ""
	var old_value: float = 0.0
	var new_value: float = 0.0
	var source: Dictionary = {}
	
	func _init() -> void:
		kind = ATTRIBUTE_CHANGED_EVENT
	
	static func create(p_actor_id: String, p_attribute: String, p_old_value: float, p_new_value: float, p_source: Dictionary = {}) -> AttributeChanged:
		var e := AttributeChanged.new()
		e.actor_id = p_actor_id
		e.attribute = p_attribute
		e.old_value = p_old_value
		e.new_value = p_new_value
		e.source = p_source
		return e
	
	func to_dict() -> Dictionary:
		var d := { "kind": kind, "actorId": actor_id, "attribute": attribute, "oldValue": old_value, "newValue": new_value }
		if not source.is_empty():
			d["source"] = source
		return d
	
	static func from_dict(d: Dictionary) -> AttributeChanged:
		var e := AttributeChanged.new()
		e.actor_id = d.get("actorId", "")
		e.attribute = d.get("attribute", "")
		e.old_value = d.get("oldValue", 0.0)
		e.new_value = d.get("newValue", 0.0)
		e.source = d.get("source", {})
		return e
	
	static func is_match(d: Dictionary) -> bool:
		return d.get("kind") == ATTRIBUTE_CHANGED_EVENT


class AbilityGranted extends Base:
	var actor_id: String = ""
	var ability: Dictionary = {}
	
	func _init() -> void:
		kind = ABILITY_GRANTED_EVENT
	
	static func create(p_actor_id: String, p_ability: Dictionary) -> AbilityGranted:
		var e := AbilityGranted.new()
		e.actor_id = p_actor_id
		e.ability = p_ability
		return e
	
	func to_dict() -> Dictionary:
		return { "kind": kind, "actorId": actor_id, "ability": ability }
	
	static func from_dict(d: Dictionary) -> AbilityGranted:
		var e := AbilityGranted.new()
		e.actor_id = d.get("actorId", "")
		e.ability = d.get("ability", {})
		return e
	
	static func is_match(d: Dictionary) -> bool:
		return d.get("kind") == ABILITY_GRANTED_EVENT


class AbilityRemoved extends Base:
	var actor_id: String = ""
	var ability_instance_id: String = ""
	
	func _init() -> void:
		kind = ABILITY_REMOVED_EVENT
	
	static func create(p_actor_id: String, p_ability_instance_id: String) -> AbilityRemoved:
		var e := AbilityRemoved.new()
		e.actor_id = p_actor_id
		e.ability_instance_id = p_ability_instance_id
		return e
	
	func to_dict() -> Dictionary:
		return { "kind": kind, "actorId": actor_id, "abilityInstanceId": ability_instance_id }
	
	static func from_dict(d: Dictionary) -> AbilityRemoved:
		var e := AbilityRemoved.new()
		e.actor_id = d.get("actorId", "")
		e.ability_instance_id = d.get("abilityInstanceId", "")
		return e
	
	static func is_match(d: Dictionary) -> bool:
		return d.get("kind") == ABILITY_REMOVED_EVENT


class AbilityActivated extends Base:
	var actor_id: String = ""
	var ability_instance_id: String = ""
	var ability_config_id: String = ""
	var target: Dictionary = {}
	
	func _init() -> void:
		kind = ABILITY_ACTIVATED_EVENT
	
	static func create(p_actor_id: String, p_ability_instance_id: String, p_ability_config_id: String, p_target: Dictionary = {}) -> AbilityActivated:
		var e := AbilityActivated.new()
		e.actor_id = p_actor_id
		e.ability_instance_id = p_ability_instance_id
		e.ability_config_id = p_ability_config_id
		e.target = p_target
		return e
	
	func to_dict() -> Dictionary:
		var d := { "kind": kind, "actorId": actor_id, "abilityInstanceId": ability_instance_id, "abilityConfigId": ability_config_id }
		if not target.is_empty():
			d["target"] = target
		return d
	
	static func from_dict(d: Dictionary) -> AbilityActivated:
		var e := AbilityActivated.new()
		e.actor_id = d.get("actorId", "")
		e.ability_instance_id = d.get("abilityInstanceId", "")
		e.ability_config_id = d.get("abilityConfigId", "")
		e.target = d.get("target", {})
		return e
	
	static func is_match(d: Dictionary) -> bool:
		return d.get("kind") == ABILITY_ACTIVATED_EVENT


class AbilityTriggered extends Base:
	var actor_id: String = ""
	var ability_instance_id: String = ""
	var ability_config_id: String = ""
	var trigger_event_kind: String = ""
	var triggered_components: Array = []
	
	func _init() -> void:
		kind = ABILITY_TRIGGERED_EVENT
	
	static func create(p_actor_id: String, p_ability_instance_id: String, p_ability_config_id: String, p_trigger_event_kind: String, p_triggered_components: Array) -> AbilityTriggered:
		var e := AbilityTriggered.new()
		e.actor_id = p_actor_id
		e.ability_instance_id = p_ability_instance_id
		e.ability_config_id = p_ability_config_id
		e.trigger_event_kind = p_trigger_event_kind
		e.triggered_components = p_triggered_components.duplicate()
		return e
	
	func to_dict() -> Dictionary:
		return {
			"kind": kind,
			"actorId": actor_id,
			"abilityInstanceId": ability_instance_id,
			"abilityConfigId": ability_config_id,
			"triggerEventKind": trigger_event_kind,
			"triggeredComponents": triggered_components.duplicate(),
		}
	
	static func from_dict(d: Dictionary) -> AbilityTriggered:
		var e := AbilityTriggered.new()
		e.actor_id = d.get("actorId", "")
		e.ability_instance_id = d.get("abilityInstanceId", "")
		e.ability_config_id = d.get("abilityConfigId", "")
		e.trigger_event_kind = d.get("triggerEventKind", "")
		e.triggered_components = d.get("triggeredComponents", []).duplicate()
		return e
	
	static func is_match(d: Dictionary) -> bool:
		return d.get("kind") == ABILITY_TRIGGERED_EVENT


class ExecutionActivated extends Base:
	var actor_id: String = ""
	var ability_instance_id: String = ""
	var ability_config_id: String = ""
	var execution_id: String = ""
	var timeline_id: String = ""
	
	func _init() -> void:
		kind = EXECUTION_ACTIVATED_EVENT
	
	static func create(p_actor_id: String, p_ability_instance_id: String, p_ability_config_id: String, p_execution_id: String, p_timeline_id: String) -> ExecutionActivated:
		var e := ExecutionActivated.new()
		e.actor_id = p_actor_id
		e.ability_instance_id = p_ability_instance_id
		e.ability_config_id = p_ability_config_id
		e.execution_id = p_execution_id
		e.timeline_id = p_timeline_id
		return e
	
	func to_dict() -> Dictionary:
		return {
			"kind": kind,
			"actorId": actor_id,
			"abilityInstanceId": ability_instance_id,
			"abilityConfigId": ability_config_id,
			"executionId": execution_id,
			"timelineId": timeline_id,
		}
	
	static func from_dict(d: Dictionary) -> ExecutionActivated:
		var e := ExecutionActivated.new()
		e.actor_id = d.get("actorId", "")
		e.ability_instance_id = d.get("abilityInstanceId", "")
		e.ability_config_id = d.get("abilityConfigId", "")
		e.execution_id = d.get("executionId", "")
		e.timeline_id = d.get("timelineId", "")
		return e
	
	static func is_match(d: Dictionary) -> bool:
		return d.get("kind") == EXECUTION_ACTIVATED_EVENT


class TagChanged extends Base:
	var actor_id: String = ""
	var tag: String = ""
	var old_count: int = 0
	var new_count: int = 0
	
	func _init() -> void:
		kind = TAG_CHANGED_EVENT
	
	static func create(p_actor_id: String, p_tag: String, p_old_count: int, p_new_count: int) -> TagChanged:
		var e := TagChanged.new()
		e.actor_id = p_actor_id
		e.tag = p_tag
		e.old_count = p_old_count
		e.new_count = p_new_count
		return e
	
	func to_dict() -> Dictionary:
		return { "kind": kind, "actorId": actor_id, "tag": tag, "oldCount": old_count, "newCount": new_count }
	
	static func from_dict(d: Dictionary) -> TagChanged:
		var e := TagChanged.new()
		e.actor_id = d.get("actorId", "")
		e.tag = d.get("tag", "")
		e.old_count = d.get("oldCount", 0)
		e.new_count = d.get("newCount", 0)
		return e
	
	static func is_match(d: Dictionary) -> bool:
		return d.get("kind") == TAG_CHANGED_EVENT


class StageCue extends Base:
	var source_actor_id: String = ""
	var target_actor_ids: Array = []
	var cue_id: String = ""
	var params: Dictionary = {}
	
	func _init() -> void:
		kind = STAGE_CUE_EVENT
	
	static func create(p_source_actor_id: String, p_target_actor_ids: Array, p_cue_id: String, p_params: Dictionary = {}) -> StageCue:
		var e := StageCue.new()
		e.source_actor_id = p_source_actor_id
		e.target_actor_ids = p_target_actor_ids.duplicate()
		e.cue_id = p_cue_id
		e.params = p_params
		return e
	
	func to_dict() -> Dictionary:
		var d := { "kind": kind, "sourceActorId": source_actor_id, "targetActorIds": target_actor_ids.duplicate(), "cueId": cue_id }
		if not params.is_empty():
			d["params"] = params
		return d
	
	static func from_dict(d: Dictionary) -> StageCue:
		var e := StageCue.new()
		e.source_actor_id = d.get("sourceActorId", "")
		e.target_actor_ids = d.get("targetActorIds", []).duplicate()
		e.cue_id = d.get("cueId", "")
		e.params = d.get("params", {})
		return e
	
	static func is_match(d: Dictionary) -> bool:
		return d.get("kind") == STAGE_CUE_EVENT


class AbilityActivate extends Base:
	var ability_instance_id: String = ""
	var source_id: String = ""
	
	func _init() -> void:
		kind = ABILITY_ACTIVATE_EVENT
	
	static func create(p_ability_instance_id: String, p_source_id: String) -> AbilityActivate:
		var e := AbilityActivate.new()
		e.ability_instance_id = p_ability_instance_id
		e.source_id = p_source_id
		return e
	
	func to_dict() -> Dictionary:
		return { "kind": kind, "abilityInstanceId": ability_instance_id, "sourceId": source_id }
	
	static func from_dict(d: Dictionary) -> AbilityActivate:
		var e := AbilityActivate.new()
		e.ability_instance_id = d.get("abilityInstanceId", "")
		e.source_id = d.get("sourceId", "")
		return e
	
	static func is_match(d: Dictionary) -> bool:
		return d.get("kind") == ABILITY_ACTIVATE_EVENT


# ========== 旧工厂函数（标记 deprecated，保持兼容） ==========

## @deprecated Use AbilityActivate.create() instead
static func create_ability_activate_event(ability_instance_id: String, source_id: String) -> Dictionary:
	return {
		"kind": ABILITY_ACTIVATE_EVENT,
		"abilityInstanceId": ability_instance_id,
		"sourceId": source_id,
	}

## @deprecated Use AbilityActivate.is_match() instead
static func is_ability_activate_event(event: Dictionary) -> bool:
	return event.get("kind", "") == ABILITY_ACTIVATE_EVENT \
		and event.has("abilityInstanceId") \
		and event.has("sourceId")

## @deprecated Use ActorSpawned.create() instead
static func create_actor_spawned_event(actor) -> Dictionary:
	return {
		"kind": ACTOR_SPAWNED_EVENT,
		"actor": actor,
	}

## @deprecated Use ActorDestroyed.create() instead
static func create_actor_destroyed_event(actor_id: String, reason: String = "") -> Dictionary:
	var payload := {
		"kind": ACTOR_DESTROYED_EVENT,
		"actorId": actor_id,
	}
	if reason != "":
		payload["reason"] = reason
	return payload

## @deprecated Use AttributeChanged.create() instead
static func create_attribute_changed_event(actor_id: String, attribute: String, old_value: float, new_value: float, source: Dictionary = {}) -> Dictionary:
	var payload := {
		"kind": ATTRIBUTE_CHANGED_EVENT,
		"actorId": actor_id,
		"attribute": attribute,
		"oldValue": old_value,
		"newValue": new_value,
	}
	if not source.is_empty():
		payload["source"] = source
	return payload

## @deprecated Use AbilityGranted.create() instead
static func create_ability_granted_event(actor_id: String, ability: Dictionary) -> Dictionary:
	return {
		"kind": ABILITY_GRANTED_EVENT,
		"actorId": actor_id,
		"ability": ability,
	}

## @deprecated Use AbilityRemoved.create() instead
static func create_ability_removed_event(actor_id: String, ability_instance_id: String) -> Dictionary:
	return {
		"kind": ABILITY_REMOVED_EVENT,
		"actorId": actor_id,
		"abilityInstanceId": ability_instance_id,
	}

## @deprecated Use AbilityActivated.create() instead
static func create_ability_activated_event(actor_id: String, ability_instance_id: String, ability_config_id: String, target: Dictionary = {}) -> Dictionary:
	var payload := {
		"kind": ABILITY_ACTIVATED_EVENT,
		"actorId": actor_id,
		"abilityInstanceId": ability_instance_id,
		"abilityConfigId": ability_config_id,
	}
	if not target.is_empty():
		payload["target"] = target
	return payload

## @deprecated Use TagChanged.create() instead
static func create_tag_changed_event(actor_id: String, tag: String, old_count: int, new_count: int) -> Dictionary:
	return {
		"kind": TAG_CHANGED_EVENT,
		"actorId": actor_id,
		"tag": tag,
		"oldCount": old_count,
		"newCount": new_count,
	}

## @deprecated Use AbilityTriggered.create() instead
static func create_ability_triggered_event(actor_id: String, ability_instance_id: String, ability_config_id: String, trigger_event_kind: String, triggered_components: Array) -> Dictionary:
	return {
		"kind": ABILITY_TRIGGERED_EVENT,
		"actorId": actor_id,
		"abilityInstanceId": ability_instance_id,
		"abilityConfigId": ability_config_id,
		"triggerEventKind": trigger_event_kind,
		"triggeredComponents": triggered_components.duplicate(),
	}

## @deprecated Use ExecutionActivated.create() instead
static func create_execution_activated_event(actor_id: String, ability_instance_id: String, ability_config_id: String, execution_id: String, timeline_id: String) -> Dictionary:
	return {
		"kind": EXECUTION_ACTIVATED_EVENT,
		"actorId": actor_id,
		"abilityInstanceId": ability_instance_id,
		"abilityConfigId": ability_config_id,
		"executionId": execution_id,
		"timelineId": timeline_id,
	}

## @deprecated Use StageCue.create() instead
static func create_stage_cue_event(source_actor_id: String, target_actor_ids: Array, cue_id: String, params: Dictionary = {}) -> Dictionary:
	var payload := {
		"kind": STAGE_CUE_EVENT,
		"sourceActorId": source_actor_id,
		"targetActorIds": target_actor_ids.duplicate(),
		"cueId": cue_id,
	}
	if not params.is_empty():
		payload["params"] = params
	return payload

## @deprecated Use ActorSpawned.is_match() instead
static func is_actor_spawned_event(event: Dictionary) -> bool:
	return event.get("kind", "") == ACTOR_SPAWNED_EVENT

## @deprecated Use ActorDestroyed.is_match() instead
static func is_actor_destroyed_event(event: Dictionary) -> bool:
	return event.get("kind", "") == ACTOR_DESTROYED_EVENT

## @deprecated Use AttributeChanged.is_match() instead
static func is_attribute_changed_event(event: Dictionary) -> bool:
	return event.get("kind", "") == ATTRIBUTE_CHANGED_EVENT

## @deprecated Use AbilityGranted.is_match() instead
static func is_ability_granted_event(event: Dictionary) -> bool:
	return event.get("kind", "") == ABILITY_GRANTED_EVENT

## @deprecated Use AbilityRemoved.is_match() instead
static func is_ability_removed_event(event: Dictionary) -> bool:
	return event.get("kind", "") == ABILITY_REMOVED_EVENT

## @deprecated Use AbilityActivated.is_match() instead
static func is_ability_activated_event(event: Dictionary) -> bool:
	return event.get("kind", "") == ABILITY_ACTIVATED_EVENT

## @deprecated Use TagChanged.is_match() instead
static func is_tag_changed_event(event: Dictionary) -> bool:
	return event.get("kind", "") == TAG_CHANGED_EVENT

## @deprecated Use AbilityTriggered.is_match() instead
static func is_ability_triggered_event(event: Dictionary) -> bool:
	return event.get("kind", "") == ABILITY_TRIGGERED_EVENT

## @deprecated Use ExecutionActivated.is_match() instead
static func is_execution_activated_event(event: Dictionary) -> bool:
	return event.get("kind", "") == EXECUTION_ACTIVATED_EVENT

## @deprecated Use StageCue.is_match() instead
static func is_stage_cue_event(event: Dictionary) -> bool:
	return event.get("kind", "") == STAGE_CUE_EVENT
