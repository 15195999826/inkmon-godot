extends RefCounted
class_name EventCollector

var _events: Array[Dictionary] = []

func push(event: Dictionary) -> Dictionary:
	_events.append(event)
	return event

func collect() -> Array[Dictionary]:
	return _events.duplicate(true)

func flush() -> Array[Dictionary]:
	var events := _events
	_events = []
	return events

func clear() -> void:
	_events = []

func get_count() -> int:
	return _events.size()

func has_events() -> bool:
	return _events.size() > 0

func filter_by_kind(kind: String) -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []
	for event in _events:
		if event.get("kind", "") == kind:
			filtered.append(event)
	return filtered

func merge(other: EventCollector) -> void:
	_events.append_array(other._events)
