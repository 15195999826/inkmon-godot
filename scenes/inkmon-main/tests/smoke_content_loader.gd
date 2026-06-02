extends Node
## Smoke: server-projection (v2) content import → local static content → catalog read.
## Proves the canon→godot bridge consumer side: a v2 creature-base contract (mon_NNNN ids +
## root evolution_edges) is parsed, validated, loaded as static content, and read back via
## the catalog's stat path with the EXPLICIT res:// values (not the stub root×mult), and the
## evolution forest is registered (branch reachable via get_evolution_edges).


const FIXTURE_PATH := "res://scenes/inkmon-main/tests/fixtures/sample_creature_contract.json"
const MISSING_PATH := "res://scenes/inkmon-main/tests/fixtures/_does_not_exist.json"

# mon_0001 is the proof species: synthetic, unmistakable stats (no stub species carries
# these) + an ORPHAN in the edge-list, so a stat match proves the value came from res://
# and the "no evolution" check proves orphans have no outgoing edges.
const EXPECT_SPECIES := "mon_0001"  # species_id = unit.id (mon_NNNN), no normalization
const EXPECT_DISPLAY := "Test Rock Golem"
const EXPECT_STAGE := "mature"
const EXPECT_STATS := {
	"max_hp": 111.0, "ad": 22.0, "ap": 33.0, "armor": 44.0, "mr": 55.0, "speed": 66.0,
}
# mon_0002 is the branch root: → mon_0007 (fire, conditioned) / mon_0009 (default).
const BRANCH_ROOT := "mon_0002"


func _ready() -> void:
	var status := _run()
	# (5) Always isolate the catalog's static content cache for the next scene.
	InkMonSpeciesCatalog.clear_static_content_cache_for_tests()
	if status == "":
		print("SMOKE_TEST_RESULT: PASS - content importer/loader applies res:// creature base + evolution forest into catalog")
		get_tree().quit(0)
	else:
		print("SMOKE_TEST_RESULT: FAIL - %s" % status)
		get_tree().quit(1)


func _run() -> String:
	# (1) parse_and_validate on the fixture text → ok, and validate_creature_base clean.
	var text := FileAccess.get_file_as_string(FIXTURE_PATH)
	if text == "":
		return "fixture missing/empty at %s" % FIXTURE_PATH
	var parsed := InkMonContentImporter.parse_and_validate(text)
	if not bool(parsed.get("ok", false)):
		return "fixture should parse+validate, errors=%s" % JSON.stringify(parsed.get("errors", []))
	var direct_errors := InkMonL2ContentContract.validate_creature_base(parsed.get("data", {}) as Dictionary)
	if not direct_errors.is_empty():
		return "validate_creature_base should pass on fixture, errors=%s" % JSON.stringify(direct_errors)

	# (2) reload_static_content_for_tests(fixture) → loaded == true, species reported by id (mon_NNNN).
	var loaded := InkMonSpeciesCatalog.reload_static_content_for_tests(FIXTURE_PATH)
	if not bool(loaded.get("loaded", false)):
		return "reload_static_content_for_tests should load the fixture, got %s" % JSON.stringify(loaded)
	var reported := loaded.get("species", []) as Array
	if not EXPECT_SPECIES in reported:
		return "static content should report species_id %s, got %s" % [EXPECT_SPECIES, JSON.stringify(reported)]
	if not BRANCH_ROOT in reported:
		return "static content should report branch root %s, got %s" % [BRANCH_ROOT, JSON.stringify(reported)]

	# (3) catalog stat path returns the EXPLICIT fixture values (proves res:// source, not stub).
	if not InkMonSpeciesCatalog.has_species(EXPECT_SPECIES):
		return "catalog should know static-content species %s" % EXPECT_SPECIES
	var stats := InkMonSpeciesCatalog.get_base_stats(EXPECT_SPECIES)
	for stat_key in EXPECT_STATS:
		var got := float(stats.get(stat_key, -999.0))
		var want := float(EXPECT_STATS[stat_key])
		if absf(got - want) > 0.001:
			return "get_base_stats(%s).%s = %s, expected %s (must come from res://, not a stub)" % [EXPECT_SPECIES, stat_key, got, want]
	if InkMonSpeciesCatalog.get_stage(EXPECT_SPECIES) != EXPECT_STAGE:
		return "get_stage(%s) = %s, expected %s" % [EXPECT_SPECIES, InkMonSpeciesCatalog.get_stage(EXPECT_SPECIES), EXPECT_STAGE]
	# display_name (name_en) is consumed too, not dropped.
	if InkMonSpeciesCatalog.get_display_name(EXPECT_SPECIES) != EXPECT_DISPLAY:
		return "get_display_name(%s) = %s, expected %s" % [EXPECT_SPECIES, InkMonSpeciesCatalog.get_display_name(EXPECT_SPECIES), EXPECT_DISPLAY]

	# (3b) FULL creature base consumed: elements stored (not dropped); and a content-only
	# ORPHAN species is gracefully poolless / evolutionless (no assert, no outgoing edges).
	var elements := InkMonSpeciesCatalog.get_elements(EXPECT_SPECIES)
	if elements.size() != 1 or elements[0] != "earth":
		return "get_elements(%s) = %s, expected [earth]" % [EXPECT_SPECIES, JSON.stringify(elements)]
	if InkMonSpeciesCatalog.get_slot_count(EXPECT_SPECIES) != 0:
		return "content-only species should have 0 skill slots, got %d" % InkMonSpeciesCatalog.get_slot_count(EXPECT_SPECIES)
	if not InkMonSpeciesCatalog.get_slot_pool(EXPECT_SPECIES, 0).is_empty():
		return "content-only species slot pool should be empty"
	if not InkMonSpeciesCatalog.get_evolution_edges(EXPECT_SPECIES).is_empty():
		return "orphan species should have no outgoing evolution edges"

	# (3c) Evolution forest registered: the branch root has 2 outgoing edges (multi-child),
	# thresholds sourced PER-EDGE from the contract trigger.level. The two edges carry DISTINCT
	# levels (fire=18, default=12) so a match proves the loader extracted each from the JSON
	# rather than hard-coding a constant. One edge carries an element condition.
	var edges := InkMonSpeciesCatalog.get_evolution_edges(BRANCH_ROOT)
	if edges.size() != 2:
		return "branch root %s should have 2 outgoing edges, got %d" % [BRANCH_ROOT, edges.size()]
	var level_by_child := {}
	var has_condition := false
	for edge in edges:
		var child := str(edge.get("child_species_id", ""))
		var trigger := edge.get("trigger", {}) as Dictionary
		level_by_child[child] = int(trigger.get("level", 0))
		if not (trigger.get("condition", {}) as Dictionary).is_empty():
			has_condition = true
	if not ("mon_0007" in level_by_child and "mon_0009" in level_by_child):
		return "branch children should be mon_0007 + mon_0009, got %s" % JSON.stringify(level_by_child.keys())
	if int(level_by_child.get("mon_0007", -1)) != 18:
		return "fire branch (mon_0007) trigger.level should be 18 from contract, got %s" % str(level_by_child.get("mon_0007", -1))
	if int(level_by_child.get("mon_0009", -1)) != 12:
		return "default branch (mon_0009) trigger.level should be 12 from contract, got %s" % str(level_by_child.get("mon_0009", -1))
	if not has_condition:
		return "at least one branch edge should carry a condition (the fire branch)"

	# (3c2) PER-SPECIES authority regression guard: a stub/adopted species NOT in the contract
	# edge-list must KEEP its stub evolves_to even though contract edges (mon_0002) are loaded.
	# A global `_static_evolution_edges.is_empty()` gate would strand it (return []); per-species does not.
	var stub_edges := InkMonSpeciesCatalog.get_evolution_edges("aegis_pup")
	if stub_edges.size() != 1:
		return "stub species aegis_pup should keep its stub edge while a partial contract is loaded, got %d" % stub_edges.size()
	if str(stub_edges[0].get("child_species_id", "")) != "aegis_warden":
		return "stub aegis_pup fallback edge child should be aegis_warden, got %s" % str(stub_edges[0].get("child_species_id", ""))

	# (3d) An empty-units contract is VALID (matches lab's empty-DB response units:[]).
	var empty_errors := InkMonL2ContentContract.validate_creature_base(
		{"schema": InkMonL2ContentContract.SCHEMA_ID, "version": InkMonL2ContentContract.VERSION, "units": []}
	)
	if not empty_errors.is_empty():
		return "empty-units contract should validate, got %s" % JSON.stringify(empty_errors)

	# (3e) RosterEntry.from_birth on a content-only species: no crash, projected elements +
	# stage + name_en flow through, gracefully no skill slots. (Battle-SPAWNING such a species
	# still needs skill data — the unit actor requires skills — out of P1 scope.)
	var birth := InkMonRosterEntry.from_birth(9001, EXPECT_SPECIES, 42)
	if birth.elements.size() != 1 or birth.elements[0] != "earth":
		return "from_birth(%s).elements = %s, expected [earth]" % [EXPECT_SPECIES, JSON.stringify(birth.elements)]
	if birth.stage != EXPECT_STAGE:
		return "from_birth(%s).stage = %s, expected %s" % [EXPECT_SPECIES, birth.stage, EXPECT_STAGE]
	if birth.species_id != EXPECT_SPECIES:
		return "from_birth(%s).species_id = %s, expected %s" % [EXPECT_SPECIES, birth.species_id, EXPECT_SPECIES]
	if birth.name_en != EXPECT_DISPLAY:
		return "from_birth(%s).name_en = %s, expected %s" % [EXPECT_SPECIES, birth.name_en, EXPECT_DISPLAY]
	if not birth.skill_slots.is_empty():
		return "content-only from_birth should have no skill slots (skills are a later phase)"

	# (4) missing file → loaded == false, silent stub fallback (no crash).
	var missing := InkMonSpeciesCatalog.reload_static_content_for_tests(MISSING_PATH)
	if bool(missing.get("loaded", true)):
		return "missing file should not load, got %s" % JSON.stringify(missing)
	if str(missing.get("source", "")) != "stub":
		return "missing file should fall back to source=stub, got %s" % str(missing.get("source", ""))

	return ""
