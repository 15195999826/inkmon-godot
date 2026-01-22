extends AbilityComponent
class_name StatModifierComponent

var configs: Array
var modifier_prefix: String
var applied_modifiers: Array = []
var current_scale: float = 1.0

func _init(modifier_configs: Array):
	configs = modifier_configs
	modifier_prefix = IdGenerator.generate("statmod")
	type = "StatModifierComponent"

func on_apply(context) -> void:
	applied_modifiers = []

	for i in range(configs.size()):
		var config = configs[i]
		var modifier := AttributeModifier._create_modifier(
			"%s_%d" % [modifier_prefix, i],
			config.get("attributeName", ""),
			config.get("modifierType", ""),
			config.get("value", 0.0) * current_scale,
			context.ability.id
		)
		applied_modifiers.append(modifier)

	for modifier in applied_modifiers:
		context.attributes.add_modifier(modifier)

func on_remove(context) -> void:
	context.attributes.remove_modifiers_by_source(context.ability.id)
	applied_modifiers.clear()

func get_modifiers() -> Array:
	return applied_modifiers.duplicate()

func get_modifier_ids() -> Array:
	var ids := []
	for modifier in applied_modifiers:
		ids.append(modifier.get("id", ""))
	return ids

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
