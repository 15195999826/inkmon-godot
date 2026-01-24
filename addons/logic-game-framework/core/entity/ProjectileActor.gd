extends Actor
class_name ProjectileActor

const PROJECTILE_TYPE_BULLET := "bullet"
const PROJECTILE_TYPE_HITSCAN := "hitscan"
const PROJECTILE_TYPE_MOBA := "moba"

const STATE_IDLE := "idle"
const STATE_FLYING := "flying"
const STATE_HIT := "hit"
const STATE_MISSED := "missed"
const STATE_DESPAWNED := "despawned"

const DEFAULT_CONFIG := {
	"projectileType": PROJECTILE_TYPE_BULLET,
	"speed": 500.0,
	"maxLifetime": 5000.0,
}

var config: Dictionary = {}
var _position: Vector3 = Vector3.ZERO

var _projectile_state: String = STATE_IDLE
var _launch_params: Dictionary = {}
var _fly_time: float = 0.0
var _fly_distance: float = 0.0
var _pierce_count: int = 0
var _hit_targets: Dictionary = {}

func _init(config_value: Dictionary = {}):
	type = "Projectile"
	config = DEFAULT_CONFIG.duplicate(true)
	if config_value != null:
		for key in config_value.keys():
			config[key] = config_value[key]


## 覆盖基类方法，返回投射物位置
func _get_position() -> Variant:
	return _position

func get_projectile_state() -> String:
	return _projectile_state

func is_flying() -> bool:
	return _projectile_state == STATE_FLYING

func get_launch_params() -> Dictionary:
	return _launch_params

func get_source():
	return _launch_params.get("source", null)

func get_target():
	return _launch_params.get("target", null)

func get_fly_time() -> float:
	return _fly_time

func get_fly_distance() -> float:
	return _fly_distance

func get_pierce_count() -> int:
	return _pierce_count

func get_hit_targets() -> Array:
	return _hit_targets.keys()

func launch(params: Dictionary) -> void:
	if _projectile_state != STATE_IDLE:
		return

	_launch_params = params.duplicate(true)
	if params.has("startPosition") and params["startPosition"] is Vector3:
		_position = params["startPosition"]

	_projectile_state = STATE_FLYING
	_fly_time = 0.0
	_fly_distance = 0.0
	_pierce_count = 0
	_hit_targets.clear()

	if str(config.get("projectileType", PROJECTILE_TYPE_BULLET)) == PROJECTILE_TYPE_HITSCAN:
		if params.has("targetPosition") and params["targetPosition"] is Vector3:
			_position = params["targetPosition"]

func update(dt: float) -> bool:
	if _projectile_state != STATE_FLYING:
		return false

	if str(config.get("projectileType", PROJECTILE_TYPE_BULLET)) == PROJECTILE_TYPE_HITSCAN:
		return false

	_fly_time += dt
	if _fly_time >= float(config.get("maxLifetime", 0.0)):
		miss("timeout")
		return false

	update_position(dt)
	return true

func update_position(dt: float) -> void:
	if _launch_params.is_empty():
		return

	var dt_seconds := dt / 1000.0
	var move_distance := float(config.get("speed", 0.0)) * dt_seconds
	_fly_distance += move_distance

	var movement := Vector3.ZERO
	if _launch_params.has("direction") and _launch_params["direction"] != null:
		var direction := float(_launch_params["direction"])
		movement = Vector3(cos(direction) * move_distance, sin(direction) * move_distance, 0.0)
	elif _launch_params.has("targetPosition") and _launch_params["targetPosition"] is Vector3:
		var target_pos: Vector3 = _launch_params["targetPosition"]
		var direction_vec: Vector3 = target_pos - _position
		var distance_to_target := direction_vec.length()
		if distance_to_target > 0.0:
			var actual_move := min(move_distance, distance_to_target)
			movement = direction_vec.normalized() * actual_move

	_position += movement

func get_distance_to_target() -> float:
	if not _launch_params.has("targetPosition"):
		return INF
	if not (_launch_params["targetPosition"] is Vector3):
		return INF
	return _position.distance_to(_launch_params["targetPosition"])

func hit(target_id: String) -> bool:
	if _projectile_state != STATE_FLYING:
		return false

	_hit_targets[target_id] = true

	if bool(config.get("piercing", false)):
		_pierce_count += 1
		var max_pierce = config.get("maxPierceCount", null)
		var max_pierce_count := INF if max_pierce == null else int(max_pierce)
		if _pierce_count < max_pierce_count:
			return true

	_projectile_state = STATE_HIT
	return false

func miss(_reason: String = "no_target") -> void:
	if _projectile_state != STATE_FLYING:
		return
	_projectile_state = STATE_MISSED

func despawn() -> void:
	_projectile_state = STATE_DESPAWNED
	on_despawn()

func has_hit_target(target_id: String) -> bool:
	return _hit_targets.has(target_id)

func should_moba_hit() -> bool:
	if str(config.get("projectileType", PROJECTILE_TYPE_BULLET)) != PROJECTILE_TYPE_MOBA:
		return false
	var hit_distance := float(config.get("hitDistance", 50.0))
	return get_distance_to_target() <= hit_distance

func serialize() -> Dictionary:
	var data := serialize_base()
	data["config"] = config
	data["position"] = _position
	data["projectileState"] = _projectile_state
	data["launchParams"] = _launch_params
	data["flyTime"] = _fly_time
	data["flyDistance"] = _fly_distance
	data["pierceCount"] = _pierce_count
	data["hitTargets"] = _hit_targets.keys()
	return data
