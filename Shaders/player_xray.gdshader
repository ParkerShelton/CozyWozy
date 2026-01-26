shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

uniform vec4 xray_color : source_color = vec4(0.0, 1.0, 1.0, 0.6);
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_nearest;

void fragment() {
	float scene_depth = texture(DEPTH_TEXTURE, SCREEN_UV).x;
	float delta = FRAGCOORD.z - scene_depth;

	// If delta is positive, we're behind something
	if (delta < 0.0001) {
		discard;
	}

	ALBEDO = xray_color.rgb;
	ALPHA = xray_color.a;
}