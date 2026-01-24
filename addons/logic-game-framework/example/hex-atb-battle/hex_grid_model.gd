## HexGridModel - 六边形网格模型
##
## 管理六边形地图的格子、占用和预订状态
class_name HexGridModel
extends RefCounted


# ========== 配置 ==========

var rows: int
var columns: int
var hex_size: float
var orientation: String  # "flat" or "pointy"

## 格子集合（key: "q,r"）
var _tiles: Dictionary = {}

## 占用状态（key: "q,r", value: ActorRef）
var _occupants: Dictionary = {}

## 预订状态（key: "q,r", value: actor_id）
var _reservations: Dictionary = {}


# ========== 初始化 ==========

func _init(config: Dictionary) -> void:
	rows = config.get("rows", 9)
	columns = config.get("columns", 9)
	hex_size = config.get("hex_size", 100.0)
	orientation = config.get("orientation", "flat")
	
	_generate_tiles()


## 生成中心对称的六边形地图
func _generate_tiles() -> void:
	# 中心对称地图：坐标范围是 [-half, half]
	var half_rows := rows / 2
	var half_cols := columns / 2
	
	for q in range(-half_cols, half_cols + 1):
		for r in range(-half_rows, half_rows + 1):
			var coord := { "q": q, "r": r }
			var key := HexGridCompat.hex_key(coord)
			_tiles[key] = true


# ========== 格子查询 ==========

## 检查格子是否存在
func has_tile(coord: Dictionary) -> bool:
	var key := HexGridCompat.hex_key(coord)
	return _tiles.has(key)


## 检查格子是否被占用
func is_occupied(coord: Dictionary) -> bool:
	var key := HexGridCompat.hex_key(coord)
	return _occupants.has(key)


## 检查格子是否被预订
func is_reserved(coord: Dictionary) -> bool:
	var key := HexGridCompat.hex_key(coord)
	return _reservations.has(key)


## 获取格子的占用者
func get_occupant_at(coord: Dictionary) -> ActorRef:
	var key := HexGridCompat.hex_key(coord)
	return _occupants.get(key, null)


## 获取格子的预订者 ID
func get_reservation(coord: Dictionary) -> String:
	var key := HexGridCompat.hex_key(coord)
	return _reservations.get(key, "")


# ========== 占用管理 ==========

## 放置占用者
func place_occupant(coord: Dictionary, actor_ref: ActorRef) -> bool:
	if not has_tile(coord):
		return false
	if is_occupied(coord):
		return false
	
	var key := HexGridCompat.hex_key(coord)
	_occupants[key] = actor_ref
	return true


## 移除占用者
func remove_occupant(coord: Dictionary) -> bool:
	var key := HexGridCompat.hex_key(coord)
	if not _occupants.has(key):
		return false
	_occupants.erase(key)
	return true


## 移动占用者
func move_occupant(from_coord: Dictionary, to_coord: Dictionary) -> bool:
	if not has_tile(to_coord):
		return false
	
	var from_key := HexGridCompat.hex_key(from_coord)
	var to_key := HexGridCompat.hex_key(to_coord)
	
	if not _occupants.has(from_key):
		return false
	
	# 检查目标格子是否可用（未被占用，或者被当前移动者预订）
	if _occupants.has(to_key):
		return false
	
	var actor_ref: ActorRef = _occupants[from_key]
	
	# 检查预订：如果目标被预订，必须是当前移动者的预订
	if _reservations.has(to_key):
		if _reservations[to_key] != actor_ref.id:
			return false
		# 取消预订
		_reservations.erase(to_key)
	
	# 执行移动
	_occupants.erase(from_key)
	_occupants[to_key] = actor_ref
	return true


## 查找占用者的位置
func find_occupant_position(actor_id: String) -> Dictionary:
	for key in _occupants.keys():
		var actor_ref: ActorRef = _occupants[key]
		if actor_ref.id == actor_id:
			return HexGridCompat.parse_hex_key(key)
	return {}


# ========== 预订管理 ==========

## 预订格子
func reserve_tile(coord: Dictionary, actor_id: String) -> bool:
	if not has_tile(coord):
		return false
	if is_occupied(coord):
		return false
	if is_reserved(coord):
		return false
	
	var key := HexGridCompat.hex_key(coord)
	_reservations[key] = actor_id
	return true


## 取消预订
func cancel_reservation(coord: Dictionary) -> bool:
	var key := HexGridCompat.hex_key(coord)
	if not _reservations.has(key):
		return false
	_reservations.erase(key)
	return true


# ========== 坐标转换 ==========

## 六边形坐标转世界坐标
func coord_to_world(coord: Dictionary) -> Vector2:
	return HexGridCompat.hex_to_pixel(coord, hex_size)


## 世界坐标转六边形坐标
func world_to_coord(world_pos: Vector2) -> Dictionary:
	return HexGridCompat.pixel_to_hex(world_pos, hex_size)


## 获取相邻格子的世界距离
func get_adjacent_world_distance() -> float:
	return hex_size * HexGridCompat.SQRT3
