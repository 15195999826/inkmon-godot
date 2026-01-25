## HexGridConfig - 六边形网格配置
##
## 管理六边形坐标到世界坐标的转换
class_name FrontendHexGridConfig
extends RefCounted


# ========== 方向常量 ==========

const ORIENTATION_FLAT: int = 0
const ORIENTATION_POINTY: int = 1


# ========== 配置属性 ==========

## 六边形大小（从中心到顶点的距离）
var hex_size: float = 1.0

## 六边形方向
var orientation: int = ORIENTATION_FLAT

## 地图中心（世界坐标）
var origin: Vector3 = Vector3.ZERO


# ========== 构造函数 ==========

func _init(
	p_hex_size: float = 1.0,
	p_orientation: int = ORIENTATION_FLAT,
	p_origin: Vector3 = Vector3.ZERO
) -> void:
	hex_size = p_hex_size
	orientation = p_orientation
	origin = p_origin


# ========== 坐标转换 ==========

## 六边形坐标转世界坐标（3D，Y 为高度）
func hex_to_world(hex: Vector2i) -> Vector3:
	var world_2d := _hex_to_world_2d(Vector2(hex.x, hex.y))
	return Vector3(world_2d.x, 0.0, world_2d.y) + origin


## 六边形坐标转世界坐标（2D）
func _hex_to_world_2d(hex: Vector2) -> Vector2:
	var x: float
	var y: float
	
	if orientation == ORIENTATION_FLAT:
		# 平顶六边形
		x = hex_size * (3.0 / 2.0 * hex.x)
		y = hex_size * (sqrt(3.0) / 2.0 * hex.x + sqrt(3.0) * hex.y)
	else:
		# 尖顶六边形
		x = hex_size * (sqrt(3.0) * hex.x + sqrt(3.0) / 2.0 * hex.y)
		y = hex_size * (3.0 / 2.0 * hex.y)
	
	return Vector2(x, y)


## 世界坐标转六边形坐标
func world_to_hex(world: Vector3) -> Vector2i:
	var local := world - origin
	var hex_float := _world_to_hex_2d(Vector2(local.x, local.z))
	return _round_hex(hex_float)


## 世界坐标转六边形坐标（2D，返回浮点数）
func _world_to_hex_2d(world: Vector2) -> Vector2:
	var q: float
	var r: float
	
	if orientation == ORIENTATION_FLAT:
		q = (2.0 / 3.0 * world.x) / hex_size
		r = (-1.0 / 3.0 * world.x + sqrt(3.0) / 3.0 * world.y) / hex_size
	else:
		q = (sqrt(3.0) / 3.0 * world.x - 1.0 / 3.0 * world.y) / hex_size
		r = (2.0 / 3.0 * world.y) / hex_size
	
	return Vector2(q, r)


## 四舍五入到最近的六边形坐标
func _round_hex(hex: Vector2) -> Vector2i:
	var q := hex.x
	var r := hex.y
	var s := -q - r
	
	var rq := roundi(q)
	var rr := roundi(r)
	var rs := roundi(s)
	
	var q_diff := absf(rq - q)
	var r_diff := absf(rr - r)
	var s_diff := absf(rs - s)
	
	if q_diff > r_diff and q_diff > s_diff:
		rq = -rr - rs
	elif r_diff > s_diff:
		rr = -rq - rs
	
	return Vector2i(rq, rr)


# ========== 工厂方法 ==========

## 从字典创建配置
static func from_dict(data: Dictionary) -> FrontendHexGridConfig:
	var hex_size_val := data.get("hex_size", 1.0) as float
	var orientation_str := data.get("orientation", "flat") as String
	var orientation_val: int = ORIENTATION_FLAT if orientation_str == "flat" else ORIENTATION_POINTY
	
	return FrontendHexGridConfig.new(hex_size_val, orientation_val)


## 创建默认配置（适合 3D 场景）
static func create_default_3d() -> FrontendHexGridConfig:
	# 使用较大的 hex_size 以便在 3D 场景中可见
	return FrontendHexGridConfig.new(2.0, ORIENTATION_FLAT)
