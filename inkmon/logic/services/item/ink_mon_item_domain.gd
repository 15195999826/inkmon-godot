class_name InkMonItemDomain
extends ItemDomain


func can_stack(existing_item_id: int, config_id: StringName) -> bool:
	var data := ItemSystem.get_item_data(existing_item_id)
	return data != null and data.config_id == config_id


func merge_stack(existing_data: ItemInstanceData, incoming_count: int, max_stack: int) -> int:
	var room: int = maxi(0, max_stack - existing_data.count)
	var merged: int = mini(room, incoming_count)
	existing_data.count += merged
	return incoming_count - merged
