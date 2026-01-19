extends RefCounted
class_name ExecutionContext

var event_chain: Array = []
var gameplay_state = null
var event_collector = null
var ability: Dictionary = {}
var execution: Dictionary = {}

func _init(config: Dictionary = {}):
	event_chain = config.get("eventChain", [])
	gameplay_state = config.get("gameplayState", null)
	event_collector = config.get("eventCollector", null)
	ability = config.get("ability", {})
	execution = config.get("execution", {})

func get_current_event():
	if event_chain.is_empty():
		return null
	return event_chain[event_chain.size() - 1]

func get_original_event():
	if event_chain.is_empty():
		return null
	return event_chain[0]

func push_event(event: Dictionary) -> Dictionary:
	if event_collector != null and event_collector.has_method("push"):
		return event_collector.push(event)
	return event

static func create_execution_context(config: Dictionary) -> ExecutionContext:
	return ExecutionContext.new(config)

static func create_callback_context(ctx: ExecutionContext, callback_event: Dictionary) -> ExecutionContext:
	return ExecutionContext.new({
		"eventChain": ctx.event_chain + [callback_event],
		"gameplayState": ctx.gameplay_state,
		"eventCollector": ctx.event_collector,
		"ability": ctx.ability,
		"execution": ctx.execution,
	})
