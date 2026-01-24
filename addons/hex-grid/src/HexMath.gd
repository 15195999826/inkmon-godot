## HexMath - 六边形数学运算
##
## 提供纯数学算法:
## - 距离计算
## - 邻居查找 (6方向 + 6对角)
## - 范围查询
## - 环和螺旋
## - 线段绘制
## - 旋转和反射
##
## 所有方法使用 Axial (Vector2i) 或 Cube (Vector3i) 坐标
## 参考: https://www.redblobgames.com/grids/hexagons/
class_name HexMath
extends RefCounted


# ========== 方向常量 ==========

## 6 个邻居方向 (Axial 坐标)
## 顺序: 右、右上、左上、左、左下、右下
const AXIAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),    # 0: 右 (E)
	Vector2i(1, -1),   # 1: 右上 (NE)
	Vector2i(0, -1),   # 2: 左上 (NW)
	Vector2i(-1, 0),   # 3: 左 (W)
	Vector2i(-1, 1),   # 4: 左下 (SW)
	Vector2i(0, 1),    # 5: 右下 (SE)
]

## 6 个邻居方向 (Cube 坐标)
const CUBE_DIRECTIONS: Array[Vector3i] = [
	Vector3i(1, -1, 0),   # 0: 右 (E)
	Vector3i(1, 0, -1),   # 1: 右上 (NE)
	Vector3i(0, 1, -1),   # 2: 左上 (NW)
	Vector3i(-1, 1, 0),   # 3: 左 (W)
	Vector3i(-1, 0, 1),   # 4: 左下 (SW)
	Vector3i(0, -1, 1),   # 5: 右下 (SE)
]

## 6 个对角方向 (Cube 坐标)
const CUBE_DIAGONALS: Array[Vector3i] = [
	Vector3i(2, -1, -1),  # 0
	Vector3i(1, 1, -2),   # 1
	Vector3i(-1, 2, -1),  # 2
	Vector3i(-2, 1, 1),   # 3
	Vector3i(-1, -1, 2),  # 4
	Vector3i(1, -2, 1),   # 5
]

## 6 个对角方向 (Axial 坐标)
const AXIAL_DIAGONALS: Array[Vector2i] = [
	Vector2i(2, -1),   # 0
	Vector2i(1, 1),    # 1
	Vector2i(-1, 2),   # 2
	Vector2i(-2, 1),   # 3
	Vector2i(-1, -1),  # 4
	Vector2i(1, -2),   # 5
]


# ========== 基础运算 (Axial) ==========

## 坐标相加
static func axial_add(a: Vector2i, b: Vector2i) -> Vector2i:
	return a + b


## 坐标相减
static func axial_subtract(a: Vector2i, b: Vector2i) -> Vector2i:
	return a - b


## 坐标缩放
static func axial_scale(coord: Vector2i, factor: int) -> Vector2i:
	return coord * factor


## 坐标相等
static func axial_equals(a: Vector2i, b: Vector2i) -> bool:
	return a == b


# ========== 基础运算 (Cube) ==========

## 坐标相加
static func cube_add(a: Vector3i, b: Vector3i) -> Vector3i:
	return a + b


## 坐标相减
static func cube_subtract(a: Vector3i, b: Vector3i) -> Vector3i:
	return a - b


## 坐标缩放
static func cube_scale(coord: Vector3i, factor: int) -> Vector3i:
	return coord * factor


## 坐标相等
static func cube_equals(a: Vector3i, b: Vector3i) -> bool:
	return a == b


# ========== 距离计算 ==========

## 计算两个 Axial 坐标之间的距离
static func axial_distance(a: Vector2i, b: Vector2i) -> int:
	var diff := a - b
	return (absi(diff.x) + absi(diff.x + diff.y) + absi(diff.y)) / 2


## 计算两个 Cube 坐标之间的距离
static func cube_distance(a: Vector3i, b: Vector3i) -> int:
	var diff := a - b
	return maxi(maxi(absi(diff.x), absi(diff.y)), absi(diff.z))


## 计算 Axial 坐标到原点的距离
static func axial_length(coord: Vector2i) -> int:
	return (absi(coord.x) + absi(coord.x + coord.y) + absi(coord.y)) / 2


## 计算 Cube 坐标到原点的距离
static func cube_length(coord: Vector3i) -> int:
	return maxi(maxi(absi(coord.x), absi(coord.y)), absi(coord.z))


# ========== 邻居 ==========

## 获取指定方向的邻居 (Axial)
static func axial_neighbor(coord: Vector2i, direction: int) -> Vector2i:
	return coord + AXIAL_DIRECTIONS[direction % 6]


## 获取所有 6 个邻居 (Axial)
static func axial_neighbors(coord: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dir in AXIAL_DIRECTIONS:
		result.append(coord + dir)
	return result


## 获取指定方向的邻居 (Cube)
static func cube_neighbor(coord: Vector3i, direction: int) -> Vector3i:
	return coord + CUBE_DIRECTIONS[direction % 6]


## 获取所有 6 个邻居 (Cube)
static func cube_neighbors(coord: Vector3i) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for dir in CUBE_DIRECTIONS:
		result.append(coord + dir)
	return result


# ========== 对角邻居 ==========

## 获取指定方向的对角邻居 (Axial)
static func axial_diagonal_neighbor(coord: Vector2i, direction: int) -> Vector2i:
	return coord + AXIAL_DIAGONALS[direction % 6]


## 获取所有 6 个对角邻居 (Axial)
static func axial_diagonal_neighbors(coord: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dir in AXIAL_DIAGONALS:
		result.append(coord + dir)
	return result


## 获取指定方向的对角邻居 (Cube)
static func cube_diagonal_neighbor(coord: Vector3i, direction: int) -> Vector3i:
	return coord + CUBE_DIAGONALS[direction % 6]


## 获取所有 6 个对角邻居 (Cube)
static func cube_diagonal_neighbors(coord: Vector3i) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for dir in CUBE_DIAGONALS:
		result.append(coord + dir)
	return result


# ========== 范围 ==========

## 获取指定范围内的所有六边形 (Axial)
## 返回距离 center <= radius 的所有坐标
static func axial_range(center: Vector2i, radius: int) -> Array[Vector2i]:
	var results: Array[Vector2i] = []
	
	for q in range(-radius, radius + 1):
		var r1 := maxi(-radius, -q - radius)
		var r2 := mini(radius, -q + radius)
		for r in range(r1, r2 + 1):
			results.append(Vector2i(center.x + q, center.y + r))
	
	return results


## 获取指定范围内的所有六边形 (Cube)
static func cube_range(center: Vector3i, radius: int) -> Array[Vector3i]:
	var results: Array[Vector3i] = []
	
	for q in range(-radius, radius + 1):
		var r1 := maxi(-radius, -q - radius)
		var r2 := mini(radius, -q + radius)
		for r in range(r1, r2 + 1):
			var s := -q - r
			results.append(Vector3i(center.x + q, center.y + r, center.z + s))
	
	return results


## 计算范围内六边形数量
## 公式: 3 * N * (N + 1) + 1
static func range_count(radius: int) -> int:
	return 3 * radius * (radius + 1) + 1


## 两个范围的交集 (Axial)
static func axial_range_intersection(
	center1: Vector2i, radius1: int,
	center2: Vector2i, radius2: int
) -> Array[Vector2i]:
	var results: Array[Vector2i] = []
	
	# 计算边界约束
	var q_min := maxi(center1.x - radius1, center2.x - radius2)
	var q_max := mini(center1.x + radius1, center2.x + radius2)
	var r_min := maxi(center1.y - radius1, center2.y - radius2)
	var r_max := mini(center1.y + radius1, center2.y + radius2)
	
	for q in range(q_min, q_max + 1):
		for r in range(r_min, r_max + 1):
			var coord := Vector2i(q, r)
			if axial_distance(coord, center1) <= radius1 and \
			   axial_distance(coord, center2) <= radius2:
				results.append(coord)
	
	return results


# ========== 环 ==========

## 获取指定距离的环形 (Axial)
## 返回距离 center 恰好等于 radius 的所有坐标
static func axial_ring(center: Vector2i, radius: int) -> Array[Vector2i]:
	if radius == 0:
		return [center]
	
	var results: Array[Vector2i] = []
	
	# 从起点开始 (center + radius * direction[4])
	var hex := center + axial_scale(AXIAL_DIRECTIONS[4], radius)
	
	for i in range(6):
		for j in range(radius):
			results.append(hex)
			hex = axial_neighbor(hex, i)
	
	return results


## 获取指定距离的环形 (Cube)
static func cube_ring(center: Vector3i, radius: int) -> Array[Vector3i]:
	if radius == 0:
		return [center]
	
	var results: Array[Vector3i] = []
	
	# 从起点开始
	var hex := center + cube_scale(CUBE_DIRECTIONS[4], radius)
	
	for i in range(6):
		for j in range(radius):
			results.append(hex)
			hex = cube_neighbor(hex, i)
	
	return results


## 计算环上六边形数量
## 公式: 6 * N (N > 0), 1 (N = 0)
static func ring_count(radius: int) -> int:
	if radius == 0:
		return 1
	return 6 * radius


# ========== 螺旋 ==========

## 获取螺旋形排列的所有六边形 (Axial)
## 从中心开始，按环逐层向外
static func axial_spiral(center: Vector2i, radius: int) -> Array[Vector2i]:
	var results: Array[Vector2i] = [center]
	
	for k in range(1, radius + 1):
		results.append_array(axial_ring(center, k))
	
	return results


## 获取螺旋形排列的所有六边形 (Cube)
static func cube_spiral(center: Vector3i, radius: int) -> Array[Vector3i]:
	var results: Array[Vector3i] = [center]
	
	for k in range(1, radius + 1):
		results.append_array(cube_ring(center, k))
	
	return results


# ========== 线段 ==========

## 绘制从 a 到 b 的直线 (Axial)
## 包含两端点
static func axial_line(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var n := axial_distance(from, to)
	if n == 0:
		return [from]
	
	var results: Array[Vector2i] = []
	
	# 添加小偏移避免边界歧义
	var nudge := 1e-6
	var from_q := float(from.x) + nudge
	var from_r := float(from.y) + nudge
	var to_q := float(to.x)
	var to_r := float(to.y)
	
	for i in range(n + 1):
		var t := float(i) / float(n)
		var q := lerpf(from_q, to_q, t)
		var r := lerpf(from_r, to_r, t)
		results.append(HexCoord.axial_round(q, r))
	
	return results


## 绘制从 a 到 b 的直线 (Cube)
static func cube_line(from: Vector3i, to: Vector3i) -> Array[Vector3i]:
	var n := cube_distance(from, to)
	if n == 0:
		return [from]
	
	var results: Array[Vector3i] = []
	
	# 添加小偏移避免边界歧义
	var nudge := 1e-6
	var from_q := float(from.x) + nudge
	var from_r := float(from.y) + nudge
	var from_s := float(from.z) - 2 * nudge
	var to_q := float(to.x)
	var to_r := float(to.y)
	var to_s := float(to.z)
	
	for i in range(n + 1):
		var t := float(i) / float(n)
		var q := lerpf(from_q, to_q, t)
		var r := lerpf(from_r, to_r, t)
		var s := lerpf(from_s, to_s, t)
		results.append(HexCoord.cube_round(q, r, s))
	
	return results


# ========== 旋转 ==========

## 绕原点顺时针旋转 60° (Axial)
static func axial_rotate_cw(coord: Vector2i) -> Vector2i:
	var cube := HexCoord.axial_to_cube(coord)
	var rotated := cube_rotate_cw(cube)
	return HexCoord.cube_to_axial(rotated)


## 绕原点逆时针旋转 60° (Axial)
static func axial_rotate_ccw(coord: Vector2i) -> Vector2i:
	var cube := HexCoord.axial_to_cube(coord)
	var rotated := cube_rotate_ccw(cube)
	return HexCoord.cube_to_axial(rotated)


## 绕原点顺时针旋转 60° (Cube)
## (q, r, s) -> (-r, -s, -q)
static func cube_rotate_cw(coord: Vector3i) -> Vector3i:
	return Vector3i(-coord.y, -coord.z, -coord.x)


## 绕原点逆时针旋转 60° (Cube)
## (q, r, s) -> (-s, -q, -r)
static func cube_rotate_ccw(coord: Vector3i) -> Vector3i:
	return Vector3i(-coord.z, -coord.x, -coord.y)


## 绕任意中心旋转 (Axial)
## rotations: 正数顺时针，负数逆时针，单位为 60°
static func axial_rotate_around(coord: Vector2i, center: Vector2i, rotations: int) -> Vector2i:
	# 平移到原点
	var vec := coord - center
	
	# 应用旋转
	var abs_rot := absi(rotations) % 6
	for i in range(abs_rot):
		if rotations > 0:
			vec = axial_rotate_cw(vec)
		else:
			vec = axial_rotate_ccw(vec)
	
	# 平移回去
	return vec + center


## 绕任意中心旋转 (Cube)
static func cube_rotate_around(coord: Vector3i, center: Vector3i, rotations: int) -> Vector3i:
	# 平移到原点
	var vec := coord - center
	
	# 应用旋转
	var abs_rot := absi(rotations) % 6
	for i in range(abs_rot):
		if rotations > 0:
			vec = cube_rotate_cw(vec)
		else:
			vec = cube_rotate_ccw(vec)
	
	# 平移回去
	return vec + center


# ========== 反射 ==========

## 沿 q 轴反射 (交换 r 和 s)
static func cube_reflect_q(coord: Vector3i) -> Vector3i:
	return Vector3i(coord.x, coord.z, coord.y)


## 沿 r 轴反射 (交换 q 和 s)
static func cube_reflect_r(coord: Vector3i) -> Vector3i:
	return Vector3i(coord.z, coord.y, coord.x)


## 沿 s 轴反射 (交换 q 和 r)
static func cube_reflect_s(coord: Vector3i) -> Vector3i:
	return Vector3i(coord.y, coord.x, coord.z)


## 沿 q 轴反射 (Axial)
static func axial_reflect_q(coord: Vector2i) -> Vector2i:
	var cube := HexCoord.axial_to_cube(coord)
	var reflected := cube_reflect_q(cube)
	return HexCoord.cube_to_axial(reflected)


## 沿 r 轴反射 (Axial)
static func axial_reflect_r(coord: Vector2i) -> Vector2i:
	var cube := HexCoord.axial_to_cube(coord)
	var reflected := cube_reflect_r(cube)
	return HexCoord.cube_to_axial(reflected)


## 沿 s 轴反射 (Axial)
static func axial_reflect_s(coord: Vector2i) -> Vector2i:
	var cube := HexCoord.axial_to_cube(coord)
	var reflected := cube_reflect_s(cube)
	return HexCoord.cube_to_axial(reflected)
