shader_type canvas_item;
render_mode blend_disabled;
// mockgen.py 场阶段的逐字复刻 (SEED/几何/噪声全同): 输出 raw 场
// R = elev_raw(含海岸压制) G = moist_raw B = land_f A = t_noise01。
// 值噪声 = mock 的 uint32 整数 hash —— GPU uint 运算与 numpy uint64&0xFFFFFFFF 同余, 位级一致。

uniform int u_seed = 20260705;

const float S = 40.0;
const float X0 = -6.5;
const float Y0 = -6.5;
const float PLANE_W = 28.5;
const float PLANE_H = 18.186533479473212;
const float MARGIN = 6.5;


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
	// domain warp (mock: XW = X + (fbm-0.5)*2*2.0)
	float wx = fbm(x, y, u_seed + 11, 0.09, 4) * 2.0 - 1.0;
	float wy = fbm(x, y, u_seed + 12, 0.09, 4) * 2.0 - 1.0;
	float xw = x + wx * 2.0;
	float yw = y + wy * 2.0;
	// 大陆 mask
	float dx = max(max(0.0 - x, x - PLANE_W), 0.0);
	float dy = max(max(0.0 - y, y - PLANE_H), 0.0);
	float d_out = sqrt(dx * dx + dy * dy);
	float coast_jit = 0.65 + 1.0 * fbm(xw, yw, u_seed + 5, 0.22, 4);
	float land_f = 1.0 - smoothstep(0.6, MARGIN - 1.0, d_out * coast_jit);
	float isle_noise = fbm(xw, yw, u_seed + 21, 0.30, 4);
	if (isle_noise > 0.63 && d_out > 1.8 && d_out < MARGIN - 0.8) {
		land_f = max(land_f, 0.75);
	}
	// 高程 (base + ridge², 海岸压制) / 湿度 / 温度抖动
	float base_e = fbm(xw, yw, u_seed, 0.13, 5);
	float ridge = 1.0 - abs(2.0 * fbm(xw, yw, u_seed + 33, 0.085, 4) - 1.0);
	float elev = clamp(0.55 * base_e + 0.55 * ridge * ridge, 0.0, 1.0);
	elev *= smoothstep(0.5, 0.75, land_f);
	float moist = fbm(xw * 0.95, yw, u_seed + 7, 0.09, 4);
	float t_noise = fbm(x, y, u_seed + 9, 0.15, 3);
	COLOR = vec4(elev, moist, land_f, t_noise);
}
