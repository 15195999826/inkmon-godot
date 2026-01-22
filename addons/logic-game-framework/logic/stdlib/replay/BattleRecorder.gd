extends RefCounted
class_name BattleRecorder

var config: Dictionary
var is_recording: bool = false
var current_frame: int = 0
var recorded_at: int = 0
var configs: Dictionary = {}
var initial_actors: Array = []
var timeline: Array = []
var actor_subscriptions: Dictionary = {}
var pending_events: Array = []

func _init(recorder_config: Dictionary = {}):
	var battle_id = recorder_config.get("battleId", "")
	if battle_id.is_empty():
		battle_id = IdGenerator.generate("battle")

	config = {
		"battleId": battle_id,
		"tickInterval": recorder_config.get("tickInterval", 100),
	}

func start_recording(actors: Array, configs_value: Dictionary = {}) -> void:
	if is_recording:
		push_error("[BattleRecorder] Already recording")
		return

	is_recording = true
	recorded_at = Time.get_unix_time_from_system()
	current_frame = 0
	timeline.clear()
	configs = configs_value
	pending_events.clear()

	for actor in actors:
		initial_actors.append(_capture_actor_init_data(actor))
		_subscribe_actor(actor)

func record_frame(frame: int, events: Array) -> void:
	if not is_recording:
		return

	current_frame = frame

	var all_events = []
	all_events.append_array(events)
	all_events.append_array(pending_events)
	pending_events.clear()

	if not all_events.is_empty():
		timeline.append({
			"frame": frame,
			"events": all_events,
		})

func stop_recording(result: String = "") -> Dictionary:
	if not is_recording:
		push_error("[BattleRecorder] Not recording")
		return {}

	for subscription in actor_subscriptions.values():
		for unsub in subscription.get("unsubscribes", []):
			if unsub is Callable:
				unsub.call()

	actor_subscriptions.clear()

	is_recording = false

	var meta := {
		"battleId": config.get("battleId", ""),
		"recordedAt": recorded_at,
		"tickInterval": config.get("tickInterval", 100),
		"totalFrames": current_frame,
		"result": result,
	}

	return {
		"version": "2.0",
		"meta": meta,
		"configs": configs,
		"initialActors": initial_actors,
		"timeline": timeline,
	}

func export_json(result: String = "", pretty: bool = true) -> String:
	var record = stop_recording(result)
	return JSON.stringify(record, "\t" if pretty else "")

func get_is_recording() -> bool:
	return is_recording

func get_current_frame() -> int:
	return current_frame

func get_timeline() -> Array:
	return timeline.duplicate(true)

func register_actor(actor) -> void:
	if not is_recording:
		return

	var init_data = _capture_actor_init_data(actor)
	var event = GameEvent.create_actor_spawned_event(init_data)
	pending_events.append(event)

	_subscribe_actor(actor)

func unregister_actor(actor_id: String, reason: String = "") -> void:
	if not is_recording:
		return

	var event = GameEvent.create_actor_destroyed_event(actor_id, reason)
	pending_events.append(event)

	var subscription = actor_subscriptions.get(actor_id)
	if subscription:
		for unsub in subscription.get("unsubscribes", []):
			if unsub is Callable:
				unsub.call()

		actor_subscriptions.erase(actor_id)

func _subscribe_actor(actor) -> void:
	var actor_id = actor.id

	if actor_subscriptions.has(actor_id):
		return

	if not actor.has_method("setupRecording"):
		return

	var ctx = {
		"actorId": actor_id,
		"getLogicTime": func(): return current_frame * config.get("tickInterval",100),
		"pushEvent": func(event): pending_events.append(event),
	}

	var unsubscribes := []
	if actor.setupRecording:
		var result = actor.setupRecording(ctx)
		if result is Array:
			unsubscribes = result
		else:
			unsubscribes = []

	if not unsubscribes.is_empty():
		actor_subscriptions[actor_id] = {
			"actorId": actor_id,
			"unsubscribes": unsubscribes,
		}

func _capture_actor_init_data(actor) -> Dictionary:
	var position_data := {}

	if actor.position:
		position_data["world"] = {
			"x": actor.position.x,
			"y": actor.position.y,
			"z": actor.position.z if actor.position.z else 0.0,
		}

	var attributes_data := {}
	if actor.has_method("getAttributeSnapshot"):
		attributes_data = actor.getAttributeSnapshot()

	var abilities_data := []
	if actor.has_method("getAbilitySnapshot"):
		abilities_data = actor.getAbilitySnapshot()

	var tags_data := {}
	if actor.has_method("getTagSnapshot"):
		tags_data = actor.getTagSnapshot()

	return {
		"id": actor.id,
		"configId": actor.config_id if actor.has("configId") else "unknown",
		"displayName": actor.display_name if actor.has("display_name") else actor.id,
		"team": actor.team if actor.has("team") else 0,
		"position": position_data,
		"attributes": attributes_data,
		"abilities": abilities_data,
		"tags": tags_data,
	}
