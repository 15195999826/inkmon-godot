class_name InkMonArtTileMapBase
extends Node2D

## Shared programmatic art-map explorer for tile pipeline variants.
## It intentionally reuses the fable manifest/camera contract so screenshots are comparable.

enum RenderMode {
	HARD_EDGE,
	BEVELED,
	PATCH,
}

const DEFAULT_BAKED_DIR := "res://inkmon美术探索/fable-圆角-v1/assets/baked/"
const SQRT3 := sqrt(3.0)
const PAPER_COLOR := Color(0.93, 0.91, 0.86)
const INK_COLOR := Color(0.12, 0.09, 0.06, 0.92)
const SOFT_INK_COLOR := Color(0.22, 0.17, 0.10, 0.72)

@export var render_mode := RenderMode.HARD_EDGE
@export var scene_title := "codex art tile map"
@export var ink_enabled := true
@export var decor_enabled := true
@export var decor_density := 0.85
@export var baked_dir := DEFAULT_BAKED_DIR

var _manifest: Dictionary = {}
var _map_root: Node2D
var _camera: Camera2D
var _tile_count := 0
var _decor_count := 0


func _ready() -> void:
	RenderingServer.set_default_clear_color(PAPER_COLOR)
	_manifest = _load_manifest()
	if _manifest.is_empty():
		push_error("art_tile_map: manifest load failed %s" % _manifest_path())
		return

	_camera = Camera2D.new()
	_camera.name = "Camera"
	add_child(_camera)
	_camera.make_current()
	_rebuild()
	call_deferred("_capture_if_requested")


func _rebuild() -> void:
	if _map_root != null:
		_map_root.queue_free()
	_map_root = Node2D.new()
	_map_root.name = "MapRoot"
	add_child(_map_root)
	_tile_count = 0
	_decor_count = 0

	var tiles := InkMonIsoSandboxDemoMap.generate()
	var entries: Array[Dictionary] = []
	var pitch := float(_manifest["pitch_deg"])
	var yaw := float(_manifest["yaw_deg"])
	var edge_px := float(_manifest["px_per_hex_edge"])
	var px_per_unit := float(_manifest["px_per_unit"])
	var elevation_step_px := float(_manifest["elevation_step_world"]) * px_per_unit
	var ground := InkMonRender2DIsoProjection.ground_basis(pitch, yaw)

	var rng := RandomNumberGenerator.new()
	rng.seed = 20260619

	for key in tiles.keys():
		var axial := key as Vector2i
		var info := tiles[axial] as Dictionary
		var center_plane := _center_of_flat_top(axial, edge_px)
		var ground_screen := ground * center_plane
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

		var decor := _pick_decor(info, rng)
		if decor != "":
			var jitter := Vector2.ZERO
			if decor != "decor_pine" and decor != "decor_pine_tall":
				jitter = Vector2(rng.randf_range(-0.28, 0.28), rng.randf_range(-0.28, 0.28)) * edge_px
			entries.append({
				"sort": Vector2(ground_screen.x, ground_screen.y),
				"order": 1,
				"kind": "decor",
				"asset": decor,
				"axial": axial,
				"pos": ground * (center_plane + jitter) - Vector2(0.0, lift),
			})
			_decor_count += 1

	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sort_a := a["sort"] as Vector2
		var sort_b := b["sort"] as Vector2
		if sort_a.y != sort_b.y:
			return sort_a.y < sort_b.y
		if sort_a.x != sort_b.x:
			return sort_a.x < sort_b.x
		return int(a["order"]) < int(b["order"])
	)

	for i in entries.size():
		var entry := entries[i]
		if str(entry["kind"]) == "tile":
			_add_tile_entry(entry, i)
		else:
			_add_decor_entry(entry, i)

	_fit_camera()


func _add_tile_entry(entry: Dictionary, order_index: int) -> void:
	var axial := entry["axial"] as Vector2i
	var info := entry["info"] as Dictionary
	if render_mode == RenderMode.PATCH:
		var patch := _make_patch_sprite(info, axial)
		if patch == null:
			return
		patch.name = "patch_%s_%d" % [str(info["terrain"]), order_index]
		patch.position = entry["pos"] as Vector2 - Vector2(0.0, float(entry["lift"]))
		patch.z_index = order_index * 32
		_map_root.add_child(patch)
		return

	var cell_root := Node2D.new()
	cell_root.name = "tile_%s_e%d_%s" % [str(info["terrain"]), int(info["elevation"]), str(axial)]
	cell_root.position = entry["pos"] as Vector2
	cell_root.z_index = order_index * 32
	_map_root.add_child(cell_root)
	_draw_programmatic_tile(cell_root, info, axial, float(entry["lift"]))


func _add_decor_entry(entry: Dictionary, order_index: int) -> void:
	if render_mode != RenderMode.PATCH:
		return
	var sprite := _make_sprite(str(entry["asset"]), entry["axial"] as Vector2i)
	if sprite == null:
		return
	sprite.name = "%s_%d" % [str(entry["asset"]), order_index]
	sprite.position = entry["pos"] as Vector2
	sprite.z_index = order_index * 32
	_map_root.add_child(sprite)


func _draw_programmatic_tile(cell_root: Node2D, info: Dictionary, axial: Vector2i, lift: float) -> void:
	var pitch := float(_manifest["pitch_deg"])
	var yaw := float(_manifest["yaw_deg"])
	var edge_px := float(_manifest["px_per_hex_edge"])
	var px_per_unit := float(_manifest["px_per_unit"])
	var ground := InkMonRender2DIsoProjection.ground_basis(pitch, yaw)
	var thickness_px := (float(_manifest["thickness_world"]) + float(info["elevation"]) * float(_manifest["elevation_step_world"])) * px_per_unit
	var depth_screen := InkMonRender2DIsoProjection.height_to_screen(thickness_px, pitch)
	var terrain := str(info["terrain"])
	var palette := _terrain_palette(terrain)
	var top_color := palette["top"] as Color
	var side_color := palette["side"] as Color

	var top_points := PackedVector2Array()
	for i in 6:
		top_points.append(ground * _hex_corner(i, edge_px) - Vector2(0.0, lift))

	var visible_edges := _visible_edge_indices(top_points)
	for edge_index in visible_edges:
		var next_index := (edge_index + 1) % top_points.size()
		var shade := 0.72 + 0.12 * float(visible_edges.find(edge_index))
		var face_points := PackedVector2Array([
			top_points[edge_index],
			top_points[next_index],
			top_points[next_index] + Vector2(0.0, depth_screen),
			top_points[edge_index] + Vector2(0.0, depth_screen),
		])
		_add_polygon(cell_root, "wall_%d" % edge_index, face_points, _shade_color(side_color, shade), 0)
		_add_wall_detail(cell_root, face_points, terrain, axial, edge_index)
		if ink_enabled:
			_add_polyline(cell_root, face_points, SOFT_INK_COLOR, 1.6, true, 3)

	if render_mode == RenderMode.BEVELED:
		_draw_beveled_top(cell_root, top_points, top_color, terrain, axial)
	else:
		_add_polygon(cell_root, "top", top_points, top_color, 5)
		_add_top_detail(cell_root, top_points, terrain, axial)
		if ink_enabled:
			_add_polyline(cell_root, top_points, INK_COLOR, 2.2, true, 8)


func _draw_beveled_top(cell_root: Node2D, outer_points: PackedVector2Array, top_color: Color, terrain: String, axial: Vector2i) -> void:
	var center := _average_point(outer_points)
	var inner_points := PackedVector2Array()
	for point in outer_points:
		inner_points.append(center + (point - center) * 0.86)

	for i in outer_points.size():
		var next_index := (i + 1) % outer_points.size()
		var bevel_points := PackedVector2Array([
			outer_points[i],
			outer_points[next_index],
			inner_points[next_index],
			inner_points[i],
		])
		var shade := 0.82 if i in _visible_edge_indices(outer_points) else 1.12
		_add_polygon(cell_root, "bevel_%d" % i, bevel_points, _shade_color(top_color, shade), 6)

	_add_polygon(cell_root, "top_inner", inner_points, _shade_color(top_color, 1.04), 7)
	_add_top_detail(cell_root, inner_points, terrain, axial)
	if ink_enabled:
		_add_polyline(cell_root, outer_points, INK_COLOR, 2.0, true, 10)
		_add_polyline(cell_root, inner_points, SOFT_INK_COLOR, 1.2, true, 11)


func _add_top_detail(cell_root: Node2D, points: PackedVector2Array, terrain: String, axial: Vector2i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(abs(axial.x * 928371 + axial.y * 128713 + terrain.hash()))
	var count := 5
	match terrain:
		InkMonIsoSandboxDemoMap.TERRAIN_WATER:
			count = 4
		InkMonIsoSandboxDemoMap.TERRAIN_STONE:
			count = 7
		InkMonIsoSandboxDemoMap.TERRAIN_DIRT:
			count = 6
		_:
			count = 8

	var center := _average_point(points)
	for _i in count:
		var p := center + Vector2(rng.randf_range(-58.0, 58.0), rng.randf_range(-25.0, 25.0))
		match terrain:
			InkMonIsoSandboxDemoMap.TERRAIN_WATER:
				_add_polyline(cell_root, PackedVector2Array([p + Vector2(-14.0, 0.0), p + Vector2(14.0, -2.0)]), Color(0.80, 0.95, 1.0, 0.35), 1.4, false, 20)
			InkMonIsoSandboxDemoMap.TERRAIN_STONE:
				_add_polygon(cell_root, "stone_chip", _small_diamond(p, rng.randf_range(5.0, 9.0)), Color(0.74, 0.71, 0.62, 0.58), 20)
			_:
				_add_polyline(cell_root, PackedVector2Array([p + Vector2(-4.0, 2.0), p, p + Vector2(4.0, 2.0)]), Color(0.18, 0.28, 0.12, 0.45), 1.3, false, 20)


func _add_wall_detail(cell_root: Node2D, face_points: PackedVector2Array, terrain: String, axial: Vector2i, edge_index: int) -> void:
	if terrain == InkMonIsoSandboxDemoMap.TERRAIN_WATER:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(abs(axial.x * 43711 + axial.y * 97139 + edge_index * 513))
	var top_a := face_points[0]
	var top_b := face_points[1]
	var bottom_b := face_points[2]
	var bottom_a := face_points[3]
	for row in 2:
		var t := (float(row) + 1.0) / 3.0
		var left := top_a.lerp(bottom_a, t)
		var right := top_b.lerp(bottom_b, t)
		_add_polyline(cell_root, PackedVector2Array([left, right]), Color(0.10, 0.08, 0.05, 0.28), 1.0, false, 2)
	for col in 3:
		var t := (float(col) + rng.randf_range(0.65, 1.25)) / 4.0
		var upper := top_a.lerp(top_b, t)
		var lower := bottom_a.lerp(bottom_b, t)
		_add_polyline(cell_root, PackedVector2Array([upper, lower]), Color(0.12, 0.09, 0.06, 0.20), 0.9, false, 2)


func _make_patch_sprite(info: Dictionary, axial: Vector2i) -> Sprite2D:
	var asset_name := "tile_%s_e%d" % [str(info["terrain"]), int(info["elevation"])]
	return _make_sprite(asset_name, axial)


func _make_sprite(asset_name: String, axial: Vector2i) -> Sprite2D:
	var assets := _manifest["assets"] as Dictionary
	if not assets.has(asset_name):
		push_error("art_tile_map: missing asset %s" % asset_name)
		return null
	var meta := assets[asset_name] as Dictionary
	var variants: Array = meta.get("variants", [meta["file"]]) as Array
	var pick := posmod((axial.x * 73856093) ^ (axial.y * 19349663), variants.size())
	var texture := load(_normalized_baked_dir() + str(variants[pick])) as Texture2D
	if texture == null:
		push_error("art_tile_map: texture load failed %s" % str(variants[pick]))
		return null
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = true
	var size := meta["size_px"] as Array
	var anchor := meta["anchor_px"] as Array
	sprite.offset = Vector2(float(size[0]) * 0.5 - float(anchor[0]), float(size[1]) * 0.5 - float(anchor[1]))
	return sprite


func _fit_camera() -> void:
	if _tile_count == 0 or _map_root == null:
		return
	var rect := Rect2()
	var first := true
	for child in _map_root.get_children():
		var node := child as Node2D
		if node == null:
			continue
		if first:
			rect = Rect2(node.position, Vector2.ZERO)
			first = false
		else:
			rect = rect.expand(node.position)
	var pad := float(_manifest["px_per_hex_edge"]) * 3.0
	rect = rect.grow(pad)
	var viewport_size := get_viewport_rect().size
	var zoom := minf(viewport_size.x / rect.size.x, viewport_size.y / rect.size.y)
	_camera.position = rect.get_center()
	_camera.zoom = Vector2(zoom, zoom)


func _center_of_flat_top(axial: Vector2i, edge_px: float) -> Vector2:
	return Vector2(1.5 * float(axial.x), SQRT3 * (float(axial.y) + float(axial.x) * 0.5)) * edge_px


func _hex_corner(index: int, edge_px: float) -> Vector2:
	var angle := deg_to_rad(60.0 * float(index))
	return Vector2(cos(angle), sin(angle)) * edge_px


func _visible_edge_indices(points: PackedVector2Array) -> Array[int]:
	var scored: Array[Dictionary] = []
	for i in points.size():
		var next_index := (i + 1) % points.size()
		scored.append({
			"edge_index": i,
			"screen_y": (points[i].y + points[next_index].y) * 0.5,
		})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["screen_y"]) > float(b["screen_y"])
	)
	var visible: Array[int] = []
	for i in mini(3, scored.size()):
		visible.append(int(scored[i]["edge_index"]))
	return visible


func _average_point(points: PackedVector2Array) -> Vector2:
	var total := Vector2.ZERO
	for point in points:
		total += point
	return total / float(points.size())


func _terrain_palette(terrain: String) -> Dictionary:
	match terrain:
		InkMonIsoSandboxDemoMap.TERRAIN_WATER:
			return {
				"top": Color(0.30, 0.48, 0.58),
				"side": Color(0.20, 0.32, 0.40),
			}
		InkMonIsoSandboxDemoMap.TERRAIN_DIRT:
			return {
				"top": Color(0.50, 0.38, 0.24),
				"side": Color(0.34, 0.26, 0.18),
			}
		InkMonIsoSandboxDemoMap.TERRAIN_STONE:
			return {
				"top": Color(0.56, 0.54, 0.47),
				"side": Color(0.37, 0.35, 0.30),
			}
		_:
			return {
				"top": Color(0.45, 0.52, 0.25),
				"side": Color(0.33, 0.27, 0.17),
			}


func _shade_color(color: Color, factor: float) -> Color:
	return Color(
		clampf(color.r * factor, 0.0, 1.0),
		clampf(color.g * factor, 0.0, 1.0),
		clampf(color.b * factor, 0.0, 1.0),
		color.a
	)


func _small_diamond(center: Vector2, radius: float) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(0.0, -radius),
		center + Vector2(radius * 1.35, 0.0),
		center + Vector2(0.0, radius),
		center + Vector2(-radius * 1.35, 0.0),
	])


func _add_polygon(parent: Node, node_name: String, points: PackedVector2Array, color: Color, z_index: int) -> Polygon2D:
	var polygon_node := Polygon2D.new()
	polygon_node.name = node_name
	polygon_node.polygon = points
	polygon_node.color = color
	polygon_node.z_index = z_index
	parent.add_child(polygon_node)
	return polygon_node


func _add_polyline(parent: Node, points: PackedVector2Array, color: Color, width: float, closed: bool, z_index: int) -> Line2D:
	var line := Line2D.new()
	line.default_color = color
	line.width = width
	line.antialiased = true
	line.z_index = z_index
	if closed:
		var closed_points := PackedVector2Array(points)
		closed_points.append(points[0])
		line.points = closed_points
	else:
		line.points = points
	parent.add_child(line)
	return line


func _pick_decor(info: Dictionary, rng: RandomNumberGenerator) -> String:
	if not decor_enabled or render_mode != RenderMode.PATCH:
		return ""
	var terrain := str(info["terrain"])
	if bool(info.get("tree", false)):
		return "decor_pine" if rng.randf() < 0.6 else "decor_pine_tall"
	var roll := rng.randf()
	match terrain:
		InkMonIsoSandboxDemoMap.TERRAIN_GRASS:
			if roll < 0.22 * decor_density:
				return "decor_bush"
			if roll < 0.30 * decor_density:
				return "decor_rocks"
		InkMonIsoSandboxDemoMap.TERRAIN_DIRT:
			if roll < 0.20 * decor_density:
				return "decor_rocks"
			if roll < 0.30 * decor_density:
				return "decor_bush"
		InkMonIsoSandboxDemoMap.TERRAIN_STONE:
			if roll < 0.16 * decor_density:
				return "decor_rocks"
	return ""


func _load_manifest() -> Dictionary:
	var text := FileAccess.get_file_as_string(_manifest_path())
	if text.is_empty():
		return {}
	var data: Variant = JSON.parse_string(text)
	if data is Dictionary:
		return data as Dictionary
	return {}


func _manifest_path() -> String:
	return _normalized_baked_dir() + "manifest.json"


func _normalized_baked_dir() -> String:
	return baked_dir if baked_dir.ends_with("/") else baked_dir + "/"


func _capture_if_requested() -> void:
	var target_path := OS.get_environment("INKMON_ART_CAPTURE_PATH")
	if target_path.is_empty():
		return
	await get_tree().process_frame
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(target_path.get_base_dir())
	var viewport_texture := get_viewport().get_texture()
	if viewport_texture == null:
		push_error("art_tile_map: capture failed %s viewport texture is null" % target_path)
		get_tree().quit(1)
		return
	var image := viewport_texture.get_image()
	if image == null:
		push_error("art_tile_map: capture failed %s viewport image is null" % target_path)
		get_tree().quit(1)
		return
	var err := image.save_png(target_path)
	if err != OK:
		push_error("art_tile_map: capture failed %s err=%d" % [target_path, err])
		get_tree().quit(1)
		return
	get_tree().quit(0)


func get_debug_state() -> Dictionary:
	return {
		"node_type": "InkMonArtTileMapBase",
		"scene_title": scene_title,
		"render_mode": render_mode,
		"tile_count": _tile_count,
		"decor_count": _decor_count,
		"decor_enabled": decor_enabled,
		"pitch_deg": float(_manifest.get("pitch_deg", 0.0)),
		"yaw_deg": float(_manifest.get("yaw_deg", 0.0)),
		"camera_zoom": _camera.zoom.x if _camera != null else 0.0,
	}
