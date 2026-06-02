extends Node
## Smoke: server-projection content import → catalog override → runtime stat read.
## Proves the canon→godot bridge consumer side: a CamelCase creature-base contract
## is parsed, validated, applied as a species override, and read back via the
## catalog's stat path with the EXPLICIT res:// values (not the stub root×mult).


const FIXTURE_PATH := "res://scenes/inkmon-main/tests/fixtures/sample_creature_contract.json"
const MISSING_PATH := "res://scenes/inkmon-main/tests/fixtures/_does_not_exist.json"

# Fixture's synthetic, unmistakable values (no stub species carries these), so a
# match proves the stat came from the imported file rather than a hardcoded config.
const EXPECT_SPECIES := "test_rock_golem"  # normalized from CamelCase "TestRockGolem"
const EXPECT_STAGE := "mature"
const EXPECT_STATS := {
	"max_hp": 111.0, "ad": 22.0, "ap": 33.0, "armor": 44.0, "mr": 55.0, "speed": 66.0,
}


func _ready() -> void:
	var status := _run()
	# (5) Always isolate the catalog's static override state for the next scene.
	InkMonSpeciesCatalog.clear_overrides()
	if status == "":
		print("SMOKE_TEST_RESULT: PASS - content importer/loader applies res:// creature base into catalog")
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

	# (2) apply_to_runtime(fixture) → loaded == true.
	var applied := InkMonContentLoader.apply_to_runtime(FIXTURE_PATH)
	if not bool(applied.get("loaded", false)):
		return "apply_to_runtime should load the fixture, got %s" % JSON.stringify(applied)
	if not EXPECT_SPECIES in (applied.get("species", []) as Array):
		return "apply_to_runtime should report species %s, got %s" % [EXPECT_SPECIES, JSON.stringify(applied.get("species", []))]

	# (3) catalog stat path returns the EXPLICIT fixture values (proves res:// source, not stub).
	if not InkMonSpeciesCatalog.has_species(EXPECT_SPECIES):
		return "catalog should know overridden species %s" % EXPECT_SPECIES
	var stats := InkMonSpeciesCatalog.get_base_stats(EXPECT_SPECIES)
	for stat_key in EXPECT_STATS:
		var got := float(stats.get(stat_key, -999.0))
		var want := float(EXPECT_STATS[stat_key])
		if absf(got - want) > 0.001:
			return "get_base_stats(%s).%s = %s, expected %s (must come from res://, not a stub)" % [EXPECT_SPECIES, stat_key, got, want]
	if InkMonSpeciesCatalog.get_stage(EXPECT_SPECIES) != EXPECT_STAGE:
		return "get_stage(%s) = %s, expected %s" % [EXPECT_SPECIES, InkMonSpeciesCatalog.get_stage(EXPECT_SPECIES), EXPECT_STAGE]
	# Override is reachable by the original CamelCase key too.
	if not InkMonSpeciesCatalog.has_species("TestRockGolem"):
		return "catalog should resolve the original CamelCase key TestRockGolem"

	# (4) missing file → loaded == false, silent stub fallback (no crash).
	var missing := InkMonContentLoader.apply_to_runtime(MISSING_PATH)
	if bool(missing.get("loaded", true)):
		return "missing file should not load, got %s" % JSON.stringify(missing)
	if str(missing.get("source", "")) != "stub":
		return "missing file should fall back to source=stub, got %s" % str(missing.get("source", ""))

	return ""
