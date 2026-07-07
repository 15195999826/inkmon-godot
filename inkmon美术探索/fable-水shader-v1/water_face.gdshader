shader_type canvas_item;

// fable-水shader-v1 河口截面（水从图边流出的竖直切面）：
// 参考图小瀑布语言 —— 灰蓝水体 + 细密白色竖条纹下落动画 + 顶部翻边亮线。
// UV.x = 沿岸边的平面坐标（px，跨相邻面连续），UV.y = 自水面向下的屏幕 px。

uniform vec3 top_color: source_color = vec3(0.34, 0.46, 0.50);
uniform vec3 bottom_color: source_color = vec3(0.22, 0.32, 0.38);
uniform vec3 streak_color: source_color = vec3(0.86, 0.92, 0.93);
uniform float face_height = 45.0;  // GDScript 注入：截面总高（px）
uniform float fall_speed = 42.0;   // 下落条纹速度（px/s）
uniform float lip_height = 5.0;    // 顶部翻边亮线高度（px）


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


void fragment() {
	vec2 p = UV;
	float t_v = clamp(p.y / max(face_height, 1.0), 0.0, 1.0);
	vec3 col = mix(top_color, bottom_color, t_v);

	// 细密竖条纹：列噪声（粗细/明暗随列变化）× 纵向滚动；越往下越白（水花散开）
	float column = vnoise(vec2(p.x * 0.16, 7.3));
	float column2 = vnoise(vec2(p.x * 0.34, 2.1));
	float scroll = vnoise(vec2(p.x * 0.12, (p.y - TIME * fall_speed) * 0.06));
	float streaks = smoothstep(0.40, 0.62, scroll * (0.70 + 0.4 * column) + column2 * 0.22);
	streaks *= 0.75 + 0.35 * t_v;
	// 纵向断裂：拉丝不整条贯通，白但脏
	float strand_break = vnoise(vec2(p.x * 0.09 + 5.0, (p.y - TIME * fall_speed * 0.7) * 0.025));
	streaks *= 0.55 + 0.45 * smoothstep(0.30, 0.60, strand_break);

	// 顶部翻边亮线（水折过边缘）
	float lip_wob = (vnoise(vec2(p.x * 0.14, TIME * 0.2)) - 0.5) * 3.0;
	float lip = 1.0 - smoothstep(lip_height * 0.4, lip_height, p.y + lip_wob);

	// 底部雾化（水花散成雾贴着落水区）
	float mist_n = vnoise(vec2(p.x * 0.10, TIME * 0.8));
	float mist = smoothstep(0.68, 1.0, t_v) * (0.45 + 0.30 * mist_n);

	float bright = clamp(streaks * 0.7 + lip * 0.8 + mist, 0.0, 1.0);
	col = mix(col, streak_color, bright);
	COLOR = vec4(col, 1.0);
}
