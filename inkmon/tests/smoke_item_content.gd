extends Node
## Smoke: item catalog content consumption (adr/0003). Proves the lab→godot item bridge:
## a v2 bundle's items[] is validated (defensive item checks), loaded as static content, and read
## back via InkMonItemCatalog with the imported item_NNNN configs; a missing content file yields
## an empty catalog (adr/0003: stub fallback removed). Mirrors smoke_content_loader.


const FIXTURE_PATH := "res://inkmon/tests/fixtures/sample_creature_contract.json"
const MISSING_PATH := "res://inkmon/tests/fixtures/_does_not_exist.json"


func _ready() -> void:
	var status := _run()
	# Always isolate the catalog's static caches for the next scene.
	InkMonItemCatalog.clear_static_items_cache_for_tests()
	InkMonSpeciesCatalog.clear_static_content_cache_for_tests()
	if status == "":
		print("SMOKE_TEST_RESULT: PASS - item catalog consumes res:// items[] (item_NNNN); empty when content missing")
		get_tree().quit(0)
	else:
		print("SMOKE_TEST_RESULT: FAIL - %s" % status)
		get_tree().quit(1)


func _run() -> String:
	# (1) The fixture validates as a creature-base bundle — items[] is now defensively checked.
	var text := FileAccess.get_file_as_string(FIXTURE_PATH)
	if text == "":
		return "fixture missing/empty at %s" % FIXTURE_PATH
	var parsed := InkMonContentImporter.parse_and_validate(text)
	if not bool(parsed.get("ok", false)):
		return "fixture should validate, errors=%s" % JSON.stringify(parsed.get("errors", []))

	# (2) Catalog reads the IMPORTED items (item_NNNN), not the stub slugs.
	InkMonItemCatalog.reload_static_items_for_tests(FIXTURE_PATH)
	var catalog := InkMonItemCatalog.new()
	if not catalog.has_config(&"item_0001"):
		return "catalog should know imported item_0001"
	var sword := catalog.get_config(&"item_0001")
	if str(sword.get("display_name", "")) != "Training Sword":
		return "item_0001 display_name = %s, expected Training Sword" % str(sword.get("display_name", ""))
	var sword_ad := float((sword.get("stat_mods", {}) as Dictionary).get("ad", 0.0))
	if absf(sword_ad - 5.0) > 0.001:
		return "item_0001 stat_mods.ad = %s, expected 5 (must come from res://)" % sword_ad
	if not bool(sword.get("equipable", false)):
		return "item_0001 should be equipable"
	if int(sword.get("price", -1)) != 30:
		return "item_0001 price = %s, expected 30" % str(sword.get("price", -1))
	var ids := catalog.list_config_ids()
	if not (StringName("item_0001") in ids and StringName("item_0002") in ids):
		return "catalog ids should be item_NNNN, got %s" % str(ids)

	# (3) Defensive item validation rejects a malformed item (bad id + unknown/neg stat + bad types).
	var bad := {
		"schema": InkMonL2ContentContract.SCHEMA_ID,
		"version": InkMonL2ContentContract.VERSION,
		"units": [],
		"items": [{
			"id": "sword",  # not item_NNNN
			"display_name": "Bad",
			"icon_key": "x",
			"item_tags": ["equipment"],
			"stat_mods": {"luck": -3},  # unknown key + negative
			"price": -5,
			"item_type": "weapon",  # not in equipment/material/consumable/rune
			"max_stack": 0,
			"granted_abilities": [],
		}],
	}
	var bad_errors := InkMonL2ContentContract.validate_creature_base(bad)
	if bad_errors.is_empty():
		return "malformed item should produce validation errors"

	# (4) Missing content file → empty catalog (adr/0003: stub fallback removed; content is sole source).
	InkMonItemCatalog.reload_static_items_for_tests(MISSING_PATH)
	var stub_catalog := InkMonItemCatalog.new()
	if not stub_catalog.list_config_ids().is_empty():
		return "missing content file should yield an empty catalog (no hardcoded stub; adr/0003)"

	return ""
