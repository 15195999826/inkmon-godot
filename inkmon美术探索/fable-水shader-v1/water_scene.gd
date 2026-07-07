extends InkMonArtTileMapBase

## fable-水shader-v1：以 codex-倒角-v1 program 场景为基底，剔除水地块，
## 改用 canvas shader 水面还原参考图（hex 地台 diorama）的水质感。
##
## 实现要点：
## - 每个水格一片 Polygon2D，UV 直通 hex 平面坐标，按水位共享 ShaderMaterial；
## - 岸线段以 uniform 数组注入，shader 逐像素解析"到岸距离"（灰蓝分区 + 裂纹网线 + 接触阴影）；
## - 水面按 manifest water_recess_world 下沉，露出岸壁条 = 参考图的嵌入感；
## - 上游整体抬升一级（terrace），河道中出现瀑布落差：上位水开边挂截面瀑布 quad，
##   下位水在落水线处跑白色翻涌动画；
## - 河口开边（图边流出处）同样补竖直截面 quad。
##
## 截图约定（沿用基类 INKMON_ART_CAPTURE_PATH，另加）：
## - INKMON_ART_CAPTURE_PATH_B / INKMON_ART_CAPTURE_DELAY_B：延迟第二帧，验证动画在动；
## - INKMON_ART_CAPTURE_FOCUS=river：相机聚焦河道中段特写。

const WATER_SURFACE_SHADER := preload("res://inkmon美术探索/fable-水shader-v1/water_surface.gdshader")
const WATER_FACE_SHADER := preload("res://inkmon美术探索/fable-水shader-v1/water_face.gdshader")

const MAX_SHADER_SEGMENTS := 96
const MAX_SHADER_FALLS := 8

## 上游阶地：q >= 此值的地块整体抬升一级，在河道中制造瀑布落差。
const TERRACE_MIN_Q := 1

## 边 i = corner(i)→corner(i+1)，边中点朝向 60i+30°，对应 flat-top 轴向邻居方位。
const EDGE_NEIGHBOR_DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1),
	Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, -1),
]

var _water_materials: Dictionary = {} ## elevation -> ShaderMaterial
var _water_face_materials: Dictionary = {} ## 高度键(round px) -> ShaderMaterial
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
	_apply_terrace(tiles)
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
		var elevation := int(info["elevation"])
		var lift := InkMonRender2DIsoProjection.height_to_screen(float(elevation) * elevation_step_px, pitch)
		if str(info["terrain"]) == InkMonIsoSandboxDemoMap.TERRAIN_WATER:
			var mouth_faces: Array[int] = []
			var fall_faces: Array[Dictionary] = []
			for edge_index in 6:
				if edge_index not in visible_edges:
					continue
				var neighbor := axial + EDGE_NEIGHBOR_DIRS[edge_index]
				if not tiles.has(neighbor):
					mouth_faces.append(edge_index)
					continue
				var n_info := tiles[neighbor] as Dictionary
				if str(n_info["terrain"]) == InkMonIsoSandboxDemoMap.TERRAIN_WATER \
						and int(n_info["elevation"]) < elevation:
					fall_faces.append({"edge": edge_index, "n_elevation": int(n_info["elevation"])})
			entries.append({
				"sort": Vector2(ground_screen.x, ground_screen.y),
				"order": 0,
				"kind": "water",
				"axial": axial,
				"pos": ground_screen,
				"elevation": elevation,
				"lift": lift,
				"mouth_faces": mouth_faces,
				"fall_faces": fall_faces,
			})
			continue
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

	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sort_a := a["sort"] as Vector2
		var sort_b := b["sort"] as Vector2
		if sort_a.y != sort_b.y:
			return sort_a.y < sort_b.y
		if sort_a.x != sort_b.x:
			return sort_a.x < sort_b.x
		return int(a["order"]) < int(b["order"])
	)

	_build_water_materials(tiles, edge_px)

	for i in entries.size():
		var entry := entries[i]
		match str(entry["kind"]):
			"tile":
				_add_tile_entry(entry, i)
			"water":
				_add_water_entry(entry, i, ground, edge_px, px_per_unit, pitch, elevation_step_px)

	_fit_camera()


## 上游抬升一级 + 抬升贴着高位水的低位岸地（防"水高于岸"）。
static func _apply_terrace(tiles: Dictionary) -> void:
	for key in tiles.keys():
		var axial := key as Vector2i
		if axial.x >= TERRACE_MIN_Q:
			var info := tiles[axial] as Dictionary
			info["elevation"] = int(info["elevation"]) + 1
	for key in tiles.keys():
		var axial := key as Vector2i
		var info := tiles[axial] as Dictionary
		if str(info["terrain"]) != InkMonIsoSandboxDemoMap.TERRAIN_WATER:
			continue
		var w_elev := int(info["elevation"])
		for dir in EDGE_NEIGHBOR_DIRS:
			var n_key := axial + dir
			if not tiles.has(n_key):
				continue
			var n_info := tiles[n_key] as Dictionary
			if str(n_info["terrain"]) == InkMonIsoSandboxDemoMap.TERRAIN_WATER:
				continue
			if int(n_info["elevation"]) < w_elev:
				n_info["elevation"] = w_elev


## 按水位收集岸线段/落水线段并生成各水位的水面材质。
func _build_water_materials(tiles: Dictionary, edge_px: float) -> void:
	_water_materials = {}
	_water_face_materials = {}

	var uv_image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	uv_image.fill(Color.WHITE)
	_water_uv_texture = ImageTexture.create_from_image(uv_image)

	# elev -> {"seg_a"/"seg_b"/"fall_a"/"fall_b": Array[Vector2]}
	var level_data: Dictionary = {}
	var plane_min := Vector2(INF, INF)
	var plane_max := Vector2(-INF, -INF)
	var water_found := false
	for key in tiles.keys():
		var axial := key as Vector2i
		var info := tiles[axial] as Dictionary
		if str(info["terrain"]) != InkMonIsoSandboxDemoMap.TERRAIN_WATER:
			continue
		water_found = true
		var w_elev := int(info["elevation"])
		if not level_data.has(w_elev):
			level_data[w_elev] = {"seg_a": [], "seg_b": [], "fall_a": [], "fall_b": []}
		var bucket := level_data[w_elev] as Dictionary
		var center_plane := _center_of_flat_top(axial, edge_px)
		plane_min = plane_min.min(center_plane - Vector2(edge_px, edge_px))
		plane_max = plane_max.max(center_plane + Vector2(edge_px, edge_px))
		for edge_index in 6:
			var neighbor := axial + EDGE_NEIGHBOR_DIRS[edge_index]
			if not tiles.has(neighbor):
				continue # 开边：河从图边流出，不算岸
			var n_info := tiles[neighbor] as Dictionary
			var corner_a: Vector2 = center_plane + _hex_corner(edge_index, edge_px)
			var corner_b: Vector2 = center_plane + _hex_corner((edge_index + 1) % 6, edge_px)
			if str(n_info["terrain"]) == InkMonIsoSandboxDemoMap.TERRAIN_WATER:
				if int(n_info["elevation"]) > w_elev:
					# 我是低位水，这条边是落水基线 → 白色翻涌
					(bucket["fall_a"] as Array).append(corner_a)
					(bucket["fall_b"] as Array).append(corner_b)
				continue
			(bucket["seg_a"] as Array).append(corner_a)
			(bucket["seg_b"] as Array).append(corner_b)
	if not water_found:
		push_error("water_scene: demo map 里没有水格")
		return

	# 河道沿平面 X 轴（q+2r 恒定带），取 -x = 屏幕左下方向为下游。
	var flow_dir := Vector2(-1.0, 0.0)
	var flow_span := Vector2(-plane_max.x, -plane_min.x)

	for elev_key in level_data.keys():
		var elev := int(elev_key)
		var bucket := level_data[elev] as Dictionary
		var seg_a := PackedVector2Array(bucket["seg_a"] as Array)
		var seg_b := PackedVector2Array(bucket["seg_b"] as Array)
		var fall_a := PackedVector2Array(bucket["fall_a"] as Array)
		var fall_b := PackedVector2Array(bucket["fall_b"] as Array)
		var seg_count := seg_a.size()
		if seg_count > MAX_SHADER_SEGMENTS:
			push_error("water_scene: 水位 %d 岸线段 %d 超出上限 %d" % [elev, seg_count, MAX_SHADER_SEGMENTS])
			seg_count = MAX_SHADER_SEGMENTS
		var fall_count := fall_a.size()
		if fall_count > MAX_SHADER_FALLS:
			push_error("water_scene: 水位 %d 落水线段 %d 超出上限 %d" % [elev, fall_count, MAX_SHADER_FALLS])
			fall_count = MAX_SHADER_FALLS
		seg_a.resize(MAX_SHADER_SEGMENTS)
		seg_b.resize(MAX_SHADER_SEGMENTS)
		fall_a.resize(MAX_SHADER_FALLS)
		fall_b.resize(MAX_SHADER_FALLS)
		var material := ShaderMaterial.new()
		material.shader = WATER_SURFACE_SHADER
		material.set_shader_parameter("seg_count", seg_count)
		material.set_shader_parameter("seg_a", seg_a)
		material.set_shader_parameter("seg_b", seg_b)
		material.set_shader_parameter("fall_count", fall_count)
		material.set_shader_parameter("fall_a", fall_a)
		material.set_shader_parameter("fall_b", fall_b)
		material.set_shader_parameter("flow_dir", flow_dir)
		material.set_shader_parameter("flow_span", flow_span)
		material.set_shader_parameter("edge_px", edge_px)
		_water_materials[elev] = material


func _get_face_material(face_height: float) -> ShaderMaterial:
	var height_key := roundi(face_height)
	if _water_face_materials.has(height_key):
		return _water_face_materials[height_key] as ShaderMaterial
	var material := ShaderMaterial.new()
	material.shader = WATER_FACE_SHADER
	material.set_shader_parameter("face_height", face_height)
	_water_face_materials[height_key] = material
	return material


func _add_water_entry(entry: Dictionary, order_index: int, ground: Transform2D, edge_px: float, px_per_unit: float, pitch: float, elevation_step_px: float) -> void:
	var elevation := int(entry["elevation"])
	if not _water_materials.has(elevation):
		return
	var axial := entry["axial"] as Vector2i
	var lift := float(entry["lift"])
	var center_plane := _center_of_flat_top(axial, edge_px)
	var cell_root := Node2D.new()
	cell_root.name = "water_%s" % str(axial)
	cell_root.position = entry["pos"] as Vector2
	cell_root.z_index = order_index * 32
	_map_root.add_child(cell_root)

	var recess_screen := InkMonRender2DIsoProjection.height_to_screen(
		float(_manifest["water_recess_world"]) * px_per_unit, pitch)
	var surface_offset := recess_screen - lift
	# 图边河口截面：从本格水面直落到全图统一的世界底面
	var world_bottom := InkMonRender2DIsoProjection.height_to_screen(
		float(_manifest["thickness_world"]) * px_per_unit, pitch)
	for edge_variant in (entry["mouth_faces"] as Array):
		var edge_index := int(edge_variant)
		_add_face_quad(cell_root, center_plane, edge_index, edge_px, ground,
				surface_offset, world_bottom, "face_%d" % edge_index)
	# 瀑布截面：从本格水面落到低位邻格水面
	for fall_variant in (entry["fall_faces"] as Array):
		var fall := fall_variant as Dictionary
		var n_lift := InkMonRender2DIsoProjection.height_to_screen(
			float(int(fall["n_elevation"])) * elevation_step_px, pitch)
		var edge_index := int(fall["edge"])
		_add_face_quad(cell_root, center_plane, edge_index, edge_px, ground,
				surface_offset, recess_screen - n_lift, "fall_%d" % edge_index)

	var surface := Polygon2D.new()
	surface.name = "surface"
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	for i in 6:
		points.append(ground * _hex_corner(i, edge_px) + Vector2(0.0, surface_offset))
		uvs.append(center_plane + _hex_corner(i, edge_px))
	surface.polygon = points
	surface.uv = uvs
	surface.texture = _water_uv_texture
	surface.material = _water_materials[elevation] as ShaderMaterial
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


## 竖直截面 quad（河口 / 瀑布共用）：top_offset/bottom_offset 为相对格中心的屏幕纵向偏移。
func _add_face_quad(cell_root: Node2D, center_plane: Vector2, edge_index: int, edge_px: float, ground: Transform2D, top_offset: float, bottom_offset: float, node_name: String) -> void:
	var face_height := bottom_offset - top_offset
	if face_height <= 0.5:
		return
	var corner_a := _hex_corner(edge_index, edge_px)
	var corner_b := _hex_corner((edge_index + 1) % 6, edge_px)
	var screen_a := ground * corner_a + Vector2(0.0, top_offset)
	var screen_b := ground * corner_b + Vector2(0.0, top_offset)
	var face := Polygon2D.new()
	face.name = node_name
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
	face.material = _get_face_material(face_height)
	face.z_index = 0
	cell_root.add_child(face)


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
		push_error("water_scene: capture failed %s viewport texture is null" % target_path)
		return false
	var image := viewport_texture.get_image()
	if image == null:
		push_error("water_scene: capture failed %s viewport image is null" % target_path)
		return false
	var err := image.save_png(target_path)
	if err != OK:
		push_error("water_scene: capture failed %s err=%d" % [target_path, err])
		return false
	return true
