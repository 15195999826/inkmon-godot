extends Node

var _timelines: Dictionary = {}

func register(timeline: Dictionary) -> void:
	var timeline_id := str(timeline.get("id", ""))
	if timeline_id == "":
		return
	_timelines[timeline_id] = timeline

func register_all(timelines: Array[Dictionary]) -> void:
	for timeline in timelines:
		register(timeline)

func get_timeline(timeline_id: String) -> Dictionary:
	return _timelines.get(timeline_id, {})

func has(timeline_id: String) -> bool:
	return _timelines.has(timeline_id)

func get_all_ids() -> Array[String]:
	var result: Array[String] = []
	result.assign(_timelines.keys())
	return result

func reset() -> void:
	_timelines = {}

## 获取 tag 时间，未找到返回 -1.0
static func get_tag_time(timeline: Dictionary, tag_name: String) -> float:
	var tags = timeline.get("tags", {})
	if tags is Dictionary and tags.has(tag_name):
		return float(tags[tag_name])
	return -1.0

static func get_tag_names(timeline: Dictionary) -> Array[String]:
	var tags = timeline.get("tags", {})
	if not tags is Dictionary:
		return []
	var result: Array[String] = []
	result.assign(tags.keys())
	return result

static func get_sorted_tags(timeline: Dictionary) -> Array[Dictionary]:
	var tags = timeline.get("tags", {})
	if not tags is Dictionary:
		return []
	var result: Array[Dictionary] = []
	for tag_name in tags.keys():
		result.append({ "name": tag_name, "time": float(tags[tag_name]) })
	result.sort_custom(func(a, b): return a["time"] < b["time"])
	return result

static func validate_timeline(timeline: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var timeline_id := str(timeline.get("id", ""))
	if timeline_id == "":
		errors.append("Timeline id is required")
	var total_duration := float(timeline.get("totalDuration", 0.0))
	if total_duration <= 0.0:
		errors.append("Timeline totalDuration must be positive")
	var tags = timeline.get("tags", {})
	if tags is Dictionary:
		for tag_name in tags.keys():
			var time_value := float(tags[tag_name])
			if time_value < 0.0:
				errors.append("Tag \"%s\" has negative time: %s" % [str(tag_name), str(time_value)])
			elif time_value > total_duration:
				errors.append("Tag \"%s\" time (%s) exceeds totalDuration (%s)" % [str(tag_name), str(time_value), str(total_duration)])
	return errors
