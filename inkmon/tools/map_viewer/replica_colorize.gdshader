shader_type canvas_item;
render_mode blend_disabled;
// mockgen.py build("C") 上色阶段的逐字复刻: 顺序 = 海(深浅带) → 陆 biome → hillshade(陆) →
// 海岸描线 → 苔藓斑驳(陆) → ×0.95 → 纸纹 → 暗角。所有阈值/色板/公式照抄 mock。

uniform sampler2D u_fields : filter_nearest;
uniform sampler2D u_cdf : filter_linear;        // R = elev CDF, G = moist CDF
uniform sampler2D u_shade : filter_linear;      // 模糊后的秩高程 (gblur(elev,0.2u))
uniform sampler2D u_near : filter_linear;       // gblur(land, 0.55u) → near_sea = 1-G? 用 R=blur(land)
uniform sampler2D u_shallow : filter_linear;    // gblur(land, 1.3u)
uniform sampler2D u_depth : filter_linear;      // gblur(land, 3.2u)
uniform float u_emin = 0.0;
uniform float u_erange = 1.0;
uniform float u_mmin = 0.0;
uniform float u_mrange = 1.0;
uniform vec2 u_texel = vec2(0.0);
uniform int u_seed = 20260705;

const float S = 40.0;
const float X0 = -6.5;
const float Y0 = -6.5;
const float PLANE_H = 18.186533479473212;
const float WPX = 1660.0;
const float HPX = 1247.0;

// C 色板 (mockgen build C)
const vec3 P_DEEP = vec3(0.22, 0.28, 0.33);
const vec3 P_SEA = vec3(0.30, 0.38, 0.43);
const vec3 P_SHALLOW = vec3(0.42, 0.50, 0.53);
const vec3 P_BEACH = vec3(0.56, 0.51, 0.41);
const vec3 P_GRASS = vec3(0.47, 0.48, 0.31);
const vec3 P_DRY = vec3(0.57, 0.54, 0.36);
const vec3 P_DESERT = vec3(0.62, 0.57, 0.42);
const vec3 P_FOREST = vec3(0.33, 0.38, 0.22);
const vec3 P_DENSE = vec3(0.24, 0.29, 0.17);
const vec3 P_HILLS = vec3(0.51, 0.49, 0.41);
const vec3 P_MOUNT = vec3(0.55, 0.54, 0.50);
const vec3 P_ROCK = vec3(0.63, 0.62, 0.58);
const vec3 P_SNOW = vec3(0.78, 0.79, 0.77);
const vec3 P_TUNDRA = vec3(0.58, 0.60, 0.52);
const vec3 P_STROKE = vec3(0.09, 0.13, 0.15);


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


void fragment() {
	float x = FRAGCOORD.x / S + X0;
	float y = FRAGCOORD.y / S + Y0;
	vec4 fields = texture(u_fields, UV);
	float land = step(0.5, fields.b);
	float elev = texture(u_cdf, vec2(clamp((fields.r - u_emin) / u_erange, 0.0, 1.0), 0.5)).r;
	float moist = texture(u_cdf, vec2(clamp((fields.g - u_mmin) / u_mrange, 0.0, 1.0), 0.5)).g;
	// 海像素 pctl_norm 掩膜外 = 0 (mock out[~mask]=0)
	elev *= land;
	moist *= land;
	float t_noise = fields.a - 0.5;
	float lat = clamp((y + 2.0) / (PLANE_H + 4.0), 0.0, 1.0);
	float t = clamp(lat * 1.05 - 0.03 - 0.30 * (elev - 0.5) + t_noise * 0.20, 0.0, 1.0);

	// --- 海 ---
	float depth_b = texture(u_depth, UV).g;
	float shallow_b = texture(u_shallow, UV).g;
	float dt = smoothstep(0.02, 0.30, depth_b);
	vec3 sea_col = mix(P_DEEP, P_SEA, dt);
	float sh = smoothstep(0.10, 0.45, shallow_b);
	sea_col = mix(sea_col, P_SHALLOW, sh);

	// --- 陆 biome (mock np.select 顺序) ---
	float near_sea = 1.0 - texture(u_near, UV).g;
	vec3 land_col;
	if (elev > 0.94 && t < 0.62) {
		land_col = P_SNOW;
	} else if (elev > 0.89) {
		land_col = P_ROCK;
	} else if (elev > 0.81) {
		land_col = P_MOUNT;
	} else if (elev > 0.72) {
		land_col = P_HILLS;
	} else if (t < 0.10) {
		land_col = P_TUNDRA;
	} else if (near_sea > 0.34 && elev < 0.52) {
		land_col = P_BEACH;
	} else if (moist > 0.82 && t < 0.85) {
		land_col = P_DENSE;
	} else if (moist > 0.58) {
		land_col = P_FOREST;
	} else if (moist < 0.10 && t > 0.72) {
		land_col = P_DESERT;
	} else if (moist < 0.24 && t > 0.58) {
		land_col = P_DRY;
	} else {
		land_col = mix(P_GRASS, P_DRY, smoothstep(0.50, 0.28, moist) * 0.65);
	}
	vec3 rgb = mix(sea_col, land_col, land);

	// --- hillshade (mock: np.gradient(gblur(elev,0.2u)*5) 逐像素; k=0.40, clamp 0.82..1.14) ---
	float sxp = texture(u_shade, UV + vec2(u_texel.x, 0.0)).r;
	float sxm = texture(u_shade, UV - vec2(u_texel.x, 0.0)).r;
	float syp = texture(u_shade, UV + vec2(0.0, u_texel.y)).r;
	float sym = texture(u_shade, UV - vec2(0.0, u_texel.y)).r;
	float gxx = (sxp - sxm) * 0.5 * 5.0;
	float gyy = (syp - sym) * 0.5 * 5.0;
	float shade = clamp(1.0 + 0.40 * (-(gxx + gyy) * S * 0.02) * 30.0, 0.82, 1.14);
	rgb = mix(rgb, rgb * shade, land);

	// --- 海岸描线 (mock: land − MinFilter(3)) ---
	float minv = 1.0;
	for (int oy = -1; oy <= 1; oy++) {
		for (int ox = -1; ox <= 1; ox++) {
			minv = min(minv, step(0.5, texture(u_fields, UV + u_texel * vec2(float(ox), float(oy))).b));
		}
	}
	float edge = clamp(land - minv, 0.0, 1.0);
	rgb = rgb * (1.0 - edge * 0.75) + P_STROKE * edge * 0.75;

	// --- C: 苔藓斑驳 (陆) + 整体 ×0.95 ---
	float mottle = 1.0 + (fbm(x, y, u_seed + 55, 2.4, 3) - 0.5) * 0.16;
	rgb = mix(rgb, rgb * mottle, land);
	rgb *= 0.95;

	// --- 纸纹 + 暗角 (vig 0.16) ---
	float grain = hash01(int(round(x * S)), int(round(y * S)), 77) - 0.5;
	rgb += grain * 0.05;
	float ry = (FRAGCOORD.y - 0.5 - HPX / 2.0) / HPX;
	float rx = (FRAGCOORD.x - 0.5 - WPX / 2.0) / WPX;
	float r = sqrt(rx * rx + ry * ry);
	rgb *= 1.0 - 0.16 * smoothstep(0.32, 0.62, r);

	COLOR = vec4(clamp(rgb, vec3(0.0), vec3(1.0)), 1.0);
}
