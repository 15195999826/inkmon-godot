class_name InkMonGameSession
extends RefCounted


const SAVE_VERSION := 1
const BAG_CONTAINER := "bag"


var player_state: InkMonPlayerState
var inventory_map: Dictionary = {}


func begin_new_game() -> void:
	player_state = InkMonPlayerState.create_new_game()
	_reset_item_runtime()
	_register_required_containers({})


func from_dict(data: Dictionary) -> void:
	Log.assert_crash(int(data.get("version", SAVE_VERSION)) == SAVE_VERSION, "InkMonGameSession",
		"unsupported save version: %s" % str(data.get("version", "")))
	player_state = InkMonPlayerState.from_dict(data.get("player", {}) as Dictionary)
	_reset_item_runtime()
	var inventory_data := data.get("inventory", {}) as Dictionary
	_register_required_containers(inventory_data if inventory_data != null else {})
	InkMonInventorySerializer.restore(inventory_map, inventory_data if inventory_data != null else {})


func to_dict() -> Dictionary:
	Log.assert_crash(player_state != null, "InkMonGameSession", "player_state is not initialized")
	return {
		"version": SAVE_VERSION,
		"player": player_state.to_dict(),
		"inventory": InkMonInventorySerializer.capture(inventory_map),
	}


func create_bag_item(config_id: StringName, count: int = 1, slot_index: int = -1) -> ItemCreateResult:
	Log.assert_crash(inventory_map.has(BAG_CONTAINER), "InkMonGameSession", "bag container is not registered")
	return ItemSystem.create_item(int(inventory_map[BAG_CONTAINER]), config_id, count, slot_index)


func get_container_id(logical_name: String) -> int:
	if not inventory_map.has(logical_name):
		return -1
	return int(inventory_map[logical_name])


func sync_roster_containers() -> void:
	_register_required_containers({})


func project_player_battle_roster(max_units: int = 4) -> Array[Dictionary]:
	Log.assert_crash(player_state != null, "InkMonGameSession", "player_state is not initialized")
	var snapshots := player_state.project_battle_roster(max_units)
	# battle_stats = base(f(species,level)) + 装备 stat_mods 累加 (docs §8c; 项目本地, lomolib inventoryKit)。
	for snapshot in snapshots:
		var entry := player_state.get_roster_entry(int(snapshot.get("source_entry_id", -1)))
		if entry != null:
			_fold_equipment_stats(snapshot, entry.equipment_container)
	return snapshots


## 把 entry 装备容器里物品的 stat_mods flat 累加进 snapshot 的 battle_stats (装备数值生效)。
func _fold_equipment_stats(snapshot: Dictionary, equipment_container: String) -> void:
	var container_id := get_container_id(equipment_container)
	if container_id <= 0:
		return
	var battle_stats := snapshot.get("battle_stats", {}) as Dictionary
	if battle_stats == null:
		return
	for item_id in ItemSystem.get_items_in_container(container_id):
		var item_snapshot := ItemSystem.get_item_snapshot(item_id)
		if item_snapshot.is_empty():
			continue
		var config := ItemSystem.get_item_config(StringName(str(item_snapshot.get("config_id", ""))))
		var stat_mods := config.get("stat_mods", {}) as Dictionary
		if stat_mods == null:
			continue
		var count := int(item_snapshot.get("count", 1))
		for key in stat_mods:
			if battle_stats.has(key):
				battle_stats[key] = float(battle_stats[key]) + float(stat_mods[key]) * count


func _reset_item_runtime() -> void:
	ItemSystem.reset_session()
	ItemSystem.configure_domain(InkMonItemDomain.new(), InkMonItemCatalog.new())
	inventory_map.clear()


func _register_required_containers(inventory_data: Dictionary) -> void:
	_register_logical_container(BAG_CONTAINER)
	if player_state != null:
		for entry in player_state.roster:
			if entry.equipment_container != "":
				_register_logical_container(entry.equipment_container)

	var containers := inventory_data.get("containers", {}) as Dictionary
	if containers == null:
		return
	var logical_names := containers.keys()
	logical_names.sort()
	for logical_name_value in logical_names:
		_register_logical_container(str(logical_name_value))


func _register_logical_container(logical_name: String, capacity: int = -1) -> int:
	if inventory_map.has(logical_name):
		return int(inventory_map[logical_name])
	var container := BaseContainer.new()
	container.container_name = StringName(logical_name)
	container.space_config = ContainerSpaceConfig.create_unordered(capacity)
	var container_id := ItemSystem.register_container(container)
	Log.assert_crash(container_id > 0, "InkMonGameSession", "failed to register container: %s" % logical_name)
	inventory_map[logical_name] = container_id
	return container_id
