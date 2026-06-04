class_name InkMonContentLoader
## Local static content reader. Reads the imported creature-base projection at
## `res://data/inkmon_content.json` (written by the editor import tool) and
## returns normalized catalog data.
##
## Missing file = the normal dev state before any import has run → silent stub
## fallback (no warning, no crash). Invalid file → Log.warning + stub fallback.
## The loaded content is local/static at runtime. The editor tool is the only
## server-fetching step.


const DEFAULT_PATH := "res://data/inkmon_content.json"


## Read local static content at `path`.
## Returns {loaded, source, species, species_table, evolution_edges}.
static func load_static_content(path: String = DEFAULT_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _stub_result()

	var text := FileAccess.get_file_as_string(path)
	var result := InkMonContentImporter.parse_and_validate(text)
	if not bool(result.get("ok", false)):
		Log.warning(
			"InkMonContentLoader",
			"content at %s failed validation, falling back to stub: %s"
				% [path, JSON.stringify(result.get("errors", []))]
		)
		return _stub_result()

	var data: Dictionary = result.get("data", {})
	var units_value: Variant = data.get("units", [])
	if not (units_value is Array):
		Log.warning("InkMonContentLoader", "content at %s has no units array" % path)
		return _stub_result()

	var registered: Array[String] = []
	var species_table := {}
	for unit_value in (units_value as Array):
		if not (unit_value is Dictionary):
			continue
		var unit: Dictionary = unit_value
		# v2 (adr/0010): identity key = unit.id (= species_id, mon_NNNN). display_name =
		# name_en (display). No `species` field; no key normalization (mon_NNNN is unique).
		var species_id := str(unit.get("id", ""))
		if species_id == "":
			continue
		var display_name := str(unit.get("display_name", ""))
		var base_stats_value: Variant = unit.get("base_stats", {})
		var base_stats: Dictionary = base_stats_value if base_stats_value is Dictionary else {}
		var stage := str(unit.get("stage", ""))
		var elements: Array[String] = []
		var elements_value: Variant = unit.get("elements", [])
		if elements_value is Array:
			for element_value in (elements_value as Array):
				elements.append(str(element_value))
		species_table[species_id] = _species_record(base_stats, stage, elements, display_name)
		if not species_id in registered:
			registered.append(species_id)

	# Evolution topology = a root-level edge-list forest (adr/0010), separate from units.
	var evolution_edges := _normalize_evolution_edges(data.get("evolution_edges", []))

	return {
		"loaded": true,
		"source": path,
		"species": registered,
		"species_table": species_table,
		"evolution_edges": evolution_edges,
	}


static func _species_record(
	base_stats: Dictionary,
	stage: String,
	elements: Array[String],
	display_name: String
) -> Dictionary:
	var stats := {}
	for key in base_stats:
		stats[key] = float(base_stats[key])
	return {
		"base_stats": stats,
		"stage": stage,
		"elements": elements.duplicate(),
		"display_name": display_name,
	}


static func _normalize_evolution_edges(value: Variant) -> Dictionary:
	var result := {}
	if not (value is Array):
		return result
	for edge_value in (value as Array):
		if not (edge_value is Dictionary):
			continue
		var edge: Dictionary = edge_value
		var parent := str(edge.get("parent_species_id", ""))
		var child := str(edge.get("child_species_id", ""))
		if parent == "" or child == "":
			continue
		var trigger_value: Variant = edge.get("trigger", {})
		var trigger: Dictionary = trigger_value if trigger_value is Dictionary else {}
		var condition_value: Variant = trigger.get("condition", {})
		var condition: Dictionary = condition_value if condition_value is Dictionary else {}
		var normalized := {
			"child_species_id": child,
			"trigger": {
				"level": int(trigger.get("level", 0)),
				"condition": condition.duplicate(true),
			},
		}
		if not result.has(parent):
			result[parent] = []
		(result[parent] as Array).append(normalized)
	return result


static func _stub_result() -> Dictionary:
	return {
		"loaded": false,
		"source": "stub",
		"species": [],
		"species_table": {},
		"evolution_edges": {},
	}
