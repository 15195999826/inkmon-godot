## HexGrid 单元测试
##
## 运行方式: 在 Godot 编辑器中运行此场景
extends Node


func _ready() -> void:
	print("========== HexGrid Tests ==========")
	
	var passed: int = 0
	var failed: int = 0
	
	# 测试 HexCoord
	if _test_hex_coord():
		passed += 1
		print("[PASS] HexCoord")
	else:
		failed += 1
		print("[FAIL] HexCoord")
	
	# 测试 HexMath
	if _test_hex_math():
		passed += 1
		print("[PASS] HexMath")
	else:
		failed += 1
		print("[FAIL] HexMath")
	
	# 测试 HexLayout
	if _test_hex_layout():
		passed += 1
		print("[PASS] HexLayout")
	else:
		failed += 1
		print("[FAIL] HexLayout")
	
	# 测试 HexGridCompat
	if _test_hex_grid_compat():
		passed += 1
		print("[PASS] HexGridCompat")
	else:
		failed += 1
		print("[FAIL] HexGridCompat")
	
	print("====================================")
	print("Passed: %d, Failed: %d" % [passed, failed])
	
	if failed > 0:
		print("TESTS FAILED!")
	else:
		print("ALL TESTS PASSED!")


func _test_hex_coord() -> bool:
	# 测试 Axial 坐标创建
	var a: Vector2i = HexCoord.axial(1, 2)
	if a != Vector2i(1, 2):
		print("  axial() failed")
		return false
	
	# 测试 Cube 坐标创建
	var c: Vector3i = HexCoord.cube(1, -2, 1)
	if c != Vector3i(1, -2, 1):
		print("  cube() failed")
		return false
	
	# 测试 Axial <-> Cube 转换
	var cube_from_axial: Vector3i = HexCoord.axial_to_cube(Vector2i(1, 2))
	if cube_from_axial != Vector3i(1, 2, -3):
		print("  axial_to_cube() failed: %s" % cube_from_axial)
		return false
	
	var axial_from_cube: Vector2i = HexCoord.cube_to_axial(Vector3i(1, 2, -3))
	if axial_from_cube != Vector2i(1, 2):
		print("  cube_to_axial() failed")
		return false
	
	# 测试 Cube 取整
	var rounded: Vector3i = HexCoord.cube_round(1.2, -0.8, -0.4)
	if rounded.x + rounded.y + rounded.z != 0:
		print("  cube_round() constraint failed")
		return false
	
	# 测试 Offset 转换
	var offset_coord: Vector2i = HexCoord.axial_to_offset(Vector2i(1, 2), HexCoord.OffsetType.ODD_Q)
	var back_to_axial: Vector2i = HexCoord.offset_to_axial(offset_coord, HexCoord.OffsetType.ODD_Q)
	if back_to_axial != Vector2i(1, 2):
		print("  Offset conversion roundtrip failed")
		return false
	
	return true


func _test_hex_math() -> bool:
	# 测试距离计算
	var dist: int = HexMath.axial_distance(Vector2i(0, 0), Vector2i(2, -1))
	if dist != 2:
		print("  axial_distance() failed: %d" % dist)
		return false
	
	# 测试邻居
	var neighbors: Array[Vector2i] = HexMath.axial_neighbors(Vector2i(0, 0))
	if neighbors.size() != 6:
		print("  axial_neighbors() count failed")
		return false
	
	# 测试范围
	var range_hexes: Array[Vector2i] = HexMath.axial_range(Vector2i(0, 0), 1)
	if range_hexes.size() != 7:  # 1 + 6
		print("  axial_range() count failed: %d" % range_hexes.size())
		return false
	
	# 测试环
	var ring: Array[Vector2i] = HexMath.axial_ring(Vector2i(0, 0), 2)
	if ring.size() != 12:  # 6 * 2
		print("  axial_ring() count failed: %d" % ring.size())
		return false
	
	# 测试线段
	var line: Array[Vector2i] = HexMath.axial_line(Vector2i(0, 0), Vector2i(3, 0))
	if line.size() != 4:  # 包含两端点
		print("  axial_line() count failed: %d" % line.size())
		return false
	
	# 测试旋转
	var rotated: Vector2i = HexMath.axial_rotate_cw(Vector2i(1, 0))
	var rotated_back: Vector2i = HexMath.axial_rotate_ccw(rotated)
	if rotated_back != Vector2i(1, 0):
		print("  rotation roundtrip failed")
		return false
	
	return true


func _test_hex_layout() -> bool:
	var layout: HexLayout = HexLayout.new(HexLayout.FLAT, 32.0, Vector2.ZERO)
	
	# 测试 hex -> pixel -> hex 往返
	var original: Vector2i = Vector2i(2, 3)
	var pixel: Vector2 = layout.hex_to_pixel(original)
	var back: Vector2i = layout.pixel_to_hex(pixel)
	if back != original:
		print("  hex_to_pixel roundtrip failed")
		return false
	
	# 测试角点
	var corners: PackedVector2Array = layout.hex_corners(Vector2i(0, 0))
	if corners.size() != 6:
		print("  hex_corners() count failed")
		return false
	
	# 测试 Pointy-top
	var pointy_layout: HexLayout = HexLayout.create_pointy(32.0)
	var pointy_pixel: Vector2 = pointy_layout.hex_to_pixel(original)
	var pointy_back: Vector2i = pointy_layout.pixel_to_hex(pointy_pixel)
	if pointy_back != original:
		print("  pointy hex_to_pixel roundtrip failed")
		return false
	
	return true


func _test_hex_grid_compat() -> bool:
	# 测试兼容层 (Dictionary 格式)
	var coord: Dictionary = HexGridCompat.axial(1, 2)
	if coord["q"] != 1 or coord["r"] != 2:
		print("  compat axial() failed")
		return false
	
	# 测试 hex_key
	var key: String = HexGridCompat.hex_key(coord)
	if key != "1,2":
		print("  compat hex_key() failed")
		return false
	
	# 测试 parse_hex_key
	var parsed: Dictionary = HexGridCompat.parse_hex_key(key)
	if not HexGridCompat.hex_equals(parsed, coord):
		print("  compat parse_hex_key() failed")
		return false
	
	# 测试邻居
	var neighbors: Array[Dictionary] = HexGridCompat.hex_neighbors({"q": 0, "r": 0})
	if neighbors.size() != 6:
		print("  compat hex_neighbors() failed")
		return false
	
	# 测试距离
	var dist: int = HexGridCompat.hex_distance({"q": 0, "r": 0}, {"q": 2, "r": -1})
	if dist != 2:
		print("  compat hex_distance() failed")
		return false
	
	# 测试像素转换
	var pixel: Vector2 = HexGridCompat.hex_to_pixel({"q": 1, "r": 1}, 32.0)
	var back: Dictionary = HexGridCompat.pixel_to_hex(pixel, 32.0)
	if back["q"] != 1 or back["r"] != 1:
		print("  compat pixel conversion failed")
		return false
	
	return true
