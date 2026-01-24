extends RefCounted
class_name TagContainer

var owner_id: String
var _loose_tags: Dictionary = {}
var _auto_duration_tags: Array = []
var _component_tags: Dictionary = {}
var _current_logic_time: float = 0.0
var _callbacks: Array = []

func _init(config: Dictionary):
	owner_id = str(config.get("owner_id", ""))

func add_loose_tag(tag: String, stacks: int = 1) -> void:
	var old_count := get_tag_stacks(tag)
	var current := int(_loose_tags.get(tag, 0))
	_loose_tags[tag] = current + stacks
	var new_count := get_tag_stacks(tag)

	Log.debug("TagContainer", "添加 LooseTag: %s" % tag)

	if old_count != new_count:
		_notify_tag_changed(tag, old_count, new_count)

func remove_loose_tag(tag: String, stacks: int = -1) -> bool:
	if not _loose_tags.has(tag):
		return false
	var current := int(_loose_tags[tag])
	if current <= 0:
		return false

	var old_count := get_tag_stacks(tag)
	if stacks < 0 or stacks >= current:
		_loose_tags.erase(tag)
		Log.debug("TagContainer", "移除 LooseTag: %s" % tag)
	else:
		_loose_tags[tag] = current - stacks
		Log.debug("TagContainer", "减少 LooseTag 层数: %s" % tag)

	var new_count := get_tag_stacks(tag)
	if old_count != new_count:
		_notify_tag_changed(tag, old_count, new_count)

	return true

func has_loose_tag(tag: String) -> bool:
	return int(_loose_tags.get(tag, 0)) > 0

func get_loose_tag_stacks(tag: String) -> int:
	return int(_loose_tags.get(tag, 0))

func add_auto_duration_tag(tag: String, duration: float) -> void:
	var old_count := get_tag_stacks(tag)
	var expires_at := _current_logic_time + duration
	_auto_duration_tags.append({
		"tag": tag,
		"expiresAt": expires_at,
	})
	var new_count := get_tag_stacks(tag)

	Log.debug("TagContainer", "添加 AutoDurationTag: %s" % tag)

	if old_count != new_count:
		_notify_tag_changed(tag, old_count, new_count)

func get_auto_duration_tag_stacks(tag: String) -> int:
	var count := 0
	for entry in _auto_duration_tags:
		if entry["tag"] == tag and float(entry["expiresAt"]) > _current_logic_time:
			count += 1
	return count

func cleanup_expired_tags() -> void:
	var tag_old_counts := {}
	var removed_counts := {}
	for entry in _auto_duration_tags:
		if float(entry["expiresAt"]) <= _current_logic_time:
			var tag := str(entry["tag"])
			if not tag_old_counts.has(tag):
				tag_old_counts[tag] = get_tag_stacks(tag)
			removed_counts[tag] = int(removed_counts.get(tag, 0)) + 1

	var filtered := []
	for entry in _auto_duration_tags:
		if float(entry["expiresAt"]) > _current_logic_time:
			filtered.append(entry)
	_auto_duration_tags = filtered

	for tag in tag_old_counts.keys():
		var old_count := int(tag_old_counts[tag])
		var new_count := get_tag_stacks(tag)
		Log.debug("TagContainer", "AutoDurationTag 层过期: %s" % tag)
		if old_count != new_count:
			_notify_tag_changed(tag, old_count, new_count)

func add_component_tags(component_id: String, tags: Dictionary) -> void:
	if tags.is_empty():
		return

	var old_counts := {}
	for tag in tags.keys():
		old_counts[tag] = get_tag_stacks(str(tag))

	var existing := {}
	if _component_tags.has(component_id):
		existing = _component_tags[component_id]

	var merged := existing.duplicate()
	for tag in tags.keys():
		merged[tag] = int(merged.get(tag, 0)) + int(tags[tag])
	_component_tags[component_id] = merged

	var tag_list := []
	for tag in tags.keys():
		tag_list.append("%s:%s" % [str(tag), str(tags[tag])])
	Log.debug("TagContainer", "添加 ComponentTags: %s" % ", ".join(tag_list))

	for tag in old_counts.keys():
		var old_count := int(old_counts[tag])
		var new_count := get_tag_stacks(str(tag))
		if old_count != new_count:
			_notify_tag_changed(str(tag), old_count, new_count)

func remove_component_tags(component_id: String) -> void:
	if not _component_tags.has(component_id):
		return

	var tags: Dictionary = _component_tags[component_id]
	if tags.is_empty():
		_component_tags.erase(component_id)
		return

	var old_counts := {}
	for tag in tags.keys():
		old_counts[tag] = get_tag_stacks(str(tag))

	_component_tags.erase(component_id)

	var tag_list := []
	for tag in tags.keys():
		tag_list.append("%s:%s" % [str(tag), str(tags[tag])])
	Log.debug("TagContainer", "移除 ComponentTags: %s" % ", ".join(tag_list))

	for tag in old_counts.keys():
		var old_count := int(old_counts[tag])
		var new_count := get_tag_stacks(str(tag))
		if old_count != new_count:
			_notify_tag_changed(str(tag), old_count, new_count)

func has_tag(tag: String) -> bool:
	if _loose_tags.has(tag):
		return true

	for entry in _auto_duration_tags:
		if entry["tag"] == tag and float(entry["expiresAt"]) > _current_logic_time:
			return true

	for tags in _component_tags.values():
		if tags.has(tag) and int(tags[tag]) > 0:
			return true

	return false

func get_tag_stacks(tag: String) -> int:
	var stacks := 0
	stacks += int(_loose_tags.get(tag, 0))
	for entry in _auto_duration_tags:
		if entry["tag"] == tag and float(entry["expiresAt"]) > _current_logic_time:
			stacks += 1
	for tags in _component_tags.values():
		stacks += int(tags.get(tag, 0))
	return stacks

func get_all_tags() -> Dictionary:
	var result := {}
	for tag in _loose_tags.keys():
		result[tag] = int(result.get(tag, 0)) + int(_loose_tags[tag])
	for entry in _auto_duration_tags:
		if float(entry["expiresAt"]) > _current_logic_time:
			var tag := str(entry["tag"])
			result[tag] = int(result.get(tag, 0)) + 1
	for tags in _component_tags.values():
		for tag in tags.keys():
			result[tag] = int(result.get(tag, 0)) + int(tags[tag])
	return result

func get_logic_time() -> float:
	return _current_logic_time

func set_logic_time(logic_time: float) -> void:
	_current_logic_time = logic_time

func tick(dt: float, logic_time: float = -1.0) -> void:
	if logic_time >= 0.0:
		_current_logic_time = logic_time
	else:
		_current_logic_time += dt
	cleanup_expired_tags()

func on_tag_changed(callback: Callable) -> Callable:
	_callbacks.append(callback)
	return func() -> void:
		var index := _callbacks.find(callback)
		if index != -1:
			_callbacks.remove_at(index)

func _notify_tag_changed(tag: String, old_count: int, new_count: int) -> void:
	for callback in _callbacks:
		if callback.is_valid():
			callback.call(tag, old_count, new_count, self)
		else:
			Log.error("TagContainer", "Error in tag changed callback")

func get_snapshot() -> Dictionary:
	return get_all_tags().duplicate()

static func create(owner_id_value: String) -> TagContainer:
	return TagContainer.new({"owner_id": owner_id_value})
