extends RefCounted
class_name Action


class BaseAction:
	extends RefCounted

	var type: String = "base"
	var _target_selector: TargetSelector

	func _init(params: Dictionary):
		var selector_input = params.get("targetSelector", null)
		if selector_input is TargetSelector:
			_target_selector = selector_input
		else:
			_target_selector = TargetSelector.current_target()

	func execute(_ctx: ExecutionContext) -> ActionResult:
		return ActionResult.create_success_result([])

	func get_targets(ctx: ExecutionContext) -> Array[ActorRef]:
		return _target_selector.select(ctx)


class NoopAction:
	extends BaseAction

	func _init(params: Dictionary = {}):
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
			return NoopAction.new()
		var params: Dictionary = config.get("params", {})
		if params == null:
			params = {}
		return creator.call(params)


static var _global_factory: ActionFactory = ActionFactory.new()


static func get_action_factory() -> ActionFactory:
	return _global_factory


static func set_action_factory(factory: ActionFactory) -> void:
	_global_factory = factory
