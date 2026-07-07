shader_type canvas_item;

// fable-水shader-v1 卡通青绿变体（_toon）河口截面（水从图边流出的竖直切面）：
// 深青渐变 + 下落白色条纹动画 + 顶部翻边白沫。R1-R10 迭代态。
// UV.x = 沿岸边的平面坐标（px，跨相邻面连续），UV.y = 自水面向下的屏幕 px。

uniform vec3 top_color: source_color = vec3(0.11, 0.50, 0.53);
uniform vec3 bottom_color: source_color = vec3(0.04, 0.29, 0.37);
uniform vec3 foam_color: source_color = vec3(0.95, 0.99, 0.97);
uniform float face_height = 57.0;  // GDScript 注入：截面总高（px）
uniform float fall_speed = 55.0;   // 下落条纹速度（px/s）
uniform float lip_height = 7.0;    // 顶部翻边白沫高度（px）


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

	// 竖直下落条纹：列噪声 × 纵向滚动噪声
	float column = vnoise(vec2(p.x * 0.055, 7.3));
	float scroll = vnoise(vec2(p.x * 0.05, (p.y - TIME * fall_speed) * 0.045));
	float streaks = smoothstep(0.60, 0.78, scroll * (0.7 + 0.6 * column));

	// 顶部翻边白沫（带轻微抖动）
	float lip_wob = (vnoise(vec2(p.x * 0.11, TIME * 0.2)) - 0.5) * 4.0;
	float lip = 1.0 - smoothstep(lip_height * 0.4, lip_height, p.y + lip_wob);

	float foam = clamp(streaks * 0.5 + lip, 0.0, 1.0);
	col = mix(col, foam_color, foam);
	COLOR = vec4(col, 1.0);
}
