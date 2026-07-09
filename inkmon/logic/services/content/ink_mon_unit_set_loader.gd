class_name InkMonUnitSetLoader

## content/art/units/ 单位动画装载器（T7 M4，inkmon-unitset/1 消费端）。
##
## 已发布 set manifest（6 向三形态：frames 真帧 / alias_of 直用 / mirror_of
## 运行时翻转）→ 每单位一个 UnitVisual：SpriteFrames（真帧动画 + ring）+
## 方向表（animation / shadow_animation / mirrored / offset）+ fps(含
## fps_override) / loop / stride_world 透出 + 程序影 SpriteFrames（loader 预推
## ImageTexture 缓存，契约 projection.unit_shadow 四参；影不随镜像 = **斜向**
## 恒定，mirror 向剪影随屏上身位翻转重推——二轮验收修正 2026-07-09）。
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

	## 方向条目：{ animation, shadow_animation, mirrored, offset: Vector2,
	##   shadow_offset: Vector2, size_px: Vector2, fps: float, loop: bool,
	##   stride_world: float, kind: "true"|"alias"|"mirror", src_frames: Array,
	##   src_frame_count: int }。mirror 向 shadow_animation = 从翻转剪影重推的
	##   独立影动画（本体动画仍复用真帧向 + flip_h）。
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
## with_ring=false 跳过 ring（契约 Q3 消费端条款：ring 是图鉴/查看资产，全帧
## 发布后 121 帧 RGBA 常驻 ≈66MB VRAM/单位——world 装载免吃）。
static func load_set(set_id: String, with_shadows := true, with_ring := true) -> Dictionary:
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
		var visual := _build_unit(set_dir, unit_id, units[unit_id] as Dictionary, unit_fps, shadow_params, with_shadows, with_ring)
		if visual == null:
			return {}
		visual.px_per_unit = px_per_unit
		out[unit_id] = visual
	return out


static func _build_unit(set_dir: String, unit_id: String, node: Dictionary, unit_fps: float, shadow_params: Dictionary, with_shadows: bool, with_ring: bool) -> UnitVisual:
	var visual := UnitVisual.new()
	visual.unit_id = unit_id
	visual.unit_fps = unit_fps
	visual.sprite_frames = SpriteFrames.new()
	visual.sprite_frames.remove_animation("default")
	if with_shadows:
		visual.shadow_frames = SpriteFrames.new()
		visual.shadow_frames.remove_animation("default")

	# ring（可选块）：单动画、恒 loop；fps = fps_override（全帧发布 = src 实值，
	# 契约 Q3）缺省契约 unit_fps（legacy 抽样 ring）。
	if node.has("ring") and not (node.get("ring") is Dictionary):
		push_error("[InkMonUnitSetLoader] %s: ring is not an object" % unit_id)
		return null
	if with_ring and node.get("ring") is Dictionary:
		var ring := node.get("ring") as Dictionary
		var ring_fps := float(ring.get("fps_override", unit_fps))
		var ring_entry := _add_sequence(visual, set_dir, unit_id, RING_ANIMATION, ring, ring_fps, true, shadow_params, with_shadows)
		if ring_entry.is_empty():
			return null
		visual._ring = ring_entry

	# actions：6 向三形态展开——**多真帧向**（逐向真生成 2026-07-09，取代 v1
	# 「每动作单真帧向」约束）。两遍装配：先装全部真帧向（各自动画
	# `<action>_d<dir>`、各自 fps_override/loop），再解析 alias/mirror（目标必须
	# 是本动作内**有真帧**的方向——链式引用 fail loud）。nested 节点全部形状
	# 校验后再用（坏 manifest 不得 runtime error——codex M4 review medium）。
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
		var table := {}
		for dir_key in dirs.keys():
			if not (dirs[dir_key] is Dictionary):
				push_error("[InkMonUnitSetLoader] %s/%s d%s: direction node is not an object" % [unit_id, action, str(dir_key)])
				return null
			var dnode := dirs[dir_key] as Dictionary
			if dnode.has("frames"):
				var dir_str := str(dir_key)
				var anim := "%s_d%s" % [action, dir_str]
				var fps := float(dnode.get("fps_override", unit_fps))
				var loop := bool(dnode.get("loop", false))
				var entry := _add_sequence(visual, set_dir, unit_id, anim, dnode, fps, loop, shadow_params, with_shadows)
				if entry.is_empty():
					return null
				table[dir_str] = entry
		if table.is_empty():
			push_error("[InkMonUnitSetLoader] %s/%s: no true-frame direction" % [unit_id, action])
			return null
		for dir_key in dirs.keys():
			var dir_str := str(dir_key)
			if table.has(dir_str):
				continue
			var fill := dirs[dir_key] as Dictionary
			if fill.has("alias_of"):
				var alias_target := str(fill.get("alias_of"))
				if not table.has(alias_target) or not (dirs.get(alias_target, {}) as Dictionary).has("frames"):
					push_error("[InkMonUnitSetLoader] %s/%s d%s: alias_of %s 不是真帧向" % [unit_id, action, dir_str, alias_target])
					return null
				var alias_entry := (table[alias_target] as Dictionary).duplicate()
				alias_entry["kind"] = "alias"
				table[dir_str] = alias_entry
			elif fill.has("mirror_of"):
				var mirror_target := str(fill.get("mirror_of"))
				if not table.has(mirror_target) or not (dirs.get(mirror_target, {}) as Dictionary).has("frames"):
					push_error("[InkMonUnitSetLoader] %s/%s d%s: mirror_of %s 不是真帧向" % [unit_id, action, dir_str, mirror_target])
					return null
				# 契约镜像规则：flip_h + anchor_x' = size_x − anchor_x ⇒
				# centered offset.x 取反。影不随镜像 = **斜向不翻**（世界光向
				# 恒定）；但剪影必须跟随屏上翻转身位——mirror 向从翻转剪影重推
				# 独立影动画（2026-07-09 二轮验收修正：复用真帧向影帧会让影瓣
				# 长在翻转身位的错误一侧）。
				var mirror_entry := (table[mirror_target] as Dictionary).duplicate()
				mirror_entry["kind"] = "mirror"
				mirror_entry["mirrored"] = true
				var off := mirror_entry["offset"] as Vector2
				mirror_entry["offset"] = Vector2(-off.x, off.y)
				if visual.shadow_frames != null:
					var shadow_anim := "%s_d%s" % [action, dir_str]
					var mirror_shadow := _add_mirror_shadow(visual, set_dir, unit_id, shadow_anim, dirs.get(mirror_target, {}) as Dictionary, float(mirror_entry["fps"]), bool(mirror_entry["loop"]), shadow_params)
					if mirror_shadow.is_empty():
						return null
					mirror_entry["shadow_animation"] = shadow_anim
					mirror_entry["shadow_offset"] = mirror_shadow["shadow_offset"] as Vector2
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
			var shadow := _make_shadow(tex.get_image(), anchor_px.x, anchor_px.y, shadow_params)
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
		# 影动画名：真帧/alias = 本体动画同名；mirror 向在第二遍装配时改指
		# 独立重推的翻转剪影影动画。
		"shadow_animation": anim,
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


## mirror 向程序影：从真帧向源帧**翻转剪影**重推一套影动画（只进 shadow_frames，
## 本体仍复用真帧向动画 + flip_h）。斜切仍恒向右——「影不随镜像」限定的是斜向
## （世界光向恒定），剪影必须随屏上身位（二轮验收修正 2026-07-09）。
## feet 锚点用镜像锚 anchor_x' = size_x − anchor_x（与本体 flip 后脚点对齐）。
## 返回 { shadow_offset: Vector2 }；失败 push_error 返 {}。
static func _add_mirror_shadow(visual: UnitVisual, set_dir: String, unit_id: String, shadow_anim: String, target_node: Dictionary, fps: float, loop: bool, shadow_params: Dictionary) -> Dictionary:
	var frames := target_node.get("frames", []) as Array
	var size_arr := target_node.get("size_px", []) as Array
	var anchor_arr := target_node.get("anchor_px", []) as Array
	if frames.is_empty() or size_arr.size() != 2 or anchor_arr.size() != 2:
		push_error("[InkMonUnitSetLoader] %s/%s: malformed mirror target node" % [unit_id, shadow_anim])
		return {}
	var mirror_anchor_x := float(size_arr[0]) - float(anchor_arr[0])
	var anchor_y := float(anchor_arr[1])
	visual.shadow_frames.add_animation(shadow_anim)
	visual.shadow_frames.set_animation_speed(shadow_anim, fps)
	visual.shadow_frames.set_animation_loop(shadow_anim, loop)
	var shadow_offset := Vector2.ZERO
	for frame_value in frames:
		var rel := str(frame_value)
		# 真帧向已 load 过同名资源——资源缓存命中，代价只有 get_image + flip。
		var tex := load("%s/%s" % [set_dir, rel]) as Texture2D
		if tex == null:
			push_error("[InkMonUnitSetLoader] %s: mirror shadow frame load failed: %s" % [unit_id, rel])
			return {}
		# get_image() 在部分渲染后端(headless dummy)返回资源内部缓存的引用——
		# flip 前必须 duplicate,否则污染缓存(load_set 失幂等:同进程后续
		# get_image 全被翻转;实测 smoke 重推对比踩中)。
		var img := tex.get_image().duplicate() as Image
		img.flip_x()
		var shadow := _make_shadow(img, mirror_anchor_x, anchor_y, shadow_params)
		if shadow.is_empty():
			return {}
		var shadow_img := shadow["image"] as Image
		var feet := shadow["feet"] as Vector2
		visual.shadow_frames.add_frame(shadow_anim, ImageTexture.create_from_image(shadow_img))
		shadow_offset = Vector2(
			float(shadow_img.get_width()) * 0.5 - feet.x,
			float(shadow_img.get_height()) * 0.5 - feet.y)
	return {"shadow_offset": shadow_offset}


## 程序影（契约 projection.unit_shadow 四参；Lab 探针 make_shadow 同流程的
## **近似实现**——流程同款：alpha 剪影 → 竖直压扁 squash → 脚线翻转（影从
## 脚线向画面下方展开，影尖=头部落右下）→ 向右斜切 shear → 模糊 blur_px →
## 半透黑 alpha（烧进像素）；feet 锚点公式与 PIL 版同式。
## 返回 { image, feet: Vector2 }（feet = 影画布内脚线锚点，对齐 sprite 锚点）。
##
## 脚线基准 = 序列轴锚地线 anchor_y（2026-07-09 首验收⑤修复：原实现拿画布底行
## 当脚线——union 共享画布内逐帧触地 ≠ 画布底（a03 实测 ±10px 漂移），背身帧
## 影上爬 ~11px、侧身帧影悬空 ~17px。地线以上剪影参与投影；低于中位地线的
## 脚尖在地平面上，影在其正下被本体遮蔽，忽略）。
##
## 与 PIL 原版的已知近似差（v1 预推，零逐像素路径；观感留验收任务复核，
## shader 实时是 v2 候选）：①剪影 mask = alpha>0（原版 α>40 二值阈，边缘略宽，
## blur 后柔化）②压扁重采样 bilinear（原版 LANCZOS）③模糊 = 双线性下采样↔
## 上采样近似（Godot Image 无内建高斯）④画布宽度含保守余量（margin 行参与
## shear 的上界，不裁影只多几像素透明边）。
static func _make_shadow(src: Image, anchor_x: float, anchor_y: float, params: Dictionary) -> Dictionary:
	if src == null or src.is_empty():
		push_error("[InkMonUnitSetLoader] shadow source image is empty")
		return {}
	var squash := float(params.get("squash", 0.35))
	var shear := float(params.get("shear", 0.55))
	var blur_px := int(params.get("blur_px", 7))
	var alpha := float(params.get("alpha", 0.33))

	var w := src.get_width()
	var h := src.get_height()
	var ground_row := clampi(roundi(anchor_y), 0, h - 1)
	var gh := ground_row + 1
	var sh := maxi(1, roundi(float(gh) * squash))
	# 地线以上区域压扁（先缩小再处理，后续行 blit 的量随之减少）+ 脚线翻转。
	var squashed := src.get_region(Rect2i(0, 0, w, gh))
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
