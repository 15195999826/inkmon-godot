extends RefCounted
class_name AbilityExecutionInstance

const STATE_EXECUTING := "executing"
const STATE_COMPLETED := "completed"
const STATE_CANCELLED := "cancelled"

var id: String
var timeline_id: String
var _timeline = null
var _tag_actions: Dictionary = {}
var _event_chain: Array[Dictionary] = []
var _game_state_provider = null
var _ability_info: Dictionary = {}
var _elapsed: float = 0.0
var _state: String = STATE_EXECUTING
var _triggered_tags: Dictionary = {}

func _init(config: Dictionary):
	id = IdGenerator.generate("execution")
	timeline_id = str(config.get("timelineId", ""))
	_timeline = TimelineRegistry.get_timeline(timeline_id)
	_tag_actions = config.get("tagActions", {})
	_event_chain.assign(config.get("eventChain", []))
	_game_state_provider = config.get("gameplayState", null)
	_ability_info = config.get("abilityInfo", {})
	if _timeline == null:
		Log.warning("AbilityExecutionInstance", "Timeline not found: %s" % timeline_id)

func get_elapsed() -> float:
	return _elapsed

func get_state() -> String:
	return _state

func is_executing() -> bool:
	return _state == STATE_EXECUTING

func is_completed() -> bool:
	return _state == STATE_COMPLETED

func is_cancelled() -> bool:
	return _state == STATE_CANCELLED

func get_trigger_event() -> Variant:
	if _event_chain.is_empty():
		return null
	return _event_chain[_event_chain.size() - 1]

func tick(dt: float) -> Array[String]:
	if _state != STATE_EXECUTING:
		return []
	if _timeline == null:
		_state = STATE_COMPLETED
		return []

	var previous_elapsed := _elapsed
	_elapsed += dt

	var triggered_this_tick: Array[Dictionary] = []
	var tags: Dictionary = _timeline.get("tags", {})
	for tag_name in tags.keys():
		var tag_time := float(tags[tag_name])
		var should_trigger := false
		if tag_time == 0.0:
			should_trigger = (previous_elapsed == 0.0 and _elapsed >= 0.0 and not _triggered_tags.has(tag_name))
		else:
			should_trigger = (previous_elapsed < tag_time and _elapsed >= tag_time and not _triggered_tags.has(tag_name))
		if should_trigger:
			_triggered_tags[tag_name] = true
			triggered_this_tick.append({
				"tagName": tag_name,
				"tagTime": tag_time,
				"elapsed": _elapsed,
			})

	triggered_this_tick.sort_custom(func(a, b): return a["tagTime"] < b["tagTime"])

	for entry in triggered_this_tick:
		var actions: Array = _resolve_actions_for_tag(str(entry["tagName"]))
		Log.debug("AbilityExecutionInstance", "触发 %s" % str(entry["tagName"]))
		_execute_actions_for_tag(str(entry["tagName"]), actions)

	var total_duration := float(_timeline.get("totalDuration", 0.0))
	if _elapsed >= total_duration:
		_state = STATE_COMPLETED
		Log.debug("AbilityExecutionInstance", "执行完成")

	var triggered_tags: Array[String] = []
	for entry in triggered_this_tick:
		triggered_tags.append(entry["tagName"])
	return triggered_tags

func cancel() -> void:
	if _state == STATE_EXECUTING:
		_state = STATE_CANCELLED
		Log.debug("AbilityExecutionInstance", "执行取消")

func _execute_actions_for_tag(tag_name: String, actions: Array) -> void:
	if actions.is_empty():
		return
	var exec_context = _build_execution_context(tag_name)
	for action in actions:
		if action != null:
			action.execute(exec_context)
		else:
			Log.warning("AbilityExecutionInstance", "ExecutionInstance missing action")

func _resolve_actions_for_tag(tag_name: String) -> Array:
	if _tag_actions.has(tag_name):
		return _tag_actions[tag_name]
	for pattern in _tag_actions.keys():
		if _match_pattern(str(pattern), tag_name):
			return _tag_actions[pattern]
	return []

func _match_pattern(pattern: String, tag_name: String) -> bool:
	if pattern.find("*") == -1:
		return pattern == tag_name
	if pattern.ends_with("*"):
		var prefix := pattern.substr(0, pattern.length() - 1)
		return tag_name.begins_with(prefix)
	return false

func _build_execution_context(current_tag: String) -> ExecutionContext:
	return ExecutionContext.create_execution_context({
		"eventChain": _event_chain,
		"gameplayState": _game_state_provider,
		"eventCollector": GameWorld.event_collector,
		"ability": {
			"id": _ability_info.get("id", ""),
			"configId": _ability_info.get("configId", ""),
			"owner_actor_id": _ability_info.get("owner_actor_id", ""),
			"source_actor_id": _ability_info.get("source_actor_id", ""),
		},
		"execution": {
			"id": id,
			"timelineId": timeline_id,
			"elapsed": _elapsed,
			"currentTag": current_tag,
		},
	})

func _collect_action_types(actions: Array) -> Array[String]:
	var types: Array[String] = []
	for action in actions:
		if action == null:
			continue
		if action.has("type"):
			types.append(action["type"])
		elif action.has_method("get_type"):
			types.append(action.get_type())
		elif action.has_method("type"):
			types.append(action.type)
		else:
			types.append("unknown")
	return types

func serialize() -> Dictionary:
	var triggered := []
	for tag in _triggered_tags.keys():
		triggered.append(tag)
	return {
		"id": id,
		"timelineId": timeline_id,
		"elapsed": _elapsed,
		"state": _state,
		"triggeredTags": triggered,
	}
