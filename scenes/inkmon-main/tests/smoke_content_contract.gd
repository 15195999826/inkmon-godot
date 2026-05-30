extends Node


func _ready() -> void:
	var status := _run()
	if status == "":
		print("SMOKE_TEST_RESULT: PASS - InkMon L2 content contract validates the current stub export")
		get_tree().quit(0)
	else:
		print("SMOKE_TEST_RESULT: FAIL - %s" % status)
		get_tree().quit(1)


func _run() -> String:
	var export_data := InkMonL2ContentContract.build_current_stub_export()
	var errors := InkMonL2ContentContract.validate_export(export_data)
	if not errors.is_empty():
		return "current stub export should validate: %s" % JSON.stringify(errors)
	if str(export_data.get("schema", "")) != InkMonL2ContentContract.SCHEMA_ID:
		return "stub export schema mismatch"
	if (export_data.get("units", []) as Array).size() != 8:
		return "stub export should contain 8 current M1 unit configs"
	if _has_key_recursive(export_data, "bst") or _has_key_recursive(export_data, "special_attack"):
		return "content contract should not carry old canon stat keys"

	var parsed: Variant = JSON.parse_string(JSON.stringify(export_data))
	var round_trip := parsed as Dictionary
	if round_trip == null:
		return "stub export JSON round-trip did not return an object"
	var round_trip_errors := InkMonL2ContentContract.validate_export(round_trip)
	if not round_trip_errors.is_empty():
		return "round-tripped export should validate: %s" % JSON.stringify(round_trip_errors)

	var invalid := export_data.duplicate(true)
	var invalid_units := invalid.get("units", []) as Array
	var first_unit := invalid_units[0] as Dictionary
	first_unit.erase("role")
	var invalid_errors := InkMonL2ContentContract.validate_export(invalid)
	if invalid_errors.is_empty():
		return "validator should reject a unit without role"
	return ""


func _has_key_recursive(value: Variant, key: String) -> bool:
	var dict_value := value as Dictionary
	if dict_value != null:
		if dict_value.has(key):
			return true
		for child in dict_value.values():
			if _has_key_recursive(child, key):
				return true
		return false
	var array_value := value as Array
	if array_value != null:
		for child in array_value:
			if _has_key_recursive(child, key):
				return true
	return false
