shader_type canvas_item;
render_mode blend_mix;

uniform sampler2D floor_texture : source_color, filter_linear_mipmap, repeat_enable;

uniform float horizon_y = 0.60;
uniform float scroll = 0.0;
uniform float fov_scale = 0.88;
uniform float road_texture_scale = 0.09;
uniform float texture_v_scale = 0.075;
uniform float perspective_power = 1.05;
uniform float near_depth = 7.0;
uniform float curve_strength = 0.015;
uniform float sway = 0.0;
uniform vec4 fog_color : source_color = vec4(0.18, 0.46, 0.49, 1.0);


void fragment() {
	vec2 screen_uv = UV;
	if (screen_uv.y < horizon_y) {
		COLOR = vec4(0.0);
	} else {
		float ground_y = clamp((screen_uv.y - horizon_y) / max(1.0 - horizon_y, 0.001), 0.001, 1.0);
		float depth = near_depth / pow(ground_y, perspective_power);
		float far_weight = 1.0 - ground_y;

		float bend = sin(depth * 0.09 + scroll * 6.2831853) * curve_strength * depth * depth;
		float world_x = (screen_uv.x - 0.5) * depth * fov_scale + bend + sway * far_weight;
		float sample_u = clamp(world_x * road_texture_scale + 0.5, 0.0, 1.0);
		float sample_v = fract(depth * texture_v_scale + scroll);

		vec4 ground_color = texture(floor_texture, vec2(sample_u, sample_v));
		float fog = smoothstep(0.12, 0.92, far_weight);
		float near_shade = mix(0.72, 1.08, ground_y);
		vec3 rgb = ground_color.rgb * near_shade;
		rgb = mix(rgb, fog_color.rgb, fog * 0.62);

		float side_vignette = smoothstep(0.45, 0.02, abs(screen_uv.x - 0.5));
		rgb *= mix(0.80, 1.0, side_vignette);

		COLOR = vec4(rgb, 1.0);
	}
}
