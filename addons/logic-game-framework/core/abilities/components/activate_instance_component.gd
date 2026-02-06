extends AbilityComponent
class_name ActivateInstanceComponent

const TYPE := "ActivateInstanceComponent"

var _triggers: Array[Dictionary] = []
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
	# Debug: 冻结所有 Action，检测无状态约束
	_freeze_all_actions()

func on_event(event_dict: Dictionary, context: AbilityLifecycleContext, game_state_provider: Variant) -> bool:
	if _check_triggers(event_dict, context):
		_activate_execution(event_dict, context, game_state_provider)
		return true
	return false

func _check_triggers(event_dict: Dictionary, context: AbilityLifecycleContext) -> bool:
	if _triggers.is_empty():
		return false
	if _trigger_mode == "any":
		for trigger in _triggers:
			if _match_trigger(trigger, event_dict, context):
				return true
		return false
	for trigger in _triggers:
		if not _match_trigger(trigger, event_dict, context):
			return false
	return true

func _match_trigger(trigger: Dictionary, event_dict: Dictionary, context: AbilityLifecycleContext) -> bool:
	if event_dict.get("kind", "") != str(trigger.get("eventKind", "")):
		return false
	if trigger.has("filter") and trigger["filter"] is Callable:
		return trigger["filter"].call(event_dict, context)
	return true

func _activate_execution(event_dict: Dictionary, context: AbilityLifecycleContext, game_state_provider: Variant) -> void:
	var ability: Ability = context.ability
	if ability == null:
		return
	var instance: AbilityExecutionInstance = ability.activate_new_execution_instance({
		"timelineId": _timeline_id,
		"tagActions": _tag_actions,
		"eventChain": [event_dict],
		"gameplayState": game_state_provider,
	})
	Log.debug("ActivateInstanceComponent", "开始执行")

func serialize() -> Dictionary:
	return {
		"triggersCount": _triggers.size(),
		"triggerMode": _trigger_mode,
		"timelineId": _timeline_id,
		"tagActionsCount": _tag_actions.size(),
	}

## Debug: 冻结所有 Action，用于检测无状态约束
func _freeze_all_actions() -> void:
	for tag in _tag_actions:
		var actions: Array = _tag_actions[tag]
		for action in actions:
			if action is Action.BaseAction:
				action._freeze()

static func create_event_trigger(event_kind: String, filter_callable: Variant = null) -> Dictionary:
	var trigger := {
		"eventKind": event_kind,
	}
	if filter_callable != null:
		trigger["filter"] = filter_callable
	return trigger
