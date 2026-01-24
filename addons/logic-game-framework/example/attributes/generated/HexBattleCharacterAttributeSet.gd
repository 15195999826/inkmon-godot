extends RefCounted
class_name HexBattleCharacterAttributeSet

var _raw: RawAttributeSet

func _init() -> void:
	_raw = RawAttributeSet.new()
	_raw.apply_config({
		"atk": { "baseValue": 50.0 },
		"def": { "baseValue": 30.0 },
		"hp": { "baseValue": 100.0, "minValue": 0.0 },
		"maxHp": { "baseValue": 100.0, "minValue": 1.0 },
		"speed": { "baseValue": 100.0 },
	})


var atk: float:
	get:
		return _raw.get_current_value("atk")
var atkBreakdown: Dictionary:
	get:
		return _raw.get_breakdown("atk")
func getAtkBreakdown() -> Dictionary:
	return _raw.get_breakdown("atk")
const atkAttribute := "atk"
func setAtkBase(value: float) -> void:
	_raw.set_base("atk", value)
func onAtkChanged(callback: Callable) -> Callable:
	var filtered_listener := func(event: Dictionary) -> void:
		if event.get("attributeName", "") == "atk":
			callback.call(event)
	_raw.add_change_listener(filtered_listener)
	return func() -> void:
		_raw.remove_change_listener(filtered_listener)

var def: float:
	get:
		return _raw.get_current_value("def")
var defBreakdown: Dictionary:
	get:
		return _raw.get_breakdown("def")
func getDefBreakdown() -> Dictionary:
	return _raw.get_breakdown("def")
const defAttribute := "def"
func setDefBase(value: float) -> void:
	_raw.set_base("def", value)
func onDefChanged(callback: Callable) -> Callable:
	var filtered_listener := func(event: Dictionary) -> void:
		if event.get("attributeName", "") == "def":
			callback.call(event)
	_raw.add_change_listener(filtered_listener)
	return func() -> void:
		_raw.remove_change_listener(filtered_listener)

var hp: float:
	get:
		return _raw.get_current_value("hp")
var hpBreakdown: Dictionary:
	get:
		return _raw.get_breakdown("hp")
func getHpBreakdown() -> Dictionary:
	return _raw.get_breakdown("hp")
const hpAttribute := "hp"
func setHpBase(value: float) -> void:
	_raw.set_base("hp", value)
func onHpChanged(callback: Callable) -> Callable:
	var filtered_listener := func(event: Dictionary) -> void:
		if event.get("attributeName", "") == "hp":
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

var speed: float:
	get:
		return _raw.get_current_value("speed")
var speedBreakdown: Dictionary:
	get:
		return _raw.get_breakdown("speed")
func getSpeedBreakdown() -> Dictionary:
	return _raw.get_breakdown("speed")
const speedAttribute := "speed"
func setSpeedBase(value: float) -> void:
	_raw.set_base("speed", value)
func onSpeedChanged(callback: Callable) -> Callable:
	var filtered_listener := func(event: Dictionary) -> void:
		if event.get("attributeName", "") == "speed":
			callback.call(event)
	_raw.add_change_listener(filtered_listener)
	return func() -> void:
		_raw.remove_change_listener(filtered_listener)


# ========== RecordingUtils 兼容接口 ==========

## 添加变化监听器（用于 RecordingUtils.record_attribute_changes）
## 返回取消订阅函数
func addChangeListener(listener: Callable) -> Callable:
	_raw.add_change_listener(listener)
	return func() -> void:
		_raw.remove_change_listener(listener)
