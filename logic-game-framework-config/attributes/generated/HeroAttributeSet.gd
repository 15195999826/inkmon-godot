extends RefCounted
class_name HeroAttributeSet

var _raw: RawAttributeSet
var _modifier_target: Dictionary
var modifierTarget: Dictionary

func _init() -> void:
	var attr_set := AttributeFactory.define_attributes({
		"attack": { "baseValue": 10.0 },
		"maxHp": { "baseValue": 100.0 },
	})
	_raw = attr_set["_raw"] as RawAttributeSet
	_modifier_target = attr_set["_modifierTarget"] as Dictionary
	modifierTarget = _modifier_target


var attack: float:
	get:
		return _raw.get_current_value("attack")
var attackBreakdown: Dictionary:
	get:
		return _raw.get_breakdown("attack")
func getAttackBreakdown() -> Dictionary:
	return _raw.get_breakdown("attack")
const attackAttribute := "attack"
func setAttackBase(value: float) -> void:
	_raw.set_base("attack", value)
func onAttackChanged(callback: Callable) -> Callable:
	var filtered_listener := func(event: Dictionary) -> void:
		if event.get("attributeName", "") == "attack":
			callback.call(event)
	_raw.add_change_listener(filtered_listener)
	return func() -> void:
		_raw.remove_change_listener(filtered_listener)

var maxHp: float:
	get:
		return _raw.get_current_value("maxHp")
var maxHpBreakdown: Dictionary:
	get:
		return _raw.get_breakdown("maxHp")
func getMaxHpBreakdown() -> Dictionary:
	return _raw.get_breakdown("maxHp")
const maxHpAttribute := "maxHp"
func setMaxHpBase(value: float) -> void:
	_raw.set_base("maxHp", value)
func onMaxHpChanged(callback: Callable) -> Callable:
	var filtered_listener := func(event: Dictionary) -> void:
		if event.get("attributeName", "") == "maxHp":
			callback.call(event)
	_raw.add_change_listener(filtered_listener)
	return func() -> void:
		_raw.remove_change_listener(filtered_listener)
