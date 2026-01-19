extends RefCounted
class_name Actor

const ActorRef = preload("res://logic/types/ActorRef.gd")

var _id: String = ""
var type: String = "actor"
var _state: String = "active"
var _team: String = ""
var _display_name: String = ""
var _on_spawn_callbacks: Array = []
var _on_despawn_callbacks: Array = []

func get_id() -> String:
	if _id == "":
		_id = IdGenerator.generate(type)
	return _id

func get_state() -> String:
	return _state

func is_active() -> bool:
	return _state == "active"

func is_dead() -> bool:
	return _state == "dead"

func get_team() -> String:
	return _team

func set_team(value: String) -> void:
	_team = value

func get_display_name() -> String:
	if _display_name != "":
		return _display_name
	return "%s_%s" % [type, get_id()]

func set_display_name(value: String) -> void:
	_display_name = value

func on_spawn() -> void:
	_state = "active"
	for callback in _on_spawn_callbacks:
		if callback.is_valid():
			callback.call()

func on_despawn() -> void:
	_state = "removed"
	for callback in _on_despawn_callbacks:
		if callback.is_valid():
			callback.call()

func add_spawn_listener(callback: Callable) -> Callable:
	_on_spawn_callbacks.append(callback)
	return func() -> void:
		var index := _on_spawn_callbacks.find(callback)
		if index != -1:
			_on_spawn_callbacks.remove_at(index)

func add_despawn_listener(callback: Callable) -> Callable:
	_on_despawn_callbacks.append(callback)
	return func() -> void:
		var index := _on_despawn_callbacks.find(callback)
		if index != -1:
			_on_despawn_callbacks.remove_at(index)

func on_death() -> void:
	_state = "dead"

func revive() -> void:
	if _state == "dead":
		_state = "active"

func set_state(state: String) -> void:
	_state = state

func deactivate() -> void:
	_state = "inactive"

func activate() -> void:
	if _state == "inactive":
		_state = "active"

func to_ref() -> ActorRef:
	return ActorRef.new(get_id())

func serialize_base() -> Dictionary:
	return {
		"id": get_id(),
		"type": type,
		"state": _state,
		"team": _team,
		"displayName": _display_name,
	}
