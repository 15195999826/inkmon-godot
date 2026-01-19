extends RefCounted
class_name HookContext

var hook_name: String
var related_actors: Array
var data: Dictionary

func _init(hook_name_value: String, related_actors_value: Array, data_value: Dictionary) -> void:
	hook_name = hook_name_value
	related_actors = related_actors_value
	data = data_value
