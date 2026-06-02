class_name InkMonContentLoader
## Boot-time consumer of the server creature-base contract. Reads the imported
## projection at `res://data/inkmon_content.json` (written by the editor import
## tool) and applies each creature base as a species override on the catalog, so
## the runtime stat path serves canon values instead of the hardcoded stub.
##
## Missing file = the normal dev state before any import has run → silent stub
## fallback (no warning, no crash). Invalid file → Log.warning + stub fallback.
## The override is additive: godot keeps its own skill pools + role derivation +
## evolution condition evaluation + runtime level; the creature base (stats/stage/
## identity = species_id) AND the evolution topology + thresholds (edge-list forest,
## adr/0010) come from the server.


const DEFAULT_PATH := "res://data/inkmon_content.json"


## Apply the content at `path` to the runtime catalog.
## Returns {loaded: bool, source: String, species: Array[String]} where `source`
## is the path on success or "stub" on any fallback, and `species` lists the
## normalized keys that were registered as overrides.
static func apply_to_runtime(path: String = DEFAULT_PATH) -> Dictionary:
	# Clean slate: each apply replaces ALL prior overrides so the catalog reflects
	# exactly this source. A missing/invalid file therefore reverts to pure stub
	# (not "keep whatever was loaded before").
	InkMonSpeciesCatalog.clear_overrides()
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
		InkMonSpeciesCatalog.register_override(species_id, base_stats, stage, elements, display_name)
		if not species_id in registered:
			registered.append(species_id)

	# Evolution topology = a root-level edge-list forest (adr/0010), separate from units.
	# apply_to_runtime already cleared edges at the top (clear_overrides); registering an
	# empty/absent list therefore leaves the catalog on its stub evolves_to fallback.
	var edges_value: Variant = data.get("evolution_edges", [])
	if edges_value is Array:
		InkMonSpeciesCatalog.register_evolution_edges(edges_value as Array)

	return {"loaded": true, "source": path, "species": registered}


static func _stub_result() -> Dictionary:
	return {"loaded": false, "source": "stub", "species": []}
