extends AbilityComponent
class_name PreEventComponent

const TYPE := "PreEventComponent"

var _event_kind: String
var _filter: Callable = Callable()
var _handler: Callable
var _handler_name: String = ""
var _unregister: Callable = Callable()
var _lifecycle_context: Dictionary = {}

func _init(config: Dictionary):
	type = TYPE
	_event_kind = str(config.get("eventKind", ""))
	_filter = config.get("filter", Callable())
	_handler = config.get("handler", Callable())
	_handler_name = str(config.get("name", ""))

func get_event_kind() -> String:
	return _event_kind

func on_apply(context: Dictionary) -> void:
	_lifecycle_context = context
	var event_processor = context.get("eventProcessor", null)
	if event_processor == null:
		Log.warning("PreEventComponent", "PreEventComponent: EventProcessor not available, handler will not be registered")
		return
	var ability = context.get("ability", null)
	var handler_filter = func(event):
		if _filter.is_valid():
			return _filter.call(event, _lifecycle_context)
		return true
	_unregister = event_processor.register_pre_handler({
		"id": "%s_pre_%s" % [ability.id, _event_kind],
		"name": _handler_name if _handler_name != "" else (ability.display_name if ability.display_name != "" else ability.config_id),
		"eventKind": _event_kind,
		"ownerId": context.get("owner", null).id,
		"abilityId": ability.id,
		"configId": ability.config_id,
		"filter": handler_filter,
		"handler": func(mutable, _handler_context):
			return _handle_pre_event(mutable, _handler_context),
	})

func on_remove(_context: Dictionary) -> void:
	if _unregister.is_valid():
		_unregister.call()
		_unregister = Callable()
	_lifecycle_context = {}

func _handle_pre_event(mutable, _handler_context):
	if _lifecycle_context.is_empty():
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
