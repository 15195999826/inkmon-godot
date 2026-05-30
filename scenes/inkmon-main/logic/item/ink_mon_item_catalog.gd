class_name InkMonItemCatalog
extends ItemCatalog


const TRAINING_SWORD := &"training_sword"
const MINOR_RUNE := &"minor_rune"


func has_config(config_id: StringName) -> bool:
	return _configs().has(str(config_id))


func get_config(config_id: StringName) -> Dictionary:
	var configs := _configs()
	var key := str(config_id)
	if not configs.has(key):
		return {}
	return (configs[key] as Dictionary).duplicate(true)


func list_config_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for config_id in _configs().keys():
		result.append(StringName(str(config_id)))
	return result


static func _configs() -> Dictionary:
	return {
		String(TRAINING_SWORD): {
			"id": String(TRAINING_SWORD),
			"display_name": "Training Sword",
			"icon_key": "training_sword",
			"item_tags": ["equipment", "weapon"],
			"max_stack": 1,
			"equipable": true,
			"price": 30,
			"stat_mods": {"ad": 5.0},
		},
		String(MINOR_RUNE): {
			"id": String(MINOR_RUNE),
			"display_name": "Minor Rune",
			"icon_key": "minor_rune",
			"item_tags": ["material"],
			"max_stack": 99,
			"equipable": false,
			"price": 10,
		},
	}
