extends RefCounted
class_name MutableEvent

var original: Dictionary
var phase: String
var cancelled := false
var cancel_reason := ""
var cancelled_by := ""
var _modifications: Array[Dictionary] = []

func _init(original_event: Dictionary, phase_value: String):
	original = original_event
	phase = phase_value

func get_modifications() -> Array[Dictionary]:
	return _modifications

func add_modification(modification: Dictionary) -> void:
	_modifications.append(modification)

func add_modifications(modifications: Array) -> void:
	_modifications.append_array(modifications)

func cancel(handler_id: String, reason: String) -> void:
	cancelled = true
	cancelled_by = handler_id
	cancel_reason = reason

func get_current_value(field: String) -> Variant:
	var original_value = original.get(field, null)
	if typeof(original_value) not in [TYPE_INT, TYPE_FLOAT]:
		return original_value

	var grouped := _get_grouped_field_mods(field)
	if grouped.is_empty:
		return original_value

	return _compute_value(float(original_value), grouped)

func to_final_event() -> Dictionary:
	if _modifications.is_empty():
		return original

	var final_event := original.duplicate(true)
	for field in _get_modified_fields():
		final_event[field] = get_current_value(field)
	return final_event

func get_original_values() -> Dictionary:
	var result := {}
	for field in _get_modified_fields():
		result[field] = original.get(field, null)
	return result

func get_final_values() -> Dictionary:
	var result := {}
	for field in _get_modified_fields():
		result[field] = get_current_value(field)
	return result

func get_field_computation_steps(field: String) -> Variant:
	var original_value = original.get(field, null)
	if typeof(original_value) not in [TYPE_INT, TYPE_FLOAT]:
		return null

	var grouped := _get_grouped_field_mods(field)
	if grouped.is_empty:
		return null

	var steps := []
	var value := float(original_value)

	if not grouped.sets.is_empty():
		var last_set: Dictionary = grouped.sets[-1]
		value = float(last_set.get("value", value))
		steps.append(_create_step(last_set, "set", value))

	for mod in grouped.adds:
		value += float(mod.get("value", 0.0))
		steps.append(_create_step(mod, "add", value))

	for mod in grouped.muls:
		value *= float(mod.get("value", 1.0))
		steps.append(_create_step(mod, "multiply", value))

	return {
		"field": field,
		"originalValue": original_value,
		"finalValue": value,
		"steps": steps,
	}

func get_all_computation_steps() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for field in _get_modified_fields():
		var record = get_field_computation_steps(str(field))
		if record:
			records.append(record)
	return records

func format_computation_log(field: String) -> String:
	var record = get_field_computation_steps(field)
	if record == null:
		return "%s: no modifications" % field

	var lines := ["%s: %s \t \t%s" % [field, str(record["originalValue"]), str(record["finalValue"])]]

	for step in record["steps"]:
		var source: String = str(step.get("sourceName", "")) if step.get("sourceName") else str(step.get("sourceId", "unknown"))
		var op_sign := _get_operation_sign(step)
		lines.append("  [%s] %s%s -> %s" % [source, op_sign, str(step.get("value", "")), str(step.get("resultValue", ""))])

	return "\n".join(lines)

func _get_modified_fields() -> Array[String]:
	var fields := {}
	for mod in _modifications:
		fields[mod.get("field", "")] = true
	var result: Array[String] = []
	result.assign(fields.keys())
	return result

func _get_grouped_field_mods(field: String) -> Dictionary:
	var sets := []
	var adds := []
	var muls := []

	for mod in _modifications:
		if mod.get("field", "") != field:
			continue
		match mod.get("operation", ""):
			"set":
				sets.append(mod)
			"add":
				adds.append(mod)
			"multiply":
				muls.append(mod)

	return {
		"sets": sets,
		"adds": adds,
		"muls": muls,
		"is_empty": sets.is_empty() and adds.is_empty() and muls.is_empty(),
	}

func _compute_value(base_value: float, grouped: Dictionary) -> float:
	var value := base_value
	if not grouped.sets.is_empty():
		value = float(grouped.sets[-1].get("value", value))
	for mod in grouped.adds:
		value += float(mod.get("value", 0.0))
	for mod in grouped.muls:
		value *= float(mod.get("value", 1.0))
	return value

func _create_step(mod: Dictionary, operation: String, result_value: float) -> Dictionary:
	return {
		"sourceId": mod.get("sourceId", "unknown"),
		"sourceName": mod.get("sourceName", null),
		"operation": operation,
		"value": mod.get("value", 0.0),
		"resultValue": result_value,
	}

func _get_operation_sign(step: Dictionary) -> String:
	match step.get("operation", ""):
		"add":
			return "+" if float(step.get("value", 0.0)) >= 0 else ""
		"multiply":
			return "x"
		_:
			return "="
