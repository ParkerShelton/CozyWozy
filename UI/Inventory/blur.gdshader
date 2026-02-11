shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float blur_amount : hint_range(0.0, 5.0) = 2.0;

void fragment() {
	vec4 color = vec4(0.0);
	
	// Simple box blur
	float total = 0.0;
	
	for(float x = -blur_amount; x <= blur_amount; x += 1.0) {
		for(float y = -blur_amount; y <= blur_amount; y += 1.0) {
			color += texture(SCREEN_TEXTURE, SCREEN_UV + vec2(x, y) * SCREEN_PIXEL_SIZE);
			total += 1.0;
		}
	}
	
	COLOR = color / total;
}