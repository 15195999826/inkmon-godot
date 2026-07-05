class_name InkMonMapBakeMath
## 大地图场烘焙 (adr/0012 决定四, A3 版): 每世界一次把 raw 场 → 秩归一 → 真模糊
## 烘成两张场纹理 + CDF LUT, 风格 shader (world_map_sheet) 只做上色。
##
## 两条路径, 同一纹理契约:
## - GPU 多 pass (运行时, 40px/单位 = 基准图 mockgen 同密度): fields → CDF(CPU 子采样)
##   → rank → box×3 模糊链×4 → pack。~1s/世界。
## - CPU 低密度 fallback (headless/无渲染, 4px/单位): smoke 只要求链路不炸, 不看像素。
##
## 纹理契约 (world_map_sheet.gdshader 消费):
## - field_tex: R=elev_raw×海岸压制 G=moist_raw B=land_f A=t_noise01
## - shade_tex: R=blur(rank·land, σ0.2u) G=blur(land, σ0.55u) B=blur(land, σ1.3u) A=blur(land, σ3.2u)
## - cdf_tex (8192×1 RGF): raw 归一 → 秩01 (R=elev, G=moist; 域=陆地像素, mock pctl_norm)
## - ranges: emin/erange/mmin/mrange (raw → LUT 输入的归一)


const FIELDS_SHADER := preload("res://inkmon/presentation/mission/map_gpu_fields.gdshader")
const RANK_SHADER := preload("res://inkmon/presentation/mission/map_gpu_rank.gdshader")
const BLUR_SHADER := preload("res://inkmon/presentation/mission/map_gpu_boxblur.gdshader")
const PACK_SHADER := preload("res://inkmon/presentation/mission/map_gpu_pack.gdshader")

const GPU_PX_PER_UNIT := 40.0
const CPU_PX_PER_UNIT := 2.0
const CDF_BINS := 8192
## mock 模糊 σ (平面单位): shade 0.2 / near 0.55 / shallow 1.3 / depth 3.2。
const SIGMA_SHADE := 0.2
const SIGMA_NEAR := 0.55
const SIGMA_SHALLOW := 1.3
const SIGMA_DEPTH := 3.2


## GPU 多 pass 烘焙 (host = 树内节点, SubViewport 挂它下面渲)。
static func bake_gpu(host: Node, map: InkMonWorldMapData) -> Dictionary:
	var land_rect := map.land_plane_rect()
	var margin := InkMonWorldMapData.OCEAN_MARGIN
	var width_px := int((land_rect.size.x + margin * 2.0) * GPU_PX_PER_UNIT)
	var height_px := int((land_rect.size.y + margin * 2.0) * GPU_PX_PER_UNIT)
	var size := Vector2i(width_px, height_px)
	var fields_image := await _render_pass(host, size, FIELDS_SHADER, {
		"u_seed": map.generation_seed,
		"u_land_w": land_rect.size.x, "u_land_h": land_rect.size.y,
		"u_margin": margin, "u_px_per_unit": GPU_PX_PER_UNIT,
	}, true)
	if fields_image == null or fields_image.is_empty():
		# 无真渲染环境 (headless GPU 出空图) → CPU fallback 保链路。
		return bake_cpu(map, CPU_PX_PER_UNIT)
	var fields_texture := ImageTexture.create_from_image(fields_image)
	var cdf := _cdf_from_image(fields_image, 4)
	var rank_image := await _render_pass(host, size, RANK_SHADER, {
		"u_fields": fields_texture, "u_cdf": cdf.get("texture"),
		"u_emin": cdf.get("emin"), "u_erange": cdf.get("erange"),
	}, true)
	var rank_texture := ImageTexture.create_from_image(rank_image)
	# shade 链保全分辨率 (hillshade 梯度源); 三条海带链降半分辨率跑 (低频带, 上采样不可见,
	# 深链半径 128→64, 总 fetch 成本 /8 —— codex review 性能项)。
	var half_size := Vector2i(maxi(size.x / 2, 4), maxi(size.y / 2, 4))
	var half_radius := GPU_PX_PER_UNIT * 0.5
	var rank_half_image := await _render_pass(host, half_size, PACK_SHADER, {
		"u_shade_blur": rank_texture, "u_near_blur": rank_texture,
		"u_shallow_blur": rank_texture, "u_depth_blur": rank_texture,
	}, true)
	var rank_half := ImageTexture.create_from_image(rank_half_image)
	var shade_blur := await _blur_chain_gpu(host, size, rank_texture, roundi(SIGMA_SHADE * GPU_PX_PER_UNIT))
	var near_blur := await _blur_chain_gpu(host, half_size, rank_half, roundi(SIGMA_NEAR * half_radius))
	var shallow_blur := await _blur_chain_gpu(host, half_size, rank_half, roundi(SIGMA_SHALLOW * half_radius))
	var depth_blur := await _blur_chain_gpu(host, half_size, rank_half, roundi(SIGMA_DEPTH * half_radius))
	var shade_image := await _render_pass(host, size, PACK_SHADER, {
		"u_shade_blur": shade_blur, "u_near_blur": near_blur,
		"u_shallow_blur": shallow_blur, "u_depth_blur": depth_blur,
	}, true)
	return {
		"field_tex": fields_texture,
		"shade_tex": ImageTexture.create_from_image(shade_image),
		"cdf_tex": cdf.get("texture"),
		"emin": cdf.get("emin"), "erange": cdf.get("erange"),
		"mmin": cdf.get("mmin"), "mrange": cdf.get("mrange"),
	}


## CPU fallback (headless): 同契约低密度。逐像素值噪声在 GDScript 是 float64 —— 与 GPU
## float32 的差属同源近似口径; 密度低到只保"链路可跑", 不用于观感。
static func bake_cpu(map: InkMonWorldMapData, px_per_unit: float) -> Dictionary:
	var land_rect := map.land_plane_rect()
	var margin := InkMonWorldMapData.OCEAN_MARGIN
	var width_px := maxi(int((land_rect.size.x + margin * 2.0) * px_per_unit), 8)
	var height_px := maxi(int((land_rect.size.y + margin * 2.0) * px_per_unit), 8)
	var count := width_px * height_px
	var seed_value := map.generation_seed
	var elev := PackedFloat32Array()
	var moist := PackedFloat32Array()
	var land_f := PackedFloat32Array()
	var tnoise := PackedFloat32Array()
	elev.resize(count)
	moist.resize(count)
	land_f.resize(count)
	tnoise.resize(count)
	for py in range(height_px):
		var plane_y := -margin + (float(py) + 0.5) / px_per_unit
		for px in range(width_px):
			var index := py * width_px + px
			var plane := Vector2(-margin + (float(px) + 0.5) / px_per_unit, plane_y)
			var warped := InkMonWorldMapData.warp_plane(plane, seed_value)
			var land_value := map.land_factor_at(plane)
			elev[index] = InkMonWorldMapData.raw_elevation_at(warped, seed_value) \
				* smoothstep(0.5, 0.75, land_value)
			moist[index] = InkMonWorldMapData.raw_moisture_at(warped, seed_value)
			land_f[index] = land_value
			tnoise[index] = InkMonWorldMapData.temperature_noise_at(plane, seed_value)
	var cdf := _cdf_from_grids(elev, moist, land_f)
	var emin := float(cdf.get("emin"))
	var erange := float(cdf.get("erange"))
	var cdf_elev := cdf.get("elev_cdf") as PackedFloat32Array
	var rank_land := PackedFloat32Array()
	var land01 := PackedFloat32Array()
	rank_land.resize(count)
	land01.resize(count)
	for index in range(count):
		var land_step := 1.0 if land_f[index] >= 0.5 else 0.0
		land01[index] = land_step
		var bin := clampi(int((elev[index] - emin) / erange * float(CDF_BINS - 1)), 0, CDF_BINS - 1)
		rank_land[index] = cdf_elev[bin] * land_step
	var shade := _box_blur3(rank_land, width_px, height_px, maxi(roundi(SIGMA_SHADE * px_per_unit), 1))
	var near := _box_blur3(land01, width_px, height_px, maxi(roundi(SIGMA_NEAR * px_per_unit), 1))
	var shallow := _box_blur3(land01, width_px, height_px, maxi(roundi(SIGMA_SHALLOW * px_per_unit), 1))
	var depth := _box_blur3(land01, width_px, height_px, maxi(roundi(SIGMA_DEPTH * px_per_unit), 1))
	var field_image := Image.create(width_px, height_px, false, Image.FORMAT_RGBAH)
	var shade_image := Image.create(width_px, height_px, false, Image.FORMAT_RGBAH)
	for py in range(height_px):
		for px in range(width_px):
			var index := py * width_px + px
			field_image.set_pixel(px, py, Color(elev[index], moist[index], land_f[index], tnoise[index]))
			shade_image.set_pixel(px, py, Color(shade[index], near[index], shallow[index], depth[index]))
	return {
		"field_tex": ImageTexture.create_from_image(field_image),
		"shade_tex": ImageTexture.create_from_image(shade_image),
		"cdf_tex": cdf.get("texture"),
		"emin": emin, "erange": erange,
		"mmin": cdf.get("mmin"), "mrange": cdf.get("mrange"),
	}


# === GPU pass 基建 ===


static func _render_pass(host: Node, size: Vector2i, shader: Shader, uniforms: Dictionary, hdr: bool) -> Image:
	# host 失效 (切场景/释放 view) → 空图短路; 调用方契约: 空图不得当有效结果应用
	# (fields 空走 CPU fallback, 链中空最终被 epoch/valid 守卫拦下)。
	if not is_instance_valid(host) or not host.is_inside_tree():
		return Image.create(2, 2, false, Image.FORMAT_RGBAH)
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.use_hdr_2d = hdr
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var rect := ColorRect.new()
	rect.size = Vector2(size)
	var material := ShaderMaterial.new()
	material.shader = shader
	for uniform_name in uniforms:
		material.set_shader_parameter(str(uniform_name), uniforms[uniform_name])
	rect.material = material
	viewport.add_child(rect)
	host.add_child(viewport)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	viewport.queue_free()
	return image


## box×3 分离模糊链; 半径序列 [r, r, r-Δ] 把合成 σ 贴到高斯 σ=r。
static func _blur_chain_gpu(host: Node, size: Vector2i, source: ImageTexture, radius: int) -> ImageTexture:
	var radii: Array[int] = [radius, radius, maxi(radius - (2 if radius > 60 else 1), 1)]
	var current := source
	for round_index in range(3):
		var round_radius: int = radii[round_index]
		var horizontal := await _render_pass(host, size, BLUR_SHADER, {
			"u_tex": current, "u_radius": round_radius,
			"u_dir_texel": Vector2(1.0 / float(size.x), 0.0),
		}, true)
		current = ImageTexture.create_from_image(horizontal)
		var vertical := await _render_pass(host, size, BLUR_SHADER, {
			"u_tex": current, "u_radius": round_radius,
			"u_dir_texel": Vector2(0.0, 1.0 / float(size.y)),
		}, true)
		current = ImageTexture.create_from_image(vertical)
	return current


# === CDF (mock pctl_norm: 陆地像素域 percentile) ===


static func _cdf_from_image(fields_image: Image, stride: int) -> Dictionary:
	var elev_samples := PackedFloat32Array()
	var moist_samples := PackedFloat32Array()
	for py in range(0, fields_image.get_height(), stride):
		for px in range(0, fields_image.get_width(), stride):
			var pixel := fields_image.get_pixel(px, py)
			if pixel.b >= 0.5:
				elev_samples.append(pixel.r)
				moist_samples.append(pixel.g)
	return _cdf_from_samples(elev_samples, moist_samples)


static func _cdf_from_grids(elev: PackedFloat32Array, moist: PackedFloat32Array,
		land_f: PackedFloat32Array) -> Dictionary:
	var elev_samples := PackedFloat32Array()
	var moist_samples := PackedFloat32Array()
	for index in range(elev.size()):
		if land_f[index] >= 0.5:
			elev_samples.append(elev[index])
			moist_samples.append(moist[index])
	return _cdf_from_samples(elev_samples, moist_samples)


static func _cdf_from_samples(elev_samples: PackedFloat32Array, moist_samples: PackedFloat32Array) -> Dictionary:
	Log.assert_crash(not elev_samples.is_empty(), "InkMonMapBakeMath", "cdf needs land samples")
	elev_samples.sort()
	moist_samples.sort()
	var emin := elev_samples[0]
	var erange := maxf(elev_samples[elev_samples.size() - 1] - emin, 1e-9)
	var mmin := moist_samples[0]
	var mrange := maxf(moist_samples[moist_samples.size() - 1] - mmin, 1e-9)
	var lut := Image.create(CDF_BINS, 1, false, Image.FORMAT_RGF)
	var elev_cdf := PackedFloat32Array()
	elev_cdf.resize(CDF_BINS)
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
		var elev_rank := float(elev_cursor) / float(elev_samples.size())
		elev_cdf[bin_index] = elev_rank
		lut.set_pixel(bin_index, 0, Color(elev_rank, float(moist_cursor) / float(moist_samples.size()), 0.0, 1.0))
	return {
		"texture": ImageTexture.create_from_image(lut),
		"elev_cdf": elev_cdf,
		"emin": emin, "erange": erange, "mmin": mmin, "mrange": mrange,
	}


## box 模糊 ×3 ≈ 高斯 (CPU fallback 用; 分离 + 运行和, O(n) 每趟)。
static func _box_blur3(values: PackedFloat32Array, grid_width: int, grid_height: int, radius_px: int) -> PackedFloat32Array:
	var current := values
	for _pass_index in range(3):
		current = _box_blur_axis(current, grid_width, grid_height, radius_px, true)
		current = _box_blur_axis(current, grid_width, grid_height, radius_px, false)
	return current


static func _box_blur_axis(values: PackedFloat32Array, grid_width: int, grid_height: int,
		radius_px: int, horizontal: bool) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	result.resize(values.size())
	var lanes := grid_height if horizontal else grid_width
	var lane_length := grid_width if horizontal else grid_height
	var stride := 1 if horizontal else grid_width
	var window := float(radius_px * 2 + 1)
	for lane in range(lanes):
		var base := lane * grid_width if horizontal else lane
		var running := 0.0
		for offset in range(-radius_px, radius_px + 1):
			running += values[base + clampi(offset, 0, lane_length - 1) * stride]
		for position in range(lane_length):
			result[base + position * stride] = running / window
			var leaving := clampi(position - radius_px, 0, lane_length - 1)
			var entering := clampi(position + radius_px + 1, 0, lane_length - 1)
			running += values[base + entering * stride] - values[base + leaving * stride]
	return result
