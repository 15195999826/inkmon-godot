shader_type canvas_item;

// InkMon overworld 水面 shader（生产版；探索/迭代记录见 inkmon美术探索/fable-水shader-v1）。
// 风格 = toon 青绿；动态 = voronoi 裂纹网线缓慢游动 + 整体顺流漂移。
// 几何数据（岸线段 seg / 落水线 fall / 流向 flow）由 InkMonRender2DBakedHexMap 从
// map doc 的 water_bodies + GridMapModel 推导后以平面坐标注入；UV 通道直通 hex 平面坐标
// （px），逐像素解析"到岸距离"距离场 → 深浅分区 / 岸沫 / 湿边全由它驱动。

// ============ 几何数据（GDScript 注入，勿手调） ============
uniform int seg_count = 0;
uniform vec2 seg_a[96];
uniform vec2 seg_b[96];
uniform int fall_count = 0;
uniform vec2 fall_a[8]; // 落水基线段（低位水一侧，白色翻涌；当前全平地图不触发）
uniform vec2 fall_b[8];
uniform vec2 flow_dir = vec2(-1.0, 0.0);
uniform vec2 flow_span = vec2(-1200.0, 1200.0); // dot(p, flow_dir) 的范围
uniform float edge_px = 128.0;

// ============ 视觉参数（toon 青绿；美术调这里，逐 water_body 可 override） ============
uniform vec3 deep_color: source_color = vec3(0.08, 0.38, 0.41);
uniform vec3 mid_color: source_color = vec3(0.16, 0.56, 0.53);
uniform vec3 shallow_color: source_color = vec3(0.30, 0.66, 0.64);
uniform vec3 crackle_color: source_color = vec3(0.80, 0.94, 0.91);
uniform float depth_far = 0.72;        // 深水分区尽头（edge 单位）
uniform float crackle_alpha = 0.26;    // 裂纹网线不透明度
uniform float crackle_scale = 24.0;    // 主裂纹网格尺寸（平面 px）
uniform float drift_speed = 5.0;       // 整体缓慢漂移（平面 px/s）
uniform float shimmer_strength = 0.08; // 大尺度水色斑驳强度
uniform float contact_shadow = 0.16;   // 贴岸接触阴影强度


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


// F2-F1 voronoi 边线：细碎浅色裂纹网（水面 caustics 手绘感）。
// 返回 0..1，网线处为 1。cell 缓慢正弦游动产生微光动画。
float crackle_web(vec2 p, float cell_px, float line_soft, float t) {
	vec2 q = p / cell_px;
	vec2 iq = floor(q);
	vec2 fq = fract(q);
	float f1 = 8.0;
	float f2 = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 rnd = vec2(hash21(iq + g), hash21(iq + g + 19.19));
			vec2 o = 0.5 + 0.38 * sin(t + 6.2831853 * rnd);
			vec2 r = g + o - fq;
			float d = dot(r, r);
			if (d < f1) {
				f2 = f1;
				f1 = d;
			} else if (d < f2) {
				f2 = d;
			}
		}
	}
	float edge_d = sqrt(f2) - sqrt(f1);
	return 1.0 - smoothstep(0.0, line_soft, edge_d);
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
	return sd;
}


void fragment() {
	vec2 p = UV;
	float e = edge_px;
	float sd = shore_distance(p);

	vec2 fd = normalize(flow_dir);
	vec2 sp = vec2(dot(p, fd), dot(p, vec2(-fd.y, fd.x)));

	// 深浅分区：贴岸微浅 → 中段 → 河心深，边界被噪声扰动成蜿蜒块面
	float zone_n = (vnoise(p * (1.5 / e) + vec2(2.2, 8.8)) - 0.5) * 0.12 * e;
	float sdz = sd + zone_n;
	float depth_t = smoothstep(0.34 * e, depth_far * e, sdz);
	vec3 col = mix(shallow_color, mid_color, smoothstep(0.03 * e, 0.11 * e, sdz));
	col = mix(col, deep_color, depth_t);
	col *= mix(1.0, 0.94, smoothstep(0.55 * e, 0.85 * e, sdz)); // 最深再压一档厚度

	// 顺流明度渐变（上游略深、下游略亮，非常轻）
	float t_flow = clamp((sp.x - flow_span.x) / max(flow_span.y - flow_span.x, 1.0), 0.0, 1.0);
	col *= mix(0.96, 1.04, t_flow);

	// 大尺度水色斑驳（缓慢变化的明暗块面）+ 细碎色相偏移 + 深青斑块（青绿保鲜，不做泥灰脏化）
	float patch = vnoise(p * (0.7 / e) + vec2(TIME * 0.015, 0.0));
	col *= 1.0 + shimmer_strength * (patch - 0.5) * 2.0;
	float hue_n = vnoise(p * (2.2 / e) + vec2(7.7, 3.9));
	col += vec3(-0.010, 0.006, 0.014) * (hue_n - 0.5) * 2.0;
	float mud_n = vnoise(p * (0.9 / e) + vec2(41.0, 13.0));
	col = mix(col, vec3(0.10, 0.34, 0.37), 0.06 * smoothstep(0.55, 0.85, mud_n));

	// 裂纹网线（两个尺度叠加，随水流极慢漂移 + cell 游动微光）
	vec2 pc = p - fd * (TIME * drift_speed);
	float web_a = crackle_web(pc, crackle_scale, 0.13, TIME * 0.35);
	float web_b = crackle_web(pc + vec2(311.0, 173.0), crackle_scale * 2.3, 0.11, TIME * 0.22 + 2.0);
	float web = clamp(web_a * 0.75 + web_b * 0.55, 0.0, 1.0);
	// fbm 掩码把完整蜂窝网打断成局部碎纹（避免冰裂感）
	float web_mask = vnoise(p * (1.1 / e) + vec2(17.0, 5.0)) * 0.65
			+ vnoise(p * (2.9 / e) + vec2(3.0, 29.0)) * 0.35;
	web *= smoothstep(0.28, 0.72, web_mask);
	col = mix(col, crackle_color, web * (crackle_alpha + 0.02));

	// 贴岸接触阴影（水贴壁处微暗，嵌入感）+ 断续湿边亮线（水贴壁的细亮弯月线）
	float contact = 1.0 - smoothstep(0.0, 0.06 * e, sd);
	col *= 1.0 - contact_shadow * contact;
	float lap_band = (1.0 - smoothstep(0.015 * e, 0.045 * e, sd)) * smoothstep(0.0, 0.012 * e, sd);
	float lap_gate = smoothstep(0.45, 0.62, vnoise(p * (2.6 / e) + vec2(23.1, TIME * 0.06)));
	col = mix(col, crackle_color, lap_band * lap_gate * 0.24);

	// 落水基部白色翻涌（瀑布砸进低位水面；相邻 water_body 有落差时由 fall 段触发）
	float fall_d = 1e6;
	float fall_u = 0.0;
	for (int i = 0; i < 8; i++) {
		if (i >= fall_count) {
			break;
		}
		vec2 a = fall_a[i];
		vec2 ba = fall_b[i] - a;
		vec2 pa = p - a;
		float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-4), 0.0, 1.0);
		float dd = length(pa - ba * h);
		if (dd < fall_d) {
			fall_d = dd;
			fall_u = h * length(ba);
		}
	}
	if (fall_count > 0) {
		float churn_n = vnoise(vec2(fall_u * 0.09, TIME * 1.1));
		float churn_n2 = vnoise(vec2(fall_u * 0.22 + 9.0, TIME * 1.7 + 3.0));
		float churn_w = (0.17 + 0.13 * churn_n) * e;
		float churn = 1.0 - smoothstep(churn_w * 0.35, churn_w, fall_d);
		churn *= 0.70 + 0.30 * churn_n2;
		float ray = vnoise(vec2(fall_u * 0.30 + 4.4, fall_d * 0.05 - TIME * 0.9));
		float rays = smoothstep(0.60, 0.76, ray) * (1.0 - smoothstep(0.20 * e, 0.42 * e, fall_d));
		col = mix(col, vec3(0.86, 0.95, 0.93), clamp(churn * 0.9 + rays * 0.5, 0.0, 1.0));
	}

	// 纸面颗粒（世界空间稳定，不闪）
	col += (hash21(floor(p * 0.55)) - 0.5) * 0.015;

	COLOR = vec4(col, 1.0);
}
