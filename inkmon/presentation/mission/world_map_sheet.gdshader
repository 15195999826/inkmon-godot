shader_type canvas_item;
// 大地图"地图纸" (adr/0012 决定四/五): 渲染真相 = 连续场纹理 (逐像素, mock 同法), 不是 616 格放大 ——
// CPU 只烘 场纹理 + 分位 CDF LUT, 上色/分类/海岸/浅滩/hillshade/墨线/纸纹全部逐像素在此完成。
// 入档 cells 仍是玩法/环境唯一真相 (battle 皮肤/未来生态): 同噪声同阈值同分位域 = 同源近似 ——
// 逻辑侧另有分类平滑与温度抖动 (本 shader 刻意不复刻), 临界格/亚格细节允许视觉发散,
// 不承诺格中心 bit 级一致 (adr/0012 决定四修订口径)。风格 = 色板 + 开关 uniform 整组下发。
//
// 坐标约定: UV 覆盖 sheet 矩形; plane = sheet_origin + UV * sheet_size (未压扁平面单位,
// hex 间距 = 1)。iso squish 由 view 把矩形画扁完成, 本 shader 不感知。
//
// ⚠ 海岸公式与 InkMonWorldMapData 的 _land_factor 成对 (河流入海判定用同一公式):
// land = 1 - smoothstep(0.6, ocean_margin - 1.0, 矩形外距离 * (0.65 + coast01))。
// coast01 经 field_tex.b 传入 —— view 用与河流生成完全相同的 FastNoiseLite 烘, 零漂移。

// 连续场 (sheet 矩形域, 与 UV 同映射): r = elev_raw 归一, g = moist_raw 归一,
// b = coast01 (与河流生成同源), a = 苔藓斑驳。
uniform sampler2D field_tex : filter_linear;
// 分位 CDF LUT (256×1): raw 归一值 → 秩01 (r = elev, g = moist)。
// biome 阈值作用在秩域 = 覆盖率语义, 与逻辑层分类同域 (mock 的 percentile 同款)。
uniform sampler2D cdf_tex : filter_linear;

uniform vec2 sheet_origin = vec2(0.0);
uniform vec2 sheet_size = vec2(1.0);
uniform vec2 play_origin = vec2(0.0);
uniform vec2 play_size = vec2(1.0);
uniform float ocean_margin = 6.0;

// === biome 分类 (值从 InkMonWorldMapData 常量下发, 单一来源) ===
uniform float biome_mountain_min = 0.87;
uniform float biome_hill_min = 0.72;
uniform float biome_tundra_max_t = 0.10;
uniform float biome_forest_min_m = 0.58;
uniform float biome_dry_max_m = 0.24;
uniform float biome_dry_min_t = 0.58;
// 纬度温度 (同 InkMonWorldMapData._temperature, 视觉侧省 jitter 项)。
uniform float temp_lat_lo = 0.15;
uniform float temp_lat_span = 0.7;
uniform float temp_lat_scale = 1.05;
uniform float temp_lat_bias = -0.03;
uniform float temp_elev_drop = 0.30;

// === 风格参数 (预设整组下发) ===
uniform float facet_mix = 1.0;        // >0.5 = 面片化 (low poly faceted)
uniform float facet_scale = 0.80;     // 面片格尺寸 (平面单位)
uniform float ink_strength = 0.85;    // 墨线强度 (0 = 无墨线)
uniform float hatch_strength = 0.0;   // 阴影排线 (ink sketch)
uniform float shade_k = 0.4;          // hillshade 强度
uniform float relief_gain = 3.0;      // 坡度→明暗增益 (mock 数值对齐: shade_k*gain≈1.2/坡度单位)
uniform float grain_amt = 0.05;       // 纸纹颗粒
uniform float vignette_amt = 0.12;    // 暗角
uniform float shallow_steps = 0.0;    // >0 = 浅滩量化档数 (MC 风)
uniform float mottle_amt = 0.0;       // 苔藓斑驳明度斑幅度
uniform float snowcap_amt = 1.0;      // 山顶盖混入量
uniform float snow_min_rank = 0.93;   // 山顶盖高程秩阈值
uniform float sea_facet = 1.0;        // 海面是否也面片化

// === 色板 ===
uniform vec3 col_plain = vec3(0.47, 0.48, 0.31);
uniform vec3 col_forest = vec3(0.33, 0.38, 0.22);
uniform vec3 col_hill = vec3(0.51, 0.49, 0.41);
uniform vec3 col_mountain = vec3(0.55, 0.54, 0.50);
uniform vec3 col_tundra = vec3(0.58, 0.60, 0.52);
uniform vec3 col_dry = vec3(0.57, 0.54, 0.36);
uniform vec3 col_deep = vec3(0.22, 0.28, 0.33);
uniform vec3 col_sea = vec3(0.30, 0.38, 0.43);
uniform vec3 col_shallow = vec3(0.42, 0.50, 0.53);
uniform vec3 col_shore = vec3(0.56, 0.51, 0.41);
uniform vec3 col_snowcap = vec3(0.78, 0.79, 0.77);
uniform vec3 col_ink = vec3(0.10, 0.11, 0.10);


vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}


float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}


vec2 sheet_uv(vec2 plane) {
	return clamp((plane - sheet_origin) / sheet_size, vec2(0.0), vec2(1.0));
}


// 矩形外距离 (plane 单位; 可玩矩形内 = 0)。
float rect_outside(vec2 plane) {
	vec2 rect_end = play_origin + play_size;
	float dx = max(max(play_origin.x - plane.x, plane.x - rect_end.x), 0.0);
	float dy = max(max(play_origin.y - plane.y, plane.y - rect_end.y), 0.0);
	return sqrt(dx * dx + dy * dy);
}


// 陆地系数 (⚠ 与 GDScript _land_factor 成对, 含 isle 项 —— 常量两端同值):
// 1 = 腹地, <0.5 = 海。isle 采样点 = sheet 域缩放偏移重映射 (与 coast 场解相关)。
float land_factor(vec2 plane, float coast01) {
	float outside = rect_outside(plane);
	if (outside <= 0.0) {
		return 1.0;
	}
	float land = 1.0 - smoothstep(0.6, ocean_margin - 1.0, outside * (0.65 + coast01));
	vec2 isle_plane = sheet_origin + (plane - sheet_origin) * 0.53 + vec2(0.31, 0.17) * sheet_size;
	float isle01 = texture(field_tex, sheet_uv(isle_plane)).b;
	float isle = step(0.72, isle01) * step(1.8, outside) * step(outside, ocean_margin - 0.8) * 0.75;
	return max(land, isle);
}


// 纬度温度 (视觉侧, 与逻辑层同常量省 jitter)。
float temperature_at(vec2 plane, float elev_rank) {
	float lat01 = temp_lat_lo + temp_lat_span * clamp((plane.y - play_origin.y) / play_size.y, 0.0, 1.0);
	return clamp(lat01 * temp_lat_scale + temp_lat_bias - temp_elev_drop * (elev_rank - 0.5), 0.0, 1.0);
}


// biome 分类 (与 InkMonWorldMapData._classify_biome 同序同阈值, 秩域)。
float classify(float elev_rank, float moist_rank, float t) {
	if (elev_rank > biome_mountain_min) {
		return 3.0;
	}
	if (elev_rank > biome_hill_min) {
		return 2.0;
	}
	if (t < biome_tundra_max_t) {
		return 4.0;
	}
	if (moist_rank > biome_forest_min_m) {
		return 1.0;
	}
	if (moist_rank < biome_dry_max_m && t > biome_dry_min_t) {
		return 5.0;
	}
	return 0.0;
}


vec3 biome_color(float biome, float elev_rank, float moist_rank) {
	vec3 c = col_plain;
	if (biome < 0.5) {
		// plain: 按湿度往干草过渡 (biome 内渐变, 免大色块单调)。
		c = mix(col_plain, col_dry, smoothstep(0.42, 0.20, moist_rank) * 0.6);
	} else if (biome < 1.5) {
		// forest: 高湿度加深 (密林感)。
		c = mix(col_forest, col_forest * 0.70, smoothstep(0.80, 1.0, moist_rank));
	} else if (biome < 2.5) {
		c = col_hill;
	} else if (biome < 3.5) {
		// 山体三段: 石壁 → 亮岩带 → 雪顶 (mock 的高程色阶台阶, 立体感的强线索)。
		vec3 rock = mix(col_mountain, col_snowcap, 0.45);
		c = mix(col_mountain, rock, smoothstep(0.895, 0.945, elev_rank));
		c = mix(c, col_snowcap, smoothstep(snow_min_rank, 0.99, elev_rank) * snowcap_amt);
	} else if (biome < 4.5) {
		c = col_tundra;
	} else {
		c = col_dry;
	}
	return c;
}


// hillshade 采样: 秩域高程 (等面积拉伸, 中段坡度不被 raw 分布压扁 —— mock 的 percentile
// 场同款); 海岸按陆地系数缓降到 0 (mock 的高程×海岸衰减同款 → 海岸出立体阴影带,
// 水线硬切 0 只会得到一条锐利崖线)。
float elev_rank_land_at(vec2 sp) {
	vec4 fields = texture(field_tex, sheet_uv(sp));
	float land = land_factor(sp, fields.b);
	return texture(cdf_tex, vec2(fields.r, 0.5)).r * smoothstep(0.45, 0.78, land);
}


// 某采样点的地表分类与颜色。class_id 供墨线比较: -1 海, 100 岸带, 其余 = biome。
// elev_raw_out = 归一 raw 高程 (hillshade 用连续 raw, 秩会不均匀拉伸坡度)。
vec3 surface_color(vec2 sp, out float class_id, out float land, out float elev_raw_out) {
	vec4 fields = texture(field_tex, sheet_uv(sp));
	land = land_factor(sp, fields.b);
	if (land < 0.5) {
		class_id = -1.0;
		elev_raw_out = 0.0;
		vec3 sea = mix(col_deep, col_sea, smoothstep(0.02, 0.42, land));
		float sh = smoothstep(0.30, 0.50, land);
		if (shallow_steps > 0.5) {
			sh = floor(sh * shallow_steps + 0.5) / shallow_steps;
		}
		return mix(sea, col_shallow, sh);
	}
	float elev_rank = texture(cdf_tex, vec2(fields.r, 0.5)).r;
	float moist_rank = texture(cdf_tex, vec2(fields.g, 0.5)).g;
	float t = temperature_at(sp, elev_rank);
	float biome = classify(elev_rank, moist_rank, t);
	elev_raw_out = fields.r;
	vec3 c = biome_color(biome, elev_rank, moist_rank);
	// 岸带跟水线走 (land 0.52..0.66 = 滩): 界外陆地由连续场自然延伸, 只在近水收窄滩。
	float shore_mix = smoothstep(0.66, 0.52, land);
	c = mix(c, col_shore, shore_mix);
	class_id = shore_mix > 0.6 ? 100.0 : biome;
	return c;
}


void fragment() {
	vec2 plane = sheet_origin + UV * sheet_size;
	// 采样点: 面片模式取 jitter Voronoi 最近种子 (整面片同色/同坡 = low poly faceted);
	// 平滑模式逐像素 (连续场本身有机, 无需扰动)。
	vec2 sp = plane;
	vec2 sp2 = plane;
	float edge = 1e9;
	if (facet_mix > 0.5) {
		vec2 g = plane / facet_scale;
		vec2 base_cell = floor(g);
		float f1 = 1e9;
		float f2 = 1e9;
		vec2 best1 = g;
		vec2 best2 = g;
		for (int dy = -1; dy <= 1; dy++) {
			for (int dx = -1; dx <= 1; dx++) {
				vec2 cellv = base_cell + vec2(float(dx), float(dy));
				vec2 seedp = cellv + hash22(cellv);
				float d = length(g - seedp);
				if (d < f1) {
					f2 = f1;
					best2 = best1;
					f1 = d;
					best1 = seedp;
				} else if (d < f2) {
					f2 = d;
					best2 = seedp;
				}
			}
		}
		sp = best1 * facet_scale;
		sp2 = best2 * facet_scale;
		edge = f2 - f1;
	}

	float class1;
	float land1;
	float elev1;
	vec3 c = surface_color(sp, class1, land1, elev1);

	// hillshade: 秩域高程宽差分 (mock 管线 = 先 σ0.2u 高斯模糊再逐像素梯度 —— 细于 ~1u 的
	// 坡度被滤掉, 剩 1-3u 柔和大起伏; 差分窗口太细会把 5-octave 微褶全饱和成暗色蠕虫纹,
	// 贴着色块边缘爬 = "脏边" + 整图变暗, 用户对照踩过)。双尺度差分 ≈ 模糊后梯度。
	// 面片模式 sp 整面片恒定 → 每面片一个平面阴影 = low poly 平面着色。光源西北。
	float eps = facet_mix > 0.5 ? facet_scale * 0.75 : 0.45;
	if (land1 >= 0.5 || sea_facet > 0.5) {
		float slope = (elev_rank_land_at(sp + vec2(eps, 0.0)) - elev_rank_land_at(sp - vec2(eps, 0.0))
			+ elev_rank_land_at(sp + vec2(0.0, eps)) - elev_rank_land_at(sp - vec2(0.0, eps))) / (2.0 * eps);
		if (facet_mix < 0.5) {
			float eps2 = eps * 2.0;
			float slope2 = (elev_rank_land_at(sp + vec2(eps2, 0.0)) - elev_rank_land_at(sp - vec2(eps2, 0.0))
				+ elev_rank_land_at(sp + vec2(0.0, eps2)) - elev_rank_land_at(sp - vec2(0.0, eps2))) / (2.0 * eps2);
			slope = slope * 0.6 + slope2 * 0.4;
		}
		float shade = clamp(1.0 - shade_k * slope * relief_gain, 0.82, 1.14);
		if (land1 >= 0.5) {
			c *= shade;
			// 阴影排线 (ink sketch): 只给明确背光的坡叠稀疏斜线。
			if (hatch_strength > 0.001 && shade < 0.94) {
				float stripe = step(0.55, fract((plane.x + plane.y) * 2.6));
				c *= 1.0 - hatch_strength * stripe * smoothstep(0.94, 0.84, shade);
			}
		}
	}

	// 苔藓斑驳 (低频明度斑, 概念图陈旧苔绿质感)。
	if (mottle_amt > 0.001 && land1 >= 0.5) {
		float mottle = texture(field_tex, UV).a;
		c *= 1.0 + (mottle - 0.5) * mottle_amt;
	}

	// 墨线 (ink sketch texture): 面片模式 = 分类异界强墨 + 陆地同类面片微线;
	// 平滑模式 = 海岸线描边。fwidth 抗锯齿防摩尔纹。
	if (ink_strength > 0.001) {
		float ink = 0.0;
		if (facet_mix > 0.5) {
			float class2;
			float land2;
			float elev2;
			surface_color(sp2, class2, land2, elev2);
			bool differs = abs(class1 - class2) > 0.5;
			float aa = fwidth(edge) * 1.5;
			float strong = (1.0 - smoothstep(0.03, 0.03 + aa, edge)) * (differs ? 1.0 : 0.0);
			float micro = (1.0 - smoothstep(0.012, 0.012 + aa, edge)) * 0.10 * step(0.5, land1);
			ink = ink_strength * max(strong, micro);
		} else {
			float band = abs(land1 - 0.5);
			float aa = fwidth(band) * 1.5;
			float coast_band = 1.0 - smoothstep(0.02, 0.02 + aa, band);
			ink = ink_strength * coast_band * step(0.001, rect_outside(plane));
		}
		c = mix(c, col_ink, clamp(ink, 0.0, 0.92));
	}

	// 纸纹颗粒 + 暗角 (颗粒 ~24/单位 ≈ 屏幕像素级; 96/单位在游戏缩放下亚像素化成闪烁脏点)。
	c += (hash12(floor(plane * 24.0)) - 0.5) * grain_amt;
	float vr = length((UV - 0.5) * vec2(sheet_size.x / sheet_size.y, 1.0)) / 0.7071;
	c *= 1.0 - vignette_amt * smoothstep(0.55, 1.0, vr);

	COLOR = vec4(clamp(c, vec3(0.0), vec3(1.0)), 1.0);
}
