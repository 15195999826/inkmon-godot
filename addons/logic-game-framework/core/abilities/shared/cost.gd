extends RefCounted
class_name Cost

var type: String = "cost"
var _frozen_hash: int = 0

func can_pay(_ctx: AbilityLifecycleContext, _event: Dictionary, _game_state: Variant) -> bool:
	return true

func pay(_ctx: AbilityLifecycleContext, _event: Dictionary, _game_state: Variant) -> void:
	pass

func get_fail_reason(_ctx: AbilityLifecycleContext, _event: Dictionary, _game_state: Variant) -> String:
	return ""

## 冻结 Cost，记录当前状态 hash
func _freeze() -> void:
	if _is_state_check_enabled():
		_frozen_hash = _compute_state_hash()

## 验证状态未被修改
func _verify_unchanged() -> void:
	if _frozen_hash != 0:
		var current := _compute_state_hash()
		assert(current == _frozen_hash,
			"Cost state modified during pay()! Cost: %s" % get_script().resource_path)

## 检查是否启用状态检测（通过项目设置控制）
static func _is_state_check_enabled() -> bool:
	return ProjectSettings.get_setting("logic_game_framework/debug/action_state_check", false)

## 计算所有成员变量的 hash
func _compute_state_hash() -> int:
	var parts: Array[String] = []
	for prop in get_property_list():
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var prop_name: String = prop.name
			if not prop_name.begins_with("_frozen"):
				var value = get(prop_name)
				# 使用 str() 安全转换，引用对象会得到实例标识
				parts.append("%s=%s" % [prop_name, str(value)])
	return hash(",".join(parts))


class ConsumeTagCost:
	extends Cost

	var tag: String
	var stacks: int

	func _init(tag_value: String, stacks_value: int = 1):
		type = "consumeTag"
		tag = tag_value
		stacks = stacks_value

	func can_pay(ctx: AbilityLifecycleContext, _event: Dictionary, _game_state: Variant) -> bool:
		return ctx.ability_set != null and ctx.ability_set.get_loose_tag_stacks(tag) >= stacks

	func pay(ctx: AbilityLifecycleContext, _event: Dictionary, _game_state: Variant) -> void:
		if ctx.ability_set != null:
			ctx.ability_set.remove_loose_tag(tag, stacks)

	func get_fail_reason(ctx: AbilityLifecycleContext, _event: Dictionary, _game_state: Variant) -> String:
		var current := 0
		if ctx.ability_set != null:
			current = ctx.ability_set.get_loose_tag_stacks(tag)
		return "%s 层数不足: %s/%s" % [tag, str(current), str(stacks)]


class RemoveTagCost:
	extends Cost

	var tag: String

	func _init(tag_value: String):
		type = "removeTag"
		tag = tag_value

	func can_pay(ctx: AbilityLifecycleContext, _event: Dictionary, _game_state: Variant) -> bool:
		return ctx.ability_set != null and ctx.ability_set.has_loose_tag(tag)

	func pay(ctx: AbilityLifecycleContext, _event: Dictionary, _game_state: Variant) -> void:
		if ctx.ability_set != null:
			ctx.ability_set.remove_loose_tag(tag)

	func get_fail_reason(_ctx: AbilityLifecycleContext, _event: Dictionary, _game_state: Variant) -> String:
		return "缺少 Tag: %s" % tag


class AddTagCost:
	extends Cost

	var tag: String
	var options: Dictionary

	func _init(tag_value: String, options_value: Dictionary = {}):
		type = "addTag"
		tag = tag_value
		options = options_value

	func can_pay(_ctx: AbilityLifecycleContext, _event: Dictionary, _game_state: Variant) -> bool:
		return true

	func pay(ctx: AbilityLifecycleContext, _event: Dictionary, _game_state: Variant) -> void:
		if ctx.ability_set == null:
			return
		var duration: Variant = options.get("duration", null)
		if duration != null and float(duration) > 0.0:
			ctx.ability_set.add_auto_duration_tag(tag, float(duration))
		else:
			ctx.ability_set.add_loose_tag(tag, int(options.get("stacks", 1)))
