extends Node2D
## Unit viewer(T7 M4 第一交付物)——正式 InkMonUnitSetLoader 的第一个消费场景 +
## 发布后常驻目检验收载体(替代 M1 的临时 ffmpeg 预览;map_viewer 范式:6 行
## tscn 壳 + 全代码 UI)。
##
## 能力:单位/动作切换(ring + idle/walk/attack)· **6 向同屏**(标注每向
## 真帧/mirror/alias)· loop / speed_scale 可调 · 程序影开关(loader 预推,
## 影不随镜像)。
##
## 跑法: godot --path . inkmon/tools/unit_viewer/unit_viewer.tscn
##   --unit-shot            全部动作各截一张退出(--shot 自验,存 SHOT_DIR)
##   --set-id=<id>          换 unit set(默认 inkmon-units-main)
## 交互: 滚轮 = zoom;空格 = 播放/重播(单发动作播完停,空格重播);
##   P / ⏸ 钮 = 暂停/续播;←/→ = 逐帧步进(自动先暂停)。HUD 常显当前帧号,
##   ring 附 src 源帧号 + 近似角度(验收指认帧用:「src #NNN 影子不对」)。

const DEFAULT_SET_ID := "inkmon-units-main"
const SHOT_DIR := "res://.claude/tmp/ui-shots"
const BG_COLOR := Color(46.0 / 255.0, 42.0 / 255.0, 40.0 / 255.0)
## 6 向格心(2 行 3 列,窗口 1280×720;锚点=脚点落格心)。
const DIR_SLOTS := {
	0: Vector2(260.0, 300.0), 1: Vector2(640.0, 300.0), 2: Vector2(1020.0, 300.0),
	3: Vector2(260.0, 640.0), 4: Vector2(640.0, 640.0), 5: Vector2(1020.0, 640.0),
}
const BASE_SCALE := 0.55

var _units := {}
var _unit_ids: Array[String] = []
var _current_unit := ""
var _current_action := ""
## dir → { body: AnimatedSprite2D, shadow: AnimatedSprite2D, tag: Label }。
var _slots := {}
var _ring_slot := {}
var _zoom := 1.0
var _speed := 1.0
var _shadows_on := true
var _paused := false

var _unit_pick: OptionButton
var _action_pick: OptionButton
var _loop_check: CheckButton
var _shadow_check: CheckButton
var _pause_check: CheckButton
var _speed_slider: HSlider
var _speed_label: Label
var _info: Label
var _frame_label: Label


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	RenderingServer.set_default_clear_color(BG_COLOR)

	var set_id := DEFAULT_SET_ID
	var shot_mode := false
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--set-id="):
			set_id = str(arg).trim_prefix("--set-id=")
		elif str(arg) == "--unit-shot":
			shot_mode = true

	_units = InkMonUnitSetLoader.load_set(set_id)
	if _units.is_empty():
		push_error("[unit_viewer] load_set(%s) failed" % set_id)
		get_tree().quit(1)
		return
	for unit_id in _units.keys():
		_unit_ids.append(str(unit_id))
	_unit_ids.sort()

	_build_slots()
	_build_control_bar()
	_select_unit(_unit_ids[0])

	if shot_mode:
		await _shot_all_actions()


func _visual() -> InkMonUnitSetLoader.UnitVisual:
	return _units.get(_current_unit) as InkMonUnitSetLoader.UnitVisual


## 6 向格 + ring 独格(居中大图;ring 无方向)。
func _build_slots() -> void:
	for dir in DIR_SLOTS.keys():
		var slot := _make_slot("dir%d" % int(dir), DIR_SLOTS[dir] as Vector2)
		_slots[int(dir)] = slot
	_ring_slot = _make_slot("ring", Vector2(640.0, 480.0))


func _make_slot(slot_name: String, at: Vector2) -> Dictionary:
	var holder := Node2D.new()
	holder.name = slot_name
	holder.position = at
	add_child(holder)
	var shadow := AnimatedSprite2D.new()
	shadow.name = "Shadow"
	shadow.centered = true
	holder.add_child(shadow)
	var body := AnimatedSprite2D.new()
	body.name = "Body"
	body.centered = true
	holder.add_child(body)
	# 影帧跟随本体(影 SpriteFrames 从不自走 —— frame_changed 同步,同拍不漂)。
	body.frame_changed.connect(func() -> void:
		if shadow.sprite_frames != null and shadow.visible:
			shadow.frame = body.frame)
	var tag := Label.new()
	tag.name = "Tag"
	tag.position = Vector2(-90.0, 16.0)
	tag.custom_minimum_size = Vector2(180.0, 22.0)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_color_override("font_outline_color", Color.BLACK)
	tag.add_theme_constant_override("outline_size", 4)
	holder.add_child(tag)
	return {"holder": holder, "body": body, "shadow": shadow, "tag": tag}


func _build_control_bar() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	ui.add_child(panel)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	panel.add_child(bar)

	bar.add_child(_bar_label("单位"))
	_unit_pick = OptionButton.new()
	for unit_id in _unit_ids:
		_unit_pick.add_item(unit_id)
	_unit_pick.item_selected.connect(func(idx: int) -> void: _select_unit(_unit_ids[idx]))
	bar.add_child(_unit_pick)

	bar.add_child(_bar_label("动作"))
	_action_pick = OptionButton.new()
	_action_pick.item_selected.connect(func(idx: int) -> void:
		_select_action(_action_pick.get_item_text(idx)))
	bar.add_child(_action_pick)

	_loop_check = CheckButton.new()
	_loop_check.text = "loop"
	_loop_check.toggled.connect(func(on: bool) -> void:
		var visual := _visual()
		if visual == null or _current_action.is_empty():
			return
		var anim := _anim_of(_current_action)
		visual.sprite_frames.set_animation_loop(anim, on)
		if visual.shadow_frames != null:
			visual.shadow_frames.set_animation_loop(anim, on)
		_replay())
	bar.add_child(_loop_check)

	_shadow_check = CheckButton.new()
	_shadow_check.text = "程序影"
	_shadow_check.button_pressed = true
	_shadow_check.toggled.connect(func(on: bool) -> void:
		_shadows_on = on
		_apply_action())
	bar.add_child(_shadow_check)

	bar.add_child(_bar_label("速度"))
	_speed_slider = HSlider.new()
	_speed_slider.min_value = 0.1
	_speed_slider.max_value = 4.0
	_speed_slider.step = 0.05
	_speed_slider.value = 1.0
	_speed_slider.custom_minimum_size = Vector2(160.0, 0.0)
	_speed_slider.value_changed.connect(func(v: float) -> void:
		_speed = v
		_speed_label.text = "%.2fx" % v
		_apply_speed())
	bar.add_child(_speed_slider)
	_speed_label = _bar_label("1.00x")
	bar.add_child(_speed_label)

	var replay := Button.new()
	replay.text = "⟳ 重播"
	replay.pressed.connect(_replay)
	bar.add_child(replay)

	_pause_check = CheckButton.new()
	_pause_check.text = "⏸ 暂停"
	_pause_check.toggled.connect(_set_paused)
	bar.add_child(_pause_check)

	_frame_label = _bar_label("")
	bar.add_child(_frame_label)

	_info = _bar_label("")
	bar.add_child(_info)


func _bar_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _select_unit(unit_id: String) -> void:
	_current_unit = unit_id
	_unit_pick.select(_unit_ids.find(unit_id))
	var visual := _visual()
	_action_pick.clear()
	if visual.has_ring():
		_action_pick.add_item("ring")
	for action in visual.actions():
		_action_pick.add_item(str(action))
	if _action_pick.item_count > 0:
		_action_pick.select(0)
		_select_action(_action_pick.get_item_text(0))


func _anim_of(action: String) -> String:
	if action == "ring":
		return InkMonUnitSetLoader.RING_ANIMATION
	return str(_visual().entry(action, 3).get("animation", ""))


func _select_action(action: String) -> void:
	_current_action = action
	# 下拉与实际选择保持同步（shot 模式/程序调用也一致）。
	for i in _action_pick.item_count:
		if _action_pick.get_item_text(i) == action:
			_action_pick.select(i)
			break
	var visual := _visual()
	var anim := _anim_of(action)
	_loop_check.set_pressed_no_signal(visual.sprite_frames.get_animation_loop(anim))
	_apply_action()


## 把当前 单位×动作 装到格上:ring = 独格居中;动作 = 6 向同屏。
func _apply_action() -> void:
	var visual := _visual()
	var is_ring := _current_action == "ring"
	_set_slot_visible(_ring_slot, is_ring)
	for dir in _slots.keys():
		_set_slot_visible(_slots[dir] as Dictionary, not is_ring)

	if is_ring:
		var entry := visual.ring_entry()
		var ring_count := visual.sprite_frames.get_frame_count(InkMonUnitSetLoader.RING_ANIMATION)
		_apply_slot(_ring_slot, visual, entry, "ring · %d 帧转环" % ring_count)
	else:
		for dir in _slots.keys():
			var entry := visual.entry(_current_action, int(dir))
			var kind := str(entry.get("kind", "?"))
			var kind_label: String = {"true": "真帧", "alias": "alias", "mirror": "mirror"}.get(kind, kind)
			_apply_slot(_slots[dir] as Dictionary, visual, entry, "d%d · %s" % [int(dir), kind_label])
	_apply_speed()
	# 切换选择即恢复播放（_apply_slot 已 play）,暂停态与按钮同步复位。
	_paused = false
	if _pause_check != null:
		_pause_check.set_pressed_no_signal(false)
	_refresh_info()


func _apply_slot(slot: Dictionary, visual: InkMonUnitSetLoader.UnitVisual, entry: Dictionary, tag_text: String) -> void:
	var body := slot["body"] as AnimatedSprite2D
	var shadow := slot["shadow"] as AnimatedSprite2D
	var tag := slot["tag"] as Label
	if entry.is_empty():
		body.visible = false
		shadow.visible = false
		tag.text = "%s(缺)" % tag_text
		return
	var anim := str(entry["animation"])
	var display_scale := BASE_SCALE * _zoom
	body.sprite_frames = visual.sprite_frames
	body.animation = anim
	body.flip_h = bool(entry["mirrored"])
	body.offset = entry["offset"] as Vector2
	body.scale = Vector2(display_scale, display_scale)
	body.visible = true
	body.play(anim)
	# 程序影:预推帧 + 脚线锚点;不随镜像(契约)—— flip_h 恒 false。
	if _shadows_on and visual.shadow_frames != null:
		shadow.sprite_frames = visual.shadow_frames
		shadow.animation = anim
		shadow.flip_h = false
		shadow.offset = entry["shadow_offset"] as Vector2
		shadow.scale = Vector2(display_scale, display_scale)
		shadow.visible = true
		shadow.stop()
		shadow.frame = body.frame
	else:
		shadow.visible = false
	tag.text = tag_text


func _set_slot_visible(slot: Dictionary, on: bool) -> void:
	(slot["holder"] as Node2D).visible = on


func _apply_speed() -> void:
	for slot_value in _all_slots():
		var body := (slot_value as Dictionary)["body"] as AnimatedSprite2D
		body.speed_scale = _speed


func _replay() -> void:
	_paused = false
	_pause_check.set_pressed_no_signal(false)
	for slot_value in _all_slots():
		var slot := slot_value as Dictionary
		var body := slot["body"] as AnimatedSprite2D
		if body.visible and body.sprite_frames != null:
			body.frame = 0
			body.play(body.animation)
			var shadow := slot["shadow"] as AnimatedSprite2D
			if shadow.visible:
				shadow.frame = 0


## 暂停/续播(P 键 / ⏸ 钮)。pause() 保留当前帧,play() 原位续播。
func _set_paused(on: bool) -> void:
	_paused = on
	_pause_check.set_pressed_no_signal(on)
	for slot_value in _all_slots():
		var body := (slot_value as Dictionary)["body"] as AnimatedSprite2D
		if not body.visible or body.sprite_frames == null:
			continue
		if on:
			body.pause()
		else:
			body.play()


## 逐帧步进(←/→;未暂停先自动暂停)。所有可见格同步步进,影帧经
## frame_changed 跟随。
func _step_frame(delta: int) -> void:
	if not _paused:
		_set_paused(true)
	for slot_value in _all_slots():
		var body := (slot_value as Dictionary)["body"] as AnimatedSprite2D
		if not body.visible or body.sprite_frames == null:
			continue
		var count := body.sprite_frames.get_frame_count(body.animation)
		if count > 0:
			body.frame = posmod(body.frame + delta, count)


func _all_slots() -> Array:
	var out := _slots.values()
	out.append(_ring_slot)
	return out


func _refresh_info() -> void:
	var visual := _visual()
	if _current_action == "ring":
		_info.text = "fps %.0f · loop" % visual.unit_fps
		return
	var entry := visual.entry(_current_action, 3)
	var stride := float(entry.get("stride_world", 0.0))
	var stride_text := " · stride %.3f(自然步速 %.3f w/s)" % [stride, visual.natural_speed(_current_action)] if stride > 0.0 else ""
	_info.text = "fps %.0f · %d 帧 · %s%s" % [
		float(entry.get("fps", visual.unit_fps)),
		visual.sprite_frames.get_frame_count(str(entry.get("animation", ""))),
		"loop" if bool(entry.get("loop", false)) else "单发",
		stride_text]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var btn := (event as InputEventMouseButton).button_index
		if btn == MOUSE_BUTTON_WHEEL_UP:
			_zoom = minf(3.0, _zoom * 1.1)
			_apply_action()
		elif btn == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = maxf(0.3, _zoom / 1.1)
			_apply_action()
	elif event is InputEventKey and (event as InputEventKey).pressed:
		match (event as InputEventKey).keycode:
			KEY_SPACE:
				_replay()
			KEY_P:
				_set_paused(not _paused)
			KEY_LEFT:
				_step_frame(-1)
			KEY_RIGHT:
				_step_frame(1)


func _process(_delta: float) -> void:
	_refresh_frame_label()


## 帧号 HUD 参考体:ring = 独格;动作 = d3 真帧格(六格同拍,取一即可)。
func _reference_body() -> AnimatedSprite2D:
	var slot: Dictionary = _ring_slot if _current_action == "ring" else _slots.get(3, {}) as Dictionary
	if slot.is_empty():
		return null
	return slot["body"] as AnimatedSprite2D


## 常显帧号(f 序号 1-based,与发布帧文件名对齐);ring 附 src 源帧号 +
## 近似角度(src/count×360,契约「匀速旋转近似」条款)——验收指认帧的坐标系。
func _refresh_frame_label() -> void:
	if _frame_label == null:
		return
	var body := _reference_body()
	if body == null or not body.visible or body.sprite_frames == null or _current_action.is_empty():
		_frame_label.text = ""
		return
	var count := body.sprite_frames.get_frame_count(body.animation)
	if count <= 0:
		_frame_label.text = ""
		return
	var text := "帧 f%02d/%d" % [body.frame + 1, count]
	if _current_action == "ring":
		var entry := _visual().ring_entry()
		var srcs := entry.get("src_frames", []) as Array
		var src_count := int(entry.get("src_frame_count", 0))
		if body.frame < srcs.size() and src_count > 0:
			var src := int(srcs[body.frame])
			text += " · src #%03d · ≈%d°" % [src, roundi(float(src) / float(src_count) * 360.0)]
	_frame_label.text = text


## --unit-shot:全部动作各截一张退出(逐向逐动作目检的存档载体)。
func _shot_all_actions() -> void:
	var shot_dir := ProjectSettings.globalize_path(SHOT_DIR)
	if DirAccess.make_dir_recursive_absolute(shot_dir) != OK:
		push_error("[unit_viewer] cannot create shot dir %s" % shot_dir)
		get_tree().quit(1)
		return
	var actions: Array = []
	if _visual().has_ring():
		actions.append("ring")
	actions.append_array(_visual().actions())
	var failed := false
	for action_value in actions:
		var action := str(action_value)
		_select_action(action)
		for _i in range(12):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var path := "%s/unit_viewer_%s_%s.png" % [shot_dir, _current_unit, action]
		var err := image.save_png(path)
		print("  [unit_viewer] shot %s -> %s (err=%d)" % [action, path, err])
		if err != OK:
			failed = true
	get_tree().quit(1 if failed else 0)
