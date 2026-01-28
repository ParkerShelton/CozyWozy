shader_type spatial;
render_mode unshaded;

uniform sampler2D layer_mask_texture : hint_default_white;

void fragment() {
	vec4 layer_sample = texture(layer_mask_texture, SCREEN_UV);
	
	// Show the FULL color from viewport (RGB + alpha as brightness)
	ALBEDO = layer_sample.rgb;
	ALPHA = 1.0;
}