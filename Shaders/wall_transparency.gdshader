shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

uniform vec3 player_position = vec3(0.0, 0.0, 0.0);

void fragment() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float dist = distance(player_position, world_pos);
	
	// If player is within 3 units, make wall 50% transparent
	if (dist < 3.0) {
		ALPHA = 0.5;
	} else {
		ALPHA = 1.0;
	}
	
	ALBEDO = vec3(0.5, 0.5, 0.5);
}