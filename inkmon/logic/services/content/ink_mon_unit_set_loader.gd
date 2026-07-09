class_name InkMonUnitSetLoader

## content/art/units/ 单位动画装载器（T7 M4，inkmon-unitset/1 消费端）。
##
## 已发布 set manifest（6 向三形态：frames 真帧 / alias_of 直用 / mirror_of
## 运行时翻转）→ 每单位一个 UnitVisual：SpriteFrames（真帧动画 + ring）+
## 方向表（animation / mirrored / offset）+ fps(含 fps_override) / loop /
## stride_world 透出 + 程序影 SpriteFrames（loader 预推 ImageTexture 缓存，
## 契约 projection.unit_shadow 四参；影不随镜像）。
##
## 锚定语义（契约 unitset 章）：centered sprite，offset = size_px/2 − anchor_px；
## mirror 向 anchor_x' = size_x − anchor_x ⇒ centered offset.x 取反
## （消费端镜像规则,smoke_unit_set_loader 数值覆盖）。帧走 res:// load()
## （已 .import 进扫描;探针脚本的 Image.load_from_file 随探针退役）。
##
## unit 是运行时 actor 表演资产，不进 map bundle —— 独立于 InkMonMapLoader。
## 纯 static 装载函数，无状态；产物 UnitVisual 是 RefCounted 数据袋。

const CONTENT_ROOT := "res://content"
const SCHEMA := "inkmon-unitset/1"
## ring 在 SpriteFrames 里的动画名（动作动画名 = "<action>_d<dir>"）。
const RING_ANIMATION := "ring"


## 一个单位的运行时表演资产视图。
class UnitVisual extends RefCounted:
	var unit_id := ""
	## 真帧动画（"<action>_d<dir>" + "ring"），fps/loop 已按 manifest 设置。
	var sprite_frames: SpriteFrames
	## 程序影（与 sprite_frames 同名动画同帧数；预推 ImageTexture；可为 null——
	## load_set(with_shadows=false)）。影 alpha 已烧进像素（契约 0.33）。
	var shadow_frames: SpriteFrames
	## 契约标称刷新率（speed_scale=1.0 的语义基准）。
	var unit_fps := 12.0
	## 素材密度（px/world-unit,契约 212.75）——显示 scale = 目标 edge_px / 本值。
	var px_per_unit := 212.75
	## action → { "0".."5" → entry }；entry 见 _direction_entry。
	var _actions := {}
	## ring entry（无方向）。
	var _ring := {}

	func actions() -> Array:
		return _actions.keys()

	func has_ring() -> bool:
		return not _ring.is_empty()

	func ring_entry() -> Dictionary:
		return _ring

	## 方向条目：{ animation, mirrored, offset: Vector2, shadow_offset: Vector2,
	##   size_px: Vector2, fps: float, loop: bool, stride_world: float,
	##   kind: "true"|"alias"|"mirror", src_frames: Array, src_frame_count: int }。
	## src_frames/src_frame_count = 发布帧 ↔ 源视频帧号映射（ring 必有——角度
	## 真相 ≈ src/count×360；动作节点 manifest 无此字段时为 []/0）。
	## 未知 action/dir 返回 {}。
	func entry(action: String, dir: int) -> Dictionary:
		var dirs: Dictionary = _actions.get(action, {})
		return dirs.get(str(dir), {})

	## 位移动作的一循环位移（world units；无 = 0.0，消费端不做速度绑定）。
	func stride_of(action: String) -> float:
		var e := entry(action, 3)
		return float(e.get("stride_world", 0.0))

	## 该向动作的自然步速（world units/s）= stride × fps / 循环帧数
	## （T7 探针定案公式；speed_scale = 移动速度 / 自然步速）。
	func natural_speed(action: String, dir: int = 3) -> float:
		var e := entry(action, dir)
		var stride := float(e.get("stride_world", 0.0))
		if stride <= 0.0 or sprite_frames == null:
			return 0.0
		var anim := str(e.get("animation", ""))
		var frame_count := sprite_frames.get_frame_count(anim)
		if frame_count <= 0:
			return 0.0
		return stride * float(e.get("fps", unit_fps)) / float(frame_count)


static func unit_set_dir(set_id: String) -> String:
	return "%s/art/units/%s" % [CONTENT_ROOT, set_id]


static func load_set_manifest(set_id: String) -> Dictionary:
	var path := "%s/manifest.json" % unit_set_dir(set_id)
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("[InkMonUnitSetLoader] cannot read %s" % path)
		return {}
	var data: Variant = JSON.parse_string(text)
	if not (data is Dictionary):
		push_error("[InkMonUnitSetLoader] %s is not a JSON object" % path)
		return {}
	var manifest := data as Dictionary
	if str(manifest.get("schema", "")) != SCHEMA:
		push_error("[InkMonUnitSetLoader] unit set %s: unsupported schema %s" % [set_id, str(manifest.get("schema"))])
		return {}
	if not (manifest.get("units") is Dictionary) or not (manifest.get("projection") is Dictionary):
		push_error("[InkMonUnitSetLoader] unit set %s: manifest missing units/projection" % set_id)
		return {}
	return manifest


## 装载整个 set：unit_id → UnitVisual。失败（manifest 坏 / 帧缺）fail loud 返 {}。
## with_shadows=false 跳过程序影预推（影不需要的场合省启动耗时）。
static func load_set(set_id: String, with_shadows := true) -> Dictionary:
	var manifest := load_set_manifest(set_id)
	if manifest.is_empty():
		return {}
	var projection := manifest.get("projection", {}) as Dictionary
	var unit_fps := float(projection.get("unit_fps", 12.0))
	var px_per_unit := float(projection.get("unit_px_per_unit", 212.75))
	var shadow_params := projection.get("unit_shadow", {}) as Dictionary
	var set_dir := unit_set_dir(set_id)
	var out := {}
	var units := manifest.get("units", {}) as Dictionary
	for unit_id_value in units.keys():
		var unit_id := str(unit_id_value)
		var visual := _build_unit(set_dir, unit_id, units[unit_id] as Dictionary, unit_fps, shadow_params, with_shadows)
		if visual == null:
			return {}
		visual.px_per_unit = px_per_unit
		out[unit_id] = visual
	return out


static func _build_unit(set_dir: String, unit_id: String, node: Dictionary, unit_fps: float, shadow_params: Dictionary, with_shadows: bool) -> UnitVisual:
	var visual := UnitVisual.new()
	visual.unit_id = unit_id
	visual.unit_fps = unit_fps
	visual.sprite_frames = SpriteFrames.new()
	visual.sprite_frames.remove_animation("default")
	if with_shadows:
		visual.shadow_frames = SpriteFrames.new()
		visual.shadow_frames.remove_animation("default")

	# ring（可选块）：单动画、恒 loop、契约 fps。
	if node.has("ring") and not (node.get("ring") is Dictionary):
		push_error("[InkMonUnitSetLoader] %s: ring is not an object" % unit_id)
		return null
	if node.get("ring") is Dictionary:
		var ring := node.get("ring") as Dictionary
		var ring_entry := _add_sequence(visual, set_dir, unit_id, RING_ANIMATION, ring, unit_fps, true, shadow_params, with_shadows)
		if ring_entry.is_empty():
			return null
		visual._ring = ring_entry

	# actions：6 向三形态展开。真帧向先装（alias/mirror 引用它的 entry）。
	# v1 契约 = 每动作单真帧向；alias_of/mirror_of 的目标必须指向它（fail loud，
	# 多真帧向是 v2 演进）。nested 节点全部形状校验后再用（坏 manifest 不得
	# runtime error——codex M4 review medium）。
	if not (node.get("actions", {}) is Dictionary):
		push_error("[InkMonUnitSetLoader] %s: actions is not an object" % unit_id)
		return null
	var actions := node.get("actions", {}) as Dictionary
	for action_value in actions.keys():
		var action := str(action_value)
		if not (actions[action_value] is Dictionary):
			push_error("[InkMonUnitSetLoader] %s/%s: action node is not an object" % [unit_id, action])
			return null
		var dirs := actions[action_value] as Dictionary
		var true_dir := ""
		for dir_key in dirs.keys():
			if not (dirs[dir_key] is Dictionary):
				push_error("[InkMonUnitSetLoader] %s/%s d%s: direction node is not an object" % [unit_id, action, str(dir_key)])
				return null
			if (dirs[dir_key] as Dictionary).has("frames"):
				true_dir = str(dir_key)
				break
		if true_dir.is_empty():
			push_error("[InkMonUnitSetLoader] %s/%s: no true-frame direction" % [unit_id, action])
			return null
		var true_node := dirs[true_dir] as Dictionary
		var anim := "%s_d%s" % [action, true_dir]
		var fps := float(true_node.get("fps_override", unit_fps))
		var loop := bool(true_node.get("loop", false))
		var true_entry := _add_sequence(visual, set_dir, unit_id, anim, true_node, fps, loop, shadow_params, with_shadows)
		if true_entry.is_empty():
			return null
		var table := {}
		table[true_dir] = true_entry
		for dir_key in dirs.keys():
			var dir_str := str(dir_key)
			if dir_str == true_dir:
				continue
			var fill := dirs[dir_key] as Dictionary
			if fill.has("alias_of"):
				if str(fill.get("alias_of")) != true_dir:
					push_error("[InkMonUnitSetLoader] %s/%s d%s: alias_of %s ≠ true dir %s（v1 单真帧向）" % [unit_id, action, dir_str, str(fill.get("alias_of")), true_dir])
					return null
				var alias_entry := true_entry.duplicate()
				alias_entry["kind"] = "alias"
				table[dir_str] = alias_entry
			elif fill.has("mirror_of"):
				if str(fill.get("mirror_of")) != true_dir:
					push_error("[InkMonUnitSetLoader] %s/%s d%s: mirror_of %s ≠ true dir %s（v1 单真帧向）" % [unit_id, action, dir_str, str(fill.get("mirror_of")), true_dir])
					return null
				# 契约镜像规则：flip_h + anchor_x' = size_x − anchor_x ⇒
				# centered offset.x 取反。影不随镜像（shadow_offset 保持真帧向）。
				var mirror_entry := true_entry.duplicate()
				mirror_entry["kind"] = "mirror"
				mirror_entry["mirrored"] = true
				var off := mirror_entry["offset"] as Vector2
				mirror_entry["offset"] = Vector2(-off.x, off.y)
				table[dir_str] = mirror_entry
			else:
				push_error("[InkMonUnitSetLoader] %s/%s d%s: neither frames/alias_of/mirror_of" % [unit_id, action, dir_str])
				return null
		visual._actions[action] = table
	return visual


## 一段真帧序列 → SpriteFrames 动画（+可选影动画）+ 方向条目。失败返 {}。
static func _add_sequence(visual: UnitVisual, set_dir: String, unit_id: String, anim: String, node: Dictionary, fps: float, loop: bool, shadow_params: Dictionary, with_shadows: bool) -> Dictionary:
	var frames := node.get("frames", []) as Array
	var size_arr := node.get("size_px", []) as Array
	var anchor_arr := node.get("anchor_px", []) as Array
	if frames.is_empty() or size_arr.size() != 2 or anchor_arr.size() != 2:
		push_error("[InkMonUnitSetLoader] %s/%s: malformed sequence node" % [unit_id, anim])
		return {}
	var size_px := Vector2(float(size_arr[0]), float(size_arr[1]))
	var anchor_px := Vector2(float(anchor_arr[0]), float(anchor_arr[1]))
	var src_frames_value: Variant = node.get("src_frames", [])
	var src_frames: Array = src_frames_value if src_frames_value is Array else []

	visual.sprite_frames.add_animation(anim)
	visual.sprite_frames.set_animation_speed(anim, fps)
	visual.sprite_frames.set_animation_loop(anim, loop)
	if with_shadows:
		visual.shadow_frames.add_animation(anim)
		visual.shadow_frames.set_animation_speed(anim, fps)
		visual.shadow_frames.set_animation_loop(anim, loop)

	var shadow_offset := Vector2.ZERO
	for frame_value in frames:
		var rel := str(frame_value)
		var tex := load("%s/%s" % [set_dir, rel]) as Texture2D
		if tex == null:
			push_error("[InkMonUnitSetLoader] %s: frame load failed: %s" % [unit_id, rel])
			return {}
		visual.sprite_frames.add_frame(anim, tex)
		if with_shadows:
			var shadow := _make_shadow(tex.get_image(), anchor_px.x, shadow_params)
			if shadow.is_empty():
				return {}
			var shadow_img := shadow["image"] as Image
			var feet := shadow["feet"] as Vector2
			visual.shadow_frames.add_frame(anim, ImageTexture.create_from_image(shadow_img))
			# centered shadow sprite 对齐脚线锚点：offset = size/2 − feet。
			shadow_offset = Vector2(
				float(shadow_img.get_width()) * 0.5 - feet.x,
				float(shadow_img.get_height()) * 0.5 - feet.y)

	return {
		"animation": anim,
		"mirrored": false,
		# 契约锚定：centered sprite，offset = size/2 − anchor（probe 同公式）。
		"offset": Vector2(size_px.x * 0.5 - anchor_px.x, size_px.y * 0.5 - anchor_px.y),
		"shadow_offset": shadow_offset,
		"size_px": size_px,
		"fps": fps,
		"loop": loop,
		"stride_world": float(node.get("stride_world", 0.0)),
		"kind": "true",
		"src_frames": src_frames,
		"src_frame_count": int(node.get("src_frame_count", 0)),
	}


## 程序影（契约 projection.unit_shadow 四参；Lab 探针 make_shadow 同流程的
## **近似实现**——流程同款：alpha 剪影 → 竖直压扁 squash → 脚线翻转（影从
## 脚线向画面下方展开，影尖=头部落右下）→ 向右斜切 shear → 模糊 blur_px →
## 半透黑 alpha（烧进像素）；feet 锚点公式与 PIL 版同式。
## 返回 { image, feet: Vector2 }（feet = 影画布内脚线锚点，对齐 sprite 锚点）。
##
## 与 PIL 原版的已知近似差（v1 预推，零逐像素路径；观感留验收任务复核，
## shader 实时是 v2 候选）：①剪影 mask = alpha>0（原版 α>40 二值阈，边缘略宽，
## blur 后柔化）②压扁重采样 bilinear（原版 LANCZOS）③模糊 = 双线性下采样↔
## 上采样近似（Godot Image 无内建高斯）④画布宽度含保守余量（margin 行参与
## shear 的上界，不裁影只多几像素透明边）。
static func _make_shadow(src: Image, anchor_x: float, params: Dictionary) -> Dictionary:
	if src == null or src.is_empty():
		push_error("[InkMonUnitSetLoader] shadow source image is empty")
		return {}
	var squash := float(params.get("squash", 0.35))
	var shear := float(params.get("shear", 0.55))
	var blur_px := int(params.get("blur_px", 7))
	var alpha := float(params.get("alpha", 0.33))

	var w := src.get_width()
	var h := src.get_height()
	var sh := maxi(1, roundi(float(h) * squash))
	# 压扁（先缩小再处理，后续行 blit 的量随之减少）+ 脚线翻转。
	var squashed := src.duplicate() as Image
	if squashed.get_format() != Image.FORMAT_RGBA8:
		squashed.convert(Image.FORMAT_RGBA8)
	squashed.resize(w, sh, Image.INTERPOLATE_BILINEAR)
	squashed.flip_y()

	var margin := blur_px * 2
	var out_w := w + int(ceilf(float(sh + margin * 2) * shear)) + margin * 2
	var out_h := sh + margin * 2
	var canvas := Image.create(out_w, out_h, false, Image.FORMAT_RGBA8)
	# 半透黑源（alpha 直接烧进像素）：mask = 压扁剪影的 alpha。
	var black := Image.create(w, sh, false, Image.FORMAT_RGBA8)
	black.fill(Color(0.0, 0.0, 0.0, alpha))
	# 斜切：行 r（画布 y = margin + r）右移 shear × (margin + r)（PIL 逆仿射同款：
	# 整画布 transform，margin 行也参与 —— feet.x 含 shear·margin 项）。
	for r in range(sh):
		var y := margin + r
		var dx := margin + roundi(shear * float(y))
		canvas.blit_rect_mask(black, squashed, Rect2i(0, r, w, 1), Vector2i(dx, y))
	# 模糊近似：双线性下采样 ↔ 上采样（blur_px 控制下采样因子）。
	if blur_px > 0:
		var factor := maxi(2, int(float(blur_px) / 2.0))
		var small_w := maxi(1, int(float(out_w) / float(factor)))
		var small_h := maxi(1, int(float(out_h) / float(factor)))
		canvas.resize(small_w, small_h, Image.INTERPOLATE_BILINEAR)
		canvas.resize(out_w, out_h, Image.INTERPOLATE_BILINEAR)

	return {
		"image": canvas,
		"feet": Vector2(float(margin) + anchor_x + shear * float(margin), float(margin)),
	}
