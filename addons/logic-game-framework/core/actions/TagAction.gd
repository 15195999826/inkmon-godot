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

	func _init(params: Dictionary):
		super._init(params)
		type = "applyTag"
		tag = str(params.get("tag", ""))
		duration = params.get("duration", null)
		stacks = int(params.get("stacks", 1))

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

	func _init(params: Dictionary):
		super._init(params)
		type = "removeTag"
		tag = str(params.get("tag", ""))
		stacks = params.get("stacks", null)

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

	func _init(params: Dictionary):
		super._init(params)
		type = "hasTag"
		tag = str(params.get("tag", ""))
		then_actions = params.get("then", [])
		else_actions = params.get("else", [])

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
