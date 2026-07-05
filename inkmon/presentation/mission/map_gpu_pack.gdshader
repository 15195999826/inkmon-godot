shader_type canvas_item;
render_mode blend_disabled;
// 打包 pass: 四条模糊链输出 → shade_tex 单纹理
// R = blur(rank·land, σ0.2u) G = blur(land, σ0.55u) B = blur(land, σ1.3u) A = blur(land, σ3.2u)。
// (rank prep 纹理 R=rank·land G=land; 模糊链整 RGBA 同模糊, 取各自通道即可。)

uniform sampler2D u_shade_blur : filter_linear;
uniform sampler2D u_near_blur : filter_linear;
uniform sampler2D u_shallow_blur : filter_linear;
uniform sampler2D u_depth_blur : filter_linear;


void fragment() {
	COLOR = vec4(
		texture(u_shade_blur, UV).r,
		texture(u_near_blur, UV).g,
		texture(u_shallow_blur, UV).g,
		texture(u_depth_blur, UV).g);
}
