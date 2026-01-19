extends RefCounted
class_name TargetSelector

static func current_target(ctx: ExecutionContext) -> Array:
	var event = ctx.get_current_event()
	if event == null:
		return []
	if event.has("targets") and event.targets is Array:
		return event.targets
	if event.has("target"):
		return [event.target]
	return []
