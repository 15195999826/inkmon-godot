class_name InkMonRosterEntry
extends RefCounted


const STAT_KEYS: Array[String] = ["max_hp", "ad", "ap", "armor", "mr", "speed"]


var entry_id := 0
var species := ""
var stage := ""
var role := ""
var elements: Array[String] = []
var level := 1
var exp := 0
var persistent_stats: Dictionary = {}
var learned_skill_id := ""
var equipment_container := ""
var medals: Array[String] = []


static func from_unit_config(p_entry_id: int, unit_key: String) -> InkMonRosterEntry:
	var cfg := InkMonUnitConfig.get_unit_config(unit_key)
	var entry := InkMonRosterEntry.new()
	entry.entry_id = p_entry_id
	entry.species = cfg.species
	entry.stage = cfg.stage
	entry.role = cfg.role
	entry.elements.assign(cfg.elements)
	entry.persistent_stats = _stats_from_config(cfg.stats)
	entry.learned_skill_id = cfg.active_skill_id
	entry.equipment_container = "equip:%d" % p_entry_id
	return entry


static func from_dict(data: Dictionary) -> InkMonRosterEntry:
	var entry := InkMonRosterEntry.new()
	entry.entry_id = int(data.get("entry_id", 0))
	entry.species = str(data.get("species", ""))
	entry.stage = str(data.get("stage", ""))
	entry.role = str(data.get("role", ""))
	entry.elements = _string_array(data.get("elements", []))
	entry.level = int(data.get("level", 1))
	entry.exp = int(data.get("exp", 0))
	entry.persistent_stats = _normalize_stats(data.get("persistent_stats", {}))
	entry.learned_skill_id = str(data.get("learned_skill_id", ""))
	entry.equipment_container = str(data.get("equipment_container", "equip:%d" % entry.entry_id))
	entry.medals = _string_array(data.get("medals", []))
	return entry


func to_dict() -> Dictionary:
	return {
		"entry_id": entry_id,
		"species": species,
		"stage": stage,
		"role": role,
		"elements": elements.duplicate(),
		"level": level,
		"exp": exp,
		"persistent_stats": persistent_stats.duplicate(true),
		"learned_skill_id": learned_skill_id,
		"equipment_container": equipment_container,
		"medals": medals.duplicate(),
	}


func project_to_battle_snapshot() -> Dictionary:
	var battle_stats := _normalize_stats(persistent_stats)
	return {
		"source_entry_id": entry_id,
		"species": species,
		"role": role,
		"elements": elements.duplicate(),
		"learned_skill_id": learned_skill_id,
		"battle_stats": battle_stats,
	}


func add_exp(amount: int) -> void:
	exp = max(0, exp + amount)


static func _stats_from_config(stats: Dictionary) -> Dictionary:
	var normalized := {}
	for key in STAT_KEYS:
		Log.assert_crash(stats.has(key), "InkMonRosterEntry", "config stats missing key: %s" % key)
		normalized[key] = float(stats[key])
	return normalized


static func _normalize_stats(stats_value: Variant) -> Dictionary:
	var stats := stats_value as Dictionary
	Log.assert_crash(stats != null, "InkMonRosterEntry", "stats must be a Dictionary")
	var normalized := {}
	for key in STAT_KEYS:
		Log.assert_crash(stats.has(key), "InkMonRosterEntry", "stats missing key: %s" % key)
		normalized[key] = float(stats[key])
	return normalized


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	var source := value as Array
	if source == null:
		return result
	for item in source:
		result.append(str(item))
	return result
