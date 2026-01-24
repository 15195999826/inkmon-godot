## HexMap - 六边形地图存储
##
## 提供三种存储模式:
## - Rectangular: 矩形地图，使用 Offset 坐标的 2D 数组
## - Sparse: 稀疏地图，使用 Dictionary
## - Chunked: 分块地图，适合大型/无限地图
##
## 参考: https://www.redblobgames.com/grids/hexagons/
class_name HexMap
extends RefCounted


# ========== 基类接口 ==========

## 获取格子数据
func get_hex(coord: Vector2i) -> Variant:
	return null


## 设置格子数据
func set_hex(coord: Vector2i, value: Variant) -> void:
	pass


## 检查格子是否存在
func has_hex(coord: Vector2i) -> bool:
	return false


## 移除格子
func remove_hex(coord: Vector2i) -> void:
	pass


## 清空地图
func clear() -> void:
	pass


## 获取所有格子坐标
func get_all_coords() -> Array[Vector2i]:
	return []


## 获取格子数量
func get_count() -> int:
	return 0


# ========== 矩形地图 ==========

## 矩形地图 (使用 Offset 坐标)
class Rectangular extends HexMap:
	var _width: int
	var _height: int
	var _data: Array[Array]
	var _offset_type: HexCoord.OffsetType
	var _default_value: Variant
	
	func _init(
		width: int,
		height: int,
		offset_type: HexCoord.OffsetType = HexCoord.OffsetType.ODD_Q,
		default_value: Variant = null
	) -> void:
		_width = width
		_height = height
		_offset_type = offset_type
		_default_value = default_value
		_init_data()
	
	func _init_data() -> void:
		_data = []
		for y in range(_height):
			var row: Array = []
			row.resize(_width)
			row.fill(_default_value)
			_data.append(row)
	
	## 获取宽度
	func get_width() -> int:
		return _width
	
	## 获取高度
	func get_height() -> int:
		return _height
	
	## 获取 Offset 类型
	func get_offset_type() -> HexCoord.OffsetType:
		return _offset_type
	
	## 检查 Offset 坐标是否在范围内
	func is_in_bounds(col: int, row: int) -> bool:
		return col >= 0 and col < _width and row >= 0 and row < _height
	
	## 使用 Offset 坐标获取
	func get_at(col: int, row: int) -> Variant:
		if is_in_bounds(col, row):
			return _data[row][col]
		return null
	
	## 使用 Offset 坐标设置
	func set_at(col: int, row: int, value: Variant) -> void:
		if is_in_bounds(col, row):
			_data[row][col] = value
	
	## 使用 Axial 坐标获取
	func get_hex(coord: Vector2i) -> Variant:
		var offset_coord := HexCoord.axial_to_offset(coord, _offset_type)
		return get_at(offset_coord.x, offset_coord.y)
	
	## 使用 Axial 坐标设置
	func set_hex(coord: Vector2i, value: Variant) -> void:
		var offset_coord := HexCoord.axial_to_offset(coord, _offset_type)
		set_at(offset_coord.x, offset_coord.y, value)
	
	## 检查 Axial 坐标是否在范围内
	func has_hex(coord: Vector2i) -> bool:
		var offset_coord := HexCoord.axial_to_offset(coord, _offset_type)
		return is_in_bounds(offset_coord.x, offset_coord.y)
	
	## 移除格子 (设为默认值)
	func remove_hex(coord: Vector2i) -> void:
		set_hex(coord, _default_value)
	
	## 清空地图
	func clear() -> void:
		_init_data()
	
	## 获取所有格子的 Axial 坐标
	func get_all_coords() -> Array[Vector2i]:
		var result: Array[Vector2i] = []
		for row in range(_height):
			for col in range(_width):
				var offset_coord := Vector2i(col, row)
				var axial_coord := HexCoord.offset_to_axial(offset_coord, _offset_type)
				result.append(axial_coord)
		return result
	
	## 获取格子数量
	func get_count() -> int:
		return _width * _height
	
	## 遍历所有格子
	func for_each(callback: Callable) -> void:
		for row in range(_height):
			for col in range(_width):
				var offset_coord := Vector2i(col, row)
				var axial_coord := HexCoord.offset_to_axial(offset_coord, _offset_type)
				callback.call(axial_coord, _data[row][col])


# ========== 稀疏地图 ==========

## 稀疏地图 (使用 Dictionary)
class Sparse extends HexMap:
	var _data: Dictionary = {}
	
	func _init() -> void:
		_data = {}
	
	## 获取格子
	func get_hex(coord: Vector2i) -> Variant:
		return _data.get(coord, null)
	
	## 设置格子
	func set_hex(coord: Vector2i, value: Variant) -> void:
		_data[coord] = value
	
	## 检查格子是否存在
	func has_hex(coord: Vector2i) -> bool:
		return coord in _data
	
	## 移除格子
	func remove_hex(coord: Vector2i) -> void:
		_data.erase(coord)
	
	## 清空地图
	func clear() -> void:
		_data.clear()
	
	## 获取所有格子坐标
	func get_all_coords() -> Array[Vector2i]:
		var result: Array[Vector2i] = []
		for coord in _data.keys():
			result.append(coord)
		return result
	
	## 获取格子数量
	func get_count() -> int:
		return _data.size()
	
	## 遍历所有格子
	func for_each(callback: Callable) -> void:
		for coord in _data.keys():
			callback.call(coord, _data[coord])
	
	## 获取内部 Dictionary (用于高级操作)
	func get_data() -> Dictionary:
		return _data


# ========== 分块地图 ==========

## 分块地图 (适合大型/无限地图)
class Chunked extends HexMap:
	var _chunk_size: int
	var _chunks: Dictionary = {}  # { chunk_key: Dictionary }
	
	func _init(chunk_size: int = 16) -> void:
		_chunk_size = chunk_size
		_chunks = {}
	
	## 获取块大小
	func get_chunk_size() -> int:
		return _chunk_size
	
	## 计算块坐标
	func _get_chunk_key(coord: Vector2i) -> Vector2i:
		# 使用整数除法，注意负数的处理
		var chunk_q := coord.x
		var chunk_r := coord.y
		if coord.x < 0:
			chunk_q = (coord.x - _chunk_size + 1) / _chunk_size
		else:
			chunk_q = coord.x / _chunk_size
		if coord.y < 0:
			chunk_r = (coord.y - _chunk_size + 1) / _chunk_size
		else:
			chunk_r = coord.y / _chunk_size
		return Vector2i(chunk_q, chunk_r)
	
	## 计算块内局部坐标
	func _get_local_coord(coord: Vector2i) -> Vector2i:
		var local_q := coord.x % _chunk_size
		var local_r := coord.y % _chunk_size
		if local_q < 0:
			local_q += _chunk_size
		if local_r < 0:
			local_r += _chunk_size
		return Vector2i(local_q, local_r)
	
	## 获取或创建块
	func _get_or_create_chunk(chunk_key: Vector2i) -> Dictionary:
		if chunk_key not in _chunks:
			_chunks[chunk_key] = {}
		return _chunks[chunk_key]
	
	## 获取格子
	func get_hex(coord: Vector2i) -> Variant:
		var chunk_key := _get_chunk_key(coord)
		if chunk_key not in _chunks:
			return null
		var local := _get_local_coord(coord)
		return _chunks[chunk_key].get(local, null)
	
	## 设置格子
	func set_hex(coord: Vector2i, value: Variant) -> void:
		var chunk_key := _get_chunk_key(coord)
		var chunk := _get_or_create_chunk(chunk_key)
		var local := _get_local_coord(coord)
		chunk[local] = value
	
	## 检查格子是否存在
	func has_hex(coord: Vector2i) -> bool:
		var chunk_key := _get_chunk_key(coord)
		if chunk_key not in _chunks:
			return false
		var local := _get_local_coord(coord)
		return local in _chunks[chunk_key]
	
	## 移除格子
	func remove_hex(coord: Vector2i) -> void:
		var chunk_key := _get_chunk_key(coord)
		if chunk_key not in _chunks:
			return
		var local := _get_local_coord(coord)
		_chunks[chunk_key].erase(local)
		# 如果块为空，移除块
		if _chunks[chunk_key].is_empty():
			_chunks.erase(chunk_key)
	
	## 清空地图
	func clear() -> void:
		_chunks.clear()
	
	## 获取所有格子坐标
	func get_all_coords() -> Array[Vector2i]:
		var result: Array[Vector2i] = []
		for chunk_key in _chunks.keys():
			var chunk: Dictionary = _chunks[chunk_key]
			for local in chunk.keys():
				var global := Vector2i(
					chunk_key.x * _chunk_size + local.x,
					chunk_key.y * _chunk_size + local.y
				)
				result.append(global)
		return result
	
	## 获取格子数量
	func get_count() -> int:
		var count := 0
		for chunk in _chunks.values():
			count += chunk.size()
		return count
	
	## 遍历所有格子
	func for_each(callback: Callable) -> void:
		for chunk_key in _chunks.keys():
			var chunk: Dictionary = _chunks[chunk_key]
			for local in chunk.keys():
				var global := Vector2i(
					chunk_key.x * _chunk_size + local.x,
					chunk_key.y * _chunk_size + local.y
				)
				callback.call(global, chunk[local])
	
	## 获取已加载的块数量
	func get_chunk_count() -> int:
		return _chunks.size()
	
	## 获取所有已加载的块坐标
	func get_loaded_chunks() -> Array[Vector2i]:
		var result: Array[Vector2i] = []
		for chunk_key in _chunks.keys():
			result.append(chunk_key)
		return result
	
	## 卸载指定块
	func unload_chunk(chunk_key: Vector2i) -> void:
		_chunks.erase(chunk_key)
	
	## 检查块是否已加载
	func is_chunk_loaded(chunk_key: Vector2i) -> bool:
		return chunk_key in _chunks
