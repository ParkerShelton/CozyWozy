shader_type spatial;

// Preset body colors
uniform vec4 body_color_1 : source_color = vec4(0.35, 0.25, 0.15, 1.0);  // Brown
uniform vec4 body_color_2 : source_color = vec4(0.15, 0.1, 0.05, 1.0);   // Dark brown
uniform vec4 body_color_3 : source_color = vec4(0.9, 0.85, 0.75, 1.0);   // Cream
uniform vec4 body_color_4 : source_color = vec4(0.2, 0.2, 0.2, 1.0);     // Black
uniform vec4 body_color_5 : source_color = vec4(0.6, 0.5, 0.4, 1.0);     // Tan
uniform vec4 body_color_6 : source_color = vec4(0.95, 0.95, 0.95, 1.0);  // White
uniform vec4 body_color_7 : source_color = vec4(0.5, 0.3, 0.2, 1.0);     // Chestnut

// Color selection (set from code: 0-6)
uniform int selected_color : hint_range(0, 6) = 0;

// Spot settings
uniform bool has_spots = false;
uniform vec4 spot_color : source_color = vec4(0.95, 0.95, 0.95, 1.0);  // Default white spots
uniform float spot_scale : hint_range(0.5, 20.0) = 2.5;                // Size of spots
uniform float spot_threshold : hint_range(0.0, 1.0) = 0.45;            // Higher = fewer spots
uniform float spot_edge_softness : hint_range(0.0, 0.15) = 0.05;       // Soft edges on spots
uniform float spot_seed : hint_range(0.0, 100.0) = 0.0;                // Unique per horse
uniform float spot_roundness : hint_range(0.5, 2.0) = 1.0;             // Stretch correction

// 2D hash for random dot placement
vec2 hash2(vec2 p) {
	p = vec2(
		dot(p, vec2(127.1, 311.7)),
		dot(p, vec2(269.5, 183.3))
	);
	return fract(sin(p) * 43758.5453123);
}

// Random dot size per cell
float hash1(vec2 p) {
	return fract(sin(dot(p, vec2(41.1, 289.7))) * 43758.5453);
}

// Round spots using distance to random points in grid cells
float round_spots(vec2 p) {
	vec2 i_pos = floor(p);
	vec2 f_pos = fract(p);
	
	float result = 1.0;
	
	// Check neighboring cells for overlapping dots
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			vec2 neighbor = vec2(float(x), float(y));
			vec2 cell = i_pos + neighbor;
			vec2 point = hash2(cell);  // Random center in cell
			float radius = 0.2 + hash1(cell) * 0.25;  // Random radius per dot
			vec2 diff = neighbor + point - f_pos;
			float dist = length(diff);
			float dot_mask = smoothstep(radius, radius - spot_edge_softness, dist);
			result = min(result, 1.0 - dot_mask);
		}
	}
	
	return 1.0 - result;
}

void fragment() {
	vec4 chosen_color = body_color_1;
	
	if (selected_color == 0) chosen_color = body_color_1;
	else if (selected_color == 1) chosen_color = body_color_2;
	else if (selected_color == 2) chosen_color = body_color_3;
	else if (selected_color == 3) chosen_color = body_color_4;
	else if (selected_color == 4) chosen_color = body_color_5;
	else if (selected_color == 5) chosen_color = body_color_6;
	else if (selected_color == 6) chosen_color = body_color_7;
	
	vec3 final_color = chosen_color.rgb;
	
	if (has_spots) {
		// Use UV coordinates + seed, with roundness correction for UV stretching
		vec2 corrected_uv = UV * vec2(1.0, spot_roundness);
		vec2 sample_pos = corrected_uv * spot_scale + vec2(spot_seed, spot_seed * 0.7);
		float spot_mask = round_spots(sample_pos);
		
		final_color = mix(chosen_color.rgb, spot_color.rgb, spot_mask);
	}
	
	ALBEDO = final_color;
	ROUGHNESS = 1.0;
}
