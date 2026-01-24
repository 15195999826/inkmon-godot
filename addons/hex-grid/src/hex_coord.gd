## HexCoord - 六边形坐标系统和转换
##
## 支持的坐标系统:
## - Cube: (q, r, s) 约束 q + r + s = 0
## - Axial: (q, r) 简化的 Cube 坐标
## - Offset: (col, row) 四种变体 (odd-q, even-q, odd-r, even-r)
## - Doubled: (col, row) 两种变体 (width, height)
##
## 参考: https://www.redblobgames.com/grids/hexagons/
class_name HexCoord
extends RefCounted


# ========== 枚举 ==========

## Offset 坐标类型
enum OffsetType {
	ODD_Q,   ## Flat-top, 奇数列下移
	EVEN_Q,  ## Flat-top, 偶数列下移
	ODD_R,   ## Pointy-top, 奇数行右移
	EVEN_R,  ## Pointy-top, 偶数行右移
}

## Doubled 坐标类型
enum DoubledType {
	WIDTH,   ## Flat-top, col = 2*q + r
	HEIGHT,  ## Pointy-top, row = 2*r + q
}


# ========== Cube 坐标 ==========

## 创建 Cube 坐标
## 约束: q + r + s = 0
static func cube(q: int, r: int, s: int) -> Vector3i:
	assert(q + r + s == 0, "Invalid cube coordinates: q + r + s must equal 0")
	return Vector3i(q, r, s)


## 从 q, r 创建 Cube 坐标 (自动计算 s)
static func cube_from_qr(q: int, r: int) -> Vector3i:
	return Vector3i(q, r, -q - r)


## 验证 Cube 坐标是否有效
static func cube_is_valid(coord: Vector3i) -> bool:
	return coord.x + coord.y + coord.z == 0


## Cube 坐标取整 (用于像素转六边形)
static func cube_round(frac_q: float, frac_r: float, frac_s: float) -> Vector3i:
	var q := roundi(frac_q)
	var r := roundi(frac_r)
	var s := roundi(frac_s)
	
	var q_diff := absf(q - frac_q)
	var r_diff := absf(r - frac_r)
	var s_diff := absf(s - frac_s)
	
	# 修正误差最大的分量以满足 q + r + s = 0
	if q_diff > r_diff and q_diff > s_diff:
		q = -r - s
	elif r_diff > s_diff:
		r = -q - s
	else:
		s = -q - r
	
	return Vector3i(q, r, s)


# ========== Axial 坐标 ==========

## 创建 Axial 坐标
static func axial(q: int, r: int) -> Vector2i:
	return Vector2i(q, r)


## Axial 坐标取整
static func axial_round(frac_q: float, frac_r: float) -> Vector2i:
	var cube_coord := cube_round(frac_q, frac_r, -frac_q - frac_r)
	return Vector2i(cube_coord.x, cube_coord.y)


# ========== Offset 坐标 ==========

## 创建 Offset 坐标
static func offset(col: int, row: int) -> Vector2i:
	return Vector2i(col, row)


# ========== Doubled 坐标 ==========

## 创建 Doubled 坐标
static func doubled(col: int, row: int) -> Vector2i:
	return Vector2i(col, row)


## 验证 Doubled 坐标是否有效 (col + row 必须为偶数)
static func doubled_is_valid(coord: Vector2i) -> bool:
	return (coord.x + coord.y) % 2 == 0


# ========== Axial <-> Cube 转换 ==========

## Axial 转 Cube
static func axial_to_cube(coord: Vector2i) -> Vector3i:
	return Vector3i(coord.x, coord.y, -coord.x - coord.y)


## Cube 转 Axial
static func cube_to_axial(coord: Vector3i) -> Vector2i:
	return Vector2i(coord.x, coord.y)


# ========== Offset <-> Cube 转换 ==========

## Offset 转 Cube
static func offset_to_cube(coord: Vector2i, offset_type: OffsetType) -> Vector3i:
	var q: int
	var r: int
	
	match offset_type:
		OffsetType.ODD_Q:
			q = coord.x
			r = coord.y - (coord.x - (coord.x & 1)) / 2
		OffsetType.EVEN_Q:
			q = coord.x
			r = coord.y - (coord.x + (coord.x & 1)) / 2
		OffsetType.ODD_R:
			q = coord.x - (coord.y - (coord.y & 1)) / 2
			r = coord.y
		OffsetType.EVEN_R:
			q = coord.x - (coord.y + (coord.y & 1)) / 2
			r = coord.y
	
	return Vector3i(q, r, -q - r)


## Cube 转 Offset
static func cube_to_offset(coord: Vector3i, offset_type: OffsetType) -> Vector2i:
	var col: int
	var row: int
	
	match offset_type:
		OffsetType.ODD_Q:
			col = coord.x
			row = coord.y + (coord.x - (coord.x & 1)) / 2
		OffsetType.EVEN_Q:
			col = coord.x
			row = coord.y + (coord.x + (coord.x & 1)) / 2
		OffsetType.ODD_R:
			col = coord.x + (coord.y - (coord.y & 1)) / 2
			row = coord.y
		OffsetType.EVEN_R:
			col = coord.x + (coord.y + (coord.y & 1)) / 2
			row = coord.y
	
	return Vector2i(col, row)


# ========== Offset <-> Axial 转换 ==========

## Offset 转 Axial
static func offset_to_axial(coord: Vector2i, offset_type: OffsetType) -> Vector2i:
	var cube_coord := offset_to_cube(coord, offset_type)
	return cube_to_axial(cube_coord)


## Axial 转 Offset
static func axial_to_offset(coord: Vector2i, offset_type: OffsetType) -> Vector2i:
	var cube_coord := axial_to_cube(coord)
	return cube_to_offset(cube_coord, offset_type)


# ========== Doubled <-> Axial 转换 ==========

## Doubled 转 Axial
static func doubled_to_axial(coord: Vector2i, doubled_type: DoubledType) -> Vector2i:
	match doubled_type:
		DoubledType.WIDTH:
			# col = 2*q + r, row = r
			# q = (col - row) / 2, r = row
			return Vector2i((coord.x - coord.y) / 2, coord.y)
		DoubledType.HEIGHT:
			# col = q, row = 2*r + q
			# q = col, r = (row - col) / 2
			return Vector2i(coord.x, (coord.y - coord.x) / 2)
	
	return Vector2i.ZERO


## Axial 转 Doubled
static func axial_to_doubled(coord: Vector2i, doubled_type: DoubledType) -> Vector2i:
	match doubled_type:
		DoubledType.WIDTH:
			# col = 2*q + r, row = r
			return Vector2i(2 * coord.x + coord.y, coord.y)
		DoubledType.HEIGHT:
			# col = q, row = 2*r + q
			return Vector2i(coord.x, 2 * coord.y + coord.x)
	
	return Vector2i.ZERO


# ========== Doubled <-> Cube 转换 ==========

## Doubled 转 Cube
static func doubled_to_cube(coord: Vector2i, doubled_type: DoubledType) -> Vector3i:
	var axial_coord := doubled_to_axial(coord, doubled_type)
	return axial_to_cube(axial_coord)


## Cube 转 Doubled
static func cube_to_doubled(coord: Vector3i, doubled_type: DoubledType) -> Vector2i:
	var axial_coord := cube_to_axial(coord)
	return axial_to_doubled(axial_coord, doubled_type)


# ========== 工具函数 ==========

## 生成 Axial 坐标的字符串 key (用于 Dictionary)
static func axial_to_key(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]


## 从字符串 key 解析 Axial 坐标
static func key_to_axial(key: String) -> Vector2i:
	var parts := key.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))


## 生成 Cube 坐标的字符串 key
static func cube_to_key(coord: Vector3i) -> String:
	return "%d,%d,%d" % [coord.x, coord.y, coord.z]


## 从字符串 key 解析 Cube 坐标
static func key_to_cube(key: String) -> Vector3i:
	var parts := key.split(",")
	return Vector3i(int(parts[0]), int(parts[1]), int(parts[2]))
