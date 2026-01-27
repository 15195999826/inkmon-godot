extends RefCounted
class_name GameplayInstance

var id: String
var type: String = "instance"
var _systems: Array = []
var _actors: Array = []
var _logic_time: float = 0.0
var _state: String = "created"

func _init(id_value: String = ""):
	id = id_value if id_value != "" else IdGenerator.generate("instance")

func get_logic_time() -> float:
	return _logic_time

func get_state() -> String:
	return _state

func is_running() -> bool:
	return _state == "running"

func get_actor_count() -> int:
	return _actors.size()

func tick(_dt: float) -> void:
	pass

func base_tick(dt: float) -> void:
	if not is_running():
		return
	_logic_time += dt
	for system in _systems:
		if system != null and system.has_method("get_enabled") and system.get_enabled():
			if system.has_method("tick"):
				var call_ok := true
				call_ok = true
				system.tick(_actors, dt)

func start() -> void:
	if _state != "created":
		Log.warning("GameplayInstance", "Cannot start instance in state: %s" % _state)
		return
	_state = "running"
	on_start()

func pause() -> void:
	if _state == "running":
		_state = "paused"
		on_pause()

func resume() -> void:
	if _state == "paused":
		_state = "running"
		on_resume()

func end() -> void:
	if _state == "ended":
		return
	_state = "ended"
	on_end()
	for actor in _actors:
		if actor != null and actor.has_method("on_despawn"):
			actor.on_despawn()
	for system in _systems:
		if system != null and system.has_method("on_unregister"):
			system.on_unregister()

func on_start() -> void:
	pass

func on_pause() -> void:
	pass

func on_resume() -> void:
	pass

func on_end() -> void:
	pass

func create_actor(factory: Callable) -> Variant:
	var actor = factory.call()
	_actors.append(actor)
	if actor != null and actor.has_method("on_spawn"):
		actor.on_spawn()
	return actor

func remove_actor(actor_id: String) -> bool:
	for i in range(_actors.size()):
		if _actors[i] != null and _actors[i].has_method("get_id") and _actors[i].get_id() == actor_id:
			var actor = _actors[i]
			if actor != null and actor.has_method("on_despawn"):
				actor.on_despawn()
			_actors.remove_at(i)
			return true
	return false

func get_actor(actor_id: String) -> Variant:
	for actor in _actors:
		if actor != null and actor.has_method("get_id") and actor.get_id() == actor_id:
			return actor
	return null

func get_actors() -> Array:
	return _actors

func get_actors_by_type(actor_type: String) -> Array:
	var results := []
	for actor in _actors:
		if actor != null and actor.has("type") and actor.type == actor_type:
			results.append(actor)
		elif actor != null and actor.has_method("type") and actor.type == actor_type:
			results.append(actor)
	return results

func find_actors(predicate: Callable) -> Array:
	var results := []
	for actor in _actors:
		if predicate.call(actor):
			results.append(actor)
	return results

func add_system(system: System) -> void:
	for existing in _systems:
		if existing != null and existing.has("type") and existing.type == system.type:
			Log.warning("GameplayInstance", "System already exists: %s" % system.type)
			return
		elif existing != null and existing.has_method("type") and existing.type == system.type:
			Log.warning("GameplayInstance", "System already exists: %s" % system.type)
			return
	_systems.append(system)
	_systems.sort_custom(func(a, b): return a.priority < b.priority)
	if system != null and system.has_method("on_register"):
		system.on_register(self)

func remove_system(system_type: String) -> bool:
	for i in range(_systems.size()):
		if _systems[i] != null and _systems[i].has("type") and _systems[i].type == system_type:
			var system = _systems[i]
			if system != null and system.has_method("on_unregister"):
				system.on_unregister()
			_systems.remove_at(i)
			return true
		elif _systems[i] != null and _systems[i].has_method("type") and _systems[i].type == system_type:
			var system_method = _systems[i]
			if system_method != null and system_method.has_method("on_unregister"):
				system_method.on_unregister()
			_systems.remove_at(i)
			return true
	return false

func get_system(system_type: String) -> Variant:
	for system in _systems:
		if system != null and system.has("type") and system.type == system_type:
			return system
		elif system != null and system.has_method("type") and system.type == system_type:
			return system
	return null

func get_systems() -> Array:
	return _systems

func serialize_base() -> Dictionary:
	var actors := []
	for actor in _actors:
		if actor != null and actor.has_method("serialize_base"):
			actors.append(actor.serialize_base())
	return {
		"id": id,
		"type": type,
		"state": _state,
		"logicTime": _logic_time,
		"actors": actors,
	}
