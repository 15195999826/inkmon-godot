extends RefCounted
class_name Actor

var _id: String = ""
var _instance_id: String = ""
var type: String = "actor"
var _state: String = "active"
var _team: String = ""
var _display_name: String = ""
var _on_spawn_callbacks: Array = []
var _on_despawn_callbacks: Array = []


## 获取完整 Actor ID（格式: "{instance_id}:{local_id}"）
func get_id() -> String:
	var local_id := get_local_id()
	if _instance_id.is_empty():
		return local_id
	return ActorId.format(_instance_id, local_id)


## 获取本地 ID（不含 instance_id 前缀）
func get_local_id() -> String:
	if _id == "":
		_id = IdGenerator.generate(type)
	return _id


## 设置所属实例 ID（由 GameplayInstance.create_actor 调用）
func set_instance_id(instance_id: String) -> void:
	_instance_id = instance_id


## 获取所属实例 ID
func get_instance_id_value() -> String:
	return _instance_id

func get_state() -> String:
	return _state

func is_active() -> bool:
	return _state == "active"

func is_dead() -> bool:
	return _state == "dead"

func get_team() -> String:
	return _team

func set_team(value: String) -> void:
	_team = value

func get_display_name() -> String:
	if _display_name != "":
		return _display_name
	return "%s_%s" % [type, get_id()]

func set_display_name(value: String) -> void:
	_display_name = value

func on_spawn() -> void:
	_state = "active"
	for callback in _on_spawn_callbacks:
		if callback.is_valid():
			callback.call()

func on_despawn() -> void:
	_state = "removed"
	for callback in _on_despawn_callbacks:
		if callback.is_valid():
			callback.call()

func add_spawn_listener(callback: Callable) -> Callable:
	_on_spawn_callbacks.append(callback)
	return func() -> void:
		var index := _on_spawn_callbacks.find(callback)
		if index != -1:
			_on_spawn_callbacks.remove_at(index)

func add_despawn_listener(callback: Callable) -> Callable:
	_on_despawn_callbacks.append(callback)
	return func() -> void:
		var index := _on_despawn_callbacks.find(callback)
		if index != -1:
			_on_despawn_callbacks.remove_at(index)

func on_death() -> void:
	_state = "dead"

func revive() -> void:
	if _state == "dead":
		_state = "active"

func set_state(state: String) -> void:
	_state = state

func deactivate() -> void:
	_state = "inactive"

func activate() -> void:
	if _state == "inactive":
		_state = "active"

func to_ref() -> ActorRef:
	return ActorRef.new(get_id())

func serialize_base() -> Dictionary:
	return {
		"id": get_id(),
		"type": type,
		"state": _state,
		"team": _team,
		"displayName": _display_name,
	}


# ========== 录像支持（BattleRecorder 接口） ==========

## Actor ID（BattleRecorder 兼容属性）
var id: String:
	get:
		return get_id()

## 配置 ID（子类应覆盖 _get_config_id 方法）
var config_id: String:
	get:
		return _get_config_id()

## 显示名称（BattleRecorder 兼容属性）
var display_name: String:
	get:
		return get_display_name()
	set(value):
		set_display_name(value)

## 队伍（BattleRecorder 兼容属性，子类应覆盖 _get_team_int 方法）
var team: int:
	get:
		return _get_team_int()

## 位置（子类应覆盖 _get_position 方法）
var position: Vector3:
	get:
		return _get_position()


## 获取配置 ID（子类可覆盖）
func _get_config_id() -> String:
	return type


## 获取队伍 ID（子类可覆盖）
func _get_team_int() -> int:
	return int(_team) if _team.is_valid_int() else 0


## 获取位置（子类可覆盖）
func _get_position() -> Vector3:
	return Vector3.ZERO


## 获取位置快照
## 返回 [x, y, z] 格式的数组，用于录像存储
## 具体含义（hex/world/tile）由 configs.positionFormats 声明，渲染层解释
func getPositionSnapshot() -> Array:
	var pos := _get_position()
	return [pos.x, pos.y, pos.z]


## 设置录像回调（BattleRecorder 调用）
## 子类可覆盖此方法以订阅事件并返回取消订阅的回调数组
func setupRecording(_ctx: Dictionary) -> Array:
	return []


## 获取属性快照（子类应覆盖）
func getAttributeSnapshot() -> Dictionary:
	return {}


## 获取 Ability 快照（子类应覆盖）
func getAbilitySnapshot() -> Array:
	return []


## 获取 Tag 快照（子类应覆盖）
func getTagSnapshot() -> Dictionary:
	return {}
