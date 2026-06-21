class_name InkMonArtCameraController2D
extends Node

## Shared 2D camera controls for art exploration scenes.

@export var enabled := true
@export var move_speed := 900.0
@export var zoom_step := 1.16
@export var min_zoom := 0.25
@export var max_zoom := 5.0
@export var drag_button := MOUSE_BUTTON_MIDDLE

var _camera: Camera2D
var _default_position := Vector2.ZERO
var _default_zoom := Vector2.ONE
var _has_default_view := false
var _is_dragging := false


func _ready() -> void:
	set_process(true)
	set_process_unhandled_input(true)


func setup(camera: Camera2D) -> void:
	_camera = camera
	if _camera != null:
		set_default_view(_camera.position, _camera.zoom)


func set_default_view(position: Vector2, zoom: Vector2) -> void:
	_default_position = position
	_default_zoom = zoom
	_has_default_view = true


func reset_view() -> void:
	if _camera == null or not _has_default_view:
		return
	_camera.position = _default_position
	_camera.zoom = _default_zoom


func _process(delta: float) -> void:
	if not enabled or _camera == null:
		return
	var direction := Vector2.ZERO
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		direction.x -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		direction.x += 1.0
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		direction.y -= 1.0
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		direction.y += 1.0
	if direction == Vector2.ZERO:
		return
	_camera.position += direction.normalized() * move_speed * delta / _safe_zoom()


func _unhandled_input(event: InputEvent) -> void:
	if not enabled or _camera == null:
		return
	var key_event := event as InputEventKey
	if key_event != null and key_event.pressed and not key_event.echo:
		if key_event.keycode == KEY_SPACE:
			reset_view()
			get_viewport().set_input_as_handled()
		return

	var button_event := event as InputEventMouseButton
	if button_event != null:
		if button_event.button_index == MOUSE_BUTTON_WHEEL_UP and button_event.pressed:
			_zoom_at_screen(button_event.position, zoom_step)
			get_viewport().set_input_as_handled()
			return
		if button_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and button_event.pressed:
			_zoom_at_screen(button_event.position, 1.0 / zoom_step)
			get_viewport().set_input_as_handled()
			return
		if button_event.button_index == drag_button:
			_is_dragging = button_event.pressed
			get_viewport().set_input_as_handled()
			return

	var motion_event := event as InputEventMouseMotion
	if motion_event != null and _is_dragging:
		_camera.position -= motion_event.relative / _safe_zoom()
		get_viewport().set_input_as_handled()


func _zoom_at_screen(screen_position: Vector2, factor: float) -> void:
	var before := _screen_to_world(screen_position)
	var next_zoom := clampf(_safe_zoom() * factor, min_zoom, max_zoom)
	_camera.zoom = Vector2(next_zoom, next_zoom)
	var after := _screen_to_world(screen_position)
	_camera.position += before - after


func _screen_to_world(screen_position: Vector2) -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size
	return _camera.position + (screen_position - viewport_size * 0.5) / _safe_zoom()


func _safe_zoom() -> float:
	return maxf(_camera.zoom.x, 0.001)
