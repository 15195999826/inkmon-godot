class_name InkMonL2ContentContract


const SCHEMA_ID := "inkmon.l2.content.v1"
const VERSION := 1
const REQUIRED_UNIT_STATS: Array[String] = ["max_hp", "ad", "ap", "armor", "mr", "speed"]
const VALID_STAGES: Array[String] = ["baby", "mature", "adult"]
const VALID_SKILL_CHANNELS: Array[String] = ["physical", "magical", "utility"]


static func build_current_stub_export() -> Dictionary:
	var units: Array[Dictionary] = []
	var skill_pools_by_id := {}
	var unit_keys := InkMonUnitConfig.get_default_roster(0)
	unit_keys.append_array(InkMonUnitConfig.get_default_roster(1))

	for unit_key in unit_keys:
		var cfg := InkMonUnitConfig.get_unit_config(unit_key)
		var pool_id := _skill_pool_id(cfg.stage, 1)
		units.append({
			"id": cfg.key,
			"display_name": cfg.display_name,
			"species": cfg.species,
			"stage": cfg.stage,
			"elements": cfg.elements.duplicate(),
			"base_stats": _export_unit_stats(cfg.stats),
			"fallback_active_skill_id": cfg.active_skill_id,
			"skill_slots": [{
				"slot": 1,
				"pool_id": pool_id,
			}],
		})
		if not skill_pools_by_id.has(pool_id):
			skill_pools_by_id[pool_id] = {
				"id": pool_id,
				"stage": cfg.stage,
				"slot": 1,
				"skill_ids": [cfg.active_skill_id],
			}
		elif not cfg.active_skill_id in (skill_pools_by_id[pool_id]["skill_ids"] as Array):
			(skill_pools_by_id[pool_id]["skill_ids"] as Array).append(cfg.active_skill_id)

	var skill_pools: Array[Dictionary] = []
	var pool_ids := skill_pools_by_id.keys()
	pool_ids.sort()
	for pool_id in pool_ids:
		skill_pools.append((skill_pools_by_id[pool_id] as Dictionary).duplicate(true))

	return {
		"schema": SCHEMA_ID,
		"version": VERSION,
		"status": "stub_contract",
		"units": units,
		"skill_pools": skill_pools,
		"skills": _skill_exports(),
		"items": _item_exports(),
		"notes": {
			"current_import_mode": "validation_only",
			"current_runtime_source": "project-local hardcoded stub configs",
			"future_runtime_source": "lab-generated JSON after validation passes",
		},
	}


static func validate_export(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if str(data.get("schema", "")) != SCHEMA_ID:
		errors.append("schema must be %s" % SCHEMA_ID)
	if int(data.get("version", 0)) != VERSION:
		errors.append("version must be %d" % VERSION)

	var skill_ids := _collect_ids(data.get("skills", []), "skills", errors)
	var pool_ids := _collect_ids(data.get("skill_pools", []), "skill_pools", errors)
	_validate_units(data.get("units", []), skill_ids, pool_ids, errors)
	_validate_skill_pools(data.get("skill_pools", []), skill_ids, errors)
	_validate_skills(data.get("skills", []), errors)
	_validate_items(data.get("items", []), errors)
	return errors


# Validates a creature-base contract (the server canon projection): schema/version
# + per-unit id/species/stage/elements/base_stats only. Unlike validate_export it
# does NOT require role, skill bindings, skill_pools, skills, or items — the server
# projects creature bases alone (godot owns role derivation + skill data). evolves_to
# is optional; when present it must be an array of non-empty species strings.
static func validate_creature_base(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if str(data.get("schema", "")) != SCHEMA_ID:
		errors.append("schema must be %s" % SCHEMA_ID)
	if int(data.get("version", 0)) != VERSION:
		errors.append("version must be %d" % VERSION)
	_validate_creature_units(data.get("units", []), errors)
	return errors


static func _validate_creature_units(value: Variant, errors: Array[String]) -> void:
	# NOTE: `value as Array` on a wrong-typed value raises "Invalid cast" and ABORTS
	# this function (it does NOT return null) — so a `== null` guard is dead code and
	# malformed input would be silently accepted. This validator gates untrusted
	# server JSON, so it must use `is` type tests. (validate_export's internal-only
	# helpers still use the as/null idiom; they only ever see well-formed self-check
	# input — see Progress.md Open Review Findings.)
	var units: Array = value if value is Array else []
	if units.is_empty():
		errors.append("units must be a non-empty array")
		return
	for i in range(units.size()):
		if not (units[i] is Dictionary):
			errors.append("units[%d] must be an object" % i)
			continue
		var unit: Dictionary = units[i]
		_require_string(unit, "id", "units[%d]" % i, errors)
		_require_string(unit, "species", "units[%d]" % i, errors)
		_require_enum(unit, "stage", VALID_STAGES, "units[%d]" % i, errors)
		_validate_elements(unit.get("elements", []), "units[%d].elements" % i, errors)
		_validate_unit_stats(unit.get("base_stats", {}), "units[%d].base_stats" % i, errors)
		if unit.has("evolves_to"):
			_validate_evolves_to(unit.get("evolves_to"), "units[%d].evolves_to" % i, errors)


static func _validate_evolves_to(value: Variant, label: String, errors: Array[String]) -> void:
	if not (value is Array):
		errors.append("%s must be an array" % label)
		return
	var entries: Array = value
	for entry in entries:
		if not (entry is String) or str(entry) == "":
			errors.append("%s entries must be non-empty species strings" % label)
			return


static func _validate_units(
	value: Variant,
	skill_ids: Array[String],
	pool_ids: Array[String],
	errors: Array[String]
) -> void:
	var units := value as Array
	if units == null or units.is_empty():
		errors.append("units must be a non-empty array")
		return
	for i in range(units.size()):
		var unit := units[i] as Dictionary
		if unit == null:
			errors.append("units[%d] must be an object" % i)
			continue
		_require_string(unit, "id", "units[%d]" % i, errors)
		_require_string(unit, "species", "units[%d]" % i, errors)
		_require_enum(unit, "stage", VALID_STAGES, "units[%d]" % i, errors)
		_validate_elements(unit.get("elements", []), "units[%d].elements" % i, errors)
		_validate_unit_stats(unit.get("base_stats", {}), "units[%d].base_stats" % i, errors)

		var fallback_skill := str(unit.get("fallback_active_skill_id", ""))
		if fallback_skill == "" or not fallback_skill in skill_ids:
			errors.append("units[%d].fallback_active_skill_id must reference skills" % i)
		var slots := unit.get("skill_slots", []) as Array
		if slots == null or slots.is_empty():
			errors.append("units[%d].skill_slots must be non-empty" % i)
			continue
		for slot_index in range(slots.size()):
			var slot := slots[slot_index] as Dictionary
			if slot == null:
				errors.append("units[%d].skill_slots[%d] must be an object" % [i, slot_index])
				continue
			if int(slot.get("slot", 0)) <= 0:
				errors.append("units[%d].skill_slots[%d].slot must be positive" % [i, slot_index])
			var pool_id := str(slot.get("pool_id", ""))
			if pool_id == "" or not pool_id in pool_ids:
				errors.append("units[%d].skill_slots[%d].pool_id must reference skill_pools" % [i, slot_index])


static func _validate_skill_pools(value: Variant, skill_ids: Array[String], errors: Array[String]) -> void:
	var pools := value as Array
	if pools == null or pools.is_empty():
		errors.append("skill_pools must be a non-empty array")
		return
	for i in range(pools.size()):
		var pool := pools[i] as Dictionary
		if pool == null:
			errors.append("skill_pools[%d] must be an object" % i)
			continue
		_require_string(pool, "id", "skill_pools[%d]" % i, errors)
		_require_enum(pool, "stage", VALID_STAGES, "skill_pools[%d]" % i, errors)
		if int(pool.get("slot", 0)) <= 0:
			errors.append("skill_pools[%d].slot must be positive" % i)
		var pool_skill_ids := pool.get("skill_ids", []) as Array
		if pool_skill_ids == null or pool_skill_ids.is_empty():
			errors.append("skill_pools[%d].skill_ids must be non-empty" % i)
			continue
		for skill_value in pool_skill_ids:
			var skill_id := str(skill_value)
			if not skill_id in skill_ids:
				errors.append("skill_pools[%d].skill_ids references unknown skill: %s" % [i, skill_id])


static func _validate_skills(value: Variant, errors: Array[String]) -> void:
	var skills := value as Array
	if skills == null or skills.is_empty():
		errors.append("skills must be a non-empty array")
		return
	for i in range(skills.size()):
		var skill := skills[i] as Dictionary
		if skill == null:
			errors.append("skills[%d] must be an object" % i)
			continue
		_require_string(skill, "id", "skills[%d]" % i, errors)
		_require_string(skill, "implementation_key", "skills[%d]" % i, errors)
		_require_enum(skill, "channel", VALID_SKILL_CHANNELS, "skills[%d]" % i, errors)
		_validate_elements([str(skill.get("element", ""))], "skills[%d].element" % i, errors)


static func _validate_items(value: Variant, errors: Array[String]) -> void:
	var items := value as Array
	if items == null or items.is_empty():
		errors.append("items must be a non-empty array")
		return
	for i in range(items.size()):
		var item := items[i] as Dictionary
		if item == null:
			errors.append("items[%d] must be an object" % i)
			continue
		_require_string(item, "id", "items[%d]" % i, errors)
		_require_string(item, "display_name", "items[%d]" % i, errors)
		if int(item.get("price", -1)) < 0:
			errors.append("items[%d].price must be >= 0" % i)
		var tags := item.get("item_tags", []) as Array
		if tags == null:
			errors.append("items[%d].item_tags must be an array" % i)


static func _collect_ids(value: Variant, label: String, errors: Array[String]) -> Array[String]:
	var result: Array[String] = []
	var entries := value as Array
	if entries == null:
		errors.append("%s must be an array" % label)
		return result
	for i in range(entries.size()):
		var entry := entries[i] as Dictionary
		if entry == null:
			continue
		var id_value := str(entry.get("id", ""))
		if id_value == "":
			continue
		if id_value in result:
			errors.append("%s duplicate id: %s" % [label, id_value])
		result.append(id_value)
	return result


static func _validate_unit_stats(value: Variant, label: String, errors: Array[String]) -> void:
	# `is` guard, not `value as Dictionary` (which aborts on wrong type — see
	# _validate_creature_units). Shared by validate_creature_base (untrusted) and
	# validate_export, so it must reject a non-object base_stats cleanly.
	if not (value is Dictionary):
		errors.append("%s must be an object" % label)
		return
	var stats: Dictionary = value
	for stat_key in REQUIRED_UNIT_STATS:
		if not stats.has(stat_key):
			errors.append("%s missing %s" % [label, stat_key])
			continue
		var stat_value := float(stats.get(stat_key, 0.0))
		if stat_key in ["max_hp", "speed"] and stat_value <= 0.0:
			errors.append("%s.%s must be > 0" % [label, stat_key])
		elif stat_value < 0.0:
			errors.append("%s.%s must be >= 0" % [label, stat_key])


static func _validate_elements(value: Variant, label: String, errors: Array[String]) -> void:
	# `is` guard, not `value as Array` (which aborts on wrong type — see
	# _validate_creature_units). Shared by validate_creature_base (untrusted).
	var elements: Array = value if value is Array else []
	if elements.is_empty():
		errors.append("%s must be a non-empty array" % label)
		return
	var valid_elements := InkMonElementChart.all_elements()
	for element_value in elements:
		var element := str(element_value)
		if not element in valid_elements:
			errors.append("%s contains unknown element: %s" % [label, element])


static func _require_string(data: Dictionary, key: String, label: String, errors: Array[String]) -> void:
	if str(data.get(key, "")) == "":
		errors.append("%s.%s must be a non-empty string" % [label, key])


static func _require_enum(
	data: Dictionary,
	key: String,
	valid_values: Array[String],
	label: String,
	errors: Array[String]
) -> void:
	var value := str(data.get(key, ""))
	if not value in valid_values:
		errors.append("%s.%s has invalid value: %s" % [label, key, value])


static func _export_unit_stats(stats: Dictionary) -> Dictionary:
	var result := {}
	for stat_key in REQUIRED_UNIT_STATS:
		result[stat_key] = float(stats.get(stat_key, 0.0))
	return result


static func _skill_pool_id(stage: String, slot: int) -> String:
	return "%s.slot_%d" % [stage, slot]


static func _skill_exports() -> Array[Dictionary]:
	return [
		_skill_export(InkMonStun.CONFIG_ID, "InkMonStun", InkMonElementChart.WATER, "utility"),
		_skill_export(InkMonFireball.CONFIG_ID, "InkMonFireball", InkMonElementChart.FIRE, "magical"),
		_skill_export(InkMonHolyHeal.CONFIG_ID, "InkMonHolyHeal", InkMonElementChart.LIGHT, "utility"),
		_skill_export(InkMonChainLightning.CONFIG_ID, "InkMonChainLightning", InkMonElementChart.WIND, "magical"),
		_skill_export(InkMonPoison.CONFIG_ID, "InkMonPoison", InkMonElementChart.DARK, "utility"),
	]


static func _skill_export(id_value: String, implementation_key: String, element: String, channel: String) -> Dictionary:
	return {
		"id": id_value,
		"implementation_key": implementation_key,
		"element": element,
		"channel": channel,
	}


static func _item_exports() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var catalog := InkMonItemCatalog.new()
	for config_id in catalog.list_config_ids():
		var config := catalog.get_config(config_id)
		result.append({
			"id": str(config_id),
			"display_name": str(config.get("display_name", str(config_id))),
			"item_tags": (config.get("item_tags", []) as Array).duplicate(),
			"price": int(config.get("price", 0)),
			"equipable": bool(config.get("equipable", false)),
			"stat_mods": (config.get("stat_mods", {}) as Dictionary).duplicate(true),
		})
	return result
