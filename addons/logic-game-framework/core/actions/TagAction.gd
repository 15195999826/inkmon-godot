extends RefCounted
class_name TagAction

static func _get_ability_set_for_target(ctx: ExecutionContext, target) -> AbilitySet:
	var state = ctx.gameplay_state
	if AbilitySet.is_ability_set_provider(state):
		return state.get_ability_set_for_actor(target.id)
	return null

static func _get_logic_time(ctx: ExecutionContext) -> float:
	var event = ctx.get_current_event()
	if event != null and event.has("logicTime") and typeof(event["logicTime"]) in [TYPE_INT, TYPE_FLOAT]:
		return float(event["logicTime"])
	var state = ctx.gameplay_state
	if state != null and state.has("logicTime"):
		return float(state.logicTime)
	return float(Time.get_ticks_msec())

class ApplyTagAction:
	extends Action.BaseAction

	var tag: String
	var duration = null
	var stacks: int = 1

	## 构造函数
	## @param target_selector: 目标选择器
	## @param tag_name: 标签名称
	## @param stacks_count: 层数（默认 1）
	## @param tag_duration: 持续时间（可选，null 表示永久）
	func _init(
		target_selector: TargetSelector,
		tag_name: String,
		stacks_count: int = 1,
		tag_duration: Variant = null
	) -> void:
		super._init(target_selector)
		type = "applyTag"
		tag = tag_name
		stacks = stacks_count
		duration = tag_duration

	func execute(ctx: ExecutionContext) -> ActionResult:
		var targets = get_targets(ctx)
		for target in targets:
			var ability_set = TagAction._get_ability_set_for_target(ctx, target)
			if ability_set == null:
				Log.debug("TagAction", "ApplyTagAction: 无法获取 AbilitySet")
				continue
			if duration != null and float(duration) > 0.0:
				ability_set.add_auto_duration_tag(tag, float(duration))
			else:
				ability_set.add_loose_tag(tag, stacks)
		return ActionResult.create_success_result([])

class RemoveTagAction:
	extends Action.BaseAction

	var tag: String
	var stacks = null

	## 构造函数
	## @param target_selector: 目标选择器
	## @param tag_name: 标签名称
	## @param stacks_count: 要移除的层数（可选，null 表示全部移除）
	func _init(
		target_selector: TargetSelector,
		tag_name: String,
		stacks_count: Variant = null
	) -> void:
		super._init(target_selector)
		type = "removeTag"
		tag = tag_name
		stacks = stacks_count

	func execute(ctx: ExecutionContext) -> ActionResult:
		var targets = get_targets(ctx)
		for target in targets:
			var ability_set = TagAction._get_ability_set_for_target(ctx, target)
			if ability_set == null:
				Log.debug("TagAction", "RemoveTagAction: 无法获取 AbilitySet")
				continue
			var stacks_value := -1
			if stacks != null:
				stacks_value = int(stacks)
			ability_set.remove_loose_tag(tag, stacks_value)
		return ActionResult.create_success_result([])

class HasTagAction:
	extends Action.BaseAction

	var tag: String
	var then_actions: Array = []
	var else_actions: Array = []

	## 构造函数
	## @param target_selector: 目标选择器
	## @param tag_name: 标签名称
	## @param then_action_list: 有标签时执行的 Action 列表
	## @param else_action_list: 无标签时执行的 Action 列表
	func _init(
		target_selector: TargetSelector,
		tag_name: String,
		then_action_list: Array = [],
		else_action_list: Array = []
	) -> void:
		super._init(target_selector)
		type = "hasTag"
		tag = tag_name
		then_actions = then_action_list
		else_actions = else_action_list

	func execute(ctx: ExecutionContext) -> ActionResult:
		Log.debug("TagAction", "HasTagAction 多目标行为可能非预期")
		var targets = get_targets(ctx)
		var all_events: Array = []
		for target in targets:
			var ability_set = TagAction._get_ability_set_for_target(ctx, target)
			if ability_set == null:
				continue
			var has_tag := ability_set.has_tag(tag)
			var actions = then_actions if has_tag else else_actions
			for action in actions:
				if action != null and action.has_method("execute"):
					var result: ActionResult = action.execute(ctx)
					if result != null and result.events is Array:
						all_events.append_array(result.events)
		return ActionResult.create_success_result(all_events)
