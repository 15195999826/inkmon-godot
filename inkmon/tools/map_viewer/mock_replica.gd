extends Node2D
## mockgen.py 的 Godot 1:1 复刻 (dev 工具): SEED 20260705, 画布 1660×1247 @ 40px/单位,
## 值噪声 uint32 hash 位级同源, 处理链逐字对齐 (场 → 陆地掩膜秩归一 → box×3 模糊 →
## build("C") 上色 → 河流折线[python 导出数据])。产出 replica_c.png 与 mock_style_C.png
## 逐像素对比 —— 渲染能力争议的最终裁决场景。
## 跑法: F6; 附 --replica-quit (user args) = 烘完存图即退。


const WPX := 1660
const HPX := 1247
const OUT_PATH := "res://.claude/tmp/replica_c.png"
const RIVERS_JSON := "res://inkmon/tools/map_viewer/mock_rivers_c.json"

const FIELDS_SHADER := preload("res://inkmon/tools/map_viewer/replica_fields.gdshader")
const RANK_SHADER := preload("res://inkmon/tools/map_viewer/replica_rank.gdshader")
const BLUR_SHADER := preload("res://inkmon/tools/map_viewer/replica_boxblur.gdshader")
const COLORIZE_SHADER := preload("res://inkmon/tools/map_viewer/replica_colorize.gdshader")

## PIL GaussianBlur(σ) ≈ box×3(radius=σ): shade σ8px / near σ22 / shallow σ52 / depth σ128。
const BLUR_SHADE := 8
const BLUR_NEAR := 22
const BLUR_SHALLOW := 52
const BLUR_DEPTH := 128
const CDF_BINS := 8192


var _status_label: Label = null


func _ready() -> void:
	get_window().size = Vector2i(1600, 900)
	get_window().title = "Mock Replica (python mockgen 1:1)"
	_status_label = Label.new()
	_status_label.position = Vector2(16, 12)
	_status_label.text = "baking replica..."
	add_child(_status_label)
	await _bake()


func _bake() -> void:
	var started := Time.get_ticks_msec()
	# ① raw 场 (GPU, 位级同源值噪声)
	_status("fields pass...")
	var fields_image := await _render_pass(FIELDS_SHADER, {}, true)
	var fields_texture := ImageTexture.create_from_image(fields_image)
	# ② CDF (CPU, 陆地像素域 percentile —— mock pctl_norm)
	_status("cdf...")
	var cdf := _build_cdf(fields_image)
	var cdf_texture := cdf.get("texture") as ImageTexture
	# ③ 秩 prep → 模糊链 (GPU)
	_status("rank prep...")
	var rank_image := await _render_pass(RANK_SHADER, {
		"u_fields": fields_texture, "u_cdf": cdf_texture,
		"u_emin": cdf.get("emin"), "u_erange": cdf.get("erange"),
	}, true)
	var rank_texture := ImageTexture.create_from_image(rank_image)
	_status("blur chains...")
	var shade_texture := await _blur_chain(rank_texture, BLUR_SHADE)
	var near_texture := await _blur_chain(rank_texture, BLUR_NEAR)
	var shallow_texture := await _blur_chain(rank_texture, BLUR_SHALLOW)
	var depth_texture := await _blur_chain(rank_texture, BLUR_DEPTH)
	# ④ 上色 (GPU, build("C") 逐字)
	_status("colorize...")
	var color_image := await _render_pass(COLORIZE_SHADER, {
		"u_fields": fields_texture, "u_cdf": cdf_texture,
		"u_shade": shade_texture, "u_near": near_texture,
		"u_shallow": shallow_texture, "u_depth": depth_texture,
		"u_emin": cdf.get("emin"), "u_erange": cdf.get("erange"),
		"u_mmin": cdf.get("mmin"), "u_mrange": cdf.get("mrange"),
		"u_texel": Vector2(1.0 / float(WPX), 1.0 / float(HPX)),
	}, false)
	# ⑤ 河流 (python 导出折线, PIL 同款宽度渐变) 直接画进 Image
	_status("rivers...")
	_draw_rivers_into(color_image)
	var absolute := ProjectSettings.globalize_path(OUT_PATH)
	color_image.save_png(absolute)
	print("REPLICA_SAVED: %s (%.1fs)" % [absolute, float(Time.get_ticks_msec() - started) / 1000.0])
	# 展示 (fit 窗口)
	var texture_rect := TextureRect.new()
	texture_rect.texture = ImageTexture.create_from_image(color_image)
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_rect.size = get_viewport().get_visible_rect().size
	add_child(texture_rect)
	_status("replica ready: %s" % absolute)
	move_child(_status_label, get_child_count() - 1)
	if OS.get_cmdline_user_args().has("--replica-quit"):
		await RenderingServer.frame_post_draw
		get_tree().quit(0)


func _status(text_value: String) -> void:
	_status_label.text = text_value
	print("[replica] %s" % text_value)


## 单趟全屏 shader 渲染 → Image (hdr = RGBA16F, 场/模糊用; 否则 8bpc)。
func _render_pass(shader: Shader, uniforms: Dictionary, hdr: bool) -> Image:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(WPX, HPX)
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.use_hdr_2d = hdr
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var rect := ColorRect.new()
	rect.size = Vector2(WPX, HPX)
	var material := ShaderMaterial.new()
	material.shader = shader
	for uniform_name in uniforms:
		material.set_shader_parameter(str(uniform_name), uniforms[uniform_name])
	rect.material = material
	viewport.add_child(rect)
	add_child(viewport)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	viewport.queue_free()
	return image


## box×3 分离模糊链 (6 趟渲染), 返回终态纹理。半径序列 [r, r, r-?] 把合成 σ 贴到
## PIL GaussianBlur(σ=r) (纯 box×3(r) 的 σ ≈ r+0.5, 略糊)。
func _blur_chain(source: ImageTexture, radius: int) -> ImageTexture:
	var radii: Array[int] = [radius, radius, maxi(radius - (2 if radius > 60 else 1), 1)]
	var current := source
	for round_index in range(3):
		var round_radius: int = radii[round_index]
		var horizontal := await _render_pass(BLUR_SHADER, {
			"u_tex": current, "u_radius": round_radius,
			"u_dir_texel": Vector2(1.0 / float(WPX), 0.0),
		}, true)
		current = ImageTexture.create_from_image(horizontal)
		var vertical := await _render_pass(BLUR_SHADER, {
			"u_tex": current, "u_radius": round_radius,
			"u_dir_texel": Vector2(0.0, 1.0 / float(HPX)),
		}, true)
		current = ImageTexture.create_from_image(vertical)
	return current


## CDF LUT (2048×1 RGF): x → 陆地样本中 ≤(min+range·x) 的比例。R = elev, G = moist。
func _build_cdf(fields_image: Image) -> Dictionary:
	var elev_samples := PackedFloat32Array()
	var moist_samples := PackedFloat32Array()
	for py in range(0, HPX, 2):
		for px in range(0, WPX, 2):
			var pixel := fields_image.get_pixel(px, py)
			if pixel.b >= 0.5:
				elev_samples.append(pixel.r)
				moist_samples.append(pixel.g)
	elev_samples.sort()
	moist_samples.sort()
	var emin := elev_samples[0]
	var erange := maxf(elev_samples[elev_samples.size() - 1] - emin, 1e-9)
	var mmin := moist_samples[0]
	var mrange := maxf(moist_samples[moist_samples.size() - 1] - mmin, 1e-9)
	var lut := Image.create(CDF_BINS, 1, false, Image.FORMAT_RGF)
	var elev_cursor := 0
	var moist_cursor := 0
	for bin_index in range(CDF_BINS):
		var fraction := float(bin_index) / float(CDF_BINS - 1)
		var elev_value := emin + erange * fraction
		var moist_value := mmin + mrange * fraction
		while elev_cursor < elev_samples.size() and elev_samples[elev_cursor] <= elev_value:
			elev_cursor += 1
		while moist_cursor < moist_samples.size() and moist_samples[moist_cursor] <= moist_value:
			moist_cursor += 1
		lut.set_pixel(bin_index, 0, Color(
			float(elev_cursor) / float(elev_samples.size()),
			float(moist_cursor) / float(moist_samples.size()), 0.0, 1.0))
	return {
		"texture": ImageTexture.create_from_image(lut),
		"emin": emin, "erange": erange, "mmin": mmin, "mrange": mrange,
	}


## 河流: python 导出折线 (px 坐标), PIL 宽度渐变 w = 1+int(3·i/m), 色 (86,104,116,210)。
## 逐段画进 Image (粗线 = 沿段扫描圆刷, 视觉与 PIL 直线等价)。
func _draw_rivers_into(image: Image) -> void:
	var file := FileAccess.open(RIVERS_JSON, FileAccess.READ)
	if file == null:
		print("[replica] rivers json missing, skip")
		return
	var data := JSON.parse_string(file.get_as_text()) as Dictionary
	if data == null:
		return
	var color := Color(86.0 / 255.0, 104.0 / 255.0, 116.0 / 255.0, 210.0 / 255.0)
	for river_value in data.get("rivers", []) as Array:
		var points := river_value as Array
		var m := points.size()
		for i in range(1, m):
			var from_point := points[i - 1] as Array
			var to_point := points[i] as Array
			@warning_ignore("integer_division")
			var width := 1 + int(3 * i / m)
			_stamp_line(image, Vector2(float(from_point[0]), float(from_point[1])),
				Vector2(float(to_point[0]), float(to_point[1])), float(width), color)


static func _stamp_line(image: Image, from_point: Vector2, to_point: Vector2, width: float, color: Color) -> void:
	var length := from_point.distance_to(to_point)
	var steps := maxi(int(ceil(length)), 1)
	var radius := maxf(width * 0.5, 0.5)
	for step_index in range(steps + 1):
		var center := from_point.lerp(to_point, float(step_index) / float(steps))
		var r_int := int(ceil(radius))
		for oy in range(-r_int, r_int + 1):
			for ox in range(-r_int, r_int + 1):
				if Vector2(float(ox), float(oy)).length() > radius:
					continue
				var px := int(center.x) + ox
				var py := int(center.y) + oy
				if px < 0 or py < 0 or px >= image.get_width() or py >= image.get_height():
					continue
				var base := image.get_pixel(px, py)
				image.set_pixel(px, py, base.lerp(Color(color.r, color.g, color.b, 1.0), color.a))
