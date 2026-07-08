extends Node
## T7 fps 裁定探针（非断言型，不进 launcher；裁定后可删）：world_main 真实渲染链上
## 三个 AnimatedSprite2D 并排播 walk 8 / 12 / 24 fps —— wall-clock 等速（24=全帧、
## 12=隔1抽、8=隔2抽，步态周期时长一致），用户游戏内目检裁定契约 fps。
## 帧源 = Lab 仓 fps_probe_frames.py 预处理产物（union bbox 裁切 + 中位轴锚 +
## 1.4 world × 212.75 px/unit 契约密度），运行时从项目外绝对路径加载——
## 不进 res:// 扫描（121 帧探针产物不许被编辑器 import / 不进 git）。
##
## 跑法: godot --path . inkmon/tests/probe_unit_fps.tscn —— **不带 --headless**。
##   --frames-dir=<dir> 覆盖帧目录（默认 = 本机 Lab 仓探针产物，探针级 hardcode）
##   --shot-and-quit    截一张图退出（布局自检用）
## 交互: 空格 = 移动/原地切换；←/→ = 走速调节；↑/↓ = stride 校准；M = 位移模式
## （平滑 60fps ⇄ 步进跟动画帧——姿态定格期身体平移是烘帧滑步感的固有成分，
## 步进 = 位移只在动画帧切换瞬间冲销累计量，脚地帧内完全锁定）；滚轮 = zoom。
## 走线: 方向 3（前左，母版向）去 / 方向 0 回，回程 flip_h（契约 "0": mirror_of 3，
##   anchor_x' = size_x − anchor_x ⇒ centered offset.x 取反——消费端镜像规则同款）。
##
## 循环段 + 速度绑定（2026-07-09 fps 裁定现场实证，契约 unitset 章两新条款）:
## 动画帧 = meta.loop [in,out) 循环段（视频起步 idle 段非循环，walk_loop_pick.py 量化
## 挑选）；位移动作播放速率随移动速度调制 speed_scale = 走速 / 自然步速（= stride ×
## fps / 档内循环帧数）——否则滑步。↑/↓ 微调 stride 目检校准（终值登记 manifest
## stride_world）；原地模式 speed_scale = 1（素材原生踏步率）。

const DEFAULT_FRAMES_DIR := "E:/the-seed-projects/inkmon-lab/docs/plan/current/unit-anim-probe/out/fps_probe"
const DEFAULT_SHOT_DIR := "res://.claude/tmp/ui-shots"
## 三档 fps 与抽帧步长（24=全帧 121、12=隔1 61 帧、8=隔2 41 帧——循环时长 5.04/5.08/5.13s）。
const VARIANTS: Array[Dictionary] = [
	{"fps": 8.0, "step": 3},
	{"fps": 12.0, "step": 2},
	{"fps": 24.0, "step": 1},
]
## 走廊（world_main 实测平地 e0 grass/dirt 无水无 decor）：三行起点 (1,-2)(2,-1)(3,0)
## （行偏移 (1,1)，屏幕对角错开 ~204×118px > sprite 宽——三熊互不遮挡），
## 沿方向 3 位移 (-1,+1)，t ∈ [0, 3]。
const CORRIDOR_START := Vector2i(1, -2)
const ROW_OFFSET := Vector2i(1, 1)
const CORRIDOR_LEN := 3.0

var _map: InkMonRender2DBakedHexMap = null
var _camera: Camera2D = null
var _units: Array[Dictionary] = []
var _moving := true
var _speed := 0.35  # 格/s（默认 ≈ stride 自然步速，speed_scale≈1 起步）
var _stride := 0.382  # world units/循环（meta stride_world_est 覆盖；↑/↓ 校准）
var _quantized := false  # M：位移步进跟动画帧
var _hud: Label = null


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	var frames_dir := DEFAULT_FRAMES_DIR
	var shot_and_quit := false
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--frames-dir="):
			frames_dir = str(arg).trim_prefix("--frames-dir=")
		elif str(arg) == "--shot-and-quit":
			shot_and_quit = true

	var bundle := InkMonMapLoader.load_bundle("world_main")
	if bundle.is_empty():
		push_error("[probe_unit_fps] load_bundle failed")
		get_tree().quit(1)
		return
	_map = InkMonRender2DBakedHexMap.new()
	add_child(_map)
	if not _map.setup_from_bundle(bundle, 96.0):
		push_error("[probe_unit_fps] setup_from_bundle failed")
		get_tree().quit(1)
		return

	var meta := _load_meta(frames_dir)
	if meta.is_empty():
		get_tree().quit(1)
		return
	var textures := _load_textures(frames_dir, meta)
	if textures.is_empty():
		get_tree().quit(1)
		return
	# 循环段（缺 loop 字段 = 未跑 walk_loop_pick.py，退化全序列并告警——会滑步/跳变）。
	var loop_in := 0
	var loop_out := textures.size()
	if meta.has("loop"):
		var loop := meta["loop"] as Dictionary
		loop_in = int(loop["in"])
		loop_out = int(loop["out"])
	else:
		push_warning("[probe_unit_fps] meta.json 无 loop 字段——先跑 walk_loop_pick.py")
	_stride = float(meta.get("stride_world_est", _stride))
	var sprite_frames := _build_sprite_frames(textures, loop_in, loop_out)

	# 素材 212.75 px/world-unit；显示密度 = edge_px()/hex_edge_world(=1.0 契约常量)。
	var unit_scale: float = _map.edge_px() / float(meta["px_per_unit"])
	var size_px := meta["size_px"] as Array
	var anchor_px := meta["anchor_px"] as Array
	var base_offset := Vector2(
		float(size_px[0]) * 0.5 - float(anchor_px[0]),
		float(size_px[1]) * 0.5 - float(anchor_px[1]))

	for i in VARIANTS.size():
		var v := VARIANTS[i]
		var holder := Node2D.new()
		holder.name = "unit_fps%d" % int(v["fps"])
		add_child(holder)
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = sprite_frames
		sprite.centered = true
		sprite.scale = Vector2(unit_scale, unit_scale)
		sprite.offset = base_offset
		sprite.play("walk%d" % int(v["fps"]))
		holder.add_child(sprite)
		var tag := Label.new()
		tag.text = "%d fps" % int(v["fps"])
		tag.position = Vector2(-60.0, -float(size_px[1]) * unit_scale - 34.0)
		tag.custom_minimum_size = Vector2(120.0, 22.0)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.add_theme_color_override("font_outline_color", Color.BLACK)
		tag.add_theme_constant_override("outline_size", 4)
		holder.add_child(tag)
		var unit := {
			"holder": holder, "sprite": sprite, "row": CORRIDOR_START + ROW_OFFSET * i,
			"t": CORRIDOR_LEN * 0.5, "dir": 1.0, "base_offset": base_offset,
			"t_shown": CORRIDOR_LEN * 0.5, "dir_shown": 1.0,
			"fps": float(v["fps"]),
			"loop_frames": int(ceilf(float(loop_out - loop_in) / float(v["step"]))),
		}
		# 步进模式：位移只在动画帧切换瞬间应用（姿态与位移跳变同帧 ⇒ 帧内脚地锁定）。
		sprite.frame_changed.connect(_on_frame_step.bind(unit))
		_units.append(unit)
	_place_units()

	_camera = Camera2D.new()
	_camera.position = _map.coord_to_world(1, 0) + Vector2(0.0, -40.0)
	_camera.zoom = Vector2(0.9, 0.9)
	add_child(_camera)
	_camera.make_current()

	var ui := CanvasLayer.new()
	add_child(ui)
	_hud = Label.new()
	_hud.position = Vector2(16.0, 12.0)
	_hud.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud.add_theme_constant_override("outline_size", 4)
	ui.add_child(_hud)
	_refresh_hud()

	print("  [probe_unit_fps] frames=%d variants=8/12/24 corridor=%s len=%.0f" % [
		int(meta["frame_count"]), str(CORRIDOR_START), CORRIDOR_LEN])

	if shot_and_quit:
		var shot_dir := ProjectSettings.globalize_path(DEFAULT_SHOT_DIR)
		DirAccess.make_dir_recursive_absolute(shot_dir)
		for _i in range(10):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var path := "%s/probe_unit_fps.png" % shot_dir
		var err := image.save_png(path)
		print("  [probe_unit_fps] shot -> %s (err=%d)" % [path, err])
		get_tree().quit(0)


func _load_meta(frames_dir: String) -> Dictionary:
	var raw := FileAccess.get_file_as_string(frames_dir.path_join("meta.json"))
	if raw.is_empty():
		push_error("[probe_unit_fps] meta.json missing at %s — 先跑 Lab 仓 fps_probe_frames.py" % frames_dir)
		return {}
	var parsed: Variant = JSON.parse_string(raw)
	if parsed == null or not (parsed is Dictionary):
		push_error("[probe_unit_fps] meta.json parse failed")
		return {}
	return parsed as Dictionary


func _load_textures(frames_dir: String, meta: Dictionary) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for name_value in meta["frames"] as Array:
		var image := Image.load_from_file(frames_dir.path_join("frames").path_join(str(name_value)))
		if image == null or image.is_empty():
			push_error("[probe_unit_fps] frame load failed: %s" % str(name_value))
			return []
		out.append(ImageTexture.create_from_image(image))
	return out


## 一份 SpriteFrames 三条动画（walk8/walk12/walk24），共享同一批纹理对象；
## 帧 = 循环段 [loop_in, loop_out) 内按档抽取。
func _build_sprite_frames(textures: Array[Texture2D], loop_in: int, loop_out: int) -> SpriteFrames:
	var sf := SpriteFrames.new()
	for v in VARIANTS:
		var anim := "walk%d" % int(v["fps"])
		sf.add_animation(anim)
		sf.set_animation_speed(anim, float(v["fps"]))
		sf.set_animation_loop(anim, true)
		for i in range(loop_in, loop_out, int(v["step"])):
			sf.add_frame(anim, textures[i])
	sf.remove_animation("default")
	return sf


## 该单位所在档的自然步速（world units/s）= 一循环位移 / 一循环时长。
func _nat_speed(u: Dictionary) -> float:
	return _stride * float(u["fps"]) / float(u["loop_frames"])


func _process(delta: float) -> void:
	for u in _units:
		var sprite := u["sprite"] as AnimatedSprite2D
		# 位移动作速度绑定（契约条款）: speed_scale = 走速/自然步速；原地 = 素材原生踏步率。
		sprite.speed_scale = (_speed / _nat_speed(u)) if _moving else 1.0
		if not _moving:
			continue
		var t := float(u["t"]) + float(u["dir"]) * _speed * delta
		var dir := float(u["dir"])
		if t >= CORRIDOR_LEN:
			t = CORRIDOR_LEN - (t - CORRIDOR_LEN)
			dir = -1.0
		elif t <= 0.0:
			t = -t
			dir = 1.0
		u["t"] = t
		u["dir"] = dir
		if not _quantized:
			u["t_shown"] = t
			u["dir_shown"] = dir
			_apply_unit(u)


func _on_frame_step(u: Dictionary) -> void:
	if _quantized and _moving:
		u["t_shown"] = u["t"]
		u["dir_shown"] = u["dir"]
		_apply_unit(u)


func _place_units() -> void:
	for u in _units:
		_apply_unit(u)


func _apply_unit(u: Dictionary) -> void:
	var row := u["row"] as Vector2i
	var t := float(u["t_shown"])
	var holder := u["holder"] as Node2D
	holder.position = _map.coord_to_world_f(float(row.x) - t, float(row.y) + t)
	var sprite := u["sprite"] as AnimatedSprite2D
	var mirrored := float(u["dir_shown"]) < 0.0  # 回程 = 方向 0 = mirror_of 3
	sprite.flip_h = mirrored
	var base := u["base_offset"] as Vector2
	sprite.offset = Vector2(-base.x if mirrored else base.x, base.y)


func _refresh_hud() -> void:
	var scale12 := 0.0  # 12fps 档参考 speed_scale
	for u in _units:
		if int(u["fps"]) == 12:
			scale12 = _speed / _nat_speed(u)
	_hud.text = "T7 fps 探针 — 空格: %s | ←/→ 走速 %.2f 格/s | ↑/↓ stride %.3f (12fps 档 speed_scale %.2f) | M 位移: %s | 滚轮 zoom %.1fx" % [
		"移动中" if _moving else "原地踏步", _speed, _stride, scale12,
		"步进跟帧" if _quantized else "平滑 60fps",
		_camera.zoom.x if _camera != null else 1.0]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var key := (event as InputEventKey).keycode
		if key == KEY_SPACE:
			_moving = not _moving
		elif key == KEY_LEFT:
			_speed = maxf(0.1, _speed / 1.25)
		elif key == KEY_RIGHT:
			_speed = minf(3.0, _speed * 1.25)
		elif key == KEY_UP:
			_stride = minf(1.0, _stride + 0.02)
		elif key == KEY_DOWN:
			_stride = maxf(0.1, _stride - 0.02)
		elif key == KEY_M:
			_quantized = not _quantized
		_refresh_hud()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var btn := (event as InputEventMouseButton).button_index
		if btn == MOUSE_BUTTON_WHEEL_UP:
			_camera.zoom = (_camera.zoom * 1.1).clampf(0.4, 4.0)
			_refresh_hud()
		elif btn == MOUSE_BUTTON_WHEEL_DOWN:
			_camera.zoom = (_camera.zoom / 1.1).clampf(0.4, 4.0)
			_refresh_hud()
