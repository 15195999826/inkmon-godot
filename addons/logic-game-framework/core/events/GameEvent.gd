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

static func create_ability_activate_event(ability_instance_id: String, source_id: String) -> Dictionary:
	return {
		"kind": ABILITY_ACTIVATE_EVENT,
		"abilityInstanceId": ability_instance_id,
		"sourceId": source_id,
	}

static func is_ability_activate_event(event: Dictionary) -> bool:
	return event.get("kind", "") == ABILITY_ACTIVATE_EVENT \
		and event.has("abilityInstanceId") \
		and event.has("sourceId")

static func create_actor_spawned_event(actor) -> Dictionary:
	return {
		"kind": ACTOR_SPAWNED_EVENT,
		"actor": actor,
	}

static func create_actor_destroyed_event(actor_id: String, reason: String = "") -> Dictionary:
	var payload := {
		"kind": ACTOR_DESTROYED_EVENT,
		"actorId": actor_id,
	}
	if reason != "":
		payload["reason"] = reason
	return payload

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

static func create_ability_granted_event(actor_id: String, ability: Dictionary) -> Dictionary:
	return {
		"kind": ABILITY_GRANTED_EVENT,
		"actorId": actor_id,
		"ability": ability,
	}

static func create_ability_removed_event(actor_id: String, ability_instance_id: String) -> Dictionary:
	return {
		"kind": ABILITY_REMOVED_EVENT,
		"actorId": actor_id,
		"abilityInstanceId": ability_instance_id,
	}

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

static func create_tag_changed_event(actor_id: String, tag: String, old_count: int, new_count: int) -> Dictionary:
	return {
		"kind": TAG_CHANGED_EVENT,
		"actorId": actor_id,
		"tag": tag,
		"oldCount": old_count,
		"newCount": new_count,
	}

static func create_ability_triggered_event(actor_id: String, ability_instance_id: String, ability_config_id: String, trigger_event_kind: String, triggered_components: Array) -> Dictionary:
	return {
		"kind": ABILITY_TRIGGERED_EVENT,
		"actorId": actor_id,
		"abilityInstanceId": ability_instance_id,
		"abilityConfigId": ability_config_id,
		"triggerEventKind": trigger_event_kind,
		"triggeredComponents": triggered_components.duplicate(),
	}

static func create_execution_activated_event(actor_id: String, ability_instance_id: String, ability_config_id: String, execution_id: String, timeline_id: String) -> Dictionary:
	return {
		"kind": EXECUTION_ACTIVATED_EVENT,
		"actorId": actor_id,
		"abilityInstanceId": ability_instance_id,
		"abilityConfigId": ability_config_id,
		"executionId": execution_id,
		"timelineId": timeline_id,
	}

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

static func is_actor_spawned_event(event: Dictionary) -> bool:
	return event.get("kind", "") == ACTOR_SPAWNED_EVENT

static func is_actor_destroyed_event(event: Dictionary) -> bool:
	return event.get("kind", "") == ACTOR_DESTROYED_EVENT

static func is_attribute_changed_event(event: Dictionary) -> bool:
	return event.get("kind", "") == ATTRIBUTE_CHANGED_EVENT

static func is_ability_granted_event(event: Dictionary) -> bool:
	return event.get("kind", "") == ABILITY_GRANTED_EVENT

static func is_ability_removed_event(event: Dictionary) -> bool:
	return event.get("kind", "") == ABILITY_REMOVED_EVENT

static func is_ability_activated_event(event: Dictionary) -> bool:
	return event.get("kind", "") == ABILITY_ACTIVATED_EVENT

static func is_tag_changed_event(event: Dictionary) -> bool:
	return event.get("kind", "") == TAG_CHANGED_EVENT

static func is_ability_triggered_event(event: Dictionary) -> bool:
	return event.get("kind", "") == ABILITY_TRIGGERED_EVENT

static func is_execution_activated_event(event: Dictionary) -> bool:
	return event.get("kind", "") == EXECUTION_ACTIVATED_EVENT

static func is_stage_cue_event(event: Dictionary) -> bool:
	return event.get("kind", "") == STAGE_CUE_EVENT
