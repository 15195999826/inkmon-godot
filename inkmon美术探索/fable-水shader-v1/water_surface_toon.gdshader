shader_type canvas_item;

// fable-水shader-v1 卡通青绿变体（_toon）水面：高饱和青绿三段分区 + 贴岸白沫描边 +
// 顺流白色 dash 笔触漂移动画 + 礁石下游尾流白沫。R1-R10 迭代态，重建自 style_a_turquoise_r10.png。
// 几何数据（岸线段 / 礁石圆）由 water_scene_toon.gd 以平面坐标注入，
// UV 通道直通 hex 平面坐标（px），逐像素解析"到岸距离"距离场。

// ============ 几何数据（GDScript 注入，勿手调） ============
uniform int seg_count = 0;
uniform vec2 seg_a[96];
uniform vec2 seg_b[96];
uniform int rock_count = 0;
uniform vec3 rock_data[8]; // xy = 平面圆心, z = 半径
uniform vec2 flow_dir = vec2(-1.0, 0.0);
uniform vec2 flow_span = vec2(-1200.0, 1200.0); // dot(p, flow_dir) 的范围
uniform float edge_px = 128.0;

// ============ 视觉参数（迭代调这里） ============
uniform vec3 deep_color: source_color = vec3(0.08, 0.38, 0.41);
uniform vec3 mid_color: source_color = vec3(0.16, 0.56, 0.53);
uniform vec3 shallow_color: source_color = vec3(0.30, 0.66, 0.64);
uniform vec3 foam_color: source_color = vec3(0.93, 0.97, 0.94);
uniform float depth_far = 0.62;       // 深水渐变尽头（edge 单位）
uniform float foam_width = 0.042;     // 贴岸白沫宽度（edge 单位）
uniform float foam2_dist = 0.16;      // 第二道碎沫离岸距离（edge 单位）
uniform float foam2_width = 0.018;    // 第二道碎沫半宽（edge 单位）
uniform float streak_alpha = 0.8;     // 流线不透明度
uniform float streak_speed = 34.0;    // 流线漂移速度（平面 px/s）
uniform float shimmer_strength = 0.12; // 大尺度水色斑驳强度


float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}


float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}


// 盖章式白色笔触：流向空间划分交错网格，每格按概率放一枚圆头胶囊 dash。
// q 单位 = 平面 px（已含漂移），cell_size = (沿流, 横流) 格尺寸。
float dash_field(vec2 q, vec2 cell_size, float density, float seed) {
	float row = floor(q.y / cell_size.y);
	q.x += mod(row, 2.0) * cell_size.x * 0.5;
	vec2 id = floor(q / cell_size);
	vec2 local_px = (fract(q / cell_size) - 0.5) * cell_size;
	float has_dash = step(hash21(id + vec2(seed, seed * 1.7)), density);
	float len_t = pow(hash21(id + vec2(seed + 3.1, 1.3)), 1.4); // 偏短分布
	float half_len = cell_size.x * mix(0.10, 0.42, len_t);
	float half_th = mix(1.7, 3.4, hash21(id + vec2(seed + 5.7, 2.9)));
	vec2 offs = (vec2(hash21(id + vec2(seed + 7.7, 0.7)), hash21(id + vec2(seed + 9.3, 4.1))) - 0.5)
			* vec2(cell_size.x * 0.22, cell_size.y * 0.45);
	vec2 d = local_px - offs;
	float ang = (hash21(id + vec2(seed + 13.7, 8.9)) - 0.5) * 0.30; // 每笔 ±8.6° 随机倾角
	float ca = cos(ang);
	float sa = sin(ang);
	d = vec2(ca * d.x - sa * d.y, sa * d.x + ca * d.y);
	float cap_d = length(vec2(max(abs(d.x) - half_len, 0.0), d.y));
	float inside = 1.0 - smoothstep(half_th - 1.0, half_th + 1.0, cap_d);
	float fade = mix(0.55, 1.0, hash21(id + vec2(seed + 11.9, 6.3)));
	return inside * has_dash * fade;
}


float shore_distance(vec2 p) {
	float sd = 1e6;
	for (int i = 0; i < 96; i++) {
		if (i >= seg_count) {
			break;
		}
		vec2 a = seg_a[i];
		vec2 ba = seg_b[i] - a;
		vec2 pa = p - a;
		float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-4), 0.0, 1.0);
		sd = min(sd, length(pa - ba * h));
	}
	for (int i = 0; i < 8; i++) {
		if (i >= rock_count) {
			break;
		}
		sd = min(sd, length(p - rock_data[i].xy) - rock_data[i].z);
	}
	return sd;
}


void fragment() {
	vec2 p = UV;
	float e = edge_px;
	float sd = shore_distance(p);

	vec2 fd = normalize(flow_dir);
	vec2 pd = vec2(-fd.y, fd.x);
	vec2 sp = vec2(dot(p, fd), dot(p, pd));

	// 深浅分区平涂：浅→中→深三段色区，边界被噪声扰动成蜿蜒手绘块面
	float zone_n = (vnoise(p * (1.5 / e) + vec2(2.2, 8.8)) - 0.5) * 0.10 * e;
	float sdz = sd + zone_n;
	float depth_t = smoothstep(0.32 * e, 0.44 * e, sdz);
	vec3 col = mix(shallow_color, mid_color, smoothstep(0.08 * e, 0.15 * e, sdz));
	col = mix(col, deep_color, depth_t);
	col *= mix(1.0, 0.88, smoothstep(0.50 * e, 0.72 * e, sdz)); // 最深再压一档厚度

	// 顺流明度渐变（上游略深、下游略亮）
	float t_flow = clamp((sp.x - flow_span.x) / max(flow_span.y - flow_span.x, 1.0), 0.0, 1.0);
	col *= mix(0.93, 1.06, t_flow);

	// 大尺度水色斑驳 + 亮青水洗斑块 + 细碎色相偏移（手绘块面感）
	float patch = vnoise(p * (0.7 / e) + vec2(TIME * 0.02, 0.0));
	col *= 1.0 + shimmer_strength * (patch - 0.5) * 2.0;
	float wash = smoothstep(0.60, 0.82, vnoise(p * (0.55 / e) + vec2(31.7, TIME * 0.015)));
	col = mix(col, shallow_color, wash * 0.35);
	float hue_n = vnoise(p * (2.4 / e) + vec2(7.7, 3.9));
	col += vec3(-0.015, 0.010, 0.014) * (hue_n - 0.5) * 2.0;

	// 轻降饱和去"电子感"
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(luma), 0.06);

	// 顺流白色笔触：流向空间先做蜿蜒扰动，再盖两层 dash（长+短）+ 一条弱等值线长曲线
	float drift = streak_speed * TIME;
	vec2 spw = sp;
	spw.y += (vnoise(vec2(sp.x * (0.35 / e), 3.3)) - 0.5) * 36.0; // 笔触行随水流蜿蜒
	float dash_a = dash_field(vec2(spw.x - drift, spw.y), vec2(150.0, 22.0), 0.34, 1.0);
	float dash_b = dash_field(vec2(spw.x - drift * 1.5, spw.y + 37.0), vec2(72.0, 15.0), 0.24, 21.0);
	float n1 = vnoise(vec2((spw.x - drift * 0.8) * (0.5 / e), spw.y * (4.6 / e)));
	float curve = (1.0 - smoothstep(0.015, 0.05, abs(n1 - 0.58))) * 0.5;
	float streaks = max(max(dash_a, dash_b * 0.8), curve);
	float sparsity = vnoise(vec2((spw.x - drift * 0.3) * (0.45 / e), spw.y * (0.9 / e)));
	streaks *= smoothstep(0.48, 0.64, sparsity); // 疏密分布：成簇出现
	streaks *= smoothstep(0.10 * e, 0.20 * e, sd); // 避开岸沫区
	streaks *= 1.0 - 0.25 * depth_t; // 深水区纹理略稀
	// 软高光：浅青灰笔触（大多数），硬白点留给白沫/尾流
	col = mix(col, vec3(0.88, 0.95, 0.93), streaks * streak_alpha);

	// 礁石下游尾流白沫（顺流拖尾 + 噪声破碎）
	float wake = 0.0;
	for (int i = 0; i < 8; i++) {
		if (i >= rock_count) {
			break;
		}
		vec2 rel = p - rock_data[i].xy;
		float ru = dot(rel, fd);
		float rv = dot(rel, pd);
		float rr = rock_data[i].z;
		float wake_len = rr * 7.0;
		float t_w = clamp(ru / max(wake_len, 1.0), 0.0, 1.0);
		float half_w = mix(rr * 0.9, rr * 1.8, t_w);
		float lateral = 1.0 - smoothstep(half_w * 0.5, half_w, abs(rv));
		float along = (1.0 - smoothstep(0.0, 1.0, t_w)) * step(0.0, ru);
		float wn = vnoise(vec2((ru - drift * 0.9) * 0.05, rv * 0.12));
		wake = max(wake, lateral * along * smoothstep(0.25, 0.55, wn));
		// 石后实心白沫领圈（蛋形：下游拉长、上游圆收）
		float axial = mix(ru, ru * 0.72, step(0.0, ru));
		float collar_d = length(vec2(axial, rv));
		wake = max(wake, 1.0 - smoothstep(rr * 1.0, rr * 1.4, collar_d));
	}

	// 常亮湿边：低调浅色水线打底（白沫断口处仍看得到贴岸过渡）
	float wet = 1.0 - smoothstep(0.0, 0.07 * e, sd);
	col = mix(col, foam_color, wet * 0.22);

	// 贴岸白沫主线：双尺度手绘抖动 + 更强断口
	float wob = (vnoise(p * (1.8 / e) + vec2(0.0, TIME * 0.08)) - 0.5) * 0.18 * e
			+ (vnoise(p * (6.5 / e) + vec2(5.1, TIME * 0.12)) - 0.5) * 0.04 * e;
	float aa = max(fwidth(sd) * 1.2, 1.0);
	float foam_main = 1.0 - smoothstep(foam_width * e + wob - aa, foam_width * e + wob + aa, sd);
	float gap_n = vnoise(p * (3.2 / e) + vec2(13.3, 7.7));
	foam_main *= smoothstep(0.22, 0.40, gap_n); // 偶发断口让岸沫不闭合

	// 第二道碎沫（断续弧线，顺流缓漂）
	float band_d = abs(sd - (foam2_dist * e + wob * 1.2));
	float foam_band = 1.0 - smoothstep(foam2_width * e - aa, foam2_width * e + aa, band_d);
	float band_break = vnoise(vec2((sp.x - drift * 0.4) * (1.8 / e), sp.y * (1.8 / e)));
	foam_band *= smoothstep(0.44, 0.58, band_break);

	float foam = clamp(foam_main + foam_band * 0.8 + wake * 0.9, 0.0, 1.0);
	col = mix(col, foam_color, foam);

	// 纸面颗粒（世界空间稳定，不闪）
	col += (hash21(floor(p * 0.55)) - 0.5) * 0.018;

	COLOR = vec4(col, 1.0);
}
