shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, skip_vertex_transform, depth_test_disabled;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float depth_threshold : hint_range(0.0, 1.0, 0.01) = 0.05;
uniform float normal_threshold : hint_range(0.0, 2.0, 0.01) = 0.5;
uniform float outline_thickness : hint_range(1.0, 5.0, 0.5) = 1.0;

uniform sampler2D depth_tex : hint_depth_texture;
uniform sampler2D normal_tex : hint_normal_roughness_texture;
uniform sampler2D screen_tex : hint_screen_texture;

void vertex() {
	POSITION = vec4(VERTEX.xy, 0.0, 1.0);
}

void fragment() {
	vec2 pixel = outline_thickness / VIEWPORT_SIZE;
	
	float d = texture(depth_tex, SCREEN_UV).r;
	float d_up = texture(depth_tex, SCREEN_UV + vec2(0.0, pixel.y)).r;
	float d_down = texture(depth_tex, SCREEN_UV - vec2(0.0, pixel.y)).r;
	float d_left = texture(depth_tex, SCREEN_UV - vec2(pixel.x, 0.0)).r;
	float d_right = texture(depth_tex, SCREEN_UV + vec2(pixel.x, 0.0)).r;
	
	float depth_diff = abs(d - d_up) + abs(d - d_down) + abs(d - d_left) + abs(d - d_right);
	
	vec3 n = texture(normal_tex, SCREEN_UV).rgb;
	vec3 n_up = texture(normal_tex, SCREEN_UV + vec2(0.0, pixel.y)).rgb;
	vec3 n_down = texture(normal_tex, SCREEN_UV - vec2(0.0, pixel.y)).rgb;
	vec3 n_left = texture(normal_tex, SCREEN_UV - vec2(pixel.x, 0.0)).rgb;
	vec3 n_right = texture(normal_tex, SCREEN_UV + vec2(pixel.x, 0.0)).rgb;
	
	float normal_diff = length(n - n_up) + length(n - n_down) + length(n - n_left) + length(n - n_right);
	
	float edge = step(depth_threshold, depth_diff) + step(normal_threshold, normal_diff);
	edge = clamp(edge, 0.0, 1.0);
	
	vec3 screen = texture(screen_tex, SCREEN_UV).rgb;
	ALBEDO = mix(screen, outline_color.rgb, edge);
	ALPHA = 1.0;
}