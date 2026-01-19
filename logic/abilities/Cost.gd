extends RefCounted
class_name Cost

var type: String = "cost"

func can_pay(_ctx: Dictionary) -> bool:
	return true

func pay(_ctx: Dictionary) -> void:
	pass

func get_fail_reason(_ctx: Dictionary) -> String:
	return ""


class ConsumeTagCost:
	extends Cost

	var tag: String
	var stacks: int

	func _init(tag_value: String, stacks_value: int = 1):
		type = "consumeTag"
		tag = tag_value
		stacks = stacks_value

	func can_pay(ctx: Dictionary) -> bool:
		var ability_set = ctx.get("abilitySet", null)
		return ability_set != null and ability_set.get_loose_tag_stacks(tag) >= stacks

	func pay(ctx: Dictionary) -> void:
		var ability_set = ctx.get("abilitySet", null)
		if ability_set != null:
			ability_set.remove_loose_tag(tag, stacks)

	func get_fail_reason(ctx: Dictionary) -> String:
		var ability_set = ctx.get("abilitySet", null)
		var current := 0
		if ability_set != null:
			current = ability_set.get_loose_tag_stacks(tag)
		return "%s 层数不足: %s/%s" % [tag, str(current), str(stacks)]


class RemoveTagCost:
	extends Cost

	var tag: String

	func _init(tag_value: String):
		type = "removeTag"
		tag = tag_value

	func can_pay(ctx: Dictionary) -> bool:
		var ability_set = ctx.get("abilitySet", null)
		return ability_set != null and ability_set.has_loose_tag(tag)

	func pay(ctx: Dictionary) -> void:
		var ability_set = ctx.get("abilitySet", null)
		if ability_set != null:
			ability_set.remove_loose_tag(tag)

	func get_fail_reason(_ctx: Dictionary) -> String:
		return "缺少 Tag: %s" % tag


class AddTagCost:
	extends Cost

	var tag: String
	var options: Dictionary

	func _init(tag_value: String, options_value: Dictionary = {}):
		type = "addTag"
		tag = tag_value
		options = options_value

	func can_pay(_ctx: Dictionary) -> bool:
		return true

	func pay(ctx: Dictionary) -> void:
		var ability_set = ctx.get("abilitySet", null)
		if ability_set == null:
			return
		var duration = options.get("duration", null)
		if duration != null and float(duration) > 0.0:
			ability_set.add_auto_duration_tag(tag, float(duration))
		else:
			ability_set.add_loose_tag(tag, int(options.get("stacks", 1)))
