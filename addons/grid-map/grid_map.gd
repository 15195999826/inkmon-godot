## GridMapAutoload - 通用网格地图全局服务
##
## Autoload 单例，提供全局访问 GridMapModel
##
## 使用方式:
##   # 在战斗开始时配置
##   var config := GridMapConfig.new()
##   config.grid_type = GridMapConfig.GridType.HEX
##   config.draw_mode = GridMapConfig.DrawMode.RADIUS
##   config.radius = 5
##   config.size = 32.0
##   GridMap.configure(config)
##
##   # 在任何地方使用
##   var world_pos := GridMap.coord_to_world(Vector2i(1, 2))
##   var neighbors := GridMap.get_neighbors(Vector2i(0, 0))
##
## 注意: 必须先调用 configure() 才能使用 model
extends Node

const _GridMapModel = preload("res://addons/grid-map/model/grid_map_model.gd")


# ========== 信号 ==========

## 当 model 被配置时触发
signal model_configured(new_model: _GridMapModel)

## 当 model 被清除时触发
signal model_cleared()


# ========== 属性 ==========

## 当前活跃的网格模型
var model: _GridMapModel = null


# ========== 配置方法 ==========

## 配置网格模型
func configure(config: GridMapConfig) -> void:
	if config == null:
		push_error("[GridMap] Cannot configure with null config")
		return
	
	# 创建新模型
	var new_model := _GridMapModel.new()
	new_model.initialize(config)
	
	model = new_model
	model_configured.emit(new_model)


## 清除当前模型
func clear() -> void:
	model = null
	model_cleared.emit()


## 检查是否已配置
func is_configured() -> bool:
	return model != null


# ========== 便捷方法（直接转发到 model）==========

## 网格坐标转世界坐标
func coord_to_world(coord: Vector2i) -> Vector2:
	if model == null:
		push_error("[GridMap] Model not configured. Call configure() first.")
		return Vector2.ZERO
	return model.coord_to_world(coord)


## 世界坐标转网格坐标
func world_to_coord(world_pos: Vector2) -> Vector2i:
	if model == null:
		push_error("[GridMap] Model not configured. Call configure() first.")
		return Vector2i.ZERO
	return model.world_to_coord(world_pos)


## 获取邻居坐标
func get_neighbors(coord: Vector2i) -> Array[Vector2i]:
	if model == null:
		push_error("[GridMap] Model not configured. Call configure() first.")
		return []
	return model.get_neighbors(coord)


## 计算两个格子之间的距离
func get_distance(from: Vector2i, to: Vector2i) -> int:
	if model == null:
		push_error("[GridMap] Model not configured. Call configure() first.")
		return 0
	return model.get_distance(from, to)


## 检查坐标是否可通行
func is_passable(coord: Vector2i) -> bool:
	if model == null:
		push_error("[GridMap] Model not configured. Call configure() first.")
		return false
	return model.is_passable(coord)


## 获取瓦片数据
func get_tile(coord: Vector2i):
	if model == null:
		push_error("[GridMap] Model not configured. Call configure() first.")
		return null
	return model.get_tile(coord)


## 检查格子是否存在
func has_tile(coord: Vector2i) -> bool:
	if model == null:
		push_error("[GridMap] Model not configured. Call configure() first.")
		return false
	return model.has_tile(coord)


## 获取指定范围内的所有格子
func get_range(center: Vector2i, range_radius: int) -> Array[Vector2i]:
	if model == null:
		push_error("[GridMap] Model not configured. Call configure() first.")
		return []
	return model.get_range(center, range_radius)


## 获取所有格子坐标
func get_all_coords() -> Array[Vector2i]:
	if model == null:
		push_error("[GridMap] Model not configured. Call configure() first.")
		return []
	return model.get_all_coords()
