extends RefCounted
class_name AttributeFactory

const _KEY_RAW := "_raw"
const _KEY_MODIFIER_TARGET := "_modifierTarget"

static func define_attributes(config: Dictionary) -> Dictionary:
	var attributes := []
	var attr_names := {}
	for name in config.keys():
		var cfg: Dictionary = config[name]
		attributes.append({
			"name": str(name),
			"baseValue": float(cfg.get("baseValue", 0.0)),
			"minValue": cfg.get("minValue", null),
			"maxValue": cfg.get("maxValue", null),
		})
		attr_names[str(name)] = true

	var raw := RawAttributeSet.new(attributes)
	var modifier_target := _create_modifier_target(raw)
	return _create_attribute_set(raw, attr_names, modifier_target)

static func restore_attributes(data: Dictionary) -> Dictionary:
	var raw := RawAttributeSet.deserialize(data)
	var attr_names := {}
	for name in data.keys():
		attr_names[str(name)] = true
	var modifier_target := _create_modifier_target(raw)
	return _create_attribute_set(raw, attr_names, modifier_target)

static func _create_modifier_target(raw: RawAttributeSet) -> Dictionary:
	return {
		"addModifier": func(modifier: Dictionary) -> void:
			raw.add_modifier(modifier),
		"removeModifier": func(modifier_id: String) -> bool:
			return raw.remove_modifier(modifier_id),
		"removeModifiersBySource": func(source: String) -> int:
			return raw.remove_modifiers_by_source(source),
		"getModifiers": func(name: String) -> Array:
			return raw.get_modifiers(name),
		"hasModifier": func(modifier_id: String) -> bool:
			return raw.has_modifier(modifier_id),
	}

static func _create_attribute_set(raw: RawAttributeSet, attr_names: Dictionary, modifier_target: Dictionary) -> Dictionary:
	var attribute_set := {}
	attribute_set[_KEY_RAW] = raw
	attribute_set[_KEY_MODIFIER_TARGET] = modifier_target

	attribute_set["getBase"] = func(name: String) -> float:
		return raw.get_base(name)
	attribute_set["modifyBase"] = func(name: String, delta: float) -> void:
		raw.modify_base(name, delta)
	attribute_set["getBreakdown"] = func(name: String) -> Dictionary:
		return raw.get_breakdown(name)
	attribute_set["hasAttribute"] = func(name: String) -> bool:
		return raw.has_attribute(name)
	attribute_set["addChangeListener"] = func(listener: Callable) -> void:
		raw.add_change_listener(listener)
	attribute_set["removeChangeListener"] = func(listener: Callable) -> void:
		raw.remove_change_listener(listener)
	attribute_set["removeAllChangeListeners"] = func() -> void:
		raw.remove_all_change_listeners()
	attribute_set["setHooks"] = func(name: String, hooks: Dictionary) -> void:
		raw.set_hooks(name, hooks)
	attribute_set["setGlobalHooks"] = func(hooks: Dictionary) -> void:
		raw.set_global_hooks(hooks)
	attribute_set["serialize"] = func() -> Dictionary:
		return raw.serialize()

	for attr_name in attr_names.keys():
		var attr_key := str(attr_name)
		var capitalized := attr_key.left(1).to_upper() + attr_key.substr(1)

		attribute_set[attr_key] = func(name := attr_key) -> float:
			return raw.get_current_value(name)
		attribute_set["$" + attr_key] = func(name := attr_key) -> Dictionary:
			return raw.get_breakdown(name)
		attribute_set[attr_key + "Attribute"] = attr_key
		attribute_set["set" + capitalized + "Base"] = func(value: float, name := attr_key) -> void:
			raw.set_base(name, value)
		attribute_set["on" + capitalized + "Changed"] = func(callback: Callable, name := attr_key) -> Callable:
			var filtered_listener := func(event: Dictionary) -> void:
				if event.get("attributeName", "") == name:
					callback.call(event)
			raw.add_change_listener(filtered_listener)
			return func() -> void:
				raw.remove_change_listener(filtered_listener)

	attribute_set["getCurrentValue"] = func(name: String) -> float:
		return raw.get_current_value(name)
	attribute_set["getBodyValue"] = func(name: String) -> float:
		return raw.get_body_value(name)
	attribute_set["getAddBaseSum"] = func(name: String) -> float:
		return raw.get_add_base_sum(name)
	attribute_set["getMulBaseProduct"] = func(name: String) -> float:
		return raw.get_mul_base_product(name)
	attribute_set["getAddFinalSum"] = func(name: String) -> float:
		return raw.get_add_final_sum(name)
	attribute_set["getMulFinalProduct"] = func(name: String) -> float:
		return raw.get_mul_final_product(name)

	return attribute_set
