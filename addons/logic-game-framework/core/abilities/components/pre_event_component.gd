extends AbilityComponent
class_name PreEventComponent

const TYPE := "PreEventComponent"

var _event_kind: String
var _filter: Callable = Callable()
var _handler: Callable
var _handler_name: String = ""
var _unregister: Callable = Callable()
var _lifecycle_context: AbilityLifecycleContext = null

func _init(config: PreEventConfig):
	type = TYPE
	_event_kind = config.event_kind
	_filter = config.filter
	_handler = config.handler
	_handler_name = config.name

func get_event_kind() -> String:
	return _event_kind

func on_apply(context: AbilityLifecycleContext) -> void:
	_lifecycle_context = context
	var event_processor: EventProcessor = context.event_processor
	if event_processor == null:
		Log.warning("PreEventComponent", "PreEventComponent: EventProcessor not available, handler will not be registered")
		return
	var ability: Ability = context.ability
	var handler_filter := func(event_dict: Dictionary) -> bool:
		if _filter.is_valid():
			return _filter.call(event_dict, _lifecycle_context)
		return true
	_unregister = event_processor.register_pre_handler({
		"id": "%s_pre_%s" % [ability.id, _event_kind],
		"name": _handler_name if _handler_name != "" else (ability.display_name if ability.display_name != "" else ability.config_id),
		"eventKind": _event_kind,
		"ownerId": context.owner.id,
		"abilityId": ability.id,
		"configId": ability.config_id,
		"filter": handler_filter,
		"handler": func(mutable: MutableEvent, _handler_context: Dictionary):
			return _handle_pre_event(mutable, _handler_context),
	})

func on_remove(_context: AbilityLifecycleContext) -> void:
	if _unregister.is_valid():
		_unregister.call()
		_unregister = Callable()
	_lifecycle_context = null

func _handle_pre_event(mutable: MutableEvent, _handler_context: Dictionary):
	if _lifecycle_context == null:
		Log.warning("PreEventComponent", "PreEventComponent: lifecycleContext not available")
		return EventPhase.pass_intent()
	if not _handler.is_valid():
		return EventPhase.pass_intent()
	return _handler.call(mutable, _lifecycle_context)

func serialize() -> Dictionary:
	return {
		"eventKind": _event_kind,
		"handlerName": _handler_name,
	}
