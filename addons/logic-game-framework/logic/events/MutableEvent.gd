extends RefCounted
class_name MutableEvent

var original: Dictionary
var phase: String
var cancelled := false
var cancel_reason := ""
var cancelled_by := ""
var _modifications: Array = []

func _init(original_event: Dictionary, phase_value: String):
	original = original_event
	phase = phase_value

func get_modifications() -> Array:
	return _modifications

func add_modification(modification: Dictionary) -> void:
	_modifications.append(modification)

func add_modifications(modifications: Array) -> void:
	for modification in modifications:
		_modifications.append(modification)

func cancel(handler_id: String, reason: String) -> void:
	cancelled = true
	cancelled_by = handler_id
	cancel_reason = reason

func get_current_value(field: String):
	var original_value = original.get(field, null)
	if typeof(original_value) not in [TYPE_INT, TYPE_FLOAT]:
		return original_value

	var field_mods := []
	for mod in _modifications:
		if mod.get("field", "") == field:
			field_mods.append(mod)
	if field_mods.is_empty():
		return original_value

	var sets := []
	var adds := []
	var muls := []
	for mod in field_mods:
		match mod.get("operation", ""):
			"set":
				sets.append(mod)
			"add":
				adds.append(mod)
			"multiply":
				muls.append(mod)

	var value := float(original_value)
	if not sets.is_empty():
		value = float(sets[sets.size() - 1].get("value", value))

	for mod in adds:
		value += float(mod.get("value", 0.0))

	for mod in muls:
		value *= float(mod.get("value", 1.0))

	return value

func to_final_event() -> Dictionary:
	if _modifications.is_empty():
		return original

	var modified_fields := {}
	for mod in _modifications:
		modified_fields[mod.get("field", "")] = true

	var final_event := original.duplicate(true)
	for field in modified_fields.keys():
		final_event[field] = get_current_value(field)
	return final_event

func get_original_values() -> Dictionary:
	var result := {}
	var modified_fields := {}
	for mod in _modifications:
		modified_fields[mod.get("field", "")] = true
	for field in modified_fields.keys():
		result[field] = original.get(field, null)
	return result

func get_final_values() -> Dictionary:
	var result := {}
	var modified_fields := {}
	for mod in _modifications:
		modified_fields[mod.get("field", "")] = true
	for field in modified_fields.keys():
		result[field] = get_current_value(field)
	return result

func get_field_computation_steps(field: String):
	var original_value = original.get(field, null)
	if typeof(original_value) not in [TYPE_INT, TYPE_FLOAT]:
		return null

	var field_mods := []
	for mod in _modifications:
		if mod.get("field", "") == field:
			field_mods.append(mod)
	if field_mods.is_empty():
		return null

	var sets := []
	var adds := []
	var muls := []
	for mod in field_mods:
		match mod.get("operation", ""):
			"set":
				sets.append(mod)
			"add":
				adds.append(mod)
			"multiply":
				muls.append(mod)

	var steps := []
	var value := float(original_value)
	if not sets.is_empty():
		var last_set: Dictionary = sets[sets.size() - 1]
		value = float(last_set.get("value", value))
		steps.append({
			"sourceId": last_set.get("sourceId", "unknown"),
			"sourceName": last_set.get("sourceName", null),
			"operation": "set",
			"value": last_set.get("value", 0.0),
			"resultValue": value,
		})

	for mod in adds:
		value += float(mod.get("value", 0.0))
		steps.append({
			"sourceId": mod.get("sourceId", "unknown"),
			"sourceName": mod.get("sourceName", null),
			"operation": "add",
			"value": mod.get("value", 0.0),
			"resultValue": value,
		})

	for mod in muls:
		value *= float(mod.get("value", 1.0))
		steps.append({
			"sourceId": mod.get("sourceId", "unknown"),
			"sourceName": mod.get("sourceName", null),
			"operation": "multiply",
			"value": mod.get("value", 1.0),
			"resultValue": value,
		})

	return {
		"field": field,
		"originalValue": original_value,
		"finalValue": value,
		"steps": steps,
	}

func get_all_computation_steps() -> Array:
	var modified_fields := {}
	for mod in _modifications:
		modified_fields[mod.get("field", "")] = true

	var records := []
	for field in modified_fields.keys():
		var record = get_field_computation_steps(str(field))
		if record != null:
			records.append(record)
	return records

func format_computation_log(field: String) -> String:
	var record = get_field_computation_steps(field)
	if record == null:
		return "%s: no modifications" % field

	var lines := []
	lines.append("%s: %s 	 	%s" % [field, str(record["originalValue"]), str(record["finalValue"])])

	for step in record["steps"]:
		var source_name: String = str(step.get("sourceName", ""))
		var source_id: String = str(step.get("sourceId", "unknown"))
		var source: String = source_name
		if source == "":
			source = source_id
		var op_sign := "="
		if step.get("operation", "") == "add":
			op_sign = "+" if float(step.get("value", 0.0)) >= 0 else ""
		elif step.get("operation", "") == "multiply":
			op_sign = "x"
		lines.append("  [%s] %s%s -> %s" % [source, op_sign, str(step.get("value", "")), str(step.get("resultValue", ""))])

	return "\n".join(lines)
