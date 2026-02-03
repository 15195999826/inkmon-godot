extends AbilityComponent
class_name Condition

func get_condition_type() -> String:
	return "condition"

func check(_ctx: Dictionary) -> bool:
	return true

func get_fail_reason(_ctx: Dictionary) -> String:
	return ""

class HasTagCondition:
	extends Condition

	func _init(tag_value: String):
		tag = tag_value

	func get_condition_type() -> String:
		return "hasTag"

	var tag: String

	func check(ctx: Dictionary) -> bool:
		var ability_set = ctx.get("abilitySet", null)
		return ability_set != null and ability_set.has_tag(tag)

	func get_fail_reason(_ctx: Dictionary) -> String:
		return "缺少 Tag: %s" % tag


class NoTagCondition:
	extends Condition

	func _init(tag_value: String):
		tag = tag_value

	func get_condition_type() -> String:
		return "noTag"

	var tag: String

	func check(ctx: Dictionary) -> bool:
		var ability_set = ctx.get("abilitySet", null)
		return ability_set == null or not ability_set.has_tag(tag)

	func get_fail_reason(_ctx: Dictionary) -> String:
		return "已有 Tag: %s" % tag


class TagStacksCondition:
	extends Condition

	func _init(tag_value: String, min_stacks_value: int):
		tag = tag_value
		min_stacks = min_stacks_value

	func get_condition_type() -> String:
		return "tagStacks"

	var tag: String
	var min_stacks: int

	func check(ctx: Dictionary) -> bool:
		var ability_set = ctx.get("abilitySet", null)
		if ability_set == null:
			return false
		return ability_set.get_tag_stacks(tag) >= min_stacks

	func get_fail_reason(ctx: Dictionary) -> String:
		var ability_set = ctx.get("abilitySet", null)
		var current := 0
		if ability_set != null:
			current = ability_set.get_tag_stacks(tag)
		return "%s 层数不足: %s/%s" % [tag, str(current), str(min_stacks)]


class AllConditions:
	extends Condition

	func _init(conditions_value: Array):
		conditions.assign(conditions_value)

	func get_condition_type() -> String:
		return "all"

	var conditions: Array[Condition] = []

	func check(ctx: Dictionary) -> bool:
		for condition in conditions:
			if not condition.check(ctx):
				return false
		return true

	func get_fail_reason(ctx: Dictionary) -> String:
		for condition in conditions:
			if not condition.check(ctx):
				if condition.has_method("get_fail_reason"):
					return condition.get_fail_reason(ctx)
				return "条件不满足: %s" % (condition.get_condition_type() if condition.has_method("get_condition_type") else "")
		return ""


class AnyCondition:
	extends Condition

	func _init(conditions_value: Array):
		conditions.assign(conditions_value)

	func get_condition_type() -> String:
		return "any"

	var conditions: Array[Condition] = []

	func check(ctx: Dictionary) -> bool:
		for condition in conditions:
			if condition.check(ctx):
				return true
		return false

	func get_fail_reason(_ctx: Dictionary) -> String:
		return "所有条件都不满足"
