class_name InkMonMapBakeMath
## 大地图 CPU 烘焙数学 (adr/0012 决定四, "python 处理流程" 版):
## 采样网格 → 逐像素秩归一 (陆地像素域) → box×3 分离模糊 (≈高斯) → 场纹理 / 参照图。
##
## 两个消费方:
## - InkMonMissionMapView: 烘 field_tex (rank 场直存) + shade_tex (模糊着色场 + 三档模糊陆地带),
##   shader 只做上色/墨线/面片 —— 需要低通的一切都在这里真模糊, shader 稀疏差分冒充模糊
##   会让阴影与色块形体不同频, 读作"云影贴花"而非地形阴面 (用户对照踩过)。
## - map_viewer 的 Ref 模式: bake_reference_image 把整条 python 管线逐像素烘成参照图,
##   与 shader 版 A/B 定位渲染差异 (同一世界同一数值, 只差实现)。
##
## 域约定: 网格覆盖 sheet 矩形 (可玩 ± OCEAN_MARGIN), row-major, PX_PER_UNIT 采样密度。


const PX_PER_UNIT := 10.0
## 着色场模糊半径 (平面单位, mock 的 σ0.2u 高斯; box×3 半径 ≈ σ·1.73 → 0.115u/px 档取 2px×3)。
const SHADE_BLUR_RADIUS_PX := 2
## 三档陆地带模糊 (mock: near_sea σ0.55u / shallow σ1.3u / depth σ3.2u; box×3 半径 ≈ σ)。
const LAND_BLUR_NEAR_PX := 6
const LAND_BLUR_SHALLOW_PX := 13
const LAND_BLUR_DEPTH_PX := 32
## 秩归一直方图桶数 (逐像素 percentile 的 O(n) 实现)。
const RANK_BINS := 2048


## 采样网格包: 一次算好全部 raw 场 (后续秩/模糊/上色共用)。
## 返回 {width, height, rect, elev_rank, moist_rank, land01, land_soft, coast01, mottle01}。
static func sample_grids(map: InkMonWorldMapData) -> Dictionary:
	var play_rect := Rect2(0.0, 0.0, float(map.width - 1) + 0.5, float(map.height - 1) * sqrt(3.0) / 2.0)
	var rect := play_rect.grow(InkMonWorldMapData.OCEAN_MARGIN)
	var grid_width := maxi(8, int(ceil(rect.size.x * PX_PER_UNIT)))
	var grid_height := maxi(8, int(ceil(rect.size.y * PX_PER_UNIT)))
	var count := grid_width * grid_height
	var elevation_noise := InkMonWorldMapData.make_elevation_noise(map.generation_seed)
	var ridge_noise := InkMonWorldMapData.make_ridge_noise(map.generation_seed)
	var moisture_noise := InkMonWorldMapData.make_moisture_noise(map.generation_seed)
	var coast_noise := InkMonWorldMapData.make_coast_noise(map.generation_seed)
	var mottle_noise := _make_mottle_noise(map.generation_seed)
	var elev_raw := PackedFloat32Array()
	var moist_raw := PackedFloat32Array()
	var land01 := PackedFloat32Array()
	var land_soft := PackedFloat32Array()
	var coast01 := PackedFloat32Array()
	var mottle01 := PackedFloat32Array()
	elev_raw.resize(count)
	moist_raw.resize(count)
	land01.resize(count)
	land_soft.resize(count)
	coast01.resize(count)
	mottle01.resize(count)
	for py in range(grid_height):
		var plane_y := rect.position.y + (float(py) + 0.5) / PX_PER_UNIT
		for px in range(grid_width):
			var index := py * grid_width + px
			var plane := Vector2(rect.position.x + (float(px) + 0.5) / PX_PER_UNIT, plane_y)
			var land_value := map.land_factor_at(plane, coast_noise)
			elev_raw[index] = InkMonWorldMapData.raw_elevation_at(elevation_noise, ridge_noise, plane)
			moist_raw[index] = InkMonWorldMapData.raw_moisture_at(moisture_noise, plane)
			land01[index] = 1.0 if land_value >= 0.5 else 0.0
			land_soft[index] = land_value
			coast01[index] = (coast_noise.get_noise_2d(plane.x, plane.y) + 1.0) * 0.5
			mottle01[index] = (mottle_noise.get_noise_2d(plane.x, plane.y) + 1.0) * 0.5
	# 海岸高程下潜 (mock: 高程 × 海岸衰减, 先于秩归一) → 海岸出立体阴影带。
	for index in range(count):
		elev_raw[index] *= smoothstep(0.45, 0.78, land_soft[index])
	return {
		"width": grid_width,
		"height": grid_height,
		"rect": rect,
		"elev_rank": rank_normalize(elev_raw, land01),
		"moist_rank": rank_normalize(moist_raw, land01),
		"land01": land01,
		"land_soft": land_soft,
		"coast01": coast01,
		"mottle01": mottle01,
	}


## 逐像素秩归一 (陆地像素域, mock 的 pctl_norm 同款): 直方图 CDF, O(n)。
## 海像素也给值 (按同一 CDF 映射), 供岸外延伸取色。
static func rank_normalize(values: PackedFloat32Array, mask01: PackedFloat32Array) -> PackedFloat32Array:
	var lowest := INF
	var highest := -INF
	for index in range(values.size()):
		if mask01[index] > 0.5:
			lowest = minf(lowest, values[index])
			highest = maxf(highest, values[index])
	if not is_finite(lowest) or highest - lowest < 1e-9:
		return values.duplicate()
	var span := highest - lowest
	var histogram := PackedInt32Array()
	histogram.resize(RANK_BINS)
	var masked_total := 0
	for index in range(values.size()):
		if mask01[index] > 0.5:
			var bin := clampi(int((values[index] - lowest) / span * float(RANK_BINS - 1)), 0, RANK_BINS - 1)
			histogram[bin] += 1
			masked_total += 1
	var cumulative := PackedFloat32Array()
	cumulative.resize(RANK_BINS)
	var running := 0
	for bin in range(RANK_BINS):
		running += histogram[bin]
		cumulative[bin] = float(running) / float(maxi(masked_total, 1))
	var ranked := PackedFloat32Array()
	ranked.resize(values.size())
	for index in range(values.size()):
		var bin := clampi(int((values[index] - lowest) / span * float(RANK_BINS - 1)), 0, RANK_BINS - 1)
		ranked[index] = cumulative[bin]
	return ranked


## box 模糊 ×3 ≈ 高斯 (分离 + 运行和, O(n) 每趟)。radius_px = 单趟半径。
static func box_blur3(values: PackedFloat32Array, grid_width: int, grid_height: int, radius_px: int) -> PackedFloat32Array:
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


## view 的场纹理包: field_tex (r=elev_rank, g=moist_rank, b=coast01, a=mottle01) +
## shade_tex (r=模糊着色场, g/b/a=三档模糊陆地带)。半浮点, 免 8-bit 台阶。
static func bake_view_textures(map: InkMonWorldMapData) -> Dictionary:
	var grids := sample_grids(map)
	var grid_width := int(grids.get("width", 0))
	var grid_height := int(grids.get("height", 0))
	var elev_rank := grids.get("elev_rank") as PackedFloat32Array
	var moist_rank := grids.get("moist_rank") as PackedFloat32Array
	var coast01 := grids.get("coast01") as PackedFloat32Array
	var mottle01 := grids.get("mottle01") as PackedFloat32Array
	var land01 := grids.get("land01") as PackedFloat32Array
	var shade_field := box_blur3(elev_rank, grid_width, grid_height, SHADE_BLUR_RADIUS_PX)
	var land_near := box_blur3(land01, grid_width, grid_height, LAND_BLUR_NEAR_PX)
	var land_shallow := box_blur3(land01, grid_width, grid_height, LAND_BLUR_SHALLOW_PX)
	var land_depth := box_blur3(land01, grid_width, grid_height, LAND_BLUR_DEPTH_PX)
	var field_image := Image.create(grid_width, grid_height, false, Image.FORMAT_RGBAH)
	var shade_image := Image.create(grid_width, grid_height, false, Image.FORMAT_RGBAH)
	for py in range(grid_height):
		for px in range(grid_width):
			var index := py * grid_width + px
			field_image.set_pixel(px, py, Color(elev_rank[index], moist_rank[index], coast01[index], mottle01[index]))
			shade_image.set_pixel(px, py, Color(shade_field[index], land_near[index], land_shallow[index], land_depth[index]))
	return {
		"field_tex": ImageTexture.create_from_image(field_image),
		"shade_tex": ImageTexture.create_from_image(shade_image),
		"rect": grids.get("rect"),
	}


## Ref 参照图 (map_viewer 调试): 整条管线 CPU 逐像素上色, 与 shader 版同世界同数值 A/B。
## uniforms = InkMonMapStylePresets.preset(...)["uniforms"] (平滑风格; 面片/墨线参数忽略)。
static func bake_reference_image(map: InkMonWorldMapData, uniforms: Dictionary) -> ImageTexture:
	var grids := sample_grids(map)
	var grid_width := int(grids.get("width", 0))
	var grid_height := int(grids.get("height", 0))
	var rect := grids.get("rect") as Rect2
	var elev_rank := grids.get("elev_rank") as PackedFloat32Array
	var moist_rank := grids.get("moist_rank") as PackedFloat32Array
	var mottle01 := grids.get("mottle01") as PackedFloat32Array
	var land_soft := grids.get("land_soft") as PackedFloat32Array
	var land01 := grids.get("land01") as PackedFloat32Array
	var shade_field := box_blur3(elev_rank, grid_width, grid_height, SHADE_BLUR_RADIUS_PX)
	var land_near := box_blur3(land01, grid_width, grid_height, LAND_BLUR_NEAR_PX)
	var land_shallow := box_blur3(land01, grid_width, grid_height, LAND_BLUR_SHALLOW_PX)
	var land_depth := box_blur3(land01, grid_width, grid_height, LAND_BLUR_DEPTH_PX)
	var play_rect := Rect2(0.0, 0.0, float(map.width - 1) + 0.5, float(map.height - 1) * sqrt(3.0) / 2.0)
	var image := Image.create(grid_width, grid_height, false, Image.FORMAT_RGBA8)
	var shade_k := float(uniforms.get("shade_k", 0.4))
	var relief_gain := 3.0
	var mottle_amt := float(uniforms.get("mottle_amt", 0.0))
	var grain_amt := float(uniforms.get("grain_amt", 0.0))
	var vignette_amt := float(uniforms.get("vignette_amt", 0.0))
	for py in range(grid_height):
		for px in range(grid_width):
			var index := py * grid_width + px
			var plane := rect.position + Vector2((float(px) + 0.5) / PX_PER_UNIT, (float(py) + 0.5) / PX_PER_UNIT)
			var color := Color.BLACK
			if land_soft[index] < 0.5:
				color = _sea_color(uniforms, land_shallow[index], land_depth[index])
			else:
				var temperature := _temperature(plane, play_rect, elev_rank[index])
				color = _land_color(uniforms, elev_rank[index], moist_rank[index], temperature,
					1.0 - land_near[index])
				# hillshade: 模糊秩场中央差分 (1px), mock 数值 (gain 1.2, clamp 0.82..1.14)。
				var right := shade_field[py * grid_width + mini(px + 1, grid_width - 1)]
				var left := shade_field[py * grid_width + maxi(px - 1, 0)]
				var down := shade_field[mini(py + 1, grid_height - 1) * grid_width + px]
				var up := shade_field[maxi(py - 1, 0) * grid_width + px]
				var slope := (right - left + down - up) / (2.0 / PX_PER_UNIT)
				var shade := clampf(1.0 - shade_k * slope * relief_gain, 0.82, 1.14)
				color *= shade
				color = color * (1.0 + (mottle01[index] - 0.5) * mottle_amt)
			var grain := _hash01(float(floori(plane.x * 24.0)) * 92837.0 + float(floori(plane.y * 24.0)))
			color += Color(1, 1, 1, 0) * ((grain - 0.5) * grain_amt)
			var uv := Vector2(float(px) / float(grid_width - 1), float(py) / float(grid_height - 1))
			var vr := (uv - Vector2(0.5, 0.5)).length() / 0.7071
			color *= 1.0 - vignette_amt * smoothstep(0.55, 1.0, vr)
			color.a = 1.0
			image.set_pixel(px, py, color.clamp())
	return ImageTexture.create_from_image(image)


static func _sea_color(uniforms: Dictionary, shallow01: float, depth01: float) -> Color:
	var deep := uniforms.get("col_deep", Color.BLACK) as Color
	var sea := uniforms.get("col_sea", Color.BLACK) as Color
	var shallow := uniforms.get("col_shallow", Color.BLACK) as Color
	var color := deep.lerp(sea, smoothstep(0.02, 0.30, depth01))
	return color.lerp(shallow, smoothstep(0.10, 0.45, shallow01))


static func _land_color(uniforms: Dictionary, elev_rank: float, moist_rank: float,
		temperature: float, near_sea: float) -> Color:
	var color := uniforms.get("col_plain", Color.BLACK) as Color
	if elev_rank > InkMonWorldMapData.BIOME_MOUNTAIN_MIN:
		var mountain := uniforms.get("col_mountain", Color.BLACK) as Color
		var snowcap := uniforms.get("col_snowcap", Color.WHITE) as Color
		var rock := mountain.lerp(snowcap, 0.45)
		color = mountain.lerp(rock, smoothstep(0.895, 0.945, elev_rank))
		color = color.lerp(snowcap, smoothstep(0.93, 0.99, elev_rank) * float(uniforms.get("snowcap_amt", 1.0)))
	elif elev_rank > InkMonWorldMapData.BIOME_HILL_MIN:
		color = uniforms.get("col_hill", Color.BLACK) as Color
	elif near_sea > 0.34 and elev_rank < 0.52:
		color = uniforms.get("col_shore", Color.BLACK) as Color
	elif temperature < InkMonWorldMapData.BIOME_TUNDRA_MAX_T:
		color = uniforms.get("col_tundra", Color.BLACK) as Color
	elif moist_rank > InkMonWorldMapData.BIOME_FOREST_MIN_M:
		var forest := uniforms.get("col_forest", Color.BLACK) as Color
		color = forest.lerp(forest * 0.70, smoothstep(0.80, 1.0, moist_rank))
	elif moist_rank < InkMonWorldMapData.BIOME_DRY_MAX_M and temperature > InkMonWorldMapData.BIOME_DRY_MIN_T:
		color = uniforms.get("col_dry", Color.BLACK) as Color
	else:
		color = color.lerp(uniforms.get("col_dry", Color.BLACK) as Color,
			smoothstep(0.42, 0.20, moist_rank) * 0.6)
	return color


static func _temperature(plane: Vector2, play_rect: Rect2, elev_rank: float) -> float:
	var lat01 := InkMonWorldMapData.TEMP_LAT_LO + InkMonWorldMapData.TEMP_LAT_SPAN \
		* clampf((plane.y - play_rect.position.y) / play_rect.size.y, 0.0, 1.0)
	return clampf(lat01 * InkMonWorldMapData.TEMP_LAT_SCALE + InkMonWorldMapData.TEMP_LAT_BIAS
		- InkMonWorldMapData.TEMP_ELEV_DROP * (elev_rank - 0.5), 0.0, 1.0)


static func _make_mottle_noise(seed_value: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = seed_value + 424267
	noise.frequency = 1.6
	noise.fractal_octaves = 3
	return noise


static func _hash01(value: float) -> float:
	return fposmod(sin(value) * 43758.5453, 1.0)
