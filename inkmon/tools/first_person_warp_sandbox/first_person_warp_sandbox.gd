class_name InkMonFirstPersonWarpSandbox
extends Control

## First-person 2D floor-warp sandbox.
## Scope: technical proof only. It does not touch main-game logic, hex grid, or
## the production overworld/battle renderer.

const LOOP_SECONDS := 10.0
const CAPTURE_FPS := 30
const CAPTURE_WIDTH := 1280
const CAPTURE_HEIGHT := 720

const FLOOR_SHADER_PATH := "res://inkmon/tools/first_person_warp_sandbox/first_person_floor.gdshader"
const ROAD_TEXTURE_PATH := "res://inkmon/tools/first_person_warp_sandbox/assets/road_strip_ai.png"
const HORIZON_TEXTURE_PATH := "res://inkmon/tools/first_person_warp_sandbox/assets/horizon_plate_ai.png"
const HAND_TEXTURE_PATH := "res://inkmon/tools/first_person_warp_sandbox/assets/hand_overlay_ai.png"
const PROP_TEXTURE_PATH := "res://inkmon/tools/first_person_warp_sandbox/assets/roadside_tree_ai.png"

var horizon_y := 0.60
var fov_scale := 0.88
var road_texture_scale := 0.09
var texture_v_scale := 0.075
var curve_strength := 0.015
var lateral_sway := 0.035
var scroll_repeats := 2.0
var show_debug_overlay := true

var _time_seconds := 0.0
var _floor_material: ShaderMaterial
var _floor_rect: ColorRect
var _horizon_rect: TextureRect
var _hand_rect: TextureRect
var _prop_layer: Control
var _prop_sprites: Array[TextureRect] = []
var _readout: Label
var _ui_panel: PanelContainer

var _capture_enabled := false
var _capture_output_dir := ""
var _capture_frames := 0
var _capture_start_frame := 0
var _smoke_enabled := false


func _ready() -> void:
	var args := _parse_user_args()
	_capture_enabled = args.has("capture_dir")
	_smoke_enabled = args.has("smoke")
	if _capture_enabled:
		show_debug_overlay = args.has("debug_overlay")
		_capture_output_dir = _globalize_path(str(args["capture_dir"]))
		_capture_frames = int(args.get("capture_frames", int(LOOP_SECONDS * float(CAPTURE_FPS))))
		_capture_start_frame = int(args.get("capture_start_frame", 0))
		get_window().size = Vector2i(CAPTURE_WIDTH, CAPTURE_HEIGHT)
		custom_minimum_size = Vector2(float(CAPTURE_WIDTH), float(CAPTURE_HEIGHT))
	elif args.has("no_debug"):
		show_debug_overlay = false

	_build_scene()
	_apply_time(0.0)
	print("FIRST_PERSON_WARP_SANDBOX_READY: %s" % JSON.stringify(get_debug_state()))

	if _capture_enabled:
		call_deferred("_run_capture")
	elif _smoke_enabled:
		call_deferred("_run_smoke")


func _process(delta: float) -> void:
	if _capture_enabled or _smoke_enabled:
		return
	_apply_time(_time_seconds + delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_layout()
		queue_redraw()


func get_debug_state() -> Dictionary:
	return {
		"node_type": "InkMonFirstPersonWarpSandbox",
		"horizon_y": horizon_y,
		"fov_scale": fov_scale,
		"road_texture_scale": road_texture_scale,
		"texture_v_scale": texture_v_scale,
		"curve_strength": curve_strength,
		"scroll_repeats": scroll_repeats,
		"loop_seconds": LOOP_SECONDS,
		"prop_count": _prop_sprites.size(),
		"debug_overlay": show_debug_overlay,
	}


func _build_scene() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_horizon_rect = TextureRect.new()
	_horizon_rect.name = "HorizonPlate"
	_horizon_rect.texture = load(HORIZON_TEXTURE_PATH) as Texture2D
	_horizon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_horizon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_horizon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_horizon_rect)

	_floor_rect = ColorRect.new()
	_floor_rect.name = "WarpedFloor"
	_floor_rect.color = Color.WHITE
	_floor_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_floor_material = ShaderMaterial.new()
	_floor_material.shader = load(FLOOR_SHADER_PATH) as Shader
	_floor_material.set_shader_parameter("floor_texture", load(ROAD_TEXTURE_PATH) as Texture2D)
	_floor_rect.material = _floor_material
	add_child(_floor_rect)

	_prop_layer = Control.new()
	_prop_layer.name = "BillboardProps"
	_prop_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prop_layer)
	_build_props()

	_hand_rect = TextureRect.new()
	_hand_rect.name = "ForegroundHand"
	_hand_rect.texture = load(HAND_TEXTURE_PATH) as Texture2D
	_hand_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hand_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_hand_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hand_rect)

	_build_ui()
	_update_shader_params()
	_update_layout()


func _build_props() -> void:
	var prop_texture := load(PROP_TEXTURE_PATH) as Texture2D
	for i in range(8):
		var prop := TextureRect.new()
		prop.name = "RoadsideProp%d" % i
		prop.texture = prop_texture
		prop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		prop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		prop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_prop_layer.add_child(prop)
		_prop_sprites.append(prop)


func _build_ui() -> void:
	_ui_panel = PanelContainer.new()
	_ui_panel.name = "DebugPanel"
	_ui_panel.visible = not _capture_enabled
	_ui_panel.position = Vector2(12.0, 12.0)
	add_child(_ui_panel)

	var box := VBoxContainer.new()
	_ui_panel.add_child(box)

	_readout = Label.new()
	_readout.name = "Readout"
	box.add_child(_readout)

	_add_slider(box, "horizon", 0.32, 0.68, horizon_y, func(value: float) -> void:
		horizon_y = value
		_update_shader_params()
	)
	_add_slider(box, "fov", 0.45, 1.45, fov_scale, func(value: float) -> void:
		fov_scale = value
		_update_shader_params()
	)
	_add_slider(box, "road scale", 0.025, 0.11, road_texture_scale, func(value: float) -> void:
		road_texture_scale = value
		_update_shader_params()
	)
	_add_slider(box, "curve", -0.05, 0.05, curve_strength, func(value: float) -> void:
		curve_strength = value
		_update_shader_params()
	)

	var debug_toggle := CheckButton.new()
	debug_toggle.text = "debug overlay"
	debug_toggle.button_pressed = show_debug_overlay
	debug_toggle.toggled.connect(func(enabled: bool) -> void:
		show_debug_overlay = enabled
		queue_redraw()
		_update_readout()
	)
	box.add_child(debug_toggle)

	_update_readout()


func _add_slider(
		parent: Control,
		title: String,
		min_value: float,
		max_value: float,
		initial_value: float,
		on_changed: Callable) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(84.0, 0.0)
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = 0.001
	slider.value = initial_value
	slider.custom_minimum_size = Vector2(220.0, 0.0)
	slider.value_changed.connect(func(value: float) -> void:
		on_changed.call(value)
		_update_readout()
		queue_redraw()
	)
	row.add_child(slider)


func _update_layout() -> void:
	var viewport_size := get_viewport_rect().size
	_fit_full_rect(_horizon_rect, viewport_size)
	_fit_full_rect(_floor_rect, viewport_size)
	_fit_full_rect(_prop_layer, viewport_size)
	_fit_full_rect(_hand_rect, viewport_size)
	_update_layers(_loop_progress())


func _fit_full_rect(control: Control, viewport_size: Vector2) -> void:
	if control == null:
		return
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 0.0
	control.anchor_bottom = 0.0
	control.position = Vector2.ZERO
	control.size = viewport_size


func _update_shader_params() -> void:
	if _floor_material == null:
		return
	_floor_material.set_shader_parameter("horizon_y", horizon_y)
	_floor_material.set_shader_parameter("fov_scale", fov_scale)
	_floor_material.set_shader_parameter("road_texture_scale", road_texture_scale)
	_floor_material.set_shader_parameter("texture_v_scale", texture_v_scale)
	_floor_material.set_shader_parameter("curve_strength", curve_strength)


func _apply_time(next_time_seconds: float) -> void:
	_time_seconds = fposmod(next_time_seconds, LOOP_SECONDS)
	var progress := _loop_progress()
	var scroll := progress * scroll_repeats
	var sway := sin(progress * TAU) * lateral_sway
	if _floor_material != null:
		_floor_material.set_shader_parameter("scroll", scroll)
		_floor_material.set_shader_parameter("sway", sway)
	_update_layers(progress)
	queue_redraw()


func _loop_progress() -> float:
	return _time_seconds / LOOP_SECONDS


func _update_layers(progress: float) -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	if _horizon_rect != null:
		var sky_offset := sin(progress * TAU) * 10.0
		_horizon_rect.position = Vector2(sky_offset - 10.0, 0.0)
		_horizon_rect.size = viewport_size + Vector2(20.0, 0.0)

	for i in range(_prop_sprites.size()):
		var prop := _prop_sprites[i]
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var phase: float = fposmod(progress + float(i) * 0.137, 1.0)
		var approach: float = phase * phase
		var y_pos: float = lerpf(viewport_size.y * (horizon_y + 0.02), viewport_size.y * 1.10, approach)
		var x_offset: float = side * viewport_size.x * lerpf(0.12, 0.48, approach)
		var prop_size: float = lerpf(26.0, 230.0, approach)
		var alpha: float = smoothstep(0.02, 0.16, phase) * (1.0 - smoothstep(0.88, 0.99, phase))
		prop.position = Vector2(viewport_size.x * 0.5 + x_offset - prop_size * 0.5, y_pos - prop_size)
		prop.size = Vector2(prop_size, prop_size * 1.85)
		prop.modulate = Color(1.0, 1.0, 1.0, alpha)

	if _hand_rect != null:
		var hand_sway := Vector2(sin(progress * TAU) * 7.0, cos(progress * TAU * 2.0) * 4.0)
		_hand_rect.position = hand_sway
		_hand_rect.size = viewport_size


func _draw() -> void:
	if not show_debug_overlay:
		return

	var viewport_size := get_viewport_rect().size
	var horizon_px: float = viewport_size.y * horizon_y
	draw_line(Vector2(0.0, horizon_px), Vector2(viewport_size.x, horizon_px), Color(1.0, 0.25, 0.18, 0.88), 2.0)
	draw_line(Vector2(viewport_size.x * 0.5, horizon_px), Vector2(viewport_size.x * 0.5, viewport_size.y), Color(0.95, 0.95, 1.0, 0.45), 1.0)

	for i in range(1, 9):
		var ground_y: float = float(i) / 9.0
		var y_pos: float = lerpf(horizon_px, viewport_size.y, ground_y)
		var depth: float = 0.16 / pow(maxf(ground_y, 0.001), 1.05)
		var half_road: float = (0.12 / maxf(road_texture_scale, 0.001)) / maxf(depth * maxf(fov_scale, 0.001), 0.001)
		half_road = clampf(half_road * viewport_size.x, 18.0, viewport_size.x * 0.48)
		var center_x: float = viewport_size.x * 0.5
		draw_line(Vector2(0.0, y_pos), Vector2(viewport_size.x, y_pos), Color(1.0, 1.0, 1.0, 0.16), 1.0)
		draw_line(Vector2(center_x - half_road, y_pos), Vector2(center_x - half_road * 0.55, y_pos - 26.0), Color(1.0, 0.25, 0.18, 0.55), 1.0)
		draw_line(Vector2(center_x + half_road, y_pos), Vector2(center_x + half_road * 0.55, y_pos - 26.0), Color(1.0, 0.25, 0.18, 0.55), 1.0)


func _update_readout() -> void:
	if _readout == null:
		return
	_readout.text = "First-person floor warp | horizon %.3f | fov %.2f | loop %.1fs" % [
		horizon_y,
		fov_scale,
		LOOP_SECONDS,
	]


func _parse_user_args() -> Dictionary:
	var parsed := {}
	for raw_arg in OS.get_cmdline_user_args():
		var text := str(raw_arg)
		if text == "--smoke":
			parsed["smoke"] = true
		elif text == "--no-debug":
			parsed["no_debug"] = true
		elif text == "--debug-overlay":
			parsed["debug_overlay"] = true
		elif text.begins_with("--capture-dir="):
			parsed["capture_dir"] = text.trim_prefix("--capture-dir=")
		elif text.begins_with("--capture-frames="):
			parsed["capture_frames"] = int(text.trim_prefix("--capture-frames="))
		elif text.begins_with("--capture-start-frame="):
			parsed["capture_start_frame"] = int(text.trim_prefix("--capture-start-frame="))
	return parsed


func _run_smoke() -> void:
	_apply_time(0.0)
	await get_tree().process_frame
	_apply_time(LOOP_SECONDS * 0.5)
	await get_tree().process_frame
	if _floor_material == null or _floor_rect == null or _horizon_rect == null or _hand_rect == null:
		print("SMOKE_TEST_RESULT: FAIL - required layer node missing")
		get_tree().quit(1)
		return
	var road_texture := _floor_material.get_shader_parameter("floor_texture") as Texture2D
	if road_texture == null:
		print("SMOKE_TEST_RESULT: FAIL - floor texture missing")
		get_tree().quit(1)
		return
	if _prop_sprites.size() != 8:
		print("SMOKE_TEST_RESULT: FAIL - expected 8 prop sprites, got %d" % _prop_sprites.size())
		get_tree().quit(1)
		return
	print("SMOKE_TEST_RESULT: PASS - scene loaded, shader texture bound, loop params valid")
	get_tree().quit(0)


func _run_capture() -> void:
	var make_result := DirAccess.make_dir_recursive_absolute(_capture_output_dir)
	if make_result != OK:
		push_error("Could not create capture dir: %s" % _capture_output_dir)
		get_tree().quit(1)
		return

	for frame_index in range(_capture_frames):
		var frame_time := float(_capture_start_frame + frame_index) / float(CAPTURE_FPS)
		_apply_time(frame_time)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var frame_image := get_viewport().get_texture().get_image()
		var frame_path := "%s/frame_%04d.png" % [_capture_output_dir, frame_index]
		var save_result := frame_image.save_png(frame_path)
		if save_result != OK:
			push_error("Could not save frame: %s" % frame_path)
			get_tree().quit(1)
			return

	print("FIRST_PERSON_WARP_CAPTURE_DONE: %s frames -> %s" % [_capture_frames, _capture_output_dir])
	get_tree().quit(0)


func _globalize_path(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	return path
