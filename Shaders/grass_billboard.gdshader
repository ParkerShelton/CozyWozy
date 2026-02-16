shader_type spatial;
render_mode cull_back;

global uniform float wind_scale;
global uniform float wind_speed;
global uniform float wind_strength;
global uniform vec3 wind_direction;
global uniform sampler2D wind_noise : filter_linear_mipmap;
global uniform vec3 player_position;

uniform sampler2D cloud_shadow_texture : filter_linear_mipmap;
uniform float cloud_shadow_scale = 0.02;
uniform float cloud_shadow_speed = 0.05;
uniform float cloud_shadow_strength = 0.4;
uniform vec2 cloud_direction = vec2(1.0, 0.5);

uniform vec4 grass_color : source_color;
uniform sampler2D grass_alpha : source_color;
uniform float grass_bend_amount = 1.0;
uniform float sway_back : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float light_steps = 3.0;
uniform float interaction_radius = 2.0;
uniform float interaction_strength = 0.5;

varying vec3 node_pos_view;
varying vec3 node_pos_world;

vec4 CalculateWind(vec4 uv, float speed, vec3 rotate_direction, float uv_scale, float mip_level){
	// Scrolling Wind Noise
	vec3 noise_texture = textureLod(wind_noise, (uv.xz * uv_scale) - (speed * wind_direction.xz), mip_level).rgb;
	noise_texture = noise_texture * (1. + sway_back) - sway_back;
	// Vertex Displacement
	vec4 displace = vec4((noise_texture * rotate_direction) , 0.0);
	return displace;
}

void vertex() {
	// Varyings
	node_pos_view = NODE_POSITION_VIEW;
	node_pos_world = NODE_POSITION_WORLD;
	
	// Wind Animation
	vec4 world_pos = MODEL_MATRIX * vec4(VERTEX, 1.0);
	float speed = TIME * wind_speed;
	float displace_ammount = wind_strength * grass_bend_amount;
	
	vec4 direction = normalize(VIEW_MATRIX * vec4(wind_direction, 0.0)); //rotate the billboard in the direction of the wind
	//vec3 direction = vec3(1.0, 0.0, 0.0); //rotate the billboard sideways to the camera
	vec4 displace = CalculateWind(world_pos, speed, direction.xyz, wind_scale, 2.0);
	float uv_mask = 1. - UV.y;
	displace *= displace_ammount * uv_mask;
	
	// PLAYER INTERACTION
	vec3 grass_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 to_grass = grass_world_pos - player_position;
	to_grass.y = 0.0; // Only horizontal displacement
	float distance_to_player = length(to_grass);
	
	if (distance_to_player < interaction_radius) {
		// Smooth falloff using smoothstep
		float influence = 1.0 - smoothstep(0.0, interaction_radius, distance_to_player);
		vec3 push_direction = normalize(to_grass);
		
		// Push grass away from player
		vec3 push = push_direction * influence * interaction_strength * uv_mask;
		displace.xyz += push;
	}
	
	// Billboard
MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		MAIN_CAM_INV_VIEW_MATRIX[0],
		MAIN_CAM_INV_VIEW_MATRIX[1],
		MAIN_CAM_INV_VIEW_MATRIX[2],
		MODEL_MATRIX[3]);
// Billboard Keep Scale: Enabled
MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
VERTEX += displace.rgb;
}

void fragment() {
	// Color Variation
	float noise = texture(wind_noise, node_pos_world.xz * 0.04).r;
	noise = (noise + 2.5) / 3.5;
	noise = ceil(noise * 5.0) / 5.0;
	
	// Cloud Shadows
	vec2 cloud_uv = node_pos_world.xz * cloud_shadow_scale;
	cloud_uv += cloud_direction * TIME * cloud_shadow_speed;
	float cloud_shadow = texture(cloud_shadow_texture, cloud_uv).r;
	
	// Apply shadow (darken grass where clouds are)
	float shadow_amount = 1.0 - (cloud_shadow * cloud_shadow_strength);
	
	ALBEDO = grass_color.rgb * noise * shadow_amount;
	ALPHA = texture(grass_alpha, UV).r;
	ALPHA_SCISSOR_THRESHOLD = 0.75;
	SPECULAR = 0.0;
	LIGHT_VERTEX = node_pos_view; // shade the entire mesh based on the object position(pivot) instead of the pixel position
}

void light(){
	//Diffuse lighting
	float light = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	DIFFUSE_LIGHT += light * (LIGHT_COLOR / PI) * ATTENUATION;
}