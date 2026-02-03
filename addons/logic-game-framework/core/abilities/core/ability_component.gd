extends RefCounted
class_name AbilityComponent
## Ability 组件基类
##
## 所有 Ability 组件都应继承此类。
## 提供可选的生命周期钩子，子类按需覆盖。

var type: String = "AbilityComponent"
var _state: String = "active"
var _ability: Ability = null


func get_state() -> String:
	return _state


func initialize(ability: Ability) -> void:
	_ability = ability
	_state = "active"


func is_active() -> bool:
	return _state == "active"


func mark_expired() -> void:
	_state = "expired"


func is_expired() -> bool:
	return _state == "expired"


func get_ability() -> Ability:
	return _ability


## 每帧 tick（可选覆盖）
func on_tick(_dt: float) -> void:
	pass


## 响应事件（可选覆盖）
## @return true 表示组件被触发
func on_event(_event_dict: Dictionary, _context: AbilityLifecycleContext, _game_state_provider: Variant) -> bool:
	return false


## 能力生效时调用（可选覆盖）
func on_apply(_context: AbilityLifecycleContext) -> void:
	pass


## 能力移除时调用（可选覆盖）
func on_remove(_context: AbilityLifecycleContext) -> void:
	pass


## 序列化组件状态（可选覆盖）
func serialize() -> Dictionary:
	return {}
