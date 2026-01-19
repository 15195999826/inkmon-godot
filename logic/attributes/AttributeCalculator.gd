extends RefCounted
class_name AttributeCalculator

const _MODIFIER_ADD_BASE := AttributeModifier.MODIFIER_TYPE_ADD_BASE
const _MODIFIER_MUL_BASE := AttributeModifier.MODIFIER_TYPE_MUL_BASE
const _MODIFIER_ADD_FINAL := AttributeModifier.MODIFIER_TYPE_ADD_FINAL
const _MODIFIER_MUL_FINAL := AttributeModifier.MODIFIER_TYPE_MUL_FINAL

static func calculate_attribute(base_value: float, modifiers: Array) -> Dictionary:
	var add_base_sum := 0.0
	var mul_base_sum := 0.0
	var add_final_sum := 0.0
	var mul_final_sum := 0.0

	for modifier in modifiers:
		var modifier_type := str(modifier.get("modifierType", ""))
		match modifier_type:
			_MODIFIER_ADD_BASE:
				add_base_sum += float(modifier.get("value", 0.0))
			_MODIFIER_MUL_BASE:
				mul_base_sum += float(modifier.get("value", 0.0))
			_MODIFIER_ADD_FINAL:
				add_final_sum += float(modifier.get("value", 0.0))
			_MODIFIER_MUL_FINAL:
				mul_final_sum += float(modifier.get("value", 0.0))

	var mul_base_product := 1.0 + mul_base_sum
	var mul_final_product := 1.0 + mul_final_sum
	var body_value := (base_value + add_base_sum) * mul_base_product
	var current_value := (body_value + add_final_sum) * mul_final_product

	return {
		"base": base_value,
		"addBaseSum": add_base_sum,
		"mulBaseProduct": mul_base_product,
		"bodyValue": body_value,
		"addFinalSum": add_final_sum,
		"mulFinalProduct": mul_final_product,
		"currentValue": current_value,
	}

static func calculate_body_value(base_value: float, modifiers: Array) -> float:
	var add_base_sum := 0.0
	var mul_base_sum := 0.0

	for modifier in modifiers:
		var modifier_type := str(modifier.get("modifierType", ""))
		if modifier_type == _MODIFIER_ADD_BASE:
			add_base_sum += float(modifier.get("value", 0.0))
		elif modifier_type == _MODIFIER_MUL_BASE:
			mul_base_sum += float(modifier.get("value", 0.0))

	return (base_value + add_base_sum) * (1.0 + mul_base_sum)

static func calculate_current_value(base_value: float, modifiers: Array) -> float:
	return float(calculate_attribute(base_value, modifiers).get("currentValue", base_value))
