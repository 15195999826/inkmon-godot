extends RefCounted
class_name ExampleTowerAttributeSet

var _raw: RawAttributeSet
var _modifier_target: Dictionary
var modifierTarget: Dictionary

func _init() -> void:
	var attr_set := AttributeFactory.define_attributes({
		"maxHp": { "baseValue": 350.0 },
		"range": { "baseValue": 6.0 },
	})
	_raw = attr_set["_raw"] as RawAttributeSet
	_modifier_target = attr_set["_modifierTarget"] as Dictionary
	modifierTarget = _modifier_target


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

var range_: float:
	get:
		return _raw.get_current_value("range")
var range_Breakdown: Dictionary:
	get:
		return _raw.get_breakdown("range")
func getRangeBreakdown() -> Dictionary:
	return _raw.get_breakdown("range")
const range_Attribute := "range"
func setRangeBase(value: float) -> void:
	_raw.set_base("range", value)
func onRangeChanged(callback: Callable) -> Callable:
	var filtered_listener := func(event: Dictionary) -> void:
		if event.get("attributeName", "") == "range":
			callback.call(event)
	_raw.add_change_listener(filtered_listener)
	return func() -> void:
		_raw.remove_change_listener(filtered_listener)
