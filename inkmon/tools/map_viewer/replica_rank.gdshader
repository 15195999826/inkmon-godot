shader_type canvas_item;
render_mode blend_disabled;
// 秩归一 prep: raw 场 + CDF LUT → R = elev 秩 (海=0, mock 的 pctl_norm 掩膜语义) G = land 0/1。

uniform sampler2D u_fields : filter_nearest;
uniform sampler2D u_cdf : filter_linear;
uniform float u_emin = 0.0;
uniform float u_erange = 1.0;


void fragment() {
	vec4 fields = texture(u_fields, UV);
	float land = step(0.5, fields.b);
	float rank = texture(u_cdf, vec2(clamp((fields.r - u_emin) / u_erange, 0.0, 1.0), 0.5)).r;
	COLOR = vec4(rank * land, land, 0.0, 1.0);
}
