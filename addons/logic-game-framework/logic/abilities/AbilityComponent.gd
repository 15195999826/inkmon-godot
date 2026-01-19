extends RefCounted
class_name AbilityComponent

var type: String = "AbilityComponent"
var _state: String = "active"
var _ability = null

func get_state() -> String:
	return _state

func initialize(ability) -> void:
	_ability = ability
	_state = "active"

func mark_expired() -> void:
	_state = "expired"

func is_expired() -> bool:
	return _state == "expired"

func get_ability():
	return _ability
