extends RefCounted
class_name AttributeModifier

const MODIFIER_TYPE_ADD_BASE := "AddBase"
const MODIFIER_TYPE_MUL_BASE := "MulBase"
const MODIFIER_TYPE_ADD_FINAL := "AddFinal"
const MODIFIER_TYPE_MUL_FINAL := "MulFinal"

static func create_add_base_modifier(id: String, attribute_name: String, value: float, source: String = "") -> Dictionary:
	return _create_modifier(id, attribute_name, MODIFIER_TYPE_ADD_BASE, value, source)

static func create_mul_base_modifier(id: String, attribute_name: String, value: float, source: String = "") -> Dictionary:
	return _create_modifier(id, attribute_name, MODIFIER_TYPE_MUL_BASE, value, source)

static func create_add_final_modifier(id: String, attribute_name: String, value: float, source: String = "") -> Dictionary:
	return _create_modifier(id, attribute_name, MODIFIER_TYPE_ADD_FINAL, value, source)

static func create_mul_final_modifier(id: String, attribute_name: String, value: float, source: String = "") -> Dictionary:
	return _create_modifier(id, attribute_name, MODIFIER_TYPE_MUL_FINAL, value, source)

static func create_breakdown(base_value: float) -> Dictionary:
	return {
		"base": base_value,
		"addBaseSum": 0.0,
		"mulBaseProduct": 1.0,
		"bodyValue": base_value,
		"addFinalSum": 0.0,
		"mulFinalProduct": 1.0,
		"currentValue": base_value,
	}

static func _create_modifier(id: String, attribute_name: String, modifier_type: String, value: float, source: String) -> Dictionary:
	var modifier := {
		"id": id,
		"attributeName": attribute_name,
		"modifierType": modifier_type,
		"value": value,
	}
	if source != "":
		modifier["source"] = source
	return modifier
