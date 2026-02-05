shader_type spatial;

uniform vec4 base_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);

// Individual neighbor colors
uniform vec4 right_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 left_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 forward_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 back_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);

// Blend amounts for each direction
uniform float right_blend : hint_range(0.0, 1.0) = 0.0;
uniform float left_blend : hint_range(0.0, 1.0) = 0.0;
uniform float forward_blend : hint_range(0.0, 1.0) = 0.0;
uniform float back_blend : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 color = base_color;
	
	// Blend with right neighbor
	if (right_blend > 0.0) {
		float factor = UV.x * right_blend;
		color = mix(color, right_color, factor);
	}
	
	// Blend with left neighbor
	if (left_blend > 0.0) {
		float factor = (1.0 - UV.x) * left_blend;
		color = mix(color, left_color, factor);
	}
	
	// Blend with forward neighbor
	if (forward_blend > 0.0) {
		float factor = UV.y * forward_blend;
		color = mix(color, forward_color, factor);
	}
	
	// Blend with back neighbor
	if (back_blend > 0.0) {
		float factor = (1.0 - UV.y) * back_blend;
		color = mix(color, back_color, factor);
	}
	
	ALBEDO = color.rgb;
}