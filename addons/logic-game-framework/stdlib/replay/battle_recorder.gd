extends RefCounted
class_name BattleRecorder

var config: Dictionary
var is_recording: bool = false
var current_frame: int = 0
var recorded_at: int = 0
var configs: Dictionary = {}
var map_config: Dictionary = {}
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

func start_recording(actors: Array, configs_value: Dictionary = {}, map_config_value: Dictionary = {}) -> void:
	if is_recording:
		push_error("[BattleRecorder] Already recording")
		return

	is_recording = true
	recorded_at = Time.get_unix_time_from_system()
	current_frame = 0
	timeline.clear()
	configs = configs_value
	map_config = map_config_value
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
		"mapConfig": map_config,
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

func register_actor(actor: Actor) -> void:
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

func _subscribe_actor(actor: Actor) -> void:
	var actor_id: String = actor.id

	if actor_subscriptions.has(actor_id):
		return

	var state := {
		"current_frame": current_frame,
		"tick_interval": config.get("tickInterval", 100),
		"pending_events": pending_events,
		"is_recording": is_recording,
	}

	var ctx := {
		"actorId": actor_id,
		"getLogicTime": func(): return state.current_frame * state.tick_interval,
		"pushEvent": func(event):
			if state.is_recording:
				state.pending_events.append(event),
	}

	var unsubscribes: Array = actor.setupRecording(ctx)

	if not unsubscribes.is_empty():
		actor_subscriptions[actor_id] = {
			"actorId": actor_id,
			"unsubscribes": unsubscribes,
		}

func _capture_actor_init_data(actor: Actor) -> Dictionary:
	return {
		"id": actor.id,
		"type": actor.type,  # 用于查找 positionFormats
		"configId": actor.config_id,
		"displayName": actor.display_name,
		"team": actor.team,
		"position": actor.getPositionSnapshot(),
		"attributes": actor.getAttributeSnapshot(),
		"abilities": actor.getAbilitySnapshot(),
		"tags": actor.getTagSnapshot(),
	}
