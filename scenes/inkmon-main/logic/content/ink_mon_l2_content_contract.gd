class_name InkMonL2ContentContract


const SCHEMA_ID := "inkmon.l2.content.v2"
const VERSION := 2
const REQUIRED_UNIT_STATS: Array[String] = ["max_hp", "ad", "ap", "armor", "mr", "speed"]
const VALID_STAGES: Array[String] = ["baby", "mature", "adult"]
const VALID_SKILL_CHANNELS: Array[String] = ["physical", "magical", "utility"]

## species_id 形状 `^mon_\d+$` (adr/0010): canon 在 POST 时 MAX+1 发号, godot 防御性复检。
## 编译一次复用 (校验是冷路径, RegEx 开销可接受)。
static var _species_id_re: RegEx = null


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
		# v2 (adr/0010): 进化拓扑 = 根级 edge-list 森林, 不再 per-unit evolves_to。godot 的
		# stub 自描述里物种=8 个 baby default-roster, 其进化目标 (cinder_fox 等) 不在 units 内,
		# 发边会悬空引用 → 自描述发空森林。stub 模式真实进化拓扑住 catalog _build_table fallback。
		"evolution_edges": [],
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


# Validates a v2 creature-base contract (the server canon projection): schema/version
# + per-unit id(=species_id `^mon_\d+$`)/display_name/stage/elements/base_stats, plus the
# root-level evolution_edges forest. Unlike validate_export it does NOT require
# skill bindings, skill_pools, skills, or items — the server projects creature bases +
# topology alone (godot owns AI personality derivation [interim, adr/0008] + skill data + condition evaluation).
# v2 break (adr/0010): identity moved species→id, per-unit evolves_to removed (topology
# is now the root edge-list). Edge checks are DEFENSIVE (structure + bundle-local
# references); single-parent/acyclic/stage-monotonic are the server's hard gate (spec §3).
static func validate_creature_base(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if str(data.get("schema", "")) != SCHEMA_ID:
		errors.append("schema must be %s" % SCHEMA_ID)
	if int(data.get("version", 0)) != VERSION:
		errors.append("version must be %d" % VERSION)
	var unit_ids := _validate_creature_units(data.get("units", []), errors)
	_validate_evolution_edges(data.get("evolution_edges", []), unit_ids, errors)
	return errors


# Returns the collected valid unit ids (for the edge reference check). Empty units is
# VALID: a fresh/empty canon serves a valid (creature-less) contract (lab returns
# units:[] for an empty DB). Only malformed entries fail.
# NOTE: `value as Array` on a wrong-typed value raises "Invalid cast" and ABORTS this
# function — so a `== null` guard is dead code and malformed input would be silently
# accepted. This validator gates untrusted server JSON, so it must use `is` type tests.
# (validate_export's internal-only helpers still use the older as/null idiom; harmless
# there because they only ever see build_current_stub_export output, never external input.)
static func _validate_creature_units(value: Variant, errors: Array[String]) -> Array[String]:
	var ids: Array[String] = []
	if not (value is Array):
		errors.append("units must be an array")
		return ids
	var units: Array = value
	for i in range(units.size()):
		if not (units[i] is Dictionary):
			errors.append("units[%d] must be an object" % i)
			continue
		var unit: Dictionary = units[i]
		# id = species_id (mon_NNNN). display_name = name_en (display, non-empty). No
		# `species` field in v2 (identity is the id).
		_require_species_id(unit.get("id"), "units[%d].id" % i, errors)
		_require_string(unit, "display_name", "units[%d]" % i, errors)
		_require_enum(unit, "stage", VALID_STAGES, "units[%d]" % i, errors)
		_validate_elements(unit.get("elements", []), "units[%d].elements" % i, errors)
		_validate_unit_stats(unit.get("base_stats", {}), "units[%d].base_stats" % i, errors)
		var id_value := str(unit.get("id", ""))
		if id_value != "":
			# Defensive (server is the hard uniqueness gate, spec §3): catch a duplicate
			# species_id here so it surfaces as a validation error instead of silently
			# overwriting the earlier creature base in the static content table.
			if id_value in ids:
				errors.append("units[%d].id duplicate species_id: %s" % [i, id_value])
			ids.append(id_value)
	return ids


# Root-level evolution forest (edge-list). OPTIONAL: a chain-less/creature-less canon
# serves [] (or omits it). Defensive checks only — each edge's parent/child must be a
# species_id shape AND reference a unit in THIS bundle; trigger.level required positive
# int; trigger.condition optional + STRUCTURAL only (type non-empty string, params object
# — canon is semantics-blind, godot evaluates by type at runtime, see adr/0010 + spec §2.1).
static func _validate_evolution_edges(value: Variant, unit_ids: Array[String], errors: Array[String]) -> void:
	if not (value is Array):
		errors.append("evolution_edges must be an array")
		return
	var edges: Array = value
	for i in range(edges.size()):
		if not (edges[i] is Dictionary):
			errors.append("evolution_edges[%d] must be an object" % i)
			continue
		var edge: Dictionary = edges[i]
		var label := "evolution_edges[%d]" % i
		_require_edge_ref(edge.get("parent_species_id"), "%s.parent_species_id" % label, unit_ids, errors)
		_require_edge_ref(edge.get("child_species_id"), "%s.child_species_id" % label, unit_ids, errors)
		_validate_edge_trigger(edge.get("trigger"), "%s.trigger" % label, errors)


static func _validate_edge_trigger(value: Variant, label: String, errors: Array[String]) -> void:
	if not (value is Dictionary):
		errors.append("%s must be an object" % label)
		return
	var trigger: Dictionary = value
	if not trigger.has("level"):
		errors.append("%s.level is required" % label)
	else:
		var level: Variant = trigger.get("level")
		var level_number := float(level) if (level is int or level is float) else NAN
		if (
			is_nan(level_number)
			or is_inf(level_number)
			or level_number <= 0.0
			or absf(level_number - float(int(level_number))) > 0.0
		):
			errors.append("%s.level must be a positive integer" % label)
	if trigger.has("condition"):
		_validate_edge_condition(trigger.get("condition"), "%s.condition" % label, errors)


static func _validate_edge_condition(value: Variant, label: String, errors: Array[String]) -> void:
	# Structure only: canon does NOT enum-check `type` nor inspect `params` semantics
	# (so adding a condition type does not bump the schema). godot dispatches by type.
	if not (value is Dictionary):
		errors.append("%s must be an object" % label)
		return
	var condition: Dictionary = value
	if str(condition.get("type", "")) == "":
		errors.append("%s.type must be a non-empty string" % label)
	if not (condition.get("params", {}) is Dictionary):
		errors.append("%s.params must be an object" % label)


# species_id shape check (`^mon_\d+$`). Used for unit.id and edge parent/child refs.
static func _require_species_id(value: Variant, label: String, errors: Array[String]) -> void:
	var id_value := str(value) if (value is String) else ""
	if id_value == "":
		errors.append("%s must be a non-empty species_id string" % label)
		return
	if not _is_species_id(id_value):
		errors.append("%s must match ^mon_\\d+$ (species_id), got: %s" % [label, id_value])


# Edge endpoint: species_id shape AND must reference a unit present in this bundle.
static func _require_edge_ref(value: Variant, label: String, unit_ids: Array[String], errors: Array[String]) -> void:
	var before := errors.size()
	_require_species_id(value, label, errors)
	if errors.size() != before:
		return  # already malformed; skip the reference check to avoid double noise
	var id_value := str(value)
	if not id_value in unit_ids:
		errors.append("%s references unknown unit: %s" % [label, id_value])


static func _is_species_id(value: String) -> bool:
	if _species_id_re == null:
		_species_id_re = RegEx.create_from_string("^mon_[0-9]+$")
	return _species_id_re.search(value) != null


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
		var raw_stat: Variant = stats.get(stat_key)
		if not (raw_stat is int or raw_stat is float):
			errors.append("%s.%s must be a number" % [label, stat_key])
			continue
		var stat_value := float(raw_stat)
		if is_nan(stat_value) or is_inf(stat_value):
			errors.append("%s.%s must be finite" % [label, stat_key])
			continue
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
