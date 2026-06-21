extends Node2D

const FORMAL_MANIFEST_PATH := "res://inkmon美术探索/fable-圆角-v1/assets/baked/manifest.json"
const OUTPUT_DIR_REL := "blender/textures/_candidates/tile-pipeline-seam-prototype-20260617-01"
const INPUT_DIR_REL := "docs/美术素材制作探索/原始候选完整归档/02_Godot拼接缝_当前最佳参数_完整候选"
const SEAM_GEOMETRY_PATH := "res://docs/美术素材制作探索/原始候选完整归档/02_Godot拼接缝_当前最佳参数_完整候选/seam_geometry.json"
const SQRT3 := sqrt(3.0)
const PAPER_COLOR := Color(0.93, 0.91, 0.86)
const TARGET_SIZE := Vector2i(1600, 1000)
const TILE_RADIUS := 2
const TILE_NAMES: Array[String] = [
	"tile_01_grass_meadow",
	"tile_02_cracked_dry_earth",
	"tile_03_mossy_flagstone",
	"tile_04_dirt_arena",
	"tile_05_pale_limestone",
	"tile_06_dark_forest_floor",
]
const ROUNDS: Array[Dictionary] = [
	{
		"id": 1,
		"slug": "wide-dark-outline",
		"shadow_width_px": 9.0,
		"shadow_alpha": 0.28,
		"core_width_px": 3.2,
		"core_alpha": 0.55,
		"highlight_width_px": 1.9,
		"highlight_alpha": 0.26,
		"highlight_offset_px": 1.8,
		"endpoint_trim_px": 0.0,
	},
	{
		"id": 2,
		"slug": "narrower-core",
		"shadow_width_px": 7.5,
		"shadow_alpha": 0.23,
		"core_width_px": 2.3,
		"core_alpha": 0.44,
		"highlight_width_px": 1.5,
		"highlight_alpha": 0.17,
		"highlight_offset_px": 1.6,
		"endpoint_trim_px": 1.0,
	},
	{
		"id": 3,
		"slug": "subtle-catch-light",
		"shadow_width_px": 6.8,
		"shadow_alpha": 0.21,
		"core_width_px": 1.9,
		"core_alpha": 0.38,
		"highlight_width_px": 1.2,
		"highlight_alpha": 0.11,
		"highlight_offset_px": 1.5,
		"endpoint_trim_px": 2.0,
	},
	{
		"id": 4,
		"slug": "final-narrow-seam",
		"shadow_width_px": 6.6,
		"shadow_alpha": 0.24,
		"core_width_px": 1.8,
		"core_alpha": 0.44,
		"highlight_width_px": 1.05,
		"highlight_alpha": 0.12,
		"highlight_offset_px": 1.35,
		"endpoint_trim_px": 2.2,
	},
]

var _manifest: Dictionary = {}
var _map_root: Node2D
var _camera: Camera2D
var _cell_positions: Array[Vector2i] = []
var _tile_assignments: Dictionary = {}
var _outputs: Dictionary = {"save_attempts": [], "start_events": [], "process_events": [], "save_call_count": 0}
var _had_error := false
var _capture_jobs: Array[Dictionary] = []
var _job_index := -1
var _frames_waited := 0


func _ready() -> void:
	RenderingServer.set_default_clear_color(PAPER_COLOR)
	get_viewport().transparent_bg = false
	get_viewport().size = TARGET_SIZE
	_manifest = _load_json_res(FORMAL_MANIFEST_PATH)
	if _manifest.is_empty():
		push_error("candidate seam: manifest load failed")
		get_tree().quit(1)
		return
	_camera = Camera2D.new()
	_camera.name = "Camera"
	add_child(_camera)
	_camera.make_current()
	_prepare_cells()
	if _should_capture_all():
		_prepare_capture_jobs()
		_start_next_capture_job()
		return
	var display_config := _display_config()
	if not _is_display_only() and display_config.is_empty():
		display_config = ROUNDS.back()
	_write_display_debug(display_config)
	_rebuild(display_config)
	set_process(false)


func _is_display_only() -> bool:
	return OS.get_environment("INKMON_SEAM_DISPLAY_ONLY") == "1"


func _should_capture_all() -> bool:
	return OS.get_environment("INKMON_SEAM_CAPTURE_ALL") == "1"


func _display_config() -> Dictionary:
	var round_id := int(OS.get_environment("INKMON_SEAM_ROUND"))
	for round_config in ROUNDS:
		if int(round_config["id"]) == round_id:
			return round_config
	return {}


func _write_display_debug(display_config: Dictionary) -> void:
	var out_dir := _output_dir_abs()
	var path := out_dir.path_join("logs").path_join("display_args_debug.json")
	_write_json_abs(path, {
		"args": OS.get_cmdline_user_args(),
		"env_round": OS.get_environment("INKMON_SEAM_ROUND"),
		"config": display_config,
		"has_config": not display_config.is_empty(),
	})


func _process(_delta: float) -> void:
	if _job_index < 0 or _job_index >= _capture_jobs.size():
		return
	_frames_waited += 1
	if _frames_waited < 3:
		return
	var job := _capture_jobs[_job_index]
	var output_paths: Array = job["outputs"]
	var process_events := _outputs["process_events"] as Array
	process_events.append({
		"job_index": _job_index,
		"frames_waited": _frames_waited,
		"output_count": output_paths.size(),
		"outputs": output_paths,
	})
	for output_path in output_paths:
		_outputs["save_call_count"] = int(_outputs["save_call_count"]) + 1
		_save_viewport_png(str(output_path))
	_start_next_capture_job()


func _prepare_capture_jobs() -> void:
	var out_dir := _output_dir_abs()
	_ensure_dir(out_dir)
	_ensure_dir(out_dir.path_join("iterations"))
	var baseline := out_dir.path_join("map_no_seam_baseline.png")
	_outputs["baseline"] = baseline
	var iteration_outputs: Array[Dictionary] = []
	_capture_jobs.append({
		"config": {},
		"outputs": [baseline],
	})
	for round_config in ROUNDS:
		var round_id := int(round_config["id"])
		var slug := str(round_config["slug"])
		var path := out_dir.path_join("iterations").path_join("round_%02d_%s_godot.png" % [round_id, slug])
		iteration_outputs.append({
			"round": round_id,
			"slug": slug,
			"output": path,
			"params": round_config,
		})
		var output_paths: Array[String] = [path]
		if round_id == int(ROUNDS.back()["id"]):
			var final_path := out_dir.path_join("map_godot_seam_preview.png")
			output_paths.append(final_path)
			_outputs["preview"] = final_path
		_capture_jobs.append({
			"config": round_config,
			"outputs": output_paths,
		})
	_outputs["iterations"] = iteration_outputs
	_outputs["tile_count"] = _cell_positions.size()
	_outputs["shared_edge_count"] = _shared_edges().size()
	_outputs["job_count_after_prepare"] = _capture_jobs.size()


func _start_next_capture_job() -> void:
	_job_index += 1
	var start_events := _outputs["start_events"] as Array
	start_events.append({"job_index": _job_index, "job_count": _capture_jobs.size()})
	if _job_index >= _capture_jobs.size():
		var out_dir := _output_dir_abs()
		_write_json_abs(out_dir.path_join("logs").path_join("godot_preview_outputs.json"), _outputs)
		get_tree().quit(1 if _had_error else 0)
		return
	var job := _capture_jobs[_job_index]
	_rebuild(job["config"] as Dictionary)
	_frames_waited = 0


func _rebuild(seam_config: Dictionary) -> void:
	if _map_root != null:
		_map_root.queue_free()
	_map_root = Node2D.new()
	_map_root.name = "CandidateMapRoot"
	add_child(_map_root)
	var entries := _build_entries()
	for i in entries.size():
		var entry := entries[i]
		var sprite := _make_sprite(str(entry["asset"]))
		sprite.name = "%s_%d" % [str(entry["asset"]), i]
		sprite.position = entry["pos"] as Vector2
		_map_root.add_child(sprite)
	_fit_camera()
	if not seam_config.is_empty():
		_add_seams(seam_config)
	if OS.get_environment("INKMON_SEAM_DEBUG_SHARED_RED") == "1":
		var shared_width := 8.0 / maxf(_camera.zoom.x, 0.001)
		for edge in _shared_edges():
			var points := edge["points"] as Array
			_add_line(points[0] as Vector2, points[1] as Vector2, shared_width, Color(1.0, 0.0, 0.0, 1.0))
	if OS.get_environment("INKMON_SEAM_DEBUG_RED") == "1":
		var debug_width := 12.0 / maxf(_camera.zoom.x, 0.001)
		_add_line(Vector2(-420.0, 0.0), Vector2(420.0, 0.0), debug_width, Color(1.0, 0.0, 0.0, 1.0))


func _prepare_cells() -> void:
	_cell_positions.clear()
	_tile_assignments.clear()
	var ordered: Array[Vector2i] = []
	for q in range(-TILE_RADIUS, TILE_RADIUS + 1):
		var r_min := maxi(-TILE_RADIUS, -q - TILE_RADIUS)
		var r_max := mini(TILE_RADIUS, -q + TILE_RADIUS)
		for r in range(r_min, r_max + 1):
			ordered.append(Vector2i(q, r))
	ordered.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x)
	for i in ordered.size():
		var axial := ordered[i]
		_cell_positions.append(axial)
		_tile_assignments[axial] = TILE_NAMES[i % TILE_NAMES.size()]


func _build_entries() -> Array[Dictionary]:
	var pitch := float(_manifest["pitch_deg"])
	var yaw := float(_manifest["yaw_deg"])
	var edge_px := float(_manifest["px_per_hex_edge"])
	var ground := InkMonRender2DIsoProjection.ground_basis(pitch, yaw)
	var entries: Array[Dictionary] = []
	for axial in _cell_positions:
		var center_plane := _center_of_flat_top(axial, edge_px)
		var ground_screen := ground * center_plane
		entries.append({
			"sort": Vector2(ground_screen.x, ground_screen.y),
			"order": 0,
			"asset": str(_tile_assignments[axial]),
			"pos": ground_screen,
			"axial": axial,
		})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sa := a["sort"] as Vector2
		var sb := b["sort"] as Vector2
		if sa.y != sb.y:
			return sa.y < sb.y
		if sa.x != sb.x:
			return sa.x < sb.x
		return int(a["order"]) < int(b["order"]))
	return entries


func _center_of_flat_top(axial: Vector2i, edge_px: float) -> Vector2:
	return Vector2(1.5 * float(axial.x), SQRT3 * (float(axial.y) + float(axial.x) * 0.5)) * edge_px


func _hex_corners_plane(axial: Vector2i) -> Array[Vector2]:
	var edge_px := float(_manifest["px_per_hex_edge"])
	var center := _center_of_flat_top(axial, edge_px)
	var corners: Array[Vector2] = []
	for i in range(6):
		var angle := deg_to_rad(60.0 * float(i))
		corners.append(center + Vector2(cos(angle), sin(angle)) * edge_px)
	return corners


func _make_sprite(asset_name: String) -> Sprite2D:
	var image_path := _input_dir_abs().path_join("assets").path_join("baked_tiles").path_join(asset_name + "_baked.png")
	var image := Image.new()
	var err := image.load(image_path)
	if err != OK:
		push_error("candidate seam: image load failed %s" % image_path)
		_had_error = true
	var texture := ImageTexture.create_from_image(image)
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = true
	sprite.offset = Vector2.ZERO
	return sprite


func _fit_camera() -> void:
	var rect := Rect2()
	var first := true
	for child in _map_root.get_children():
		var sprite := child as Sprite2D
		if sprite == null:
			continue
		if first:
			rect = Rect2(sprite.position, Vector2.ZERO)
			first = false
		else:
			rect = rect.expand(sprite.position)
	var pad := float(_manifest["px_per_hex_edge"]) * 2.2
	rect = rect.grow(pad)
	var vp := Vector2(TARGET_SIZE)
	var zoom := minf(vp.x / rect.size.x, vp.y / rect.size.y)
	_camera.position = rect.get_center()
	_camera.zoom = Vector2(zoom, zoom)


func _add_seams(seam_config: Dictionary) -> void:
	var zoom := maxf(_camera.zoom.x, 0.001)
	var shadow_width := float(seam_config["shadow_width_px"]) / zoom
	var core_width := float(seam_config["core_width_px"]) / zoom
	var highlight_width := float(seam_config["highlight_width_px"]) / zoom
	var highlight_offset := float(seam_config["highlight_offset_px"]) / zoom
	var trim := float(seam_config["endpoint_trim_px"]) / zoom
	var shadow_color := Color(0.02, 0.025, 0.022, float(seam_config["shadow_alpha"]))
	var core_color := Color(0.015, 0.018, 0.016, float(seam_config["core_alpha"]))
	var highlight_color := Color(1.0, 0.92, 0.70, float(seam_config["highlight_alpha"]))
	var light_dir := Vector2(-0.55, -0.35).normalized()
	for edge in _shared_edges():
		var points := edge["points"] as Array
		var start := points[0] as Vector2
		var end := points[1] as Vector2
		var delta := end - start
		if delta.length() <= trim * 2.0:
			continue
		var unit := delta.normalized()
		var a := start + unit * trim
		var b := end - unit * trim
		_add_line(a, b, shadow_width, shadow_color)
		_add_line(a, b, core_width, core_color)
		var normal := Vector2(-unit.y, unit.x)
		if normal.dot(light_dir) < 0.0:
			normal = -normal
		if normal.dot(light_dir) >= 0.14:
			_add_line(a + normal * highlight_offset, b + normal * highlight_offset, highlight_width, highlight_color)


func _add_line(start: Vector2, end: Vector2, width: float, color: Color) -> void:
	var line := Line2D.new()
	line.points = PackedVector2Array([start, end])
	line.width = width
	line.default_color = color
	line.antialiased = true
	line.z_index = 20
	_map_root.add_child(line)


func _shared_edges() -> Array[Dictionary]:
	var baked_geometry := _shared_edges_from_geometry_file()
	if not baked_geometry.is_empty():
		return baked_geometry
	var pitch := float(_manifest["pitch_deg"])
	var yaw := float(_manifest["yaw_deg"])
	var ground := InkMonRender2DIsoProjection.ground_basis(pitch, yaw)
	var cell_set: Dictionary = {}
	for axial in _cell_positions:
		cell_set[_axial_key(axial)] = true
	var edge_specs: Array[Dictionary] = [
		{"dq": 1, "dr": 0, "corner": 0},
		{"dq": 0, "dr": 1, "corner": 1},
		{"dq": -1, "dr": 1, "corner": 2},
	]
	var edges: Array[Dictionary] = []
	for axial in _cell_positions:
		var corners := _hex_corners_plane(axial)
		for spec in edge_specs:
			var neighbor := Vector2i(axial.x + int(spec["dq"]), axial.y + int(spec["dr"]))
			if not cell_set.has(_axial_key(neighbor)):
				continue
			var idx := int(spec["corner"])
			var p0 := corners[idx]
			var p1 := corners[(idx + 1) % 6]
			edges.append({"points": [ground * p0, ground * p1]})
	return edges


func _shared_edges_from_geometry_file() -> Array[Dictionary]:
	var data := _load_json_res(SEAM_GEOMETRY_PATH)
	if data.is_empty():
		return []
	var raw_edges: Array = data.get("edges", []) as Array
	var edges: Array[Dictionary] = []
	for raw_edge in raw_edges:
		if not raw_edge is Dictionary:
			continue
		var raw_points: Array = (raw_edge as Dictionary).get("points", []) as Array
		if raw_points.size() != 2:
			continue
		var p0: Array = raw_points[0] as Array
		var p1: Array = raw_points[1] as Array
		if p0.size() != 2 or p1.size() != 2:
			continue
		edges.append({
			"points": [
				Vector2(float(p0[0]), float(p0[1])),
				Vector2(float(p1[0]), float(p1[1])),
			],
		})
	return edges


func _axial_key(axial: Vector2i) -> String:
	return "%d,%d" % [axial.x, axial.y]


func _edge_key(p0: Vector2, p1: Vector2) -> String:
	var a := _point_key(p0)
	var b := _point_key(p1)
	if a < b:
		return "%s|%s" % [a, b]
	return "%s|%s" % [b, a]


func _point_key(point: Vector2) -> String:
	return "%d,%d" % [roundi(point.x * 100.0), roundi(point.y * 100.0)]


func _save_viewport_png(path: String) -> void:
	var image := get_viewport().get_texture().get_image()
	if image.get_width() <= 0 or image.get_height() <= 0:
		push_error("candidate seam: viewport capture is empty for %s" % path)
		_record_save_attempt({"path": path, "error": "empty_image"})
		_had_error = true
		return
	var buffer := image.save_png_to_buffer()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("candidate seam: open png failed %s" % path)
		_record_save_attempt({"path": path, "error": "open_failed", "open_error": FileAccess.get_open_error()})
		_had_error = true
		return
	file.store_buffer(buffer)
	file.close()
	_record_save_attempt({
		"path": path,
		"buffer_size": buffer.size(),
		"exists_after": FileAccess.file_exists(path),
	})
	if not FileAccess.file_exists(path):
		push_error("candidate seam: save failed %s" % path)
		_had_error = true


func _record_save_attempt(entry: Dictionary) -> void:
	var attempts: Array = _outputs.get("save_attempts", [])
	attempts.append(entry)
	_outputs["save_attempts"] = attempts


func _load_json_res(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {}
	var data: Variant = JSON.parse_string(text)
	if data is Dictionary:
		return data as Dictionary
	return {}


func _write_json_abs(path: String, data: Dictionary) -> void:
	_ensure_dir(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("candidate seam: json write failed %s" % path)
		_had_error = true
		return
	file.store_string(JSON.stringify(data, "\t"))


func _output_dir_abs() -> String:
	return ProjectSettings.globalize_path("res://" + OUTPUT_DIR_REL)


func _input_dir_abs() -> String:
	return ProjectSettings.globalize_path("res://" + INPUT_DIR_REL)


func _ensure_dir(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path)
