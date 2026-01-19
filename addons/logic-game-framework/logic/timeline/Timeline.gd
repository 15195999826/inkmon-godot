extends RefCounted
class_name TimelineRegistry

var _timelines: Dictionary = {}

func register(timeline: Dictionary) -> void:
	var timeline_id := str(timeline.get("id", ""))
	if timeline_id == "":
		return
	_timelines[timeline_id] = timeline

func register_all(timelines: Array) -> void:
	for timeline in timelines:
		register(timeline)

func get_timeline(timeline_id: String):
	return _timelines.get(timeline_id, null)

func has(timeline_id: String) -> bool:
	return _timelines.has(timeline_id)

func get_all_ids() -> Array:
	return _timelines.keys()

static var _global_registry: TimelineRegistry = TimelineRegistry.new()

static func get_timeline_registry() -> TimelineRegistry:
	return _global_registry

static func set_timeline_registry(registry: TimelineRegistry) -> void:
	_global_registry = registry if registry != null else TimelineRegistry.new()

static func get_tag_time(timeline: Dictionary, tag_name: String):
	var tags: Dictionary = timeline.get("tags", {})
	if tags is Dictionary and tags.has(tag_name):
		return float(tags[tag_name])
	return null

static func get_tag_names(timeline: Dictionary) -> Array:
	var tags: Dictionary = timeline.get("tags", {})
	return tags.keys() if tags is Dictionary else []

static func get_sorted_tags(timeline: Dictionary) -> Array:
	var tags: Dictionary = timeline.get("tags", {})
	if not tags is Dictionary:
		return []
	var result := []
	for tag_name in tags.keys():
		result.append({
			"name": tag_name,
			"time": float(tags[tag_name]),
		})
	result.sort_custom(func(a, b): return a["time"] < b["time"])
	return result

static func validate_timeline(timeline: Dictionary) -> Array:
	var errors := []
	var timeline_id := str(timeline.get("id", ""))
	if timeline_id == "":
		errors.append("Timeline id is required")
	var total_duration := float(timeline.get("totalDuration", 0.0))
	if total_duration <= 0.0:
		errors.append("Timeline totalDuration must be positive")
	var tags: Dictionary = timeline.get("tags", {})
	if tags is Dictionary:
		for tag_name in tags.keys():
			var time_value := float(tags[tag_name])
			if time_value < 0.0:
				errors.append("Tag \"%s\" has negative time: %s" % [str(tag_name), str(time_value)])
			if time_value > total_duration:
				errors.append("Tag \"%s\" time (%s) exceeds totalDuration (%s)" % [str(tag_name), str(time_value), str(total_duration)])
	return errors
