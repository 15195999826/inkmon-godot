extends RefCounted
class_name TargetSelector

const ExecutionContext = preload("res://logic/actions/ExecutionContext.gd")
const ActorRef = preload("res://logic/types/ActorRef.gd")

static func current_target(ctx: ExecutionContext) -> Array:
	var event = ctx.get_current_event()
	if event == null:
		return []
	if event.has("targets") and event.targets is Array:
		return event.targets
	if event.has("target"):
		return [event.target]
	return []
