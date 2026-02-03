extends AbilityComponent
class_name NoInstanceComponent

const TYPE := "NoInstanceComponent"

var _triggers: Array = []
var _trigger_mode: String = "any"
var _actions: Array[Action.BaseAction] = []

func _init(config: NoInstanceConfig):
	type = TYPE
	_trigger_mode = config.trigger_mode
	_actions.assign(config.actions)
	# 转换 TriggerConfig 为内部格式
	for trigger in config.triggers:
		if trigger is TriggerConfig:
			var trigger_dict := { "eventKind": trigger.event_kind }
			if trigger.filter.is_valid():
				trigger_dict["filter"] = trigger.filter
			_triggers.append(trigger_dict)
		else:
			_triggers.append(trigger)

func get_triggers() -> Array:
	return _triggers

func matches_event(event: Dictionary, context: Dictionary) -> bool:
	return _check_triggers(event, context)

func on_event(event: Dictionary, context: Dictionary, game_state_provider) -> bool:
	if _check_triggers(event, context):
		_execute_actions(event, context, game_state_provider)
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

func _execute_actions(event: Dictionary, context: Dictionary, game_state_provider) -> void:
	var exec_context = _build_execution_context(event, context, game_state_provider)
	for action in _actions:
		action.execute(exec_context)

func _build_execution_context(event: Dictionary, context: Dictionary, game_state_provider):
	var ability = context.get("ability", null)
	return ExecutionContext.create_execution_context({
		"eventChain": [event],
		"gameplayState": game_state_provider,
		"eventCollector": GameWorld.event_collector,
		"ability": {
			"id": ability.id if ability != null else "",
			"configId": ability.config_id if ability != null else "",
			"owner": context.get("owner", null),
			"source": context.get("owner", null),
		},
	})

func serialize() -> Dictionary:
	return {
		"triggersCount": _triggers.size(),
		"triggerMode": _trigger_mode,
		"actionsCount": _actions.size(),
	}

static func create_event_trigger(event_kind: String, filter_callable = null) -> Dictionary:
	var trigger := {
		"eventKind": event_kind,
	}
	if filter_callable != null:
		trigger["filter"] = filter_callable
	return trigger
