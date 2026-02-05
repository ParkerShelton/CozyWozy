shader_type spatial;

// Color palette to choose from
uniform vec4 color_1 : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform vec4 color_2 : source_color = vec4(0.0, 1.0, 0.0, 1.0);
uniform vec4 color_3 : source_color = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 color_4 : source_color = vec4(1.0, 1.0, 0.0, 1.0);

// Random seed - set this per instance from code
uniform float random_seed = 0.0;

float random(float seed) {
	return fract(sin(seed * 12.9898) * 43758.5453);
}

void fragment() {
	float rand = random(random_seed);
	
	vec4 chosen_color = color_1;
	if (rand < 0.25) chosen_color = color_1;
	else if (rand < 0.5) chosen_color = color_2;
	else if (rand < 0.75) chosen_color = color_3;
	else chosen_color = color_4;
	
	ALBEDO = chosen_color.rgb;
}