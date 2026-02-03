extends AbilityComponent
class_name TagComponent

const TYPE := "TagComponent"

var _tags: Dictionary = {}

func _init(config: Dictionary):
	type = TYPE
	_tags = config.get("tags", {}).duplicate(true)

func on_apply(context: AbilityLifecycleContext) -> void:
	var ability_set: AbilitySet = context.ability_set
	if ability_set == null:
		return
	ability_set._add_component_tags(context.ability.id, _tags)

func on_remove(context: AbilityLifecycleContext) -> void:
	var ability_set: AbilitySet = context.ability_set
	if ability_set == null:
		return
	ability_set._remove_component_tags(context.ability.id)

func serialize() -> Dictionary:
	return {
		"type": type,
		"tags": _tags,
	}
