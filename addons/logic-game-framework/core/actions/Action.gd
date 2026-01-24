extends RefCounted
class_name Action


class BaseAction:
	extends RefCounted

	var type: String = "base"
	var _target_selector: TargetSelector

	## 子类必须调用 super._init(target_selector)
	func _init(target_selector: TargetSelector = null) -> void:
		if target_selector != null:
			_target_selector = target_selector
		else:
			_target_selector = TargetSelector.current_target()

	func execute(_ctx: ExecutionContext) -> ActionResult:
		return ActionResult.create_success_result([])

	func get_targets(ctx: ExecutionContext) -> Array[ActorRef]:
		return _target_selector.select(ctx)


class NoopAction:
	extends BaseAction

	func _init(target_selector: TargetSelector = null) -> void:
		super._init(target_selector)
		type = "noop"

	func execute(_ctx: ExecutionContext) -> ActionResult:
		return ActionResult.create_success_result([])
