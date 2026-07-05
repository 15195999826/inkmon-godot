shader_type canvas_item;
render_mode blend_disabled;
// 1D box 模糊 (分离两趟 ×3 轮 ≈ 高斯 σ≈radius; PIL GaussianBlur(radius=σ) 的复刻近似)。

uniform sampler2D u_tex : filter_nearest;
uniform vec2 u_dir_texel = vec2(0.0);
uniform int u_radius = 1;


void fragment() {
	vec4 total = vec4(0.0);
	for (int i = -u_radius; i <= u_radius; i++) {
		total += texture(u_tex, clamp(UV + u_dir_texel * float(i), vec2(0.0), vec2(1.0)));
	}
	COLOR = total / float(u_radius * 2 + 1);
}
