class_name InkMonIsoAngleSandbox
extends Node2D

## iso 角度沙盒（绘制版）：pitch/yaw 双滑杆运行时调角，找"脑海中的那个视角"。
## F6 直接跑。调出的角度 = 后续美术出图规格（squish/相机角）与正式管线选型的输入。
## 对照场景：iso_tilemap_sandbox.tscn（Godot 内置 tile 管线、角度烘死版）。
## dev-agent：挂通用 bridge（--dev-agent 启用，平时休眠）；scene ops = state / set_angles。

const DevAgentBridgeScript := preload("res://addons/lomolib/dev_agent/dev_agent_bridge.gd")

var _renderer: InkMonIsoHexPrismRenderer
var _pitch_slider: HSlider
var _yaw_slider: HSlider
var _readout: Label


func _ready() -> void:
	var camera := Camera2D.new()
	camera.name = "Camera"
	add_child(camera)
	camera.make_current()

	_renderer = InkMonIsoHexPrismRenderer.new()
	_renderer.name = "PrismRenderer"
	add_child(_renderer)
	_renderer.set_map(_build_colored_map())

	_build_ui()
	set_angles(33.4, 0.0)
	_install_dev_agent()


## smoke / preset 共用入口：设角度并同步 UI。
func set_angles(pitch_deg: float, yaw_deg: float) -> void:
	_renderer.set_angles(pitch_deg, yaw_deg)
	if _pitch_slider != null:
		_pitch_slider.set_value_no_signal(pitch_deg)
	if _yaw_slider != null:
		_yaw_slider.set_value_no_signal(yaw_deg)
	_update_readout()


func get_debug_state() -> Dictionary:
	var probe := Vector2i(2, -1)
	var ground := InkMonRender2DIsoProjection.ground_basis(_renderer.pitch_deg, _renderer.yaw_deg)
	var probe_screen := ground * _renderer.center_of(probe)
	return {
		"node_type": "InkMonIsoAngleSandbox",
		"tile_count": _renderer.tile_count(),
		"pitch_deg": _renderer.pitch_deg,
		"yaw_deg": _renderer.yaw_deg,
		"squish": InkMonRender2DIsoProjection.squish_of(_renderer.pitch_deg),
		"pick_roundtrip_ok": _renderer.pick_axial(probe_screen) == probe,
	}


# === dev-agent scene ops（DevAgentBridge 契约：get_supported_ops + run_scene_op）===

func get_supported_ops() -> Array:
	return ["state", "set_angles"]


func run_scene_op(op_name: String, args: Dictionary) -> Dictionary:
	match op_name:
		"state":
			return {"ok": true, "message": "sandbox state", "data": get_debug_state()}
		"set_angles":
			set_angles(float(args.get("pitch", _renderer.pitch_deg)), float(args.get("yaw", _renderer.yaw_deg)))
			return {"ok": true, "message": "angles applied", "data": get_debug_state()}
		_:
			return {"ok": false, "message": "unknown scene op: %s" % op_name}


func _install_dev_agent() -> void:
	var bridge := DevAgentBridgeScript.new()
	bridge.name = "DevAgentBridge"
	bridge.scene_ops_path = NodePath("..")
	add_child(bridge)


func _build_colored_map() -> Dictionary:
	var src := InkMonIsoSandboxDemoMap.generate()
	var out := {}
	for key in src.keys():
		var info := src[key] as Dictionary
		out[key] = {
			"color": InkMonIsoSandboxDemoMap.terrain_color(str(info["terrain"])),
			"elevation": int(info["elevation"]),
			"tree": bool(info["tree"]),
		}
	return out


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "UI"
	add_child(layer)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.position = Vector2(12.0, 12.0)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)

	_readout = Label.new()
	_readout.name = "Readout"
	box.add_child(_readout)

	_pitch_slider = _add_slider(box, "俯仰 pitch (绕X)", 15.0, 80.0)
	_yaw_slider = _add_slider(box, "旋转 yaw (绕Y)", -60.0, 60.0)

	var presets := HBoxContainer.new()
	box.add_child(presets)
	_add_preset(presets, "2:1 (30°)", 30.0, 0.0)
	_add_preset(presets, "真等轴 (35.3°)", 35.26, 0.0)
	_add_preset(presets, "现行 (33.4°)", 33.4, 0.0)
	_add_preset(presets, "概念图感 (45°/15°)", 45.0, 15.0)


func _add_slider(parent: Control, title: String, min_value: float, max_value: float) -> HSlider:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(130.0, 0.0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = 0.1
	slider.custom_minimum_size = Vector2(240.0, 0.0)
	slider.value_changed.connect(_on_slider_changed)
	row.add_child(slider)
	return slider


func _add_preset(parent: Control, title: String, pitch_deg: float, yaw_deg: float) -> void:
	var button := Button.new()
	button.text = title
	button.pressed.connect(func() -> void: set_angles(pitch_deg, yaw_deg))
	parent.add_child(button)


func _on_slider_changed(_value: float) -> void:
	_renderer.set_angles(_pitch_slider.value, _yaw_slider.value)
	_update_readout()


func _update_readout() -> void:
	if _readout == null:
		return
	_readout.text = "pitch %.1f°  yaw %.1f°  →  squish %.3f" % [
		_renderer.pitch_deg,
		_renderer.yaw_deg,
		InkMonRender2DIsoProjection.squish_of(_renderer.pitch_deg),
	]
