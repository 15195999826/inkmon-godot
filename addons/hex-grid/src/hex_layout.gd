## HexLayout - 六边形像素坐标转换
##
## 支持两种方向:
## - Flat-top: 六边形顶部是平的
## - Pointy-top: 六边形顶部是尖的
##
## 使用方式:
##   var layout := HexLayout.new(HexLayout.FLAT, 32.0, Vector2.ZERO)
##   var pixel := layout.hex_to_pixel(Vector2i(1, 2))
##   var hex := layout.pixel_to_hex(Vector2(100, 100))
##
## 参考: https://www.redblobgames.com/grids/hexagons/
class_name HexLayout
extends RefCounted


# ========== 常量 ==========

const SQRT3 := 1.7320508075688772935

## Flat-top (顶部平)
const FLAT := 0
## Pointy-top (顶部尖)
const POINTY := 1


# ========== 方向矩阵 ==========

## Flat-top 方向矩阵
## f: hex -> pixel, b: pixel -> hex
const FLAT_ORIENTATION := {
	"f0": 1.5,
	"f1": 0.0,
	"f2": SQRT3 / 2.0,
	"f3": SQRT3,
	"b0": 2.0 / 3.0,
	"b1": 0.0,
	"b2": -1.0 / 3.0,
	"b3": SQRT3 / 3.0,
	"start_angle": 0.0,  # 第一个角的角度 (弧度)
}

## Pointy-top 方向矩阵
const POINTY_ORIENTATION := {
	"f0": SQRT3,
	"f1": SQRT3 / 2.0,
	"f2": 0.0,
	"f3": 1.5,
	"b0": SQRT3 / 3.0,
	"b1": -1.0 / 3.0,
	"b2": 0.0,
	"b3": 2.0 / 3.0,
	"start_angle": 0.5,  # 30度 (以 60度为单位)
}


# ========== 属性 ==========

## 六边形方向 (FLAT 或 POINTY)
var orientation: int

## 六边形大小 (中心到角的距离)
var size: float

## 原点偏移
var origin: Vector2

## 当前使用的方向矩阵
var _matrix: Dictionary


# ========== 构造 ==========

func _init(
	p_orientation: int = FLAT,
	p_size: float = 32.0,
	p_origin: Vector2 = Vector2.ZERO
) -> void:
	orientation = p_orientation
	size = p_size
	origin = p_origin
	_update_matrix()


func _update_matrix() -> void:
	if orientation == FLAT:
		_matrix = FLAT_ORIENTATION.duplicate()
	else:
		_matrix = POINTY_ORIENTATION.duplicate()


# ========== 配置 ==========

## 设置方向
func set_orientation(p_orientation: int) -> void:
	orientation = p_orientation
	_update_matrix()


## 设置大小
func set_size(p_size: float) -> void:
	size = p_size


## 设置原点
func set_origin(p_origin: Vector2) -> void:
	origin = p_origin


# ========== 尺寸计算 ==========

## 获取六边形宽度
func get_hex_width() -> float:
	if orientation == FLAT:
		return size * 2.0
	else:
		return size * SQRT3


## 获取六边形高度
func get_hex_height() -> float:
	if orientation == FLAT:
		return size * SQRT3
	else:
		return size * 2.0


## 获取水平间距 (相邻列中心距离)
func get_horizontal_spacing() -> float:
	if orientation == FLAT:
		return size * 1.5
	else:
		return size * SQRT3


## 获取垂直间距 (相邻行中心距离)
func get_vertical_spacing() -> float:
	if orientation == FLAT:
		return size * SQRT3
	else:
		return size * 1.5


# ========== 坐标转换 ==========

## 六边形坐标转像素坐标 (Axial)
func hex_to_pixel(coord: Vector2i) -> Vector2:
	var f0: float = _matrix["f0"]
	var f1: float = _matrix["f1"]
	var f2: float = _matrix["f2"]
	var f3: float = _matrix["f3"]
	var x: float = (f0 * coord.x + f1 * coord.y) * size
	var y: float = (f2 * coord.x + f3 * coord.y) * size
	return Vector2(x, y) + origin


## 六边形坐标转像素坐标 (Cube)
func cube_to_pixel(coord: Vector3i) -> Vector2:
	return hex_to_pixel(Vector2i(coord.x, coord.y))


## 像素坐标转六边形坐标 (Axial)
func pixel_to_hex(pixel: Vector2) -> Vector2i:
	var pt: Vector2 = (pixel - origin) / size
	var b0: float = _matrix["b0"]
	var b1: float = _matrix["b1"]
	var b2: float = _matrix["b2"]
	var b3: float = _matrix["b3"]
	var q: float = b0 * pt.x + b1 * pt.y
	var r: float = b2 * pt.x + b3 * pt.y
	return HexCoord.axial_round(q, r)


## 像素坐标转六边形坐标 (Cube)
func pixel_to_cube(pixel: Vector2) -> Vector3i:
	var axial_coord: Vector2i = pixel_to_hex(pixel)
	return HexCoord.axial_to_cube(axial_coord)


## 像素坐标转浮点六边形坐标 (不取整)
func pixel_to_hex_frac(pixel: Vector2) -> Vector2:
	var pt: Vector2 = (pixel - origin) / size
	var b0: float = _matrix["b0"]
	var b1: float = _matrix["b1"]
	var b2: float = _matrix["b2"]
	var b3: float = _matrix["b3"]
	var q: float = b0 * pt.x + b1 * pt.y
	var r: float = b2 * pt.x + b3 * pt.y
	return Vector2(q, r)


# ========== 角点计算 ==========

## 获取六边形的一个角点偏移 (相对于中心)
## corner: 0-5
func hex_corner_offset(corner: int) -> Vector2:
	var start_angle: float = _matrix["start_angle"]
	var angle: float = 2.0 * PI * (start_angle + corner) / 6.0
	return Vector2(size * cos(angle), size * sin(angle))


## 获取六边形的所有角点 (世界坐标)
func hex_corners(coord: Vector2i) -> PackedVector2Array:
	var corners := PackedVector2Array()
	var center: Vector2 = hex_to_pixel(coord)
	
	for i in range(6):
		corners.append(center + hex_corner_offset(i))
	
	return corners


## 获取六边形的所有角点 (Cube 坐标)
func cube_corners(coord: Vector3i) -> PackedVector2Array:
	return hex_corners(Vector2i(coord.x, coord.y))


# ========== 边中点计算 ==========

## 获取六边形的一条边的中点偏移 (相对于中心)
## edge: 0-5
func hex_edge_midpoint_offset(edge: int) -> Vector2:
	var corner1: Vector2 = hex_corner_offset(edge)
	var corner2: Vector2 = hex_corner_offset((edge + 1) % 6)
	return (corner1 + corner2) / 2.0


## 获取六边形的所有边中点 (世界坐标)
func hex_edge_midpoints(coord: Vector2i) -> PackedVector2Array:
	var midpoints := PackedVector2Array()
	var center: Vector2 = hex_to_pixel(coord)
	
	for i in range(6):
		midpoints.append(center + hex_edge_midpoint_offset(i))
	
	return midpoints


# ========== 静态便捷方法 ==========

## 快速创建 Flat-top 布局
static func create_flat(hex_size: float, origin_offset: Vector2 = Vector2.ZERO) -> HexLayout:
	return HexLayout.new(FLAT, hex_size, origin_offset)


## 快速创建 Pointy-top 布局
static func create_pointy(hex_size: float, origin_offset: Vector2 = Vector2.ZERO) -> HexLayout:
	return HexLayout.new(POINTY, hex_size, origin_offset)


# ========== 静态转换方法 (无需实例化) ==========

## Flat-top: 六边形转像素
static func flat_hex_to_pixel(coord: Vector2i, hex_size: float) -> Vector2:
	var x: float = hex_size * (1.5 * float(coord.x))
	var y: float = hex_size * (SQRT3 / 2.0 * float(coord.x) + SQRT3 * float(coord.y))
	return Vector2(x, y)


## Flat-top: 像素转六边形
static func flat_pixel_to_hex(pixel: Vector2, hex_size: float) -> Vector2i:
	var q: float = (2.0 / 3.0 * pixel.x) / hex_size
	var r: float = (-1.0 / 3.0 * pixel.x + SQRT3 / 3.0 * pixel.y) / hex_size
	return HexCoord.axial_round(q, r)


## Pointy-top: 六边形转像素
static func pointy_hex_to_pixel(coord: Vector2i, hex_size: float) -> Vector2:
	var x: float = hex_size * (SQRT3 * float(coord.x) + SQRT3 / 2.0 * float(coord.y))
	var y: float = hex_size * (1.5 * float(coord.y))
	return Vector2(x, y)


## Pointy-top: 像素转六边形
static func pointy_pixel_to_hex(pixel: Vector2, hex_size: float) -> Vector2i:
	var q: float = (SQRT3 / 3.0 * pixel.x - 1.0 / 3.0 * pixel.y) / hex_size
	var r: float = (2.0 / 3.0 * pixel.y) / hex_size
	return HexCoord.axial_round(q, r)
