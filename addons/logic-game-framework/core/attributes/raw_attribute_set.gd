class_name RawAttributeSet
extends RefCounted

const _CHANGE_TYPE_BASE := "base"
const _CHANGE_TYPE_MODIFIER := "modifier"
const _CHANGE_TYPE_CURRENT := "current"

var _base_values: Dictionary = {}
## { String -> Array[AttributeModifier] } 按属性名索引
var _modifiers: Dictionary = {}
## { String -> Array[AttributeModifier] } 按 source 索引，用于快速移除
var _source_index: Dictionary = {}
## { String -> AttributeBreakdown }
var _cache: Dictionary = {}
var _dirty_set: Dictionary = {}
var _computing_set: Dictionary = {}
var _constraints: Dictionary = {}
var _listeners: Array[Callable] = []
var _hooks: Dictionary = {}
var _global_hooks: Dictionary = {}
## current 值变化前的回调，签名: func(attr_name: String, inout_value: Dictionary) -> void
## inout_value = { "value": float }，可直接修改 inout_value["value"] 来调整最终值
var _pre_change_callback: Callable = Callable()

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


## 获取属性的完整计算结果（含循环依赖检测）
##
## 【循环依赖检测说明】
##
## _computing_set 记录当前正在计算的属性。如果在计算 A 的过程中又要计算 A，说明形成了循环。
##
## 【场景 1：动态修改器 —— 血量越高攻击力越高 & 攻击力越高血量越高】
##
## 假设你想实现两个技能：
##   - 技能 A：攻击力 +10% 当前血量
##   - 技能 B：血量 +10% 当前攻击力
##
## 如果用 Listener 实现动态更新修改器：
##   attr_set.add_change_listener(func(event):
##       if event.attributeName == "hp":
##           # hp 变了，重新计算 atk 的修改器值
##           var new_atk_bonus = attr_set.get_current_value("hp") * 0.1
##           update_atk_modifier(new_atk_bonus)
##       if event.attributeName == "atk":
##           # atk 变了，重新计算 hp 的修改器值
##           var new_hp_bonus = attr_set.get_current_value("atk") * 0.1  # ← 可能触发循环
##           update_hp_modifier(new_hp_bonus)
##   )
##
## 执行流程（hp 变化时）：
##   1. hp 变化 → 触发 Listener
##   2. Listener 更新 atk 修改器 → atk 变化 → 触发 Listener
##   3. Listener 内调用 get_current_value("hp") → 此时 hp 可能正在计算中 → 循环！
##
## 【场景 2：约束检查 —— hp 不超过 max_hp】
##
## 用 Hook 实现 hp 上限约束：
##   attr_set.set_global_hooks({
##       "preBaseChange": func(event):
##           if event.attributeName == "hp":
##               var max_hp = attr_set.get_current_value("max_hp")
##               return min(event.newValue, max_hp)
##           if event.attributeName == "max_hp":
##               var hp = attr_set.get_current_value("hp")  # ← 如果 hp 正在计算，触发循环
##               # ... 某些逻辑
##           return null
##   })
##
## 【触发循环后的处理】
##
## 假设 hp: base=100, 有 +20 的修改器，正常计算结果应为 120
##
## 情况 A - 有缓存（hp 之前被计算过，缓存值为 120）：
##   → 返回缓存值 120
##   → 日志：[循环依赖] 属性 'hp' ... 已返回缓存值以中断循环
##
## 情况 B - 无缓存（hp 首次计算就遇到循环）：
##   → 返回 AttributeBreakdown.from_base(100)，即只有基础值，忽略 +20 修改器
##   → 日志：[循环依赖] 属性 'hp' ... 无缓存可用，已返回基础值 100.00 以中断循环
##   → 这意味着：本次计算得到的是不完整的值（少了修改器的加成）
func get_breakdown(attr_name: String) -> AttributeBreakdown:
	if _computing_set.has(attr_name):
		var computing_chain := ", ".join(_computing_set.keys())
		if _cache.has(attr_name):
			Log.warning("AttributeSet",
				"[循环依赖] 属性 '%s' 在计算过程中被再次访问，形成循环。当前计算链: [%s]。已返回缓存值以中断循环。" % [attr_name, computing_chain])
			return _cache[attr_name] as AttributeBreakdown
		var fallback_base := float(_base_values.get(attr_name, 0.0))
		Log.warning("AttributeSet",
			"[循环依赖] 属性 '%s' 在计算过程中被再次访问，形成循环。当前计算链: [%s]。无缓存可用，已返回基础值 %.2f 以中断循环。" % [attr_name, computing_chain, fallback_base])
		return AttributeBreakdown.from_base(fallback_base)

	if not _dirty_set.has(attr_name) and _cache.has(attr_name):
		return _cache[attr_name] as AttributeBreakdown

	_computing_set[attr_name] = true
	var base_value := float(_base_values.get(attr_name, 0.0))
	var mods := _get_modifiers_typed(attr_name)
	var breakdown := AttributeCalculator.calculate(base_value, mods)

	# 1. 先应用 minValue/maxValue 约束
	var clamped_current := _clamp_value(attr_name, breakdown.current_value)
	if clamped_current != breakdown.current_value:
		breakdown = breakdown.with_clamped_value(clamped_current)

	# 2. 再调用 pre_change 回调（允许跨属性约束，如 hp ≤ max_hp）
	if _pre_change_callback.is_valid():
		var inout_value := { "value": breakdown.current_value }
		_pre_change_callback.call(attr_name, inout_value)
		var callback_value: float = inout_value["value"]
		if callback_value != breakdown.current_value:
			breakdown = breakdown.with_clamped_value(callback_value)

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
	_add_to_source_index(modifier)
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
			var removed_mod := mods[index]
			mods.remove_at(index)
			_remove_from_source_index(removed_mod)
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
	if not _source_index.has(source):
		return 0

	var source_mods := _get_source_index_typed(source)
	if source_mods.is_empty():
		return 0

	# 按属性分组，记录需要移除的修改器
	var affected_attrs: Dictionary = {}  # { attr_name -> Array[AttributeModifier] }
	for mod in source_mods:
		if not affected_attrs.has(mod.attribute_name):
			affected_attrs[mod.attribute_name] = []
		affected_attrs[mod.attribute_name].append(mod)

	var count := source_mods.size()

	# 从各属性的修改器列表中移除
	for attr_name in affected_attrs.keys():
		var old_value := get_current_value(attr_name)
		var mods := _get_modifiers_typed(attr_name)
		var to_remove: Array = affected_attrs[attr_name]

		var filtered: Array[AttributeModifier] = []
		for mod in mods:
			if mod.source != source:
				filtered.append(mod)
		_modifiers[attr_name] = filtered
		_mark_dirty(attr_name)

		var new_value := get_current_value(attr_name)
		if old_value != new_value:
			_notify_change({
				"attributeName": attr_name,
				"oldValue": old_value,
				"newValue": new_value,
				"changeType": _CHANGE_TYPE_MODIFIER,
			})

	# 清空 source 索引
	_source_index.erase(source)
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


## 设置 current 值变化前的回调
## 签名: func(attr_name: String, inout_value: Dictionary) -> void
## inout_value = { "value": float }，可直接修改 inout_value["value"] 来调整最终值
##
## 示例：hp 不超过 max_hp
##   attr_set.set_pre_change(func(attr_name: String, inout_value: Dictionary) -> void:
##       if attr_name == "hp":
##           var max_hp := attr_set.get_current_value("max_hp")
##           if inout_value["value"] > max_hp:
##               inout_value["value"] = max_hp
##   )
func set_pre_change(callback: Callable) -> void:
	_pre_change_callback = callback


func clear_pre_change() -> void:
	_pre_change_callback = Callable()


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


## 内部辅助：从 _source_index Dictionary 取出类型化数组
func _get_source_index_typed(source: String) -> Array[AttributeModifier]:
	var raw_array: Variant = _source_index.get(source, [])
	if raw_array is Array[AttributeModifier]:
		return raw_array
	var typed: Array[AttributeModifier] = []
	for item in raw_array:
		if item is AttributeModifier:
			typed.append(item)
	return typed


## 内部辅助：添加修改器到 source 索引
func _add_to_source_index(modifier: AttributeModifier) -> void:
	if modifier.source == "":
		return
	if not _source_index.has(modifier.source):
		var empty_mods: Array[AttributeModifier] = []
		_source_index[modifier.source] = empty_mods
	var source_mods := _get_source_index_typed(modifier.source)
	source_mods.append(modifier)


## 内部辅助：从 source 索引移除修改器
func _remove_from_source_index(modifier: AttributeModifier) -> void:
	if modifier.source == "":
		return
	if not _source_index.has(modifier.source):
		return
	var source_mods := _get_source_index_typed(modifier.source)
	source_mods.erase(modifier)
	if source_mods.is_empty():
		_source_index.erase(modifier.source)
