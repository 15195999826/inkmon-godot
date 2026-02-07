extends RefCounted
class_name RawAttributeSet

const _CHANGE_TYPE_BASE := "base"
const _CHANGE_TYPE_MODIFIER := "modifier"
const _CHANGE_TYPE_CURRENT := "current"

var _base_values: Dictionary = {}
## { String -> Array[AttributeModifier] }
var _modifiers: Dictionary = {}
## { String -> AttributeBreakdown }
var _cache: Dictionary = {}
var _dirty_set: Dictionary = {}
var _computing_set: Dictionary = {}
var _constraints: Dictionary = {}
var _listeners: Array[Callable] = []
var _hooks: Dictionary = {}
var _global_hooks: Dictionary = {}

func _init(attributes: Array[Dictionary] = []) -> void:
	for attr in attributes:
		var min_val: float = -INF if attr.get("minValue") == null else float(attr.get("minValue"))
		var max_val: float = INF if attr.get("maxValue") == null else float(attr.get("maxValue"))
		define_attribute(str(attr.get("name", "")), float(attr.get("baseValue", 0.0)), min_val, max_val)

func define_attribute(name: String, base_value: float, min_value: float = -INF, max_value: float = INF) -> void:
	if name == "":
		return
	_base_values[name] = base_value
	var empty_mods: Array[AttributeModifier] = []
	_modifiers[name] = empty_mods
	_dirty_set[name] = true
	if min_value != -INF or max_value != INF:
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

	var hook_result: Variant = _invoke_pre_hook("preBaseChange", event)
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

func get_body_value(name: String) -> float:
	return get_breakdown(name).body_value

func get_current_value(name: String) -> float:
	return get_breakdown(name).current_value

func get_breakdown(name: String) -> AttributeBreakdown:
	if _computing_set.has(name):
		Log.warning("AttributeSet", "Circular dependency detected for attribute: %s" % name)
		if _cache.has(name):
			return _cache[name] as AttributeBreakdown
		var fallback_base := float(_base_values.get(name, 0.0))
		return AttributeBreakdown.from_base(fallback_base)

	if not _dirty_set.has(name) and _cache.has(name):
		return _cache[name] as AttributeBreakdown

	_computing_set[name] = true
	var base_value := float(_base_values.get(name, 0.0))
	var mods: Array[AttributeModifier] = _get_modifiers_typed(name)
	var breakdown := AttributeCalculator.calculate(base_value, mods)

	var constraint: Variant = _constraints.get(name, null)
	if constraint != null:
		var clamped_current := breakdown.current_value
		if constraint.has("min") and constraint["min"] != null and clamped_current < float(constraint["min"]):
			clamped_current = float(constraint["min"])
		if constraint.has("max") and constraint["max"] != null and clamped_current > float(constraint["max"]):
			clamped_current = float(constraint["max"])
		if clamped_current != breakdown.current_value:
			var clamped_breakdown := AttributeBreakdown.new(
				breakdown.base,
				breakdown.add_base_sum,
				breakdown.mul_base_product,
				breakdown.body_value,
				breakdown.add_final_sum,
				breakdown.mul_final_product,
				clamped_current,
			)
			_cache[name] = clamped_breakdown
			_dirty_set.erase(name)
			_computing_set.erase(name)
			return clamped_breakdown

	_cache[name] = breakdown
	_dirty_set.erase(name)
	_computing_set.erase(name)
	return breakdown

func get_add_base_sum(name: String) -> float:
	return get_breakdown(name).add_base_sum

func get_mul_base_product(name: String) -> float:
	return get_breakdown(name).mul_base_product

func get_add_final_sum(name: String) -> float:
	return get_breakdown(name).add_final_sum

func get_mul_final_product(name: String) -> float:
	return get_breakdown(name).mul_final_product

func add_modifier(modifier: AttributeModifier) -> void:
	if not _modifiers.has(modifier.attribute_name):
		Log.warning("AttributeSet", "Attribute not found for modifier: %s" % modifier.attribute_name)
		return

	var mods: Array[AttributeModifier] = _get_modifiers_typed(modifier.attribute_name)
	for existing in mods:
		if existing.id == modifier.id:
			Log.warning("AttributeSet", "Modifier already exists: %s" % modifier.id)
			return

	var old_value := get_current_value(modifier.attribute_name)
	mods.append(modifier)
	_mark_dirty(modifier.attribute_name)

	var new_value := get_current_value(modifier.attribute_name)
	if old_value != new_value:
		_notify_change({
			"attributeName": modifier.attribute_name,
			"oldValue": old_value,
			"newValue": new_value,
			"changeType": _CHANGE_TYPE_MODIFIER,
		})

func remove_modifier(modifier_id: String) -> bool:
	for attr_name in _modifiers.keys():
		var mods: Array[AttributeModifier] = _get_modifiers_typed(attr_name)
		var index := -1
		for i in range(mods.size()):
			if mods[i].id == modifier_id:
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
		var mods: Array[AttributeModifier] = _get_modifiers_typed(attr_name)
		var old_value := get_current_value(attr_name)
		var original_length := mods.size()
		var filtered: Array[AttributeModifier] = []
		for mod in mods:
			if mod.source != source:
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

func get_modifiers(name: String) -> Array[AttributeModifier]:
	return _get_modifiers_typed(name)

func has_modifier(modifier_id: String) -> bool:
	for attr_name in _modifiers.keys():
		var mods: Array[AttributeModifier] = _get_modifiers_typed(attr_name)
		for mod in mods:
			if mod.id == modifier_id:
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

func apply_config(config: Dictionary) -> void:
	for name in config.keys():
		var cfg: Dictionary = config[name]
		var min_val: float = -INF if cfg.get("minValue") == null else float(cfg.get("minValue"))
		var max_val: float = INF if cfg.get("maxValue") == null else float(cfg.get("maxValue"))
		define_attribute(
			str(name),
			float(cfg.get("baseValue", 0.0)),
			min_val,
			max_val
		)

func on_attribute_changed(attribute_name: String, callback: Callable) -> Callable:
	var filtered_listener := func(event: Dictionary) -> void:
		if event.get("attributeName", "") == attribute_name:
			callback.call(event)
	add_change_listener(filtered_listener)
	return func() -> void:
		remove_change_listener(filtered_listener)

static func from_config(config: Dictionary) -> RawAttributeSet:
	var attr_set := RawAttributeSet.new()
	attr_set.apply_config(config)
	return attr_set

static func restore_attributes(data: Dictionary) -> RawAttributeSet:
	return RawAttributeSet.deserialize(data)

func serialize() -> Dictionary:
	var result := {}
	for name in _base_values.keys():
		var mods: Array[AttributeModifier] = _get_modifiers_typed(name)
		var serialized_mods: Array[Dictionary] = []
		for mod in mods:
			serialized_mods.append(mod.serialize())
		result[name] = {
			"base": float(_base_values[name]),
			"modifiers": serialized_mods,
		}
	return result

static func deserialize(data: Dictionary) -> RawAttributeSet:
	var attr_set := RawAttributeSet.new()
	for name in data.keys():
		var attr_data: Dictionary = data[name]
		attr_set.define_attribute(str(name), float(attr_data.get("base", 0.0)))
		for mod_data in attr_data.get("modifiers", []):
			var mod := AttributeModifier.deserialize(mod_data)
			attr_set.add_modifier(mod)
	return attr_set

func _mark_dirty(name: String) -> void:
	_dirty_set[name] = true

func _clamp_value(name: String, value: float) -> float:
	if not _constraints.has(name):
		return value
	var constraint: Dictionary = _constraints[name]
	var result := value
	var min_val: float = constraint.get("min", -INF)
	var max_val: float = constraint.get("max", INF)
	if min_val != -INF and result < min_val:
		result = min_val
	if max_val != INF and result > max_val:
		result = max_val
	return result

func _notify_change(event: Dictionary) -> void:
	for listener in _listeners:
		if listener.is_valid():
			listener.call(event)
		else:
			Log.error("AttributeSet", "Error in attribute change listener")

func _invoke_pre_hook(hook_name: String, event: Dictionary) -> Variant:
	var attr_hooks: Dictionary = _hooks.get(event.get("attributeName", ""), {})
	if attr_hooks.has(hook_name):
		var hook: Variant = attr_hooks[hook_name]
		if hook is Callable:
			var result: Variant = hook.call(event)
			if result == false or typeof(result) in [TYPE_INT, TYPE_FLOAT]:
				return result

	if _global_hooks.has(hook_name):
		var global_hook: Variant = _global_hooks[hook_name]
		if global_hook is Callable:
			var result: Variant = global_hook.call(event)
			if result == false or typeof(result) in [TYPE_INT, TYPE_FLOAT]:
				return result

	return null

func _invoke_post_hook(hook_name: String, event: Dictionary) -> void:
	var attr_hooks: Dictionary = _hooks.get(event.get("attributeName", ""), {})
	if attr_hooks.has(hook_name):
		var hook: Variant = attr_hooks[hook_name]
		if hook is Callable:
			hook.call(event)

	if _global_hooks.has(hook_name):
		var global_hook: Variant = _global_hooks[hook_name]
		if global_hook is Callable:
			global_hook.call(event)

## 内部辅助：从 _modifiers Dictionary 取出类型化数组
func _get_modifiers_typed(name: String) -> Array[AttributeModifier]:
	var raw_array: Variant = _modifiers.get(name, [])
	if raw_array is Array[AttributeModifier]:
		return raw_array
	# 兜底：空数组情况
	var typed: Array[AttributeModifier] = []
	for item in raw_array:
		if item is AttributeModifier:
			typed.append(item)
	return typed
