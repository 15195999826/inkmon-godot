extends RefCounted
class_name GameWorld

static var _instance: GameWorld = null

var _instances: Dictionary = {}
var event_processor: EventProcessor
var event_collector: EventCollector
var _initialized := false

func _init(config: Dictionary = {}):
	event_processor = EventProcessor.create_event_processor(config.get("eventProcessor", {}))
	event_collector = EventCollector.new()

static func init(config: Dictionary = {}) -> GameWorld:
	if _instance:
		Log.warning("GameWorld", "GameWorld already initialized, reinitializing...")
		_instance.shutdown()
	_instance = GameWorld.new(config)
	_instance.initialize()
	return _instance

static func get_instance() -> GameWorld:
	if not _instance:
		_instance = GameWorld.new()
		_instance.initialize()
	return _instance

static func destroy() -> void:
	if _instance:
		_instance.shutdown()
		_instance = null

func initialize() -> void:
	if _initialized:
		return
	_initialized = true
	Log.info("GameWorld", "GameWorld initialized")

func shutdown() -> void:
	_end_all_instances()
	_instances.clear()
	_initialized = false
	Log.info("GameWorld", "GameWorld shutdown")

func create_instance(factory: Callable):
	var instance = factory.call()
	if not instance or not instance.id or str(instance.id) == "":
		Log.warning("GameWorld", "Instance factory returned invalid instance")
		return instance
	if _instances.has(instance.id):
		Log.warning("GameWorld", "Instance already exists: %s" % instance.id)
		return _instances[instance.id]
	_instances[instance.id] = instance
	Log.debug("GameWorld", "Instance created: %s (%s)" % [instance.id, instance.type])
	return instance

func get_instance_by_id(id_value: String):
	return _instances.get(id_value, null)

func get_instances() -> Array:
	return _instances.values()

func get_instances_by_type(type_value: String) -> Array:
	return _instances.values().filter(func(inst): return inst and _matches_instance_type(inst, type_value))

func destroy_instance(id_value: String) -> bool:
	if not _instances.has(id_value):
		return false
	var instance = _instances[id_value]
	if instance and instance.has_method("end"):
		instance.end()
	_instances.erase(id_value)
	Log.debug("GameWorld", "Instance destroyed: %s" % id_value)
	return true

func destroy_all_instances() -> void:
	_end_all_instances()
	_instances.clear()
	Log.debug("GameWorld", "All instances destroyed")

func tick_all(dt: float) -> void:
	for instance in _instances.values():
		if _is_running_instance(instance):
			instance.tick(dt)

func get_instance_count() -> int:
	return _instances.size()

func has_running_instances() -> bool:
	for instance in _instances.values():
		if _is_running_instance(instance):
			return true
	return false

func get_debug_info() -> Dictionary:
	var instances_info := []
	for instance in _instances.values():
		instances_info.append({
			"id": instance.id,
			"type": instance.type,
			"state": instance.get_state() if instance.has_method("get_state") else "",
			"actorCount": instance.get_actor_count() if instance.has_method("get_actor_count") else 0,
		})
	return {
		"initialized": _initialized,
		"instanceCount": _instances.size(),
		"instances": instances_info,
	}

func _end_all_instances() -> void:
	for instance in _instances.values():
		if instance and instance.has_method("end"):
			instance.end()

func _is_running_instance(instance) -> bool:
	return instance and instance.has_method("is_running") and instance.is_running()

func _matches_instance_type(instance, type_value: String) -> bool:
	if "type" in instance:
		return instance.type == type_value
	if instance.has_method("type"):
		return instance.type() == type_value
	return false
