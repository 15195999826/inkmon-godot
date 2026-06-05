extends Node
## Smoke: item-gated evolution condition (adr/0003 G2). Proves evaluate_evolution_condition
## type:item is UNBLOCKED — it returns whether the player holds the item_NNNN (config_id) in the
## given owned containers (bag + unit equipment), and stays fail-safe false for empty/unheld.
## Loads the fixture so the catalog knows item_0001 (so ItemSystem.create_item accepts it).


const FIXTURE_PATH := "res://inkmon/tests/fixtures/sample_creature_contract.json"


func _ready() -> void:
	var status := _run()
	InkMonItemCatalog.clear_static_items_cache_for_tests()
	if status == "":
		print("SMOKE_TEST_RESULT: PASS - item-gated evolution condition evaluates real holdings (item_NNNN)")
		get_tree().quit(0)
	else:
		print("SMOKE_TEST_RESULT: FAIL - %s" % status)
		get_tree().quit(1)


func _run() -> String:
	# Catalog must know item_0001 for ItemSystem.create_item to accept it (content hit, not stub slug).
	InkMonItemCatalog.reload_static_items_for_tests(FIXTURE_PATH)
	ItemSystem.configure_domain(InkMonItemDomain.new(), InkMonItemCatalog.new())

	var actor := InkMonUnitActor.new(InkMonUnitConfig.LEFT_CINDER_KIT)

	var container := BaseContainer.new()
	container.container_name = &"bag:test"
	container.space_config = ContainerSpaceConfig.create_unordered(-1)
	var cid := ItemSystem.register_container(container)
	if cid <= 0:
		return "failed to register container"

	var condition := {"type": "item", "params": {"item_id": "item_0001"}}
	var none: Array[int] = []
	var owned: Array[int] = [cid]

	# (1) fail-safe: no owned containers, or item not held yet → unmet.
	if InkMonSpeciesCatalog.evaluate_evolution_condition(condition, actor, none):
		return "empty owned containers should not satisfy an item condition"
	if InkMonSpeciesCatalog.evaluate_evolution_condition(condition, actor, owned):
		return "item condition should be unmet before the item is held"

	# (2) hold item_0001 in an owned container → condition met.
	var create_result := ItemSystem.create_item(cid, &"item_0001", 1, -1)
	if not create_result.success:
		return "failed to create item_0001: %s" % create_result.error_message
	if not InkMonSpeciesCatalog.evaluate_evolution_condition(condition, actor, owned):
		return "item condition should be MET once item_0001 is held in an owned container"

	# (3) a different item_id is still unmet (holding item_0001 != item_0002).
	var other := {"type": "item", "params": {"item_id": "item_0002"}}
	if InkMonSpeciesCatalog.evaluate_evolution_condition(other, actor, owned):
		return "holding item_0001 should not satisfy an item_0002 condition"

	# (4) invalid container ids in the list are skipped, not crashed.
	var with_invalid: Array[int] = [-1, 0, cid]
	if not InkMonSpeciesCatalog.evaluate_evolution_condition(condition, actor, with_invalid):
		return "invalid container ids should be skipped, real container still satisfies"

	return ""
