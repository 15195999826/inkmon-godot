extends AbilityComponent
class_name ActivateInstanceComponent

const TYPE := "ActivateInstanceComponent"

var _triggers: Array = []
var _trigger_mode: String = "any"
var _timeline_id: String = ""
var _tag_actions: Dictionary = {}

func _init(config: ActivateInstanceConfig):
	type = TYPE
	_timeline_id = config.timeline_id
	_tag_actions = config.tag_actions
	_trigger_mode = config.trigger_mode
	# 转换 TriggerConfig 为内部格式
	for trigger in config.triggers:
		if trigger is TriggerConfig:
			var trigger_dict := { "eventKind": trigger.event_kind }
			if trigger.filter.is_valid():
				trigger_dict["filter"] = trigger.filter
			_triggers.append(trigger_dict)
		else:
			_triggers.append(trigger)

func on_event(event: Dictionary, context: Dictionary, gameplay_state) -> bool:
	if _check_triggers(event, context):
		_activate_execution(event, context, gameplay_state)
		return true
	return false

func _check_triggers(event: Dictionary, context: Dictionary) -> bool:
	if _triggers.is_empty():
		return false
	if _trigger_mode == "any":
		for trigger in _triggers:
			if _match_trigger(trigger, event, context):
				return true
		return false
	for trigger in _triggers:
		if not _match_trigger(trigger, event, context):
			return false
	return true

func _match_trigger(trigger: Dictionary, event: Dictionary, context: Dictionary) -> bool:
	if event.get("kind", "") != str(trigger.get("eventKind", "")):
		return false
	if trigger.has("filter") and trigger["filter"] is Callable:
		return trigger["filter"].call(event, context)
	return true

func _activate_execution(event: Dictionary, context: Dictionary, gameplay_state) -> void:
	var ability = context.get("ability", null)
	if ability == null:
		return
	var instance = ability.activate_new_execution_instance({
		"timelineId": _timeline_id,
		"tagActions": _tag_actions,
		"eventChain": [event],
		"gameplayState": gameplay_state,
	})
	Log.debug("ActivateInstanceComponent", "开始执行")

func serialize() -> Dictionary:
	return {
		"triggersCount": _triggers.size(),
		"triggerMode": _trigger_mode,
		"timelineId": _timeline_id,
		"tagActionsCount": _tag_actions.size(),
	}

static func create_event_trigger(event_kind: String, filter_callable = null) -> Dictionary:
	var trigger := {
		"eventKind": event_kind,
	}
	if filter_callable != null:
		trigger["filter"] = filter_callable
	return trigger
