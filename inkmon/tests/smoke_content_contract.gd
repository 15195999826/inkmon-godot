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

	# role is no longer part of the contract: a unit stripped of role must still validate.
	var role_free := export_data.duplicate(true)
	var role_free_units := role_free.get("units", []) as Array
	(role_free_units[0] as Dictionary).erase("role")
	var role_free_errors := InkMonL2ContentContract.validate_export(role_free)
	if not role_free_errors.is_empty():
		return "validator should accept a unit without role (role removed from contract): %s" % JSON.stringify(role_free_errors)

	# species is still required: stripping it must fail validation.
	var no_species := export_data.duplicate(true)
	var no_species_units := no_species.get("units", []) as Array
	(no_species_units[0] as Dictionary).erase("species")
	var no_species_errors := InkMonL2ContentContract.validate_export(no_species)
	if no_species_errors.is_empty():
		return "validator should reject a unit without species"

	# 类型门 (Wave 2): 字符串 price 不得被吞成数字通过校验 (曾 int("free")==0 → 商店 0 金币可买)。
	var bad_price := export_data.duplicate(true)
	bad_price["items"] = [{
		"id": "item_0001", "display_name": "Free Thing", "icon_key": "icon",
		"item_tags": [], "stat_mods": {}, "price": "free", "max_stack": 1,
		"item_type": "material", "granted_abilities": [],
	}]
	var bad_price_errors := InkMonL2ContentContract.validate_export(bad_price)
	var price_flagged := false
	for error_value in bad_price_errors:
		if str(error_value).contains("price"):
			price_flagged = true
	if not price_flagged:
		return "validator must reject a string price (int type gate), errors=%s" % JSON.stringify(bad_price_errors)

	var creature_base_status := _assert_creature_base_v2()
	if creature_base_status != "":
		return creature_base_status
	return ""


## v2 (adr/0010) creature-base = the server canon projection (validate_creature_base):
## identity = id (= species_id, ^mon_\d+$), display_name = name_en, topology = root
## evolution_edges. Distinct from build_current_stub_export/validate_export (godot's richer
## internal self-export, which still carries species + skill bindings).
func _assert_creature_base_v2() -> String:
	var schema := InkMonL2ContentContract.SCHEMA_ID
	var version := InkMonL2ContentContract.VERSION

	# A valid v2 creature-base (mon_NNNN ids + display_name + root evolution_edges) validates.
	var valid := {
		"schema": schema, "version": version,
		"units": [
			_unit("mon_0001", "Sprout", "baby", ["earth"]),
			_unit("mon_0007", "Emberling", "mature", ["earth", "fire"]),
		],
		"evolution_edges": [{
			"parent_species_id": "mon_0001", "child_species_id": "mon_0007",
			"trigger": {"level": 16, "condition": {"type": "element", "params": {"primary": "fire"}}},
		}],
	}
	if not InkMonL2ContentContract.validate_creature_base(valid).is_empty():
		return "valid v2 creature-base should pass, errors=%s" % JSON.stringify(InkMonL2ContentContract.validate_creature_base(valid))

	# id must be a species_id (^mon_\d+$): a snake/name_en id (v1 shape) is rejected.
	var bad_id := valid.duplicate(true)
	(bad_id["units"][0] as Dictionary)["id"] = "cinder_kit"
	if InkMonL2ContentContract.validate_creature_base(bad_id).is_empty():
		return "validator should reject a non-mon_NNNN id (cinder_kit)"

	# display_name (name_en) is required.
	var no_name := valid.duplicate(true)
	(no_name["units"][0] as Dictionary).erase("display_name")
	if InkMonL2ContentContract.validate_creature_base(no_name).is_empty():
		return "validator should reject a unit without display_name"

	# A full v1-shaped unit (species + per-unit evolves_to, snake id, no display_name) is
	# rejected: identity moved to id=species_id, topology moved to root evolution_edges
	# (per-unit evolves_to is no longer the source of truth — it is not validated/consumed).
	var v1 := {
		"schema": schema, "version": version,
		"units": [{
			"id": "cinder_kit", "species": "cinder_kit", "stage": "baby", "elements": ["fire"],
			"base_stats": {"max_hp": 60, "ad": 30, "ap": 20, "armor": 25, "mr": 20, "speed": 45},
			"evolves_to": ["cinder_fox"],
		}],
	}
	if InkMonL2ContentContract.validate_creature_base(v1).is_empty():
		return "validator should reject the v1 unit shape (snake id + missing display_name)"

	# Non-finite / non-number base_stats must fail before import writes JSON. Otherwise
	# JSON.stringify would silently replace NaN with null.
	var nan_stat := valid.duplicate(true)
	var nan_stats := (nan_stat["units"][0] as Dictionary)["base_stats"] as Dictionary
	nan_stats["max_hp"] = NAN
	if InkMonL2ContentContract.validate_creature_base(nan_stat).is_empty():
		return "validator should reject a NaN base stat"
	var string_stat := valid.duplicate(true)
	var string_stats := (string_stat["units"][0] as Dictionary)["base_stats"] as Dictionary
	string_stats["ad"] = "30"
	if InkMonL2ContentContract.validate_creature_base(string_stat).is_empty():
		return "validator should reject a string base stat"

	# Edge with a dangling child reference (not in this bundle) is rejected.
	var dangling := valid.duplicate(true)
	(dangling["evolution_edges"][0] as Dictionary)["child_species_id"] = "mon_9999"
	if InkMonL2ContentContract.validate_creature_base(dangling).is_empty():
		return "validator should reject an edge with a dangling child reference"

	# trigger.level required + positive.
	var no_level := valid.duplicate(true)
	((no_level["evolution_edges"][0] as Dictionary)["trigger"] as Dictionary).erase("level")
	if InkMonL2ContentContract.validate_creature_base(no_level).is_empty():
		return "validator should reject an edge trigger without level"
	var zero_level := valid.duplicate(true)
	((zero_level["evolution_edges"][0] as Dictionary)["trigger"] as Dictionary)["level"] = 0
	if InkMonL2ContentContract.validate_creature_base(zero_level).is_empty():
		return "validator should reject a non-positive trigger.level"
	var nan_level := valid.duplicate(true)
	((nan_level["evolution_edges"][0] as Dictionary)["trigger"] as Dictionary)["level"] = NAN
	if InkMonL2ContentContract.validate_creature_base(nan_level).is_empty():
		return "validator should reject a NaN trigger.level"

	# condition is structural-only: empty type is rejected, but an UNKNOWN type is ACCEPTED
	# (canon is semantics-blind; godot dispatches by type — adding a type does not bump schema).
	var empty_type := valid.duplicate(true)
	(((empty_type["evolution_edges"][0] as Dictionary)["trigger"] as Dictionary)["condition"] as Dictionary)["type"] = ""
	if InkMonL2ContentContract.validate_creature_base(empty_type).is_empty():
		return "validator should reject a condition with an empty type"
	var unknown_type := valid.duplicate(true)
	(((unknown_type["evolution_edges"][0] as Dictionary)["trigger"] as Dictionary)["condition"] as Dictionary)["type"] = "weather"
	if not InkMonL2ContentContract.validate_creature_base(unknown_type).is_empty():
		return "validator should ACCEPT an unknown condition type (structural-only)"

	# Duplicate species_id is rejected (defensive; server is the hard uniqueness gate). Two
	# units share mon_0001, no edges → the ONLY violation is the duplicate.
	var dup := {
		"schema": schema, "version": version,
		"units": [_unit("mon_0001", "A", "baby", ["earth"]), _unit("mon_0001", "B", "mature", ["fire"])],
	}
	if InkMonL2ContentContract.validate_creature_base(dup).is_empty():
		return "validator should reject a duplicate unit species_id"

	# An edge-less bundle is valid (orphan-only canon).
	var no_edges := {"schema": schema, "version": version, "units": [_unit("mon_0001", "Sprout", "baby", ["earth"])]}
	if not InkMonL2ContentContract.validate_creature_base(no_edges).is_empty():
		return "edge-less creature-base should validate"
	return ""


func _unit(id_value: String, display_name: String, stage: String, elements: Array) -> Dictionary:
	return {
		"id": id_value, "display_name": display_name, "stage": stage, "elements": elements,
		"base_stats": {"max_hp": 60, "ad": 30, "ap": 20, "armor": 25, "mr": 20, "speed": 45},
	}


func _has_key_recursive(value: Variant, key: String) -> bool:
	# `is` tests, not `value as Dictionary/Array`: the latter raises a (non-fatal but
	# noisy) "Invalid cast" on every scalar leaf during recursion.
	if value is Dictionary:
		var dict_value: Dictionary = value
		if dict_value.has(key):
			return true
		for child in dict_value.values():
			if _has_key_recursive(child, key):
				return true
		return false
	if value is Array:
		var array_value: Array = value
		for child in array_value:
			if _has_key_recursive(child, key):
				return true
	return false
