extends AbilityComponent
class_name StatModifierComponent

var configs: Array
var modifier_prefix: String
var applied_modifiers: Array = []
var current_scale: float = 1.0

func _init(modifier_configs: Array):
	configs = modifier_configs
	modifier_prefix = IdGenerator.generate_id("statmod")
	type = "StatModifierComponent"

func on_apply(context: Dictionary) -> void:
	var mod_list := _create_modifiers_internal(context)

	for modifier in mod_list:
		context.attributes.add_modifier(modifier)

func _create_modifiers_internal(context: Dictionary) -> Array:
	var result := []
	for i in range(configs.size()):
		var config = configs[i]
		var modifier = AttributeModifier._create_modifier(
			"%s_%d" % [modifier_prefix, i],
			config.get("attributeName", ""),
			config.get("modifierType", ""),
			config.get("value", 0.0) * current_scale,
			context.ability.id
		)
		if modifier:
			result.append(modifier)
	return result

func on_remove(context: Dictionary) -> void:
	context.attributes.remove_modifiers_by_source(context.ability.id)
	_clear_modifiers_internal()

func _clear_modifiers_internal() -> void:
	applied_modifiers.clear()

func get_modifiers() -> Array:
	return applied_modifiers.duplicate()

func get_modifier_ids() -> Array:
	var result := []
	for modifier in applied_modifiers:
		if modifier.has("id"):
			result.append(modifier["id"])
	return result

func set_scale(scale: float) -> void:
	current_scale = scale

func scale_by_stacks(stacks: int) -> void:
	set_scale(float(stacks))

func get_configs() -> Array:
	return configs.duplicate()

func serialize() -> Dictionary:
	return {
		"configs": configs,
		"scale": current_scale,
	}

func deserialize(data: Dictionary) -> void:
	current_scale = float(data.get("scale", 1.0))
