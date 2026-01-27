## HexCoord - 六边形坐标值对象
##
## 表示六边形网格中的一个坐标位置，使用 Axial 坐标系 (q, r)
## Cube 坐标的第三分量 s = -q - r 是计算属性
##
## 使用方式:
##   var coord := HexCoord.new(1, 2)
##   var neighbor := coord.add(HexCoord.new(1, 0))
##   var cube := coord.to_cube()  # Vector3i(1, 2, -3)
##
## 参考: https://www.redblobgames.com/grids/hexagons/
class_name HexCoord
extends RefCounted


# ========== 常量 ==========

## 无效坐标的特殊值（使用极大值避免与正常坐标冲突）
const INVALID_VALUE := -999999


# ========== 属性 ==========

## Q 轴坐标
var q: int = 0

## R 轴坐标
var r: int = 0

## S 轴坐标 (计算属性，满足 q + r + s = 0)
var s: int:
	get: return -q - r


# ========== 构造 ==========

func _init(p_q: int = 0, p_r: int = 0) -> void:
	q = p_q
	r = p_r


# ========== 静态工厂方法 ==========
# 注意: 静态方法不能使用 class_name，使用 new() 代替 HexCoord.new()

## 从 Vector2i (axial) 创建 -> HexCoord
static func from_axial(axial: Vector2i):
	return new(axial.x, axial.y)


## 从 Vector3i (cube) 创建 -> HexCoord
static func from_cube(cube: Vector3i):
	return new(cube.x, cube.y)


## 从 Dictionary { "q": int, "r": int } 创建 -> HexCoord
static func from_dict(d: Dictionary):
	return new(
		d.get("q", 0) as int,
		d.get("r", 0) as int
	)


## 零坐标 -> HexCoord
static func zero():
	return new(0, 0)


## 无效坐标 -> HexCoord
## 用于表示"未设置"或"不存在"的位置，替代 null
static func invalid():
	return new(INVALID_VALUE, INVALID_VALUE)


# ========== 转换方法 ==========

## 转换为 Vector2i (axial)
func to_axial() -> Vector2i:
	return Vector2i(q, r)


## 转换为 Vector3i (cube)
func to_cube() -> Vector3i:
	return Vector3i(q, r, s)


## 转换为 Dictionary (用于序列化)
func to_dict() -> Dictionary:
	return { "q": q, "r": r }


# ========== 运算 ==========
# 注意: 使用 get_script().new() 代替 HexCoord.new() 以兼容 --headless 模式

## 加法 (other: HexCoord) -> HexCoord
func add(other) -> RefCounted:
	return get_script().new(q + other.q, r + other.r)


## 减法 (other: HexCoord) -> HexCoord
func subtract(other) -> RefCounted:
	return get_script().new(q - other.q, r - other.r)


## 标量乘法 -> HexCoord
func multiply(scalar: int) -> RefCounted:
	return get_script().new(q * scalar, r * scalar)


## 取反 -> HexCoord
func negate() -> RefCounted:
	return get_script().new(-q, -r)


# ========== 比较 ==========

## 相等判断 (other: HexCoord)
func equals(other) -> bool:
	if other == null:
		return false
	return q == other.q and r == other.r


## 是否为零坐标
func is_zero() -> bool:
	return q == 0 and r == 0


## 是否为有效坐标（非 INVALID）
func is_valid() -> bool:
	return q != INVALID_VALUE and r != INVALID_VALUE


# ========== 距离 ==========

## 计算到另一个坐标的距离 (六边形曼哈顿距离) (other: HexCoord)
func distance_to(other) -> int:
	return (absi(q - other.q) + absi(r - other.r) + absi(s - other.s)) / 2


## 计算到原点的距离
func length() -> int:
	return (absi(q) + absi(r) + absi(s)) / 2


# ========== 邻居 ==========

## 六边形方向向量 (axial)
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),   # 0: 东
	Vector2i(1, -1),  # 1: 东北
	Vector2i(0, -1),  # 2: 西北
	Vector2i(-1, 0),  # 3: 西
	Vector2i(-1, 1),  # 4: 西南
	Vector2i(0, 1),   # 5: 东南
]


## 获取指定方向的邻居 -> HexCoord
func neighbor(direction: int) -> RefCounted:
	var dir := DIRECTIONS[direction % 6]
	return get_script().new(q + dir.x, r + dir.y)


## 获取所有 6 个邻居 -> Array[HexCoord]
func get_neighbors() -> Array:
	var result: Array = []
	for i in range(6):
		result.append(neighbor(i))
	return result


# ========== 范围 ==========

## 获取指定范围内的所有坐标 (包含自身) -> Array[HexCoord]
func get_range(radius: int) -> Array:
	var result: Array = []
	for dq in range(-radius, radius + 1):
		for dr in range(maxi(-radius, -dq - radius), mini(radius, -dq + radius) + 1):
			result.append(get_script().new(q + dq, r + dr))
	return result


# ========== 字符串 ==========

func _to_string() -> String:
	return "HexCoord(%d, %d)" % [q, r]


## 生成用于 Dictionary key 的字符串
func to_key() -> String:
	return "%d,%d" % [q, r]


## 从 key 字符串解析 -> HexCoord
static func from_key(key: String):
	var parts := key.split(",")
	if parts.size() >= 2:
		return new(int(parts[0]), int(parts[1]))
	return new()


# ========== 复制 ==========

## -> HexCoord
func duplicate() -> RefCounted:
	return get_script().new(q, r)
