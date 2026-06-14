class_name InkMonItemCatalog
extends ItemCatalog


func has_config(config_id: StringName) -> bool:
	return _resolved_configs().has(str(config_id))


func get_config(config_id: StringName) -> Dictionary:
	var configs := _resolved_configs()
	var key := str(config_id)
	if not configs.has(key):
		return {}
	return (configs[key] as Dictionary).duplicate(true)


func list_config_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for config_id in _resolved_configs().keys():
		result.append(StringName(str(config_id)))
	return result


## Resolved item configs: imported lab-canon items (item_NNNN) from res://data/inkmon_content.json.
## adr/0003: stub `_configs()` was removed — content file is the sole source; empty file = empty
## catalog (explicit failure signal, not stale fallback data).
static func _resolved_configs() -> Dictionary:
	return _ensure_items_loaded()


## Imported items cache, keyed by item_id → catalog config (same shape as _configs()). Lazily
## loaded once from InkMonContentLoader (runtime read-only, no server fetch); isolated in tests.
static var _static_items_loaded := false
static var _static_items: Dictionary = {}


static func _ensure_items_loaded() -> Dictionary:
	if not _static_items_loaded:
		_static_items = _items_from(InkMonContentLoader.load_static_content())
		_static_items_loaded = true
	return _static_items


static func _items_from(result: Dictionary) -> Dictionary:
	var items_value: Variant = result.get("items", {})
	return (items_value as Dictionary).duplicate(true) if items_value is Dictionary else {}


## Test seams (mirror InkMonSpeciesCatalog): isolate the static cache between scenes.
static func clear_static_items_cache_for_tests() -> void:
	_static_items_loaded = false
	_static_items.clear()


static func reload_static_items_for_tests(path: String = InkMonContentLoader.DEFAULT_PATH) -> Dictionary:
	_static_items = _items_from(InkMonContentLoader.load_static_content(path))
	_static_items_loaded = true
	return _static_items
