class_name RawAttributeSet
extends RefCounted

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
		var min_val := -INF if attr.get("minValue") == null else float(attr.get("minValue"))
		var max_val := INF if attr.get("maxValue") == null else float(attr.get("maxValue"))
		define_attribute(str(attr.get("name", "")), float(attr.get("baseValue", 0.0)), min_val, max_val)

func define_attribute(attr_name: String, base_value: float, min_value: float = -INF, max_value: float = INF) -> void:
	if attr_name == "":
		return
	_base_values[attr_name] = base_value
	var empty_mods: Array[AttributeModifier] = []
	_modifiers[attr_name] = empty_mods
	_dirty_set[attr_name] = true
	if min_value != -INF or max_value != INF:
		_constraints[attr_name] = {"min": min_value, "max": max_value}

func has_attribute(attr_name: String) -> bool:
	return _base_values.has(attr_name)


func get_base(attr_name: String) -> float:
	if not _base_values.has(attr_name):
		Log.warning("AttributeSet", "Attribute not found: %s" % attr_name)
		return 0.0
	return float(_base_values[attr_name])


func set_base(attr_name: String, value: float) -> void:
	if not _base_values.has(attr_name):
		Log.warning("AttributeSet", "Attribute not found: %s" % attr_name)
		return

	var old_value := float(_base_values[attr_name])
	var clamped_value := _clamp_value(attr_name, value)
	if old_value == clamped_value:
		return

	var event := {
		"attributeName": attr_name,
		"oldValue": old_value,
		"newValue": clamped_value,
		"changeType": _CHANGE_TYPE_BASE,
	}

	var hook_result: Variant = _invoke_pre_hook("preBaseChange", event)
	if hook_result == false:
		return

	var final_value := clamped_value
	if typeof(hook_result) in [TYPE_INT, TYPE_FLOAT]:
		final_value = _clamp_value(attr_name, float(hook_result))

	_base_values[attr_name] = final_value
	_mark_dirty(attr_name)

	var final_event := event.duplicate(true)
	final_event["newValue"] = final_value

	_invoke_post_hook("postBaseChange", final_event)
	_notify_change(final_event)


func get_body_value(attr_name: String) -> float:
	return get_breakdown(attr_name).body_value


func get_current_value(attr_name: String) -> float:
	return get_breakdown(attr_name).current_value


func get_breakdown(attr_name: String) -> AttributeBreakdown:
	if _computing_set.has(attr_name):
		Log.warning("AttributeSet", "Circular dependency detected for attribute: %s" % attr_name)
		if _cache.has(attr_name):
			return _cache[attr_name] as AttributeBreakdown
		var fallback_base := float(_base_values.get(attr_name, 0.0))
		return AttributeBreakdown.from_base(fallback_base)

	if not _dirty_set.has(attr_name) and _cache.has(attr_name):
		return _cache[attr_name] as AttributeBreakdown

	_computing_set[attr_name] = true
	var base_value := float(_base_values.get(attr_name, 0.0))
	var mods := _get_modifiers_typed(attr_name)
	var breakdown := AttributeCalculator.calculate(base_value, mods)

	var clamped_current := _clamp_value(attr_name, breakdown.current_value)
	if clamped_current != breakdown.current_value:
		breakdown = breakdown.with_clamped_value(clamped_current)

	_cache[attr_name] = breakdown
	_dirty_set.erase(attr_name)
	_computing_set.erase(attr_name)
	return breakdown


func get_add_base_sum(attr_name: String) -> float:
	return get_breakdown(attr_name).add_base_sum


func get_mul_base_product(attr_name: String) -> float:
	return get_breakdown(attr_name).mul_base_product


func get_add_final_sum(attr_name: String) -> float:
	return get_breakdown(attr_name).add_final_sum


func get_mul_final_product(attr_name: String) -> float:
	return get_breakdown(attr_name).mul_final_product


func add_modifier(modifier: AttributeModifier) -> void:
	if not _modifiers.has(modifier.attribute_name):
		Log.warning("AttributeSet", "Attribute not found for modifier: %s" % modifier.attribute_name)
		return

	var mods := _get_modifiers_typed(modifier.attribute_name)
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
		var mods := _get_modifiers_typed(attr_name)
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
		var mods := _get_modifiers_typed(attr_name)
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


func get_modifiers(attr_name: String) -> Array[AttributeModifier]:
	return _get_modifiers_typed(attr_name)


func has_modifier(modifier_id: String) -> bool:
	for attr_name in _modifiers.keys():
		var mods := _get_modifiers_typed(attr_name)
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

func set_hooks(attr_name: String, hooks: Dictionary) -> void:
	if not _hooks.has(attr_name):
		_hooks[attr_name] = hooks.duplicate(true)
		return
	var existing: Dictionary = _hooks[attr_name]
	existing.merge(hooks, true)


func get_hooks(attr_name: String) -> Dictionary:
	return _hooks.get(attr_name, {})


func remove_hooks(attr_name: String) -> void:
	_hooks.erase(attr_name)


func set_global_hooks(hooks: Dictionary) -> void:
	_global_hooks.merge(hooks, true)


func get_global_hooks() -> Dictionary:
	return _global_hooks.duplicate(true)


func clear_global_hooks() -> void:
	_global_hooks.clear()


func apply_config(config: Dictionary) -> void:
	for attr_name in config.keys():
		var cfg: Dictionary = config[attr_name]
		var min_val := -INF if cfg.get("minValue") == null else float(cfg.get("minValue"))
		var max_val := INF if cfg.get("maxValue") == null else float(cfg.get("maxValue"))
		define_attribute(str(attr_name), float(cfg.get("baseValue", 0.0)), min_val, max_val)

func on_attribute_changed(attr_name: String, callback: Callable) -> Callable:
	var filtered_listener := func(event: Dictionary) -> void:
		if event.get("attributeName", "") == attr_name:
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
	for attr_name in _base_values.keys():
		var mods := _get_modifiers_typed(attr_name)
		var serialized_mods: Array[Dictionary] = []
		for mod in mods:
			serialized_mods.append(mod.serialize())
		result[attr_name] = {
			"base": float(_base_values[attr_name]),
			"modifiers": serialized_mods,
		}
	return result


static func deserialize(data: Dictionary) -> RawAttributeSet:
	var attr_set := RawAttributeSet.new()
	for attr_name in data.keys():
		var attr_data: Dictionary = data[attr_name]
		attr_set.define_attribute(str(attr_name), float(attr_data.get("base", 0.0)))
		for mod_data in attr_data.get("modifiers", []):
			var mod := AttributeModifier.deserialize(mod_data)
			attr_set.add_modifier(mod)
	return attr_set


func _mark_dirty(attr_name: String) -> void:
	_dirty_set[attr_name] = true


func _clamp_value(attr_name: String, value: float) -> float:
	if not _constraints.has(attr_name):
		return value
	var constraint: Dictionary = _constraints[attr_name]
	return clampf(value, constraint.get("min", -INF), constraint.get("max", INF))


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
func _get_modifiers_typed(attr_name: String) -> Array[AttributeModifier]:
	var raw_array: Variant = _modifiers.get(attr_name, [])
	if raw_array is Array[AttributeModifier]:
		return raw_array
	# 兜底：空数组情况
	var typed: Array[AttributeModifier] = []
	for item in raw_array:
		if item is AttributeModifier:
			typed.append(item)
	return typed
