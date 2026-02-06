extends AbilityComponent
class_name NoInstanceComponent

const TYPE := "NoInstanceComponent"

var _triggers: Array[Dictionary] = []
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
	# Debug: 冻结所有 Action
	_freeze_all_actions()

func get_triggers() -> Array[Dictionary]:
	return _triggers

func matches_event(event_dict: Dictionary, context: AbilityLifecycleContext) -> bool:
	return _check_triggers(event_dict, context)

func on_event(event_dict: Dictionary, context: AbilityLifecycleContext, game_state_provider: Variant) -> bool:
	if _check_triggers(event_dict, context):
		_execute_actions(event_dict, context, game_state_provider)
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

func _execute_actions(event_dict: Dictionary, context: AbilityLifecycleContext, game_state_provider: Variant) -> void:
	var exec_context := _build_execution_context(event_dict, context, game_state_provider)
	for action in _actions:
		action.execute(exec_context)
		action._verify_unchanged()

## Debug: 冻结所有 Action，用于检测无状态约束
func _freeze_all_actions() -> void:
	for action in _actions:
		action._freeze()

func _build_execution_context(event_dict: Dictionary, context: AbilityLifecycleContext, game_state_provider: Variant) -> ExecutionContext:
	var ability_ref := AbilityRef.from_ability(context.ability)
	var event_chain: Array[Dictionary] = [event_dict]
	return ExecutionContext.create(
		event_chain,
		game_state_provider,
		GameWorld.event_collector,
		ability_ref,
		null  # NoInstanceComponent 不产生 ExecutionInfo
	)

func serialize() -> Dictionary:
	return {
		"triggersCount": _triggers.size(),
		"triggerMode": _trigger_mode,
		"actionsCount": _actions.size(),
	}

static func create_event_trigger(event_kind: String, filter_callable: Variant = null) -> Dictionary:
	var trigger := {
		"eventKind": event_kind,
	}
	if filter_callable != null:
		trigger["filter"] = filter_callable
	return trigger
