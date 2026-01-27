extends RefCounted
class_name System

const SystemPriority = {
	"HIGHEST": 0,
	"HIGH": 100,
	"NORMAL": 500,
	"LOW": 900,
	"LOWEST": 1000,
}

var type: String = "system"
var priority: int = SystemPriority.NORMAL
var _enabled := true
var _instance = null

func _init(priority_value: int = SystemPriority.NORMAL):
	priority = priority_value

func get_enabled() -> bool:
	return _enabled

func set_enabled(value: bool) -> void:
	_enabled = value

func on_register(instance: GameplayInstance) -> void:
	_instance = instance

func on_unregister() -> void:
	_instance = null

func tick(_actors: Array, _dt: float) -> void:
	pass

func get_logic_time() -> float:
	if _instance == null:
		return 0.0
	if _instance.has_method("get_logic_time"):
		return float(_instance.get_logic_time())
	return 0.0

func filter_actors_by_type(actors: Array, actor_type: String) -> Array:
	var results := []
	for actor in actors:
		if actor != null and actor.has("type") and actor.type == actor_type:
			results.append(actor)
		elif actor != null and actor.has_method("type") and actor.type == actor_type:
			results.append(actor)
	return results

func filter_active_actors(actors: Array) -> Array:
	var results := []
	for actor in actors:
		if actor == null:
			continue
		if actor.has_method("is_active") and actor.is_active():
			results.append(actor)
		elif actor.has("isActive") and actor.isActive:
			results.append(actor)
	return results

class NoopSystem:
	extends System

	func _init(priority_value: int = SystemPriority.NORMAL):
		super._init(priority_value)
		type = "noop"
