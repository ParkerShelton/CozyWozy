shader_type spatial;
render_mode unshaded;
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