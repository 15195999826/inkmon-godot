## HexGridCompat - 兼容层
##
## 提供与旧 HexGrid API 兼容的接口
## 旧 API 使用 Dictionary { "q": int, "r": int }
## 新 API 使用 Vector2i
##
## 用于平滑迁移，新代码应直接使用 HexCoord, HexMath, HexLayout
class_name HexGridCompat
extends RefCounted


# ========== 常量 ==========

const SQRT3 := 1.7320508075688772


# ========== 方向常量 ==========

## 6 个邻居方向 (Dictionary 格式)
static var AXIAL_DIRECTIONS: Array[Dictionary] = [
	{ "q": 1, "r": 0 },    # 0: 右
	{ "q": 1, "r": -1 },   # 1: 右上
	{ "q": 0, "r": -1 },   # 2: 左上
	{ "q": -1, "r": 0 },   # 3: 左
	{ "q": -1, "r": 1 },   # 4: 左下
	{ "q": 0, "r": 1 },    # 5: 右下
]


# ========== 坐标创建 ==========

## 创建 Axial 坐标 (Dictionary)
static func axial(q: int, r: int) -> Dictionary:
	return { "q": q, "r": r }


## 创建 Cube 坐标 (Dictionary)
static func cube(q: int, r: int, s: int) -> Dictionary:
	assert(q + r + s == 0, "Invalid cube coordinates: q + r + s must equal 0")
	return { "q": q, "r": r, "s": s }


# ========== 坐标转换 ==========

## Axial 转 Cube
static func axial_to_cube(coord: Dictionary) -> Dictionary:
	return {
		"q": coord["q"],
		"r": coord["r"],
		"s": -coord["q"] - coord["r"],
	}


## Cube 转 Axial
static func cube_to_axial(coord: Dictionary) -> Dictionary:
	return {
		"q": coord["q"],
		"r": coord["r"],
	}


## Cube 坐标取整
static func cube_round(q: float, r: float, s: float) -> Dictionary:
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
	else:
		rs = -rq - rr
	
	return { "q": rq, "r": rr, "s": rs }


# ========== 像素转换 (Flat-top) ==========

## 六边形转像素坐标 (Flat-top)
static func hex_to_pixel(coord: Dictionary, hex_size: float) -> Vector2:
	var x: float = hex_size * (1.5 * float(coord["q"]))
	var y: float = hex_size * (SQRT3 / 2.0 * float(coord["q"]) + SQRT3 * float(coord["r"]))
	return Vector2(x, y)


## 像素坐标转六边形 (Flat-top)
static func pixel_to_hex(pixel: Vector2, hex_size: float) -> Dictionary:
	var q := (2.0 / 3.0 * pixel.x) / hex_size
	var r := (-1.0 / 3.0 * pixel.x + SQRT3 / 3.0 * pixel.y) / hex_size
	var s := -q - r
	
	var rounded := cube_round(q, r, s)
	return cube_to_axial(rounded)


# ========== 工具函数 ==========

## 坐标相等判断
static func hex_equals(a: Dictionary, b: Dictionary) -> bool:
	return a["q"] == b["q"] and a["r"] == b["r"]


## 坐标哈希 (用于 Dictionary 的 key)
static func hex_key(coord: Dictionary) -> String:
	return "%d,%d" % [coord["q"], coord["r"]]


## 从 key 解析坐标
static func parse_hex_key(key: String) -> Dictionary:
	var parts := key.split(",")
	return { "q": int(parts[0]), "r": int(parts[1]) }


## 坐标加法
static func hex_add(a: Dictionary, b: Dictionary) -> Dictionary:
	return { "q": a["q"] + b["q"], "r": a["r"] + b["r"] }


## 坐标减法
static func hex_subtract(a: Dictionary, b: Dictionary) -> Dictionary:
	return { "q": a["q"] - b["q"], "r": a["r"] - b["r"] }


## 坐标缩放
static func hex_scale(coord: Dictionary, factor: int) -> Dictionary:
	return { "q": coord["q"] * factor, "r": coord["r"] * factor }


# ========== 距离计算 ==========

## 计算两个六边形之间的距离
static func hex_distance(a: Dictionary, b: Dictionary) -> int:
	var ac := axial_to_cube(a)
	var bc := axial_to_cube(b)
	return maxi(
		maxi(absi(ac["q"] - bc["q"]), absi(ac["r"] - bc["r"])),
		absi(ac["s"] - bc["s"])
	)


# ========== 邻居 ==========

## 获取指定方向的邻居
static func hex_neighbor(coord: Dictionary, direction: int) -> Dictionary:
	var dir := AXIAL_DIRECTIONS[direction % 6]
	return hex_add(coord, dir)


## 获取所有 6 个邻居
static func hex_neighbors(coord: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for dir in AXIAL_DIRECTIONS:
		result.append(hex_add(coord, dir))
	return result


# ========== 范围 ==========

## 获取指定范围内的所有六边形
static func hex_range(center: Dictionary, radius: int) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	
	for q in range(-radius, radius + 1):
		var r1 := maxi(-radius, -q - radius)
		var r2 := mini(radius, -q + radius)
		for r in range(r1, r2 + 1):
			results.append({ "q": center["q"] + q, "r": center["r"] + r })
	
	return results


## 获取指定距离的环形
static func hex_ring(center: Dictionary, radius: int) -> Array[Dictionary]:
	if radius == 0:
		return [center]
	
	var results: Array[Dictionary] = []
	var hex := hex_add(center, { "q": -radius, "r": radius })
	
	for i in range(6):
		for j in range(radius):
			results.append(hex)
			hex = hex_neighbor(hex, i)
	
	return results


# ========== 线段 ==========

## 绘制从 a 到 b 的直线
static func hex_line_draw(from: Dictionary, to: Dictionary) -> Array[Dictionary]:
	var n := hex_distance(from, to)
	if n == 0:
		return [from]
	
	var from_cube := axial_to_cube(from)
	var to_cube := axial_to_cube(to)
	
	var nudge := 1e-6
	var nudged_from := {
		"q": from_cube["q"] + nudge,
		"r": from_cube["r"] + nudge,
		"s": from_cube["s"] - 2 * nudge,
	}
	
	var results: Array[Dictionary] = []
	for i in range(n + 1):
		var t := float(i) / float(n)
		var lerped := {
			"q": lerpf(nudged_from["q"], to_cube["q"], t),
			"r": lerpf(nudged_from["r"], to_cube["r"], t),
			"s": lerpf(nudged_from["s"], to_cube["s"], t),
		}
		var rounded := cube_round(lerped["q"], lerped["r"], lerped["s"])
		results.append(cube_to_axial(rounded))
	
	return results


# ========== 旋转 ==========

## 绕原点顺时针旋转 60°
static func hex_rotate_right(coord: Dictionary) -> Dictionary:
	var c := axial_to_cube(coord)
	return cube_to_axial({ "q": -c["r"], "r": -c["s"], "s": -c["q"] })


## 绕原点逆时针旋转 60°
static func hex_rotate_left(coord: Dictionary) -> Dictionary:
	var c := axial_to_cube(coord)
	return cube_to_axial({ "q": -c["s"], "r": -c["q"], "s": -c["r"] })


# ========== Vector2i 转换 ==========

## Dictionary 转 Vector2i
static func dict_to_vec(coord: Dictionary) -> Vector2i:
	return Vector2i(coord["q"], coord["r"])


## Vector2i 转 Dictionary
static func vec_to_dict(coord: Vector2i) -> Dictionary:
	return { "q": coord.x, "r": coord.y }
