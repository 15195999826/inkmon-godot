extends RefCounted
class_name HookContext

var hook_name: String
var related_actors: Array
var data: Dictionary

func _init(hook_name_value: String, related_actors_value: Array = null, data_value: Dictionary = null):
	hook_name = hook_name_value
	related_actors = related_actors_value if related_actors_value != null else []
	data = data_value if data_value != null else {}
