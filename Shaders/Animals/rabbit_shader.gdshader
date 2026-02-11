shader_type spatial;

// Preset body colors
uniform vec4 body_color_1 : source_color = vec4(0.45, 0.35, 0.25, 1.0);  // Agouti brown (wild rabbit)
uniform vec4 body_color_2 : source_color = vec4(0.25, 0.18, 0.12, 1.0);  // Dark chocolate
uniform vec4 body_color_3 : source_color = vec4(0.95, 0.92, 0.85, 1.0);  // Belly white
uniform vec4 body_color_4 : source_color = vec4(0.12, 0.12, 0.12, 1.0);  // Black rex
uniform vec4 body_color_5 : source_color = vec4(0.72, 0.6, 0.45, 1.0);   // Sandy/fawn
uniform vec4 body_color_6 : source_color = vec4(0.93, 0.9, 0.88, 1.0);   // Himalayan white
uniform vec4 body_color_7 : source_color = vec4(0.55, 0.38, 0.22, 1.0);  // Cinnamon

// Color selection (set from code: 0-6)
uniform int selected_color : hint_range(0, 6) = 0;

void fragment() {
	vec4 chosen_color = body_color_1;
	
	if (selected_color == 0) chosen_color = body_color_1;
	else if (selected_color == 1) chosen_color = body_color_2;
	else if (selected_color == 2) chosen_color = body_color_3;
	else if (selected_color == 3) chosen_color = body_color_4;
	else if (selected_color == 4) chosen_color = body_color_5;
	else if (selected_color == 5) chosen_color = body_color_6;
	else if (selected_color == 6) chosen_color = body_color_7;
	
	ALBEDO = chosen_color.rgb;
	ROUGHNESS = 1.0;
}