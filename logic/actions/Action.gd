extends RefCounted
class_name Action

static func default_target_selector(ctx: ExecutionContext) -> Array:
	var event = ctx.get_current_event()
	if event == null:
		return []
	if event.has("targets") and event.targets is Array:
		return event.targets
	if event.has("target"):
		return [event.target]
	return []

class BaseAction:
	extends RefCounted

	var type: String = "base"
	var target_selector: Callable
	var _callbacks: Array = []

	func _init(params: Dictionary):
		if params.has("targetSelector") and params["targetSelector"] is Callable:
			target_selector = params["targetSelector"]
		else:
			target_selector = func(ctx: ExecutionContext):
				return Action.default_target_selector(ctx)

	func execute(_ctx: ExecutionContext) -> ActionResult:
		return ActionResult.create_success_result([])

	func get_targets(ctx: ExecutionContext) -> Array:
		return target_selector.call(ctx)

	func add_callback(trigger: String, action) -> BaseAction:
		_callbacks.append({
			"trigger": trigger,
			"action": action,
		})
		return self

	func on_hit(action) -> BaseAction:
		return add_callback("onHit", action)

	func on_critical(action) -> BaseAction:
		return add_callback("onCritical", action)

	func on_kill(action) -> BaseAction:
		return add_callback("onKill", action)

	func on_heal(action) -> BaseAction:
		return add_callback("onHeal", action)

	func on_overheal(action) -> BaseAction:
		return add_callback("onOverheal", action)

	func on_buff_applied(action) -> BaseAction:
		return add_callback("onBuffApplied", action)

	func on_buff_refreshed(action) -> BaseAction:
		return add_callback("onBuffRefreshed", action)

	func process_callbacks(result: ActionResult, ctx: ExecutionContext) -> ActionResult:
		if result == null or not result.success or _callbacks.is_empty():
			return result
		var all_events: Array = result.events.duplicate(true)
		for event in result.events:
			var triggered = _get_triggered_callbacks(event)
			for callback in triggered:
				var callback_ctx = ExecutionContext.create_callback_context(ctx, event)
				var action = callback.get("action", null)
				if action == null or not action.has_method("execute"):
					continue
				var callback_result = null
				var call_ok := true
				callback_result = action.execute(callback_ctx)
				call_ok = true
				if not call_ok:
					Log.error("Action", "Callback action failed")
					continue
				if callback_result != null and callback_result.has("events"):
					all_events.append_array(callback_result.events)
		return ActionResult.new(result.success, all_events, result.failure_reason, result.data)

	func _get_triggered_callbacks(event: Dictionary) -> Array:
		var kind := str(event.get("kind", ""))
		return _callbacks.filter(func(cb):
			var trigger := str(cb.get("trigger", ""))
			if kind == "damage":
				if trigger == "onHit":
					return true
				if trigger == "onCritical" and bool(event.get("isCritical", false)):
					return true
				if trigger == "onKill" and bool(event.get("isKill", false)):
					return true
				return false
			if kind == "heal":
				if trigger == "onHeal":
					return true
				if trigger == "onOverheal" and float(event.get("overheal", 0)) > 0:
					return true
				return false
			if kind == "buffApplied":
				if trigger == "onBuffApplied":
					return true
				if trigger == "onBuffRefreshed" and bool(event.get("isRefresh", false)):
					return true
				return false
			return false
		)

class NoopAction:
	extends BaseAction

	func _init(params: Dictionary):
		super._init(params)
		type = "noop"

	func execute(_ctx: ExecutionContext) -> ActionResult:
		return ActionResult.create_success_result([])

class ActionFactory:
	extends RefCounted

	var _creators: Dictionary = {}

	func register(action_type: String, creator: Callable) -> void:
		_creators[action_type] = creator

	func create(config: Dictionary) -> BaseAction:
		var action_type := str(config.get("type", ""))
		var creator = _creators.get(action_type, null)
		if creator == null:
			Log.error("Action", "Unknown action type: %s" % action_type)
			return NoopAction.new({"targetSelector": func(ctx: ExecutionContext):
				return Action.default_target_selector(ctx)
			})
		var params: Dictionary = config.get("params", {})
		if params == null:
			params = {}
		return creator.call(params)

static var _global_factory: ActionFactory = ActionFactory.new()

static func get_action_factory() -> ActionFactory:
	return _global_factory

static func set_action_factory(factory: ActionFactory) -> void:
	_global_factory = factory
