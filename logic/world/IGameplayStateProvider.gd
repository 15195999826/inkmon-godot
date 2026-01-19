extends RefCounted
class_name IGameplayStateProvider

const Actor = preload("res://logic/entity/Actor.gd")

func get_alive_actors() -> Array:
	return []

func get_actor(_id: String):
	return null
