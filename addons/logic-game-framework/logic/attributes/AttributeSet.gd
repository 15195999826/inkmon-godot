extends RefCounted
class_name RawAttributeSet

const _CHANGE_TYPE_BASE := "base"
const _CHANGE_TYPE_MODIFIER := "modifier"
const _CHANGE_TYPE_CURRENT := "current"

var _base_values: Dictionary = {}
var _modifiers: Dictionary = {}
var _cache: Dictionary = {}
var _dirty_set: Dictionary = {}
var _computing_set: Dictionary = {}
var _constraints: Dictionary = {}
var _listeners: Array = []
var _hooks: Dictionary = {}
var _global_hooks: Dictionary = {}

func _init(attributes: Array = []):
	for attr in attributes:
		define_attribute(str(attr.get("name", "")), float(attr.get("baseValue", 0.0)), attr.get("minValue", null), attr.get("maxValue", null))

func define_attribute(name: String, base_value: float, min_value = null, max_value = null) -> void:
	if name == "":
		return
	_base_values[name] = base_value
	_modifiers[name] = []
	_dirty_set[name] = true
	if min_value != null or max_value != null:
		_constraints[name] = {
			"min": min_value,
			"max": max_value,
		}

func has_attribute(name: String) -> bool:
	return _base_values.has(name)

func get_base(name: String) -> float:
	if not _base_values.has(name):
		Log.warning("AttributeSet", "Attribute not found: %s" % name)
		return 0.0
	return float(_base_values[name])

func set_base(name: String, value: float) -> void:
	if not _base_values.has(name):
		Log.warning("AttributeSet", "Attribute not found: %s" % name)
		return

	var old_value := float(_base_values[name])
	var clamped_value := _clamp_value(name, value)
	if old_value == clamped_value:
		return

	var event := {
		"attributeName": name,
		"oldValue": old_value,
		"newValue": clamped_value,
		"changeType": _CHANGE_TYPE_BASE,
	}

	var hook_result = _invoke_pre_hook("preBaseChange", event)
	if hook_result == false:
		return

	var final_value := clamped_value
	if typeof(hook_result) in [TYPE_INT, TYPE_FLOAT]:
		final_value = _clamp_value(name, float(hook_result))

	_base_values[name] = final_value
	_mark_dirty(name)

	var final_event := event.duplicate(true)
	final_event["newValue"] = final_value

	_invoke_post_hook("postBaseChange", final_event)
	_notify_change(final_event)

func modify_base(name: String, delta: float) -> void:
	set_base(name, get_base(name) + delta)

func get_body_value(name: String) -> float:
	return float(get_breakdown(name).get("bodyValue", 0.0))

func get_current_value(name: String) -> float:
	return float(get_breakdown(name).get("currentValue", 0.0))

func get_breakdown(name: String) -> Dictionary:
	if _computing_set.has(name):
		Log.warning("AttributeSet", "Circular dependency detected for attribute: %s" % name)
		if _cache.has(name):
			return _cache[name]
		var fallback_base := float(_base_values.get(name, 0.0))
		return AttributeModifier.create_breakdown(fallback_base)

	if not _dirty_set.has(name) and _cache.has(name):
		return _cache[name]

	_computing_set[name] = true
	var breakdown := {}
	var base_value := float(_base_values.get(name, 0.0))
	var mods: Array = _modifiers.get(name, [])
	breakdown = AttributeCalculator.calculate_attribute(base_value, mods)

	var constraint = _constraints.get(name, null)
	if constraint != null:
		var clamped_current := float(breakdown.get("currentValue", base_value))
		if constraint.has("min") and constraint["min"] != null and clamped_current < float(constraint["min"]):
			clamped_current = float(constraint["min"])
		if constraint.has("max") and constraint["max"] != null and clamped_current > float(constraint["max"]):
			clamped_current = float(constraint["max"])
		if clamped_current != float(breakdown.get("currentValue", base_value)):
			var clamped_breakdown := breakdown.duplicate(true)
			clamped_breakdown["currentValue"] = clamped_current
			_cache[name] = clamped_breakdown
			_dirty_set.erase(name)
			_computing_set.erase(name)
			return clamped_breakdown

	_cache[name] = breakdown
	_dirty_set.erase(name)
	_computing_set.erase(name)
	return breakdown

func get_add_base_sum(name: String) -> float:
	return float(get_breakdown(name).get("addBaseSum", 0.0))

func get_mul_base_product(name: String) -> float:
	return float(get_breakdown(name).get("mulBaseProduct", 1.0))

func get_add_final_sum(name: String) -> float:
	return float(get_breakdown(name).get("addFinalSum", 0.0))

func get_mul_final_product(name: String) -> float:
	return float(get_breakdown(name).get("mulFinalProduct", 1.0))

func add_modifier(modifier: Dictionary) -> void:
	var attr_name := str(modifier.get("attributeName", ""))
	if not _modifiers.has(attr_name):
		Log.warning("AttributeSet", "Attribute not found for modifier: %s" % attr_name)
		return

	var mods: Array = _modifiers[attr_name]
	var modifier_id := str(modifier.get("id", ""))
	for existing in mods:
		if str(existing.get("id", "")) == modifier_id:
			Log.warning("AttributeSet", "Modifier already exists: %s" % modifier_id)
			return

	var old_value := get_current_value(attr_name)
	mods.append(modifier)
	_mark_dirty(attr_name)

	var new_value := get_current_value(attr_name)
	if old_value != new_value:
		_notify_change({
			"attributeName": attr_name,
			"oldValue": old_value,
			"newValue": new_value,
			"changeType": _CHANGE_TYPE_MODIFIER,
		})

func remove_modifier(modifier_id: String) -> bool:
	for attr_name in _modifiers.keys():
		var mods: Array = _modifiers[attr_name]
		var index := -1
		for i in range(mods.size()):
			if str(mods[i].get("id", "")) == modifier_id:
				index = i
				break
		if index != -1:
			var old_value := get_current_value(attr_name)
			mods.remove_at(index)
			_mark_dirty(attr_name)

			var new_value := get_current_value(attr_name)
			if old_value != new_value:
				_notify_change({
					"attributeName": attr_name,
					"oldValue": old_value,
					"newValue": new_value,
					"changeType": _CHANGE_TYPE_MODIFIER,
				})
			return true
	return false

func remove_modifiers_by_source(source: String) -> int:
	var count := 0
	for attr_name in _modifiers.keys():
		var mods: Array = _modifiers[attr_name]
		var old_value := get_current_value(attr_name)
		var original_length := mods.size()
		var filtered := []
		for mod in mods:
			if str(mod.get("source", "")) != source:
				filtered.append(mod)
		if filtered.size() != original_length:
			_modifiers[attr_name] = filtered
			_mark_dirty(attr_name)
			count += original_length - filtered.size()
			var new_value := get_current_value(attr_name)
			if old_value != new_value:
				_notify_change({
					"attributeName": attr_name,
					"oldValue": old_value,
					"newValue": new_value,
					"changeType": _CHANGE_TYPE_MODIFIER,
				})
	return count

func get_modifiers(name: String) -> Array:
	return _modifiers.get(name, [])

func has_modifier(modifier_id: String) -> bool:
	for mods in _modifiers.values():
		for mod in mods:
			if str(mod.get("id", "")) == modifier_id:
				return true
	return false

func add_change_listener(listener: Callable) -> void:
	_listeners.append(listener)

func remove_change_listener(listener: Callable) -> void:
	_listeners.erase(listener)

func remove_all_change_listeners() -> void:
	_listeners.clear()

func set_hooks(name: String, hooks: Dictionary) -> void:
	var existing: Dictionary = _hooks.get(name, {})
	var merged: Dictionary = existing.duplicate(true)
	for key in hooks.keys():
		merged[key] = hooks[key]
	_hooks[name] = merged

func get_hooks(name: String) -> Dictionary:
	return _hooks.get(name, {})

func remove_hooks(name: String) -> void:
	_hooks.erase(name)

func set_global_hooks(hooks: Dictionary) -> void:
	for key in hooks.keys():
		_global_hooks[key] = hooks[key]

func get_global_hooks() -> Dictionary:
	return _global_hooks.duplicate(true)

func clear_global_hooks() -> void:
	_global_hooks = {}

func serialize() -> Dictionary:
	var result := {}
	for name in _base_values.keys():
		result[name] = {
			"base": float(_base_values[name]),
			"modifiers": _modifiers.get(name, []).duplicate(true),
		}
	return result

static func deserialize(data: Dictionary) -> RawAttributeSet:
	var attr_set := RawAttributeSet.new()
	for name in data.keys():
		var attr_data: Dictionary = data[name]
		attr_set.define_attribute(str(name), float(attr_data.get("base", 0.0)))
		for mod in attr_data.get("modifiers", []):
			attr_set.add_modifier(mod)
	return attr_set

func _mark_dirty(name: String) -> void:
	_dirty_set[name] = true

func _clamp_value(name: String, value: float) -> float:
	if not _constraints.has(name):
		return value
	var constraint: Dictionary = _constraints[name]
	var result := value
	if constraint.has("min") and constraint["min"] != null and result < float(constraint["min"]):
		result = float(constraint["min"])
	if constraint.has("max") and constraint["max"] != null and result > float(constraint["max"]):
		result = float(constraint["max"])
	return result

func _notify_change(event: Dictionary) -> void:
	for listener in _listeners:
		if listener.is_valid():
			listener.call(event)
		else:
			Log.error("AttributeSet", "Error in attribute change listener")

func _invoke_pre_hook(hook_name: String, event: Dictionary):
	var attr_hooks: Dictionary = _hooks.get(event.get("attributeName", ""), {})
	if attr_hooks.has(hook_name):
		var hook = attr_hooks[hook_name]
		if hook is Callable:
			var result = hook.call(event)
			if result == false or typeof(result) in [TYPE_INT, TYPE_FLOAT]:
				return result

	if _global_hooks.has(hook_name):
		var global_hook = _global_hooks[hook_name]
		if global_hook is Callable:
			var result = global_hook.call(event)
			if result == false or typeof(result) in [TYPE_INT, TYPE_FLOAT]:
				return result

	return null

func _invoke_post_hook(hook_name: String, event: Dictionary) -> void:
	var attr_hooks: Dictionary = _hooks.get(event.get("attributeName", ""), {})
	if attr_hooks.has(hook_name):
		var hook = attr_hooks[hook_name]
		if hook is Callable:
			hook.call(event)

	if _global_hooks.has(hook_name):
		var global_hook = _global_hooks[hook_name]
		if global_hook is Callable:
			global_hook.call(event)
