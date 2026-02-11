shader_type canvas_item;

uniform float rain_intensity : hint_range(0.0, 1.0) = 0.35;
uniform vec2 wind_direction = vec2(0.1, 1.0);
uniform float rain_speed = 3.0;
uniform float rain_density = 25.0;
uniform vec3 rain_color : source_color = vec3(0.9, 0.95, 1.0);
uniform float rain_alpha : hint_range(0.0, 1.0) = 0.45;

// Fog/mist settings
uniform bool enable_fog = true;
uniform vec3 fog_color : source_color = vec3(0.6, 0.65, 0.7);
uniform float fog_intensity : hint_range(0.0, 1.0) = 0.08;

// Splash effects
uniform bool enable_splashes = true;
uniform float splash_perspective : hint_range(0.0, 1.0) = 0.6;
uniform float splash_size : hint_range(0.1, 1.0) = 0.3;  // NEW: Control splash size

float random(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

float rain_streak(vec2 uv, float time, float layer_speed, float layer_offset) {
    vec2 rain_uv = uv;
    
    // Move rain down
    rain_uv.y -= time * rain_speed * layer_speed * wind_direction.y;
    rain_uv.x += time * rain_speed * layer_speed * wind_direction.x;
    
    // Scale to create grid
    rain_uv *= vec2(rain_density, rain_density * 2.0);
    rain_uv.x += layer_offset;
    
    vec2 cell_id = floor(rain_uv);
    vec2 cell_uv = fract(rain_uv);
    
    // Skip 80% of columns
    float rand_offset = random(cell_id);
    if (rand_offset < 0.8) {
        return 0.0;
    }
    
    // Create thin rain streak
    float streak_width = 0.05;
    float center = 0.5;
    float streak = smoothstep(center - streak_width, center, cell_uv.x) * 
                   smoothstep(center + streak_width, center, cell_uv.x);
    
    // Shorter streaks
    float streak_length = 0.12;
    float length_fade = smoothstep(0.0, 0.02, cell_uv.y) * 
                        smoothstep(1.0, 1.0 - streak_length, cell_uv.y);
    
    // Vary brightness
    float brightness = mix(0.2, 0.9, random(cell_id + vec2(0.5)));
    
    return streak * length_fade * brightness;
}

float splash_effect(vec2 uv, float time) {
    if (!enable_splashes) {
        return 0.0;
    }
    
    // Perspective scale ONLY affects splash SIZE, not grid density
    // uv.y = 0 is top (far), uv.y = 1 is bottom (near)
    float perspective_scale = mix(1.0 - splash_perspective, 1.0, uv.y);
    
    // UNIFORM grid density across entire screen
    vec2 splash_uv = uv * vec2(25.0, 20.0);
    splash_uv.x += time * rain_speed * wind_direction.x * 0.2;
    
    vec2 splash_cell = floor(splash_uv);
    vec2 splash_pos = fract(splash_uv);
    
    // Random timing for each splash
    float rand = random(splash_cell);
    float splash_time = fract(time * 1.2 + rand * 10.0);
    
    // Show fewer splashes (70% don't show)
    if (rand < 0.7) {
        return 0.0;
    }
    
    // Create circular ripple at center of cell
    vec2 center = vec2(0.5, 0.5);
    float dist = length(splash_pos - center);
    
    // Size of splash affected by BOTH perspective AND splash_size uniform
    float base_size = splash_size * 0.4;  // Base size multiplier
    float max_radius = base_size * perspective_scale;
    float ring_radius = splash_time * max_radius;
    float ring_width = 0.1 * perspective_scale * splash_size;
    
    float ring = smoothstep(ring_radius + ring_width, ring_radius, dist) * 
                 smoothstep(ring_radius - ring_width, ring_radius, dist);
    
    // Fade out over time
    float fade = smoothstep(1.0, 0.3, splash_time);
    
    // Fade splashes based on distance (less visible far away)
    float distance_fade = mix(0.4, 1.0, uv.y);
    
    return ring * fade * distance_fade * 0.4;
}

void fragment() {
    vec2 uv = UV;
    float time = TIME;
    
    // Three layers
    float rain1 = rain_streak(uv, time, 1.0, 0.0);
    float rain2 = rain_streak(uv, time, 0.9, 25.0) * 0.5;
    float rain3 = rain_streak(uv, time, 1.1, 50.0) * 0.3;
    
    float rain = (rain1 + rain2 + rain3) * rain_intensity;
    
    // Add splashes
    float splashes = splash_effect(uv, time) * rain_intensity;
    
    // Combine
    float total_rain = rain + splashes;
    
    // Final color
    vec3 final_color = rain_color;
    float final_alpha = total_rain * rain_alpha;
    
    // Subtle fog
    if (enable_fog && rain_intensity > 0.1) {
        float fog_noise = random(uv * 5.0 + vec2(time * 0.01));
        float fog = fog_noise * fog_intensity * rain_intensity;
        
        final_color = mix(final_color, fog_color, 0.2);
        final_alpha += fog * 0.5;
    }
    
    COLOR = vec4(final_color, final_alpha);
}