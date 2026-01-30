shader_type canvas_item;

uniform vec4 day_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);
uniform vec4 night_color : source_color = vec4(0.1, 0.1, 0.2, 0.7);
uniform float time_of_day : hint_range(0.0, 1.0) = 0.5;

// Single light
uniform vec2 light_position = vec2(0.5, 0.5);
uniform float light_radius = 0.2;
uniform vec3 light_color = vec3(1.0, 0.7, 0.4);
uniform float light_intensity = 0.8;
uniform bool light_enabled = false;
uniform float falloff_power : hint_range(1.0, 5.0) = 2.5;

void fragment() {
	vec4 base_color = mix(night_color, day_color, time_of_day);
	
	float light_amount = 0.0;
	
	if (light_enabled) {
		float dist = distance(UV, light_position);
		float normalized_dist = clamp(dist / light_radius, 0.0, 1.0);
		
		// Adjust falloff_power to change inner circle size
		float falloff = pow(1.0 - normalized_dist, falloff_power);
		
		float pulse = 0.85 + sin(TIME * 3.0) * 0.15;
		light_amount = falloff * light_intensity * pulse;
	}
	
	vec4 final_color = base_color;
	final_color.a = base_color.a * (1.0 - light_amount);
	final_color.rgb = base_color.rgb + (light_color * light_amount);
	
	COLOR = final_color;
}