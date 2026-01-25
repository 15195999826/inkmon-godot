## HexGrid - 六边形网格全局服务
##
## Autoload 单例，提供全局访问 HexGridWorld 模型
##
## 使用方式:
##   # 在战斗开始时配置
##   HexGrid.configure_from_dict({
##       "rows": 9,
##       "columns": 9,
##       "hex_size": 100.0,
##       "orientation": "flat",
##   })
##
##   # 在任何地方使用
##   var world_pos := HexGrid.model.hex_to_world(Vector2i(1, 2))
##
## 注意: 必须先调用 configure() 才能使用 model
extends Node


# ========== 信号 ==========

## 当 model 被配置时触发
signal model_configured(new_model)

## 当 model 被清除时触发
signal model_cleared()


# ========== 属性 ==========

## 当前活跃的网格模型
var model = null  # HexGridWorld instance


# ========== 配置方法 ==========

## 配置网格模型
func configure(new_model) -> void:
	if new_model == null:
		push_error("[HexGrid] Cannot configure with null model")
		return
	
	model = new_model
	model_configured.emit(new_model)


## 使用配置字典创建并配置模型
func configure_from_dict(config: Dictionary) -> HexGridWorld:
	var new_model := HexGridWorld.new(config)
	configure(new_model)
	return new_model


## 清除当前模型
func clear() -> void:
	model = null
	model_cleared.emit()


## 检查是否已配置
func is_configured() -> bool:
	return model != null


# ========== 便捷方法（直接转发到 model）==========

## 六边形坐标转世界坐标
func hex_to_world(coord: Vector2i) -> Vector2:
	assert(model != null, "[HexGrid] Model not configured. Call configure() first.")
	return model.hex_to_world(coord)


## 六边形坐标转世界坐标（Dictionary 格式）
func hex_to_world_dict(coord: Dictionary) -> Vector2:
	assert(model != null, "[HexGrid] Model not configured. Call configure() first.")
	return model.hex_to_world_dict(coord)


## 世界坐标转六边形坐标
func world_to_hex(world_pos: Vector2) -> Vector2i:
	assert(model != null, "[HexGrid] Model not configured. Call configure() first.")
	return model.world_to_hex(world_pos)


## 世界坐标转六边形坐标（Dictionary 格式）
func world_to_hex_dict(world_pos: Vector2) -> Dictionary:
	assert(model != null, "[HexGrid] Model not configured. Call configure() first.")
	return model.world_to_hex_dict(world_pos)


## 获取 hex_size
func get_hex_size() -> float:
	if model == null:
		return 0.0
	return model.hex_size


## 获取 orientation
func get_orientation() -> String:
	if model == null:
		return ""
	return model.orientation
