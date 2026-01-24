extends AbilityComponent
class_name TagComponent

const TYPE := "TagComponent"

var _tags: Dictionary = {}

func _init(config: Dictionary):
	type = TYPE
	_tags = config.get("tags", {}).duplicate(true)

func on_apply(context: Dictionary) -> void:
	var ability_set = context.get("abilitySet", null)
	if ability_set == null:
		return
	ability_set._add_component_tags(context.get("ability", null).id, _tags)

func on_remove(context: Dictionary) -> void:
	var ability_set = context.get("abilitySet", null)
	if ability_set == null:
		return
	ability_set._remove_component_tags(context.get("ability", null).id)

func serialize() -> Dictionary:
	return {
		"type": type,
		"tags": _tags,
	}
