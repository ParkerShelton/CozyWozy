shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 electric_color : source_color = vec4(0.1, 0.4, 1.0, 1.0);  // Deep blue
uniform vec4 core_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);  // Bright white
uniform float glow_strength : hint_range(0.0, 10.0) = 4.0;
uniform float pulse_speed : hint_range(0.0, 20.0) = 8.0;
uniform float pulse_intensity : hint_range(0.0, 2.0) = 1.0;

void fragment() {
	// Strong pulsing effect
	float pulse = sin(TIME * pulse_speed) * 0.5 + 0.5;
	pulse = pow(pulse, 2.0);  // Make pulse more dramatic
	
	// Gradient from center (bright white) to edge (blue)
	vec2 center = vec2(0.5, 0.5);
	float dist = distance(UV, center) * 2.0;
	dist = clamp(dist, 0.0, 1.0);
	
	// Sharp core, blue edges
	vec3 color = mix(core_color.rgb, electric_color.rgb, pow(dist, 0.5));
	
	// Apply STRONG pulsing
	float pulse_effect = 0.5 + (pulse * pulse_intensity);
	color *= pulse_effect;
	
	ALBEDO = color;
	
	// Very strong emission with pulsing
	EMISSION = color * glow_strength * (0.5 + pulse * 1.5);
	
	ALPHA = 1.0;
}