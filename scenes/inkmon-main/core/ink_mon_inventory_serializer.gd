class_name InkMonInventorySerializer


static func capture(inventory_map: Dictionary) -> Dictionary:
	var containers := {}
	var logical_names := inventory_map.keys()
	logical_names.sort()
	for logical_name_value in logical_names:
		var logical_name := str(logical_name_value)
		var container_id := int(inventory_map[logical_name])
		var item_snapshots: Array[Dictionary] = []
		for item_id in ItemSystem.get_items_in_container(container_id):
			var snapshot := ItemSystem.get_item_snapshot(item_id)
			if snapshot.is_empty():
				continue
			item_snapshots.append(_sanitize_item_snapshot(snapshot))
		containers[logical_name] = item_snapshots
	return {
		"containers": containers,
	}


static func restore(inventory_map: Dictionary, inventory_data: Dictionary) -> void:
	var containers := inventory_data.get("containers", {}) as Dictionary
	if containers == null:
		return
	var logical_names := containers.keys()
	logical_names.sort()
	for logical_name_value in logical_names:
		var logical_name := str(logical_name_value)
		Log.assert_crash(inventory_map.has(logical_name), "InkMonInventorySerializer",
			"missing runtime container for logical name: %s" % logical_name)
		var container_id := int(inventory_map[logical_name])
		var item_data_list := containers[logical_name] as Array
		if item_data_list == null:
			continue
		for item_data_value in item_data_list:
			var item_data := item_data_value as Dictionary
			if item_data == null:
				continue
			_restore_item(container_id, item_data)


static func _sanitize_item_snapshot(snapshot: Dictionary) -> Dictionary:
	return {
		"config_id": str(snapshot.get("config_id", "")),
		"count": int(snapshot.get("count", 1)),
		"slot_index": int(snapshot.get("slot_index", -1)),
	}


static func _restore_item(container_id: int, item_data: Dictionary) -> void:
	var config_id := StringName(str(item_data.get("config_id", "")))
	Log.assert_crash(config_id != &"", "InkMonInventorySerializer", "item snapshot missing config_id")
	var count := int(item_data.get("count", 1))
	var slot_index := int(item_data.get("slot_index", -1))
	var result := ItemSystem.create_item(container_id, config_id, count, slot_index)
	Log.assert_crash(result.success, "InkMonInventorySerializer",
		"failed to restore item %s: %s" % [str(config_id), result.error_message])
