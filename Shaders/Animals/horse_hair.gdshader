shader_type spatial;
render_mode cull_disabled;  // Show both sides of hair

// Preset hair/mane colors
uniform vec4 hair_color_1 : source_color = vec4(0.1, 0.08, 0.05, 1.0);   // Dark brown/black
uniform vec4 hair_color_2 : source_color = vec4(0.3, 0.2, 0.1, 1.0);     // Brown
uniform vec4 hair_color_3 : source_color = vec4(0.95, 0.95, 0.95, 1.0);  // White
uniform vec4 hair_color_4 : source_color = vec4(0.8, 0.7, 0.5, 1.0);     // Blonde
uniform vec4 hair_color_5 : source_color = vec4(0.15, 0.15, 0.15, 1.0);  // Black

// Color selection (set from code: 0-4)
uniform int selected_color : hint_range(0, 4) = 0;

void fragment() {
	vec4 chosen_color = hair_color_1;
	
	if (selected_color == 0) chosen_color = hair_color_1;
	else if (selected_color == 1) chosen_color = hair_color_2;
	else if (selected_color == 2) chosen_color = hair_color_3;
	else if (selected_color == 3) chosen_color = hair_color_4;
	else if (selected_color == 4) chosen_color = hair_color_5;
	
	ALBEDO = chosen_color.rgb;
}