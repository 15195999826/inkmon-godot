extends InkMonArtTileMapBase

## fable-水shader-v1 卡通青绿变体（_toon）：以 codex-倒角-v1 program 场景为基底，剔除水地块，
## 改用 canvas shader 水面还原 style_a_turquoise_r10.png 的高饱和青绿卡通水质感。
##
## 与现役灰蓝版（water_scene.gd）并存、互不影响。R1-R10 迭代态特征：
## - 每个水格一片 Polygon2D（水面平贴，不下沉），UV 直通 hex 平面坐标，共享一个 ShaderMaterial；
## - 岸线段 / 礁石圆以 uniform 数组注入，shader 逐像素解析"到岸距离"；
## - 河中礁石多边形（石顶+石侧+ink 描边）+ shader 自动白沫尾流；
## - 河口开边（图边流出处）补竖直截面 quad，跑下落条纹动画。
##
## 截图约定（沿用基类 INKMON_ART_CAPTURE_PATH，另加）：
## - INKMON_ART_CAPTURE_PATH_B / INKMON_ART_CAPTURE_DELAY_B：延迟第二帧，验证动画在动；
## - INKMON_ART_CAPTURE_FOCUS=river：相机聚焦河道中段特写。

const WATER_SURFACE_SHADER := preload("res://inkmon美术探索/fable-水shader-v1/water_surface_toon.gdshader")
const WATER_FACE_SHADER := preload("res://inkmon美术探索/fable-水shader-v1/water_face_toon.gdshader")

const MAX_SHADER_SEGMENTS := 96
const MAX_SHADER_ROCKS := 8

## 边 i = corner(i)→corner(i+1)，边中点朝向 60i+30°，对应 flat-top 轴向邻居方位。
const EDGE_NEIGHBOR_DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1),
	Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, -1),
]

## 河中礁石（cell 必须是水格；offset/radius 为平面 px）。
const RIVER_ROCKS: Array[Dictionary] = [
	{"cell": Vector2i(2, 0), "offset": Vector2(14.0, 8.0), "radius": 40.0},
	{"cell": Vector2i(2, 0), "offset": Vector2(-46.0, -32.0), "radius": 24.0},
	{"cell": Vector2i(-3, 2), "offset": Vector2(-8.0, 10.0), "radius": 28.0},
]

var _water_surface_material: ShaderMaterial
var _water_face_material: ShaderMaterial
var _water_uv_texture: ImageTexture
var _water_screen_rect := Rect2()
var _has_water_rect := false


func _rebuild() -> void:
	if _map_root != null:
		_map_root.queue_free()
	_map_root = Node2D.new()
	_map_root.name = "MapRoot"
	add_child(_map_root)
	_tile_count = 0
	_decor_count = 0
	_water_screen_rect = Rect2()
	_has_water_rect = false

	var tiles := InkMonIsoSandboxDemoMap.generate()
	var pitch := float(_manifest["pitch_deg"])
	var yaw := float(_manifest["yaw_deg"])
	var edge_px := float(_manifest["px_per_hex_edge"])
	var px_per_unit := float(_manifest["px_per_unit"])
	var elevation_step_px := float(_manifest["elevation_step_world"]) * px_per_unit
	var ground := InkMonRender2DIsoProjection.ground_basis(pitch, yaw)

	var projected_corners := PackedVector2Array()
	for i in 6:
		projected_corners.append(ground * _hex_corner(i, edge_px))
	var visible_edges := _visible_edge_indices(projected_corners)

	var entries: Array[Dictionary] = []
	for key in tiles.keys():
		var axial := key as Vector2i
		var info := tiles[axial] as Dictionary
		var center_plane := _center_of_flat_top(axial, edge_px)
		var ground_screen := ground * center_plane
		if str(info["terrain"]) == InkMonIsoSandboxDemoMap.TERRAIN_WATER:
			var open_faces: Array[int] = []
			for edge_index in 6:
				var neighbor := axial + EDGE_NEIGHBOR_DIRS[edge_index]
				if not tiles.has(neighbor) and edge_index in visible_edges:
					open_faces.append(edge_index)
			entries.append({
				"sort": Vector2(ground_screen.x, ground_screen.y),
				"order": 0,
				"kind": "water",
				"axial": axial,
				"pos": ground_screen,
				"open_faces": open_faces,
			})
			continue
		var elevation := int(info["elevation"])
		var lift := InkMonRender2DIsoProjection.height_to_screen(float(elevation) * elevation_step_px, pitch)
		entries.append({
			"sort": Vector2(ground_screen.x, ground_screen.y),
			"order": 0,
			"kind": "tile",
			"axial": axial,
			"info": info,
			"pos": ground_screen,
			"lift": lift,
		})
		_tile_count += 1

	# 礁石不进 entries：小石可能 screen-y 小于所在格中心，会被后画的水面盖住。
	# 水面是同一平面的连续 shader，礁石统一画在全部地块/水面之后即可（礁石间按 y 排序）。
	var rock_entries: Array[Dictionary] = []
	for rock in RIVER_ROCKS:
		var rock_cell := rock["cell"] as Vector2i
		if not tiles.has(rock_cell) or str((tiles[rock_cell] as Dictionary)["terrain"]) != InkMonIsoSandboxDemoMap.TERRAIN_WATER:
			push_error("water_scene_toon: rock cell %s 不是水格" % str(rock_cell))
			continue
		var rock_plane := _center_of_flat_top(rock_cell, edge_px) + (rock["offset"] as Vector2)
		var rock_screen := ground * rock_plane
		rock_entries.append({
			"sort": Vector2(rock_screen.x, rock_screen.y),
			"kind": "rock",
			"pos": rock_screen,
			"radius": float(rock["radius"]),
			"blob_seed": rock_cell.x * 131 + rock_cell.y * 977 + int(rock["radius"]),
		})

	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sort_a := a["sort"] as Vector2
		var sort_b := b["sort"] as Vector2
		if sort_a.y != sort_b.y:
			return sort_a.y < sort_b.y
		if sort_a.x != sort_b.x:
			return sort_a.x < sort_b.x
		return int(a["order"]) < int(b["order"])
	)

	_build_water_materials(tiles, edge_px, px_per_unit, pitch)

	for i in entries.size():
		var entry := entries[i]
		match str(entry["kind"]):
			"tile":
				_add_tile_entry(entry, i)
			"water":
				_add_water_entry(entry, i, ground, edge_px, px_per_unit, pitch)

	rock_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["sort"] as Vector2).y < (b["sort"] as Vector2).y
	)
	for i in rock_entries.size():
		_add_rock_entry(rock_entries[i], entries.size() + i, ground)

	_fit_camera()


func _build_water_materials(tiles: Dictionary, edge_px: float, px_per_unit: float, pitch: float) -> void:
	var seg_a := PackedVector2Array()
	var seg_b := PackedVector2Array()
	var plane_min := Vector2(INF, INF)
	var plane_max := Vector2(-INF, -INF)
	var water_found := false
	for key in tiles.keys():
		var axial := key as Vector2i
		var info := tiles[axial] as Dictionary
		if str(info["terrain"]) != InkMonIsoSandboxDemoMap.TERRAIN_WATER:
			continue
		water_found = true
		var center_plane := _center_of_flat_top(axial, edge_px)
		plane_min = plane_min.min(center_plane - Vector2(edge_px, edge_px))
		plane_max = plane_max.max(center_plane + Vector2(edge_px, edge_px))
		for edge_index in 6:
			var neighbor := axial + EDGE_NEIGHBOR_DIRS[edge_index]
			if not tiles.has(neighbor):
				continue # 开边：河从图边流出，不压岸沫
			if str((tiles[neighbor] as Dictionary)["terrain"]) == InkMonIsoSandboxDemoMap.TERRAIN_WATER:
				continue
			seg_a.append(center_plane + _hex_corner(edge_index, edge_px))
			seg_b.append(center_plane + _hex_corner((edge_index + 1) % 6, edge_px))
	if not water_found:
		push_error("water_scene_toon: demo map 里没有水格")
		return
	var seg_count := seg_a.size()
	if seg_count > MAX_SHADER_SEGMENTS:
		push_error("water_scene_toon: 岸线段 %d 超出 shader 上限 %d" % [seg_count, MAX_SHADER_SEGMENTS])
		seg_count = MAX_SHADER_SEGMENTS
	seg_a.resize(MAX_SHADER_SEGMENTS)
	seg_b.resize(MAX_SHADER_SEGMENTS)

	var rock_data := PackedVector3Array()
	for rock in RIVER_ROCKS:
		var rock_cell := rock["cell"] as Vector2i
		if not tiles.has(rock_cell):
			continue
		var rock_plane := _center_of_flat_top(rock_cell, edge_px) + (rock["offset"] as Vector2)
		rock_data.append(Vector3(rock_plane.x, rock_plane.y, float(rock["radius"]) * 0.55))
	var rock_count := mini(rock_data.size(), MAX_SHADER_ROCKS)
	rock_data.resize(MAX_SHADER_ROCKS)

	# 河道沿平面 X 轴（q+2r 恒定带），取 -x = 屏幕左下方向为下游。
	var flow_dir := Vector2(-1.0, 0.0)
	var flow_span := Vector2(-plane_max.x, -plane_min.x)

	var uv_image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	uv_image.fill(Color.WHITE)
	_water_uv_texture = ImageTexture.create_from_image(uv_image)

	_water_surface_material = ShaderMaterial.new()
	_water_surface_material.shader = WATER_SURFACE_SHADER
	_water_surface_material.set_shader_parameter("seg_count", seg_count)
	_water_surface_material.set_shader_parameter("seg_a", seg_a)
	_water_surface_material.set_shader_parameter("seg_b", seg_b)
	_water_surface_material.set_shader_parameter("rock_count", rock_count)
	_water_surface_material.set_shader_parameter("rock_data", rock_data)
	_water_surface_material.set_shader_parameter("flow_dir", flow_dir)
	_water_surface_material.set_shader_parameter("flow_span", flow_span)
	_water_surface_material.set_shader_parameter("edge_px", edge_px)

	var face_height := InkMonRender2DIsoProjection.height_to_screen(
		float(_manifest["thickness_world"]) * px_per_unit, pitch)
	_water_face_material = ShaderMaterial.new()
	_water_face_material.shader = WATER_FACE_SHADER
	_water_face_material.set_shader_parameter("face_height", face_height)


func _add_water_entry(entry: Dictionary, order_index: int, ground: Transform2D, edge_px: float, px_per_unit: float, pitch: float) -> void:
	if _water_surface_material == null:
		return
	var axial := entry["axial"] as Vector2i
	var center_plane := _center_of_flat_top(axial, edge_px)
	var cell_root := Node2D.new()
	cell_root.name = "water_%s" % str(axial)
	cell_root.position = entry["pos"] as Vector2
	cell_root.z_index = order_index * 32
	_map_root.add_child(cell_root)

	var face_height := InkMonRender2DIsoProjection.height_to_screen(
		float(_manifest["thickness_world"]) * px_per_unit, pitch)
	for edge_variant in (entry["open_faces"] as Array):
		var edge_index := int(edge_variant)
		var corner_a := _hex_corner(edge_index, edge_px)
		var corner_b := _hex_corner((edge_index + 1) % 6, edge_px)
		var screen_a := ground * corner_a
		var screen_b := ground * corner_b
		var face := Polygon2D.new()
		face.name = "face_%d" % edge_index
		face.polygon = PackedVector2Array([
			screen_a, screen_b,
			screen_b + Vector2(0.0, face_height),
			screen_a + Vector2(0.0, face_height),
		])
		var edge_dir := (corner_b - corner_a).normalized()
		var u_a := (center_plane + corner_a).dot(edge_dir)
		var u_b := (center_plane + corner_b).dot(edge_dir)
		face.uv = PackedVector2Array([
			Vector2(u_a, 0.0), Vector2(u_b, 0.0),
			Vector2(u_b, face_height), Vector2(u_a, face_height),
		])
		face.texture = _water_uv_texture
		face.material = _water_face_material
		face.z_index = 0
		cell_root.add_child(face)

	var surface := Polygon2D.new()
	surface.name = "surface"
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	for i in 6:
		points.append(ground * _hex_corner(i, edge_px))
		uvs.append(center_plane + _hex_corner(i, edge_px))
	surface.polygon = points
	surface.uv = uvs
	surface.texture = _water_uv_texture
	surface.material = _water_surface_material
	surface.z_index = 5
	cell_root.add_child(surface)

	var piece_rect := Rect2(cell_root.position + points[0], Vector2.ZERO)
	for i in range(1, points.size()):
		piece_rect = piece_rect.expand(cell_root.position + points[i])
	if _has_water_rect:
		_water_screen_rect = _water_screen_rect.merge(piece_rect)
	else:
		_water_screen_rect = piece_rect
		_has_water_rect = true


func _add_rock_entry(entry: Dictionary, order_index: int, ground: Transform2D) -> void:
	var rock_root := Node2D.new()
	rock_root.name = "rock_%d" % order_index
	rock_root.position = entry["pos"] as Vector2
	rock_root.z_index = order_index * 32
	_map_root.add_child(rock_root)

	var radius := float(entry["radius"])
	var rng := RandomNumberGenerator.new()
	rng.seed = int(entry["blob_seed"])
	var vertex_count := 9
	var base_points := PackedVector2Array()
	var top_points := PackedVector2Array()
	var rock_height := radius * 0.55
	for i in vertex_count:
		var angle := TAU * (float(i) + rng.randf_range(-0.22, 0.22)) / float(vertex_count)
		var blob_radius := radius * rng.randf_range(0.95, 1.30)
		var projected := ground * (Vector2(cos(angle), sin(angle)) * blob_radius)
		base_points.append(projected)
		top_points.append(projected * 0.90 - Vector2(0.0, rock_height))

	var palette := _terrain_palette(InkMonIsoSandboxDemoMap.TERRAIN_STONE)
	_add_polygon(rock_root, "side", base_points, _shade_color(palette["side"] as Color, 0.85), 0)
	_add_polygon(rock_root, "top", top_points, _shade_color(palette["top"] as Color, 1.14), 2)
	if ink_enabled:
		_add_polyline(rock_root, base_points, SOFT_INK_COLOR, 1.3, true, 1)
		_add_polyline(rock_root, top_points, INK_COLOR, 2.0, true, 4)


func _capture_if_requested() -> void:
	var target_path := OS.get_environment("INKMON_ART_CAPTURE_PATH")
	if target_path.is_empty():
		return
	_apply_capture_focus()
	await get_tree().process_frame
	await get_tree().process_frame
	if not _save_viewport_png(target_path):
		get_tree().quit(1)
		return
	var second_path := OS.get_environment("INKMON_ART_CAPTURE_PATH_B")
	if not second_path.is_empty():
		var delay := 0.8
		var delay_env := OS.get_environment("INKMON_ART_CAPTURE_DELAY_B")
		if not delay_env.is_empty():
			delay = maxf(0.05, delay_env.to_float())
		await get_tree().create_timer(delay).timeout
		if not _save_viewport_png(second_path):
			get_tree().quit(1)
			return
	get_tree().quit(0)


func _apply_capture_focus() -> void:
	if OS.get_environment("INKMON_ART_CAPTURE_FOCUS") != "river":
		return
	if not _has_water_rect or _camera == null:
		return
	var focus_rect := _water_screen_rect
	focus_rect.position.x += focus_rect.size.x * 0.22
	focus_rect.size.x *= 0.56
	focus_rect = focus_rect.grow(float(_manifest["px_per_hex_edge"]) * 0.6)
	var viewport_size := get_viewport_rect().size
	var zoom := minf(viewport_size.x / focus_rect.size.x, viewport_size.y / focus_rect.size.y)
	_camera.position = focus_rect.get_center()
	_camera.zoom = Vector2(zoom, zoom)


func _save_viewport_png(target_path: String) -> bool:
	DirAccess.make_dir_recursive_absolute(target_path.get_base_dir())
	var viewport_texture := get_viewport().get_texture()
	if viewport_texture == null:
		push_error("water_scene_toon: capture failed %s viewport texture is null" % target_path)
		return false
	var image := viewport_texture.get_image()
	if image == null:
		push_error("water_scene_toon: capture failed %s viewport image is null" % target_path)
		return false
	var err := image.save_png(target_path)
	if err != OK:
		push_error("water_scene_toon: capture failed %s err=%d" % [target_path, err])
		return false
	return true
