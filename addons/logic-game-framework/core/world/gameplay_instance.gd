extends RefCounted
class_name GameplayInstance

var id: String
var type: String = "instance"
var _systems: Array[System] = []
var _actors: Array[Actor] = []
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
		if system.get_enabled():
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
		actor.on_despawn()
	for system in _systems:
		system.on_unregister()

func on_start() -> void:
	pass

func on_pause() -> void:
	pass

func on_resume() -> void:
	pass

func on_end() -> void:
	pass

func create_actor(factory: Callable) -> Actor:
	var actor: Actor = factory.call()
	if actor != null:
		# 设置所属实例 ID，生成规范的 Actor ID
		actor.set_instance_id(id)
		_actors.append(actor)
		actor.on_spawn()
	return actor

func remove_actor(actor_id: String) -> bool:
	for i in range(_actors.size()):
		if _actors[i].get_id() == actor_id:
			var actor := _actors[i]
			actor.on_despawn()
			_actors.remove_at(i)
			return true
	return false

func get_actor(actor_id: String) -> Actor:
	# 支持完整 ID 或 local_id 查找
	var local_id := actor_id
	if ActorId.is_valid(actor_id):
		local_id = ActorId.extract_local_id(actor_id)
	for actor in _actors:
		if actor.get_local_id() == local_id:
			return actor
	return null

func get_actors() -> Array[Actor]:
	return _actors

func get_actors_by_type(actor_type: String) -> Array[Actor]:
	var results: Array[Actor] = []
	for actor in _actors:
		if actor.type == actor_type:
			results.append(actor)
	return results

func find_actors(predicate: Callable) -> Array[Actor]:
	var results: Array[Actor] = []
	for actor in _actors:
		if predicate.call(actor):
			results.append(actor)
	return results

func add_system(system: System) -> void:
	for existing in _systems:
		if existing.type == system.type:
			Log.warning("GameplayInstance", "System already exists: %s" % system.type)
			return
	_systems.append(system)
	_systems.sort_custom(func(a: System, b: System) -> bool: return a.priority < b.priority)
	system.on_register(self)

func remove_system(system_type: String) -> bool:
	for i in range(_systems.size()):
		if _systems[i].type == system_type:
			var system := _systems[i]
			system.on_unregister()
			_systems.remove_at(i)
			return true
	return false

func get_system(system_type: String) -> System:
	for system in _systems:
		if system.type == system_type:
			return system
	return null

func get_systems() -> Array[System]:
	return _systems

func serialize_base() -> Dictionary:
	var actors: Array[Dictionary] = []
	for actor in _actors:
		actors.append(actor.serialize_base())
	return {
		"id": id,
		"type": type,
		"state": _state,
		"logicTime": _logic_time,
		"actors": actors,
	}
