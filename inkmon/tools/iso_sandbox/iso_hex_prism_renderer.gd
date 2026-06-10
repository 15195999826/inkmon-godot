class_name InkMonIsoHexPrismRenderer
extends Node2D

## 等轴 hex 棱柱程序化渲染器（沙盒专用，不进正式渲染链）。
##
## pointy-top hex 布局（公式与 ultra-grid-map GridLayout 同源），经
## InkMonRender2DIsoProjection.ground_basis(pitch, yaw) 仿射投影到屏幕 ——
## pitch/yaw 运行时可调。每 tile 画成"积木"：可见侧面（按光向分明暗）+ 顶面 +
## 描边 + 可选 billboard 树（永远屏幕直立，验证"地面转、单位立"）。
##
## painter's algorithm：按投影后平面 y 远→近整图重画（沙盒规模 ~100 tile，_draw 足够）。

const SQRT3 := sqrt(3.0)

var hex_size := 34.0          ## hex 外接圆半径（平面像素）
var thickness := 22.0          ## 积木基础厚度（世界高度）
var elevation_step := 16.0     ## 每级海拔的世界高度

var pitch_deg := 33.4:
	set(value):
		pitch_deg = value
		queue_redraw()

var yaw_deg := 0.0:
	set(value):
		yaw_deg = value
		queue_redraw()

## Vector2i(q,r) -> {"color": Color, "elevation": int, "tree": bool}
var _tiles: Dictionary = {}


func set_map(tiles: Dictionary) -> void:
	_tiles = tiles
	queue_redraw()


func set_angles(p_pitch_deg: float, p_yaw_deg: float) -> void:
	pitch_deg = p_pitch_deg
	yaw_deg = p_yaw_deg


func tile_count() -> int:
	return _tiles.size()


## axial → hex 平面中心（未投影）。
func center_of(axial: Vector2i) -> Vector2:
	return Vector2(SQRT3 * (float(axial.x) + float(axial.y) * 0.5), 1.5 * float(axial.y)) * hex_size


## 屏幕局部坐标 → axial（按海拔 0 平面反投影；沙盒拾取验证用）。
func pick_axial(local_pos: Vector2) -> Vector2i:
	var plane := InkMonRender2DIsoProjection.ground_basis(pitch_deg, yaw_deg).affine_inverse() * local_pos
	var qf := (SQRT3 / 3.0 * plane.x - plane.y / 3.0) / hex_size
	var rf := (2.0 / 3.0 * plane.y) / hex_size
	return _axial_round(qf, rf)


func _draw() -> void:
	if _tiles.is_empty():
		return
	var ground := InkMonRender2DIsoProjection.ground_basis(pitch_deg, yaw_deg)
	var order: Array[Vector2i] = []
	for key in _tiles.keys():
		order.append(key as Vector2i)
	order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (ground * center_of(a)).y < (ground * center_of(b)).y)
	for axial in order:
		_draw_tile(ground, axial, _tiles[axial] as Dictionary)


func _draw_tile(ground: Transform2D, axial: Vector2i, info: Dictionary) -> void:
	var base_color := info.get("color", Color.MAGENTA) as Color
	var elevation := int(info.get("elevation", 0))
	var center_plane := center_of(axial)
	var lift := InkMonRender2DIsoProjection.height_to_screen(float(elevation) * elevation_step, pitch_deg)
	var side_h := InkMonRender2DIsoProjection.height_to_screen(thickness + float(elevation) * elevation_step, pitch_deg)
	var lift_offset := Vector2(0.0, -lift)

	var top := PackedVector2Array()
	for i in range(6):
		top.append(ground * _corner_plane(center_plane, i) + lift_offset)
	var center_screen := ground * center_plane + lift_offset

	# 侧面：屏幕外法线朝下（out.y > 0）的边可见；明暗 = 外法线 vs 光向（右上来光 → 左暗右亮）。
	var to_light := Vector2(0.85, -0.53).normalized()
	for i in range(6):
		var a := top[i]
		var b := top[(i + 1) % 6]
		var out := (a + b) * 0.5 - center_screen
		if out.y <= 0.001:
			continue
		var quad := PackedVector2Array([a, b, b + Vector2(0.0, side_h), a + Vector2(0.0, side_h)])
		var shade := lerpf(0.36, 0.78, clampf((out.normalized().dot(to_light) + 1.0) * 0.5, 0.0, 1.0))
		draw_polygon(quad, PackedColorArray([base_color.darkened(1.0 - shade)]))

	draw_polygon(top, PackedColorArray([base_color]))

	var outline := top.duplicate()
	outline.append(top[0])
	draw_polyline(outline, Color(0.05, 0.05, 0.04, 0.45), 1.5)

	if bool(info.get("tree", false)):
		_draw_tree(center_screen)


## billboard 树：屏幕空间直立，与地面投影无关（单位/道具的表演惯例演示）。
func _draw_tree(foot: Vector2) -> void:
	var s := hex_size
	var trunk_w := s * 0.16
	var trunk_h := s * 0.30
	draw_rect(Rect2(foot + Vector2(-trunk_w * 0.5, -trunk_h), Vector2(trunk_w, trunk_h)), Color(0.42, 0.30, 0.18))
	var base_y := foot.y - trunk_h
	for layer in range(3):
		var half := s * 0.55 * (1.0 - 0.22 * float(layer))
		var y0 := base_y - s * 0.38 * float(layer)
		var tri := PackedVector2Array([
			Vector2(foot.x - half, y0),
			Vector2(foot.x + half, y0),
			Vector2(foot.x, y0 - s * 0.62),
		])
		var leaf := Color(0.16, 0.34, 0.16) if layer % 2 == 0 else Color(0.22, 0.44, 0.20)
		draw_polygon(tri, PackedColorArray([leaf]))


func _corner_plane(center: Vector2, i: int) -> Vector2:
	var angle := deg_to_rad(60.0 * float(i) - 30.0)
	return center + Vector2(cos(angle), sin(angle)) * hex_size


func _axial_round(qf: float, rf: float) -> Vector2i:
	var sf := -qf - rf
	var q := roundf(qf)
	var r := roundf(rf)
	var s := roundf(sf)
	var dq := absf(q - qf)
	var dr := absf(r - rf)
	var ds := absf(s - sf)
	if dq > dr and dq > ds:
		q = -r - s
	elif dr > ds:
		r = -q - s
	return Vector2i(int(q), int(r))
