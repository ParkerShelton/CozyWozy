shader_type canvas_item;
uniform vec2 target_resolution = vec2(640.0, 360.0);
const float colors_per_channel = 16.0;
uniform sampler2D screen_texture: hint_screen_texture, filter_nearest;
void fragment() {
	vec2 uv = floor(SCREEN_UV * target_resolution) / target_resolution;
	COLOR = vec4(texture(screen_texture, uv).rgb, 1.0);
}
