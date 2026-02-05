extends AbilityComponent
class_name Condition

func get_condition_type() -> String:
	return "condition"

func check(_ctx: AbilityLifecycleContext, _event: Dictionary, _game_state: Variant) -> bool:
	return true

func get_fail_reason(_ctx: AbilityLifecycleContext, _event: Dictionary, _game_state: Variant) -> String:
	return ""

class HasTagCondition:
	extends Condition

	var tag: String

	func _init(tag_value: String):
		tag = tag_value

	func get_condition_type() -> String:
		return "hasTag"

	func check(ctx: AbilityLifecycleContext, _event: Dictionary, _game_state: Variant) -> bool:
		return ctx.ability_set != null and ctx.ability_set.has_tag(tag)

	func get_fail_reason(_ctx: AbilityLifecycleContext, _event: Dictionary, _game_state: Variant) -> String:
		return "缺少 Tag: %s" % tag


class NoTagCondition:
	extends Condition

	var tag: String

	func _init(tag_value: String):
		tag = tag_value

	func get_condition_type() -> String:
		return "noTag"

	func check(ctx: AbilityLifecycleContext, _event: Dictionary, _game_state: Variant) -> bool:
		return ctx.ability_set == null or not ctx.ability_set.has_tag(tag)

	func get_fail_reason(_ctx: AbilityLifecycleContext, _event: Dictionary, _game_state: Variant) -> String:
		return "已有 Tag: %s" % tag


class TagStacksCondition:
	extends Condition

	var tag: String
	var min_stacks: int

	func _init(tag_value: String, min_stacks_value: int):
		tag = tag_value
		min_stacks = min_stacks_value

	func get_condition_type() -> String:
		return "tagStacks"

	func check(ctx: AbilityLifecycleContext, _event: Dictionary, _game_state: Variant) -> bool:
		if ctx.ability_set == null:
			return false
		return ctx.ability_set.get_tag_stacks(tag) >= min_stacks

	func get_fail_reason(ctx: AbilityLifecycleContext, _event: Dictionary, _game_state: Variant) -> String:
		var current := 0
		if ctx.ability_set != null:
			current = ctx.ability_set.get_tag_stacks(tag)
		return "%s 层数不足: %s/%s" % [tag, str(current), str(min_stacks)]


class AllConditions:
	extends Condition

	var conditions: Array[Condition] = []

	func _init(conditions_value: Array):
		conditions.assign(conditions_value)

	func get_condition_type() -> String:
		return "all"

	func check(ctx: AbilityLifecycleContext, event: Dictionary, game_state: Variant) -> bool:
		for condition in conditions:
			if not condition.check(ctx, event, game_state):
				return false
		return true

	func get_fail_reason(ctx: AbilityLifecycleContext, event: Dictionary, game_state: Variant) -> String:
		for condition in conditions:
			if not condition.check(ctx, event, game_state):
				var reason := condition.get_fail_reason(ctx, event, game_state)
				if reason != "":
					return reason
				return "条件不满足: %s" % condition.get_condition_type()
		return ""


class AnyCondition:
	extends Condition

	var conditions: Array[Condition] = []

	func _init(conditions_value: Array):
		conditions.assign(conditions_value)

	func get_condition_type() -> String:
		return "any"

	func check(ctx: AbilityLifecycleContext, event: Dictionary, game_state: Variant) -> bool:
		for condition in conditions:
			if condition.check(ctx, event, game_state):
				return true
		return false

	func get_fail_reason(_ctx: AbilityLifecycleContext, _event: Dictionary, _game_state: Variant) -> String:
		return "所有条件都不满足"
