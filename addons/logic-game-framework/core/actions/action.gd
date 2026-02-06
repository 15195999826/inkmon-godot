extends RefCounted
class_name Action


class BaseAction:
	extends RefCounted

	var type: String = "base"
	var _target_selector: TargetSelector
	var _frozen_hash: int = 0

	## 子类必须调用 super._init(target_selector)
	func _init(target_selector: TargetSelector = null) -> void:
		if target_selector != null:
			_target_selector = target_selector
		else:
			_target_selector = TargetSelector.current_target()

	func execute(_ctx: ExecutionContext) -> ActionResult:
		return ActionResult.create_success_result([])

	func get_targets(ctx: ExecutionContext) -> Array[TargetSelector.TargetRef]:
		return _target_selector.select(ctx)

	## 冻结 Action，记录当前状态 hash
	func _freeze() -> void:
		if _is_state_check_enabled():
			_frozen_hash = _compute_state_hash()

	## 验证状态未被修改
	func _verify_unchanged() -> void:
		if _frozen_hash != 0:
			var current := _compute_state_hash()
			assert(current == _frozen_hash,
				"Action state modified during execute()! Action: %s" % get_script().resource_path)

	## 检查是否启用状态检测（通过项目设置控制）
	static func _is_state_check_enabled() -> bool:
		return ProjectSettings.get_setting("logic_game_framework/debug/action_state_check", false)

	## 计算所有成员变量的 hash
	func _compute_state_hash() -> int:
		var parts: Array[String] = []
		for prop in get_property_list():
			if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
				var prop_name: String = prop.name
				# 排除内部标记变量
				if not prop_name.begins_with("_frozen"):
					var value = get(prop_name)
					# 使用 str() 安全转换，引用对象会得到实例标识
					parts.append("%s=%s" % [prop_name, str(value)])
		return hash(",".join(parts))


class NoopAction:
	extends BaseAction

	func _init(target_selector: TargetSelector = null) -> void:
		super._init(target_selector)
		type = "noop"

	func execute(_ctx: ExecutionContext) -> ActionResult:
		return ActionResult.create_success_result([])
