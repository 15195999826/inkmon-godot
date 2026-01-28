extends RefCounted
class_name BattleRecorder

var _record: ReplayData.BattleRecord
var _meta: ReplayData.BattleMeta
var is_recording: bool = false
var current_frame: int = 0
var actor_subscriptions: Dictionary = {}
var pending_events: Array[Dictionary] = []

func _init(recorder_config: Dictionary = {}):
	var battle_id: String = recorder_config.get("battleId", "")
	if battle_id.is_empty():
		battle_id = IdGenerator.generate("battle")
	
	_meta = ReplayData.BattleMeta.new()
	_meta.battle_id = battle_id
	_meta.tick_interval = recorder_config.get("tickInterval", 100)

func start_recording(actors: Array, configs_value: Dictionary = {}, map_config_value: Dictionary = {}) -> void:
	if is_recording:
		push_error("[BattleRecorder] Already recording")
		return

	is_recording = true
	_meta.recorded_at = Time.get_unix_time_from_system()
	current_frame = 0
	pending_events.clear()
	
	_record = ReplayData.BattleRecord.new()
	_record.meta = _meta
	_record.configs = configs_value
	_record.map_config = map_config_value
	_record.initial_actors = []
	_record.timeline = []

	for actor in actors:
		_record.initial_actors.append(ReplayData.ActorInitData.create(actor))
		_subscribe_actor(actor)

func record_frame(frame: int, events: Array[Dictionary]) -> void:
	if not is_recording:
		return

	current_frame = frame

	var all_events: Array[Dictionary] = []
	all_events.append_array(events)
	all_events.append_array(pending_events)
	pending_events.clear()

	if not all_events.is_empty():
		var frame_data := ReplayData.FrameData.new()
		frame_data.frame = frame
		frame_data.events = all_events
		_record.timeline.append(frame_data)

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

	_meta.total_frames = current_frame
	_meta.result = result

	return _record.to_dict()

func export_json(result: String = "", pretty: bool = true) -> String:
	var record = stop_recording(result)
	return JSON.stringify(record, "\t" if pretty else "")

func get_is_recording() -> bool:
	return is_recording

func get_current_frame() -> int:
	return current_frame

func get_timeline() -> Array:
	if _record == null:
		return []
	var result: Array = []
	for f in _record.timeline:
		result.append(f.to_dict() if f is ReplayData.FrameData else f)
	return result

func register_actor(actor: Actor) -> void:
	if not is_recording:
		return

	var init_data := ReplayData.ActorInitData.create(actor)
	var event := GameEvent.ActorSpawned.create(actor.id, init_data.to_dict())
	pending_events.append(event.to_dict())

	_subscribe_actor(actor)

func unregister_actor(actor_id: String, reason: String = "") -> void:
	if not is_recording:
		return

	var event := GameEvent.ActorDestroyed.create(actor_id, reason)
	pending_events.append(event.to_dict())

	var subscription: Variant = actor_subscriptions.get(actor_id)
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
		"tick_interval": _meta.tick_interval,
		"pending_events": pending_events,
		"is_recording": is_recording,
	}

	var ctx := {
		"actorId": actor_id,
		"getLogicTime": func() -> int: return state.current_frame * state.tick_interval,
		"pushEvent": func(event: Variant) -> void:
			if state.is_recording:
				state.pending_events.append(event),
	}

	var unsubscribes: Array = actor.setupRecording(ctx)

	if not unsubscribes.is_empty():
		actor_subscriptions[actor_id] = {
			"actorId": actor_id,
			"unsubscribes": unsubscribes,
		}


