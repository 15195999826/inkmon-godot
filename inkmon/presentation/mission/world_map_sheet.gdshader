shader_type canvas_item;
// 大地图"地图纸"风格 shader (adr/0012 决定四/五, A3 版): 场/秩/模糊全部由
// InkMonMapBakeMath 预烘 (mockgen 同管线), 本 shader 只做 mock build() 的上色阶段
// + 风格化 (面片/墨线/排线)。合成顺序与 mock 逐字对齐:
// 海(深浅带) → 陆 biome(mock 10 类) → hillshade → 海岸描线 → 苔藓斑驳 → post_darken
// → 纸纹 → 暗角。风格 = 色板 + 开关 uniform (InkMonMapStylePresets 整组下发)。
//
// 纹理契约 (InkMonMapBakeMath):
// field_tex: R=elev_raw×海岸压制 G=moist_raw B=land_f A=t_noise01
// shade_tex: R=blur(rank·land,σ0.2u) G=blur(land,σ0.55u) B=blur(land,σ1.3u) A=blur(land,σ3.2u)
// cdf_tex:   raw 归一 → 秩01 (R=elev G=moist; 陆地像素域 percentile)

uniform sampler2D field_tex : filter_linear;
uniform sampler2D shade_tex : filter_linear;
uniform sampler2D cdf_tex : filter_linear;
uniform float u_emin = 0.0;
uniform float u_erange = 1.0;
uniform float u_mmin = 0.0;
uniform float u_mrange = 1.0;

uniform vec2 sheet_origin = vec2(-6.5);
uniform vec2 sheet_size = vec2(41.5, 31.19);
uniform float u_land_h = 18.186533479473212;
uniform int u_seed = 0;

// === 风格参数 (预设整组下发) ===
uniform float facet_mix = 0.0;        // >0.5 = 面片化 (low poly faceted)
uniform float facet_scale = 0.80;     // 面片格尺寸 (平面单位)
uniform float ink_strength = 0.75;    // 墨线/海岸描线强度
uniform float border_ink = 0.0;       // 连续底上的 biome 边界墨线 (ink_wash 风格; 面片模式忽略)
uniform float hatch_strength = 0.0;   // 阴影排线 (ink sketch)
uniform float shade_k = 0.40;         // hillshade 强度 (mock: k=0.40)
uniform float relief_gain = 3.0;      // 坡度增益 (shade_k·gain = mock 的 1.2/坡度单位)
uniform float grain_amt = 0.05;       // 纸纹颗粒
uniform float vignette_amt = 0.16;    // 暗角
uniform float shallow_steps = 0.0;    // >0 = 浅滩量化档数 (MC 风)
uniform float mottle_amt = 0.16;      // 苔藓斑驳幅度
uniform float post_darken = 1.0;      // 整体压暗 (mock C = 0.95)

// === 色板 (mock 类 → 色; 每风格一张表) ===
uniform vec3 col_plain = vec3(0.47, 0.48, 0.31);
uniform vec3 col_forest = vec3(0.33, 0.38, 0.22);
uniform vec3 col_dense = vec3(0.24, 0.29, 0.17);
uniform vec3 col_hill = vec3(0.51, 0.49, 0.41);
uniform vec3 col_mountain = vec3(0.55, 0.54, 0.50);
uniform vec3 col_rock = vec3(0.63, 0.62, 0.58);
uniform vec3 col_snowcap = vec3(0.78, 0.79, 0.77);
uniform vec3 col_tundra = vec3(0.58, 0.60, 0.52);
uniform vec3 col_dry = vec3(0.57, 0.54, 0.36);
uniform vec3 col_desert = vec3(0.62, 0.57, 0.42);
uniform vec3 col_deep = vec3(0.22, 0.28, 0.33);
uniform vec3 col_sea = vec3(0.30, 0.38, 0.43);
uniform vec3 col_shallow = vec3(0.42, 0.50, 0.53);
uniform vec3 col_shore = vec3(0.56, 0.51, 0.41);
uniform vec3 col_ink = vec3(0.09, 0.13, 0.15);


vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}


float hash01(int ix, int iy, int seedv) {
	uint h = (uint(ix) * 2654435761u) ^ (uint(iy) * 2246822519u) ^ (uint(seedv) * 3266489917u);
	h = (h ^ (h >> 13u)) * 668265263u;
	h = h ^ (h >> 15u);
	return float(h & 16777215u) / 16777216.0;
}


float vnoise(float x, float y, int seedv) {
	float x0f = floor(x);
	float y0f = floor(y);
	float fx = x - x0f;
	float fy = y - y0f;
	int ix = int(x0f);
	int iy = int(y0f);
	float u = fx * fx * (3.0 - 2.0 * fx);
	float v = fy * fy * (3.0 - 2.0 * fy);
	float n00 = hash01(ix, iy, seedv);
	float n10 = hash01(ix + 1, iy, seedv);
	float n01 = hash01(ix, iy + 1, seedv);
	float n11 = hash01(ix + 1, iy + 1, seedv);
	return (n00 * (1.0 - u) + n10 * u) * (1.0 - v) + (n01 * (1.0 - u) + n11 * u) * v;
}


float fbm(float x, float y, int seedv, float freq, int octaves) {
	float total = 0.0;
	float amp = 1.0;
	float f = freq;
	float norm = 0.0;
	for (int i = 0; i < octaves; i++) {
		total += vnoise(x * f, y * f, seedv + i * 131) * amp;
		norm += amp;
		amp *= 0.5;
		f *= 2.0;
	}
	return total / norm;
}


vec2 sheet_uv(vec2 plane) {
	return clamp((plane - sheet_origin) / sheet_size, vec2(0.0), vec2(1.0));
}


// mock 类 id: -1 海 / 0 grass / 1 forest / 2 hills / 3 mount / 4 tundra / 5 dry /
// 6 snow / 7 rock / 8 beach / 9 dense / 10 desert (np.select 顺序)。
float classify_mock(float e, float m, float t, float near_sea) {
	if (e > 0.94 && t < 0.62) {
		return 6.0;
	}
	if (e > 0.89) {
		return 7.0;
	}
	if (e > 0.81) {
		return 3.0;
	}
	if (e > 0.72) {
		return 2.0;
	}
	if (t < 0.10) {
		return 4.0;
	}
	if (near_sea > 0.34 && e < 0.52) {
		return 8.0;
	}
	if (m > 0.82 && t < 0.85) {
		return 9.0;
	}
	if (m > 0.58) {
		return 1.0;
	}
	if (m < 0.10 && t > 0.72) {
		return 10.0;
	}
	if (m < 0.24 && t > 0.58) {
		return 5.0;
	}
	return 0.0;
}


vec3 class_color(float class_id, float m) {
	if (class_id < 0.5) {
		// grass: 按湿度往干草过渡 (mock 同款)。
		return mix(col_plain, col_dry, smoothstep(0.50, 0.28, m) * 0.65);
	} else if (class_id < 1.5) {
		return col_forest;
	} else if (class_id < 2.5) {
		return col_hill;
	} else if (class_id < 3.5) {
		return col_mountain;
	} else if (class_id < 4.5) {
		return col_tundra;
	} else if (class_id < 5.5) {
		return col_dry;
	} else if (class_id < 6.5) {
		return col_snowcap;
	} else if (class_id < 7.5) {
		return col_rock;
	} else if (class_id < 8.5) {
		return col_shore;
	} else if (class_id < 9.5) {
		return col_dense;
	}
	return col_desert;
}


// 某采样点: 上色 + 类 id (墨线比较用; -1 = 海)。
vec3 surface_color(vec2 sp, out float class_id, out float land) {
	vec4 fields = texture(field_tex, sheet_uv(sp));
	vec4 bands = texture(shade_tex, sheet_uv(sp));
	land = step(0.5, fields.b);
	if (land < 0.5) {
		class_id = -1.0;
		vec3 sea = mix(col_deep, col_sea, smoothstep(0.02, 0.30, bands.a));
		float sh = smoothstep(0.10, 0.45, bands.b);
		if (shallow_steps > 0.5) {
			sh = floor(sh * shallow_steps + 0.5) / shallow_steps;
		}
		return mix(sea, col_shallow, sh);
	}
	float e = texture(cdf_tex, vec2(clamp((fields.r - u_emin) / u_erange, 0.0, 1.0), 0.5)).r;
	float m = texture(cdf_tex, vec2(clamp((fields.g - u_mmin) / u_mrange, 0.0, 1.0), 0.5)).g;
	// mock 温度: lat 锚 (y+2)/(PLANE_H+4), 高地降温, 噪声抖动。
	float lat = clamp((sp.y + 2.0) / (u_land_h + 4.0), 0.0, 1.0);
	float t = clamp(lat * 1.05 - 0.03 - 0.30 * (e - 0.5) + (fields.a - 0.5) * 0.20, 0.0, 1.0);
	float near_sea = 1.0 - bands.g;
	class_id = classify_mock(e, m, t, near_sea);
	return class_color(class_id, m);
}


float shade_sample(vec2 sp) {
	return texture(shade_tex, sheet_uv(sp)).r;
}


// 分类采样 (biome 边界墨线用; 只要类 id, 颜色丢弃)。
float class_at(vec2 sp) {
	float class_id;
	float land;
	surface_color(sp, class_id, land);
	return class_id;
}


void fragment() {
	vec2 plane = sheet_origin + UV * sheet_size;
	// 采样点: 面片模式取 jitter Voronoi 最近种子 (整面片同色/同坡 = low poly faceted);
	// 平滑模式逐像素 (连续场天然有机)。
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
	vec3 c = surface_color(sp, class1, land1);

	// hillshade: 预模糊秩场中央差分 (mock: 先高斯模糊再逐像素梯度 —— 阴影与色阶带同频,
	// 紧贴形体; 数值 = 1 − shade_k·relief_gain·坡度, clamp 0.82..1.14)。
	// 面片模式 sp 整面片恒定 → 每面片一个平面阴影。光源西北。
	vec2 shade_ts = vec2(textureSize(shade_tex, 0));
	float eps = facet_mix > 0.5 ? facet_scale * 0.75 : (sheet_size.x / shade_ts.x);
	if (land1 >= 0.5) {
		float slope = (shade_sample(sp + vec2(eps, 0.0)) - shade_sample(sp - vec2(eps, 0.0))
			+ shade_sample(sp + vec2(0.0, eps)) - shade_sample(sp - vec2(0.0, eps))) / (2.0 * eps);
		float shade = clamp(1.0 - shade_k * slope * relief_gain, 0.82, 1.14);
		c *= shade;
		// 阴影排线 (ink sketch): 只给明确背光的坡叠稀疏斜线。
		if (hatch_strength > 0.001 && shade < 0.94) {
			float stripe = step(0.55, fract((plane.x + plane.y) * 2.6));
			c *= 1.0 - hatch_strength * stripe * smoothstep(0.94, 0.84, shade);
		}
	}

	// 墨线: 面片模式 = 分类异界强墨 + 陆地同类面片微线 (fwidth 抗锯齿);
	// 平滑模式 = mock 海岸描线 (land − MinFilter3, alpha = ink_strength; mock C 为 0.75)。
	if (ink_strength > 0.001) {
		if (facet_mix > 0.5) {
			float class2;
			float land2;
			surface_color(sp2, class2, land2);
			bool differs = abs(class1 - class2) > 0.5;
			float aa = fwidth(edge) * 1.5;
			float strong = (1.0 - smoothstep(0.03, 0.03 + aa, edge)) * (differs ? 1.0 : 0.0);
			float micro = (1.0 - smoothstep(0.012, 0.012 + aa, edge)) * 0.10 * step(0.5, land1);
			c = mix(c, col_ink, clamp(ink_strength * max(strong, micro), 0.0, 0.92));
		} else {
			vec2 field_texel = 1.0 / vec2(textureSize(field_tex, 0));
			float minv = 1.0;
			for (int oy = -1; oy <= 1; oy++) {
				for (int ox = -1; ox <= 1; ox++) {
					minv = min(minv, step(0.5, texture(field_tex, sheet_uv(plane) + field_texel * vec2(float(ox), float(oy))).b));
				}
			}
			float edge_line = clamp(land1 - minv, 0.0, 1.0);
			c = c * (1.0 - edge_line * ink_strength) + col_ink * edge_line * ink_strength;
		}
	}

	// biome 边界墨线 (ink_wash: 连续底不动, 加法叠墨线层; 与面片方案互斥 —— 面片自带界线)。
	// 采样点加低频抖动 = 手绘笔迹感; 海陆边界交给海岸描线, 此处只描陆上类界。
	if (border_ink > 0.001 && facet_mix < 0.5 && land1 >= 0.5) {
		float wob_x = fbm(plane.x, plane.y, u_seed + 301, 3.0, 2) - 0.5;
		float wob_y = fbm(plane.x, plane.y, u_seed + 302, 3.0, 2) - 0.5;
		vec2 pb = plane + vec2(wob_x, wob_y) * 0.10;
		float eps_b = (sheet_size.x / vec2(textureSize(field_tex, 0)).x) * 1.5;
		float c_e = class_at(pb + vec2(eps_b, 0.0));
		float c_w = class_at(pb - vec2(eps_b, 0.0));
		float c_s = class_at(pb + vec2(0.0, eps_b));
		float c_n = class_at(pb - vec2(0.0, eps_b));
		float differs = 0.0;
		if (min(c_e, c_w) >= -0.5 && abs(c_e - c_w) > 0.5) {
			differs += 1.0;
		}
		if (min(c_s, c_n) >= -0.5 && abs(c_s - c_n) > 0.5) {
			differs += 1.0;
		}
		c = mix(c, col_ink, clamp(differs * 0.6, 0.0, 1.0) * border_ink);
	}

	// 苔藓斑驳 (陆地, mock C: fbm(seed+55, 2.4, 3)) + 整体压暗。
	if (mottle_amt > 0.001 && land1 >= 0.5) {
		float mottle = fbm(plane.x, plane.y, u_seed + 55, 2.4, 3);
		c *= 1.0 + (mottle - 0.5) * mottle_amt;
	}
	c *= post_darken;

	// 纸纹 (mock: hash 于 40px/单位 画布格) + 暗角 (mock: r = |uv-0.5|, 0.32..0.62)。
	c += (hash01(int(round(plane.x * 40.0)), int(round(plane.y * 40.0)), 77) - 0.5) * grain_amt;
	float vr = length(UV - 0.5);
	c *= 1.0 - vignette_amt * smoothstep(0.32, 0.62, vr);

	COLOR = vec4(clamp(c, vec3(0.0), vec3(1.0)), 1.0);
}
