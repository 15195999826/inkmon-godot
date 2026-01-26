## HexGridWorld - 六边形网格世界模型
##
## 整合 HexLayout + HexMap + 占用管理的统一模型类
## 提供 hex_to_world / world_to_hex 等常用 API
##
## 使用方式:
##   # 基于行列（矩形地图）
##   var model := HexGridWorld.new({
##       "draw_mode": "row_column",  # 或省略，默认值
##       "rows": 9,
##       "columns": 9,
##       "hex_size": 100.0,
##       "orientation": "flat",
##   })
##
##   # 基于半径（六边形地图）
##   var model := HexGridWorld.new({
##       "draw_mode": "radius",
##       "radius": 4,
##       "hex_size": 100.0,
##       "orientation": "flat",
##   })
##
## 参考: TypeScript HexGridModel
class_name HexGridWorld
extends RefCounted


# ========== 绘制模式枚举 ==========

enum DrawMode {
	ROW_COLUMN,  ## 基于行列（矩形地图）
	RADIUS,      ## 基于半径（六边形地图）
}


# ========== 配置 ==========

## 绘制模式
var draw_mode: DrawMode

## 行数（仅 ROW_COLUMN 模式）
var rows: int

## 列数（仅 ROW_COLUMN 模式）
var columns: int

## 半径（仅 RADIUS 模式）
var radius: int

## 六边形大小（中心到顶点距离）
var hex_size: float

## 方向 ("flat" 或 "pointy")
var orientation: String

## 地图中心偏移
var origin: Vector2


# ========== 内部组件 ==========

## 布局转换器
var _layout: HexLayout

## 地图存储（使用 Sparse 模式）
var _map: HexMap.Sparse

## 占用状态（key: "q,r", value: OccupantRef）
var _occupants: Dictionary = {}

## 预订状态（key: "q,r", value: actor_id）
var _reservations: Dictionary = {}


# ========== 初始化 ==========

func _init(config: Dictionary = {}) -> void:
	# 解析绘制模式
	var mode_str: String = config.get("draw_mode", "row_column")
	match mode_str:
		"radius":
			draw_mode = DrawMode.RADIUS
		_:
			draw_mode = DrawMode.ROW_COLUMN
	
	# 解析模式相关参数
	rows = config.get("rows", 9)
	columns = config.get("columns", 9)
	radius = config.get("radius", 4)
	
	# 通用参数
	hex_size = config.get("hex_size", 100.0)
	orientation = config.get("orientation", "flat")
	origin = config.get("origin", Vector2.ZERO)
	
	# 创建布局转换器
	var layout_orientation := HexLayout.FLAT if orientation == "flat" else HexLayout.POINTY
	_layout = HexLayout.new(layout_orientation, hex_size, origin)
	
	# 创建地图存储
	_map = HexMap.Sparse.new()
	
	# 生成格子
	_generate_tiles()


## 根据绘制模式生成格子
func _generate_tiles() -> void:
	match draw_mode:
		DrawMode.ROW_COLUMN:
			_generate_tiles_row_column()
		DrawMode.RADIUS:
			_generate_tiles_radius()


## 基于行列生成矩形地图（中心对称）
## 使用 offset 坐标思路生成真正的矩形，然后转换为 axial 坐标
## 参考: https://www.redblobgames.com/grids/hexagons/#map-storage
func _generate_tiles_row_column() -> void:
	var half_rows := rows / 2
	var half_cols := columns / 2
	
	# 遍历 offset 坐标 (col, row)，然后转换为 axial 坐标 (q, r)
	# 对于 flat-top (odd-q offset): q = col, r = row - floor(col/2)
	# 对于 pointy-top (odd-r offset): q = col - floor(row/2), r = row
	for offset_row in range(-half_rows, half_rows + 1):
		for offset_col in range(-half_cols, half_cols + 1):
			var q: int
			var r: int
			if orientation == "flat":
				# flat-top: odd-q offset 转 axial
				q = offset_col
				r = offset_row - (offset_col >> 1)  # floor(col/2) 使用位移
			else:
				# pointy-top: odd-r offset 转 axial
				q = offset_col - (offset_row >> 1)  # floor(row/2) 使用位移
				r = offset_row
			var coord := Vector2i(q, r)
			_map.set_hex(coord, { "terrain": "normal" })


## 基于半径生成六边形地图
func _generate_tiles_radius() -> void:
	var coords := HexMath.axial_range(Vector2i.ZERO, radius)
	for coord in coords:
		_map.set_hex(coord, { "terrain": "normal" })


# ========== 坐标转换 ==========

## 六边形坐标转世界坐标
func hex_to_world(coord: Vector2i) -> Vector2:
	return _layout.hex_to_pixel(coord)


## 六边形坐标转世界坐标（Dictionary 格式，兼容旧 API）
func hex_to_world_dict(coord: Dictionary) -> Vector2:
	return hex_to_world(Vector2i(coord.get("q", 0), coord.get("r", 0)))


## 世界坐标转六边形坐标
func world_to_hex(world_pos: Vector2) -> Vector2i:
	return _layout.pixel_to_hex(world_pos)


## 世界坐标转六边形坐标（Dictionary 格式，兼容旧 API）
func world_to_hex_dict(world_pos: Vector2) -> Dictionary:
	var coord := world_to_hex(world_pos)
	return { "q": coord.x, "r": coord.y }


## 获取相邻格子的世界距离
func get_adjacent_world_distance() -> float:
	return hex_size * HexLayout.SQRT3


# ========== 格子查询 ==========

## 检查格子是否存在
func has_tile(coord: Vector2i) -> bool:
	return _map.has_hex(coord)


## 检查格子是否存在（Dictionary 格式）
func has_tile_dict(coord: Dictionary) -> bool:
	return has_tile(Vector2i(coord.get("q", 0), coord.get("r", 0)))


## 获取格子数据
func get_tile(coord: Vector2i) -> Variant:
	return _map.get_hex(coord)


## 设置格子数据
func set_tile(coord: Vector2i, data: Variant) -> void:
	_map.set_hex(coord, data)


## 获取所有格子坐标
func get_all_coords() -> Array[Vector2i]:
	return _map.get_all_coords()


## 获取格子数量
func get_tile_count() -> int:
	return _map.get_count()


# ========== 占用管理 ==========

## 检查格子是否被占用
func is_occupied(coord: Vector2i) -> bool:
	var key := HexCoord.axial_to_key(coord)
	return _occupants.has(key)


## 检查格子是否被占用（Dictionary 格式）
func is_occupied_dict(coord: Dictionary) -> bool:
	return is_occupied(Vector2i(coord.get("q", 0), coord.get("r", 0)))


## 获取格子的占用者
func get_occupant_at(coord: Vector2i) -> Variant:
	var key := HexCoord.axial_to_key(coord)
	return _occupants.get(key, null)


## 放置占用者
func place_occupant(coord: Vector2i, occupant: Variant) -> bool:
	if not has_tile(coord):
		return false
	if is_occupied(coord):
		return false
	
	var key := HexCoord.axial_to_key(coord)
	_occupants[key] = occupant
	return true


## 放置占用者（Dictionary 格式）
func place_occupant_dict(coord: Dictionary, occupant: Variant) -> bool:
	return place_occupant(Vector2i(coord.get("q", 0), coord.get("r", 0)), occupant)


## 移除占用者
func remove_occupant(coord: Vector2i) -> bool:
	var key := HexCoord.axial_to_key(coord)
	if not _occupants.has(key):
		return false
	_occupants.erase(key)
	return true


## 移除占用者（Dictionary 格式）
func remove_occupant_dict(coord: Dictionary) -> bool:
	return remove_occupant(Vector2i(coord.get("q", 0), coord.get("r", 0)))


## 获取格子的占用者（Dictionary 格式）
func get_occupant_at_dict(coord: Dictionary) -> Variant:
	return get_occupant_at(Vector2i(coord.get("q", 0), coord.get("r", 0)))


## 移动占用者
func move_occupant(from_coord: Vector2i, to_coord: Vector2i) -> bool:
	if not has_tile(to_coord):
		return false
	
	var from_key := HexCoord.axial_to_key(from_coord)
	var to_key := HexCoord.axial_to_key(to_coord)
	
	if not _occupants.has(from_key):
		return false
	
	# 检查目标格子是否可用
	if _occupants.has(to_key):
		return false
	
	var occupant = _occupants[from_key]
	
	# 检查预订：如果目标被预订，必须是当前移动者的预订
	if _reservations.has(to_key):
		var occupant_id: String = ""
		if occupant is Dictionary and occupant.has("id"):
			occupant_id = occupant["id"]
		elif occupant != null and "id" in occupant:
			occupant_id = occupant.id
		
		if _reservations[to_key] != occupant_id:
			return false
		# 取消预订
		_reservations.erase(to_key)
	
	# 执行移动
	_occupants.erase(from_key)
	_occupants[to_key] = occupant
	return true


## 移动占用者（Dictionary 格式）
func move_occupant_dict(from_coord: Dictionary, to_coord: Dictionary) -> bool:
	return move_occupant(
		Vector2i(from_coord.get("q", 0), from_coord.get("r", 0)),
		Vector2i(to_coord.get("q", 0), to_coord.get("r", 0))
	)


## 查找占用者的位置
func find_occupant_position(actor_id: String) -> Vector2i:
	for key in _occupants.keys():
		var occupant = _occupants[key]
		var occ_id: String = ""
		if occupant is Dictionary and occupant.has("id"):
			occ_id = occupant["id"]
		elif occupant != null and "id" in occupant:
			occ_id = occupant.id
		
		if occ_id == actor_id:
			return HexCoord.key_to_axial(key)
	
	return Vector2i(-9999, -9999)  # 无效坐标表示未找到


## 查找占用者的位置（Dictionary 格式）
func find_occupant_position_dict(actor_id: String) -> Dictionary:
	var coord := find_occupant_position(actor_id)
	if coord.x == -9999:
		return {}
	return { "q": coord.x, "r": coord.y }


# ========== 预订管理 ==========

## 检查格子是否被预订
func is_reserved(coord: Vector2i) -> bool:
	var key := HexCoord.axial_to_key(coord)
	return _reservations.has(key)


## 检查格子是否被预订（Dictionary 格式）
func is_reserved_dict(coord: Dictionary) -> bool:
	return is_reserved(Vector2i(coord.get("q", 0), coord.get("r", 0)))


## 预订格子
func reserve_tile(coord: Vector2i, actor_id: String) -> bool:
	if not has_tile(coord):
		return false
	if is_occupied(coord):
		return false
	if is_reserved(coord):
		return false
	
	var key := HexCoord.axial_to_key(coord)
	_reservations[key] = actor_id
	return true


## 预订格子（Dictionary 格式）
func reserve_tile_dict(coord: Dictionary, actor_id: String) -> bool:
	return reserve_tile(Vector2i(coord.get("q", 0), coord.get("r", 0)), actor_id)


## 取消预订
func cancel_reservation(coord: Vector2i) -> bool:
	var key := HexCoord.axial_to_key(coord)
	if not _reservations.has(key):
		return false
	_reservations.erase(key)
	return true


## 获取格子的预订者 ID
func get_reservation(coord: Vector2i) -> String:
	var key := HexCoord.axial_to_key(coord)
	return _reservations.get(key, "")


## 获取格子的预订者 ID（Dictionary 格式）
func get_reservation_dict(coord: Dictionary) -> String:
	return get_reservation(Vector2i(coord.get("q", 0), coord.get("r", 0)))


# ========== 邻居查询 ==========

## 获取邻居坐标
func get_neighbors(coord: Vector2i) -> Array[Vector2i]:
	return HexMath.axial_neighbors(coord)


## 获取邻居坐标（Dictionary 格式）
func get_neighbors_dict(coord: Dictionary) -> Array:
	var axial := Vector2i(coord.get("q", 0), coord.get("r", 0))
	var neighbors := get_neighbors(axial)
	var result: Array = []
	for n in neighbors:
		result.append({ "q": n.x, "r": n.y })
	return result


## 获取指定范围内的所有格子
func get_range(center: Vector2i, radius: int) -> Array[Vector2i]:
	return HexMath.axial_range(center, radius)


## 计算两个格子之间的距离
func get_distance(a: Vector2i, b: Vector2i) -> int:
	return HexMath.axial_distance(a, b)


# ========== 序列化 ==========

## 导出地图配置（用于录像/回放）
func to_map_config() -> Dictionary:
	var config := {
		"type": "hex",
		"hexSize": hex_size,
		"orientation": orientation,
	}
	
	match draw_mode:
		DrawMode.ROW_COLUMN:
			config["draw_mode"] = "row_column"
			config["rows"] = rows
			config["columns"] = columns
		DrawMode.RADIUS:
			config["draw_mode"] = "radius"
			config["radius"] = radius
	
	return config


## 序列化完整状态
func serialize() -> Dictionary:
	var tiles_data: Array = []
	for coord in _map.get_all_coords():
		var tile_data := {
			"coord": { "q": coord.x, "r": coord.y },
			"data": _map.get_hex(coord),
		}
		var occupant = get_occupant_at(coord)
		if occupant != null:
			if occupant is Dictionary and occupant.has("id"):
				tile_data["occupantId"] = occupant["id"]
			elif "id" in occupant:
				tile_data["occupantId"] = occupant.id
		tiles_data.append(tile_data)
	
	return {
		"config": to_map_config(),
		"tiles": tiles_data,
	}
