# rain.gd
extends ColorRect

# --------------- Rain Settings ---------------
@export_category("Rain Settings")
@export_range(0.0, 1.0) var rain_intensity: float = 0.35:
	set(value):
		rain_intensity = value
		if material:
			material.set_shader_parameter("rain_intensity", value)
@export var wind_direction: Vector2 = Vector2(0.1, 1.0):
	set(value):
		wind_direction = value
		if material:
			material.set_shader_parameter("wind_direction", value)
@export_range(0.5, 5.0) var rain_speed: float = 3.0:
	set(value):
		rain_speed = value
		if material:
			material.set_shader_parameter("rain_speed", value)
@export_range(20.0, 200.0) var rain_density: float = 25.0:
	set(value):
		rain_density = value
		if material:
			material.set_shader_parameter("rain_density", value)

# --------------- Visual Settings ---------------
@export_category("Visual Settings")
@export var rain_color: Color = Color(0.9, 0.95, 1.0):
	set(value):
		rain_color = value
		if material:
			material.set_shader_parameter("rain_color", Vector3(value.r, value.g, value.b))
@export_range(0.0, 1.0) var rain_alpha: float = 0.45:
	set(value):
		rain_alpha = value
		if material:
			material.set_shader_parameter("rain_alpha", value)

# --------------- Fog Settings ---------------
@export_category("Fog Settings")
@export var enable_fog: bool = true:
	set(value):
		enable_fog = value
		if material:
			material.set_shader_parameter("enable_fog", value)
@export var fog_color: Color = Color(0.6, 0.65, 0.7):
	set(value):
		fog_color = value
		if material:
			material.set_shader_parameter("fog_color", Vector3(value.r, value.g, value.b))
@export_range(0.0, 1.0) var fog_intensity: float = 0.08:
	set(value):
		fog_intensity = value
		if material:
			material.set_shader_parameter("fog_intensity", value)

# --------------- Weather Scheduling ---------------
@export_category("Weather Scheduling")
@export var rain_chance: float = 0.3          # 30% chance to rain each check window
@export var check_interval_days: int = 2      # Roll every N in-game days
@export var rain_duration_days: int = 1       # Rain lasts N full in-game days

# --------------- Internal State ---------------
var is_raining: bool = false

# Tracks how many full days have elapsed since the last roll
var days_since_last_roll: int = 0
# Tracks how many full days of rain remain (0 = not raining)
var rain_days_remaining: int = 0
# The last completed day index we processed, so we only tick once per day boundary
var last_completed_day: int = -1

# Reference to the day/night cycle node (cached on first use)
var _day_night_cycle: ColorRect = null

func _ready():
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = MOUSE_FILTER_IGNORE
	
	setup_shader()
	visible = false
	modulate.a = 0.0

func _process(_delta):
	_tick_weather_scheduler()

# --------------- Shader Setup ---------------

func setup_shader():
	var rain_shader = load("res://Shaders/rain.gdshader")
	var shader_material = ShaderMaterial.new()
	shader_material.shader = rain_shader
	material = shader_material
	update_shader_parameters()

func update_shader_parameters():
	if not material:
		return
	material.set_shader_parameter("rain_intensity", rain_intensity)
	material.set_shader_parameter("wind_direction", wind_direction)
	material.set_shader_parameter("rain_speed", rain_speed)
	material.set_shader_parameter("rain_density", rain_density)
	material.set_shader_parameter("rain_color", Vector3(rain_color.r, rain_color.g, rain_color.b))
	material.set_shader_parameter("rain_alpha", rain_alpha)
	material.set_shader_parameter("enable_fog", enable_fog)
	material.set_shader_parameter("fog_color", Vector3(fog_color.r, fog_color.g, fog_color.b))
	material.set_shader_parameter("fog_intensity", fog_intensity)

# --------------- Weather Scheduler ---------------
# Logic overview:
#   - We derive a "completed day" count from the day/night cycle's continuous timer.
#   - Each time that count increments (a new day boundary crossed), we run one tick:
#       - If currently raining, decrement rain_days_remaining. Stop rain when it hits 0.
#       - If not raining, increment days_since_last_roll. Roll when it reaches check_interval_days.

func _get_day_night_cycle() -> ColorRect:
	if _day_night_cycle and is_instance_valid(_day_night_cycle):
		return _day_night_cycle
	_day_night_cycle = get_node_or_null("/root/main/day_night_overlay/ColorRect")
	return _day_night_cycle

func _tick_weather_scheduler():
	var dnc = _get_day_night_cycle()
	if not dnc:
		return
	
	# day_duration is seconds per in-game day; time is continuous elapsed seconds
	var day_duration: float = dnc.day_duration
	var completed_day: int = int(dnc.get_time() / day_duration)
	
	# Only process once per day boundary
	if completed_day == last_completed_day:
		return
	last_completed_day = completed_day
	
	# --- Rain countdown ---
	if rain_days_remaining > 0:
		rain_days_remaining -= 1
		if rain_days_remaining <= 0:
			stop_rain()
		return  # Don't roll while it's still raining
	
	# --- Roll window countdown ---
	days_since_last_roll += 1
	if days_since_last_roll >= check_interval_days:
		days_since_last_roll = 0
		if randf() < rain_chance:
			rain_days_remaining = rain_duration_days
			start_rain()

# --------------- Public Rain Controls ---------------
# These remain available for manual triggers or events (e.g. story events).

func start_rain(intensity: float = 0.35, fade_in_time: float = 2.0):
	is_raining = true
	visible = true
	rain_intensity = intensity
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, fade_in_time)

func stop_rain(fade_out_time: float = 2.0):
	is_raining = false
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_out_time)
	tween.tween_callback(func(): visible = false)

func set_rain_intensity_smooth(new_intensity: float, transition_time: float = 1.0):
	var tween = create_tween()
	tween.tween_property(self, "rain_intensity", new_intensity, transition_time)

func set_wind_smooth(new_direction: Vector2, transition_time: float = 3.0):
	var tween = create_tween()
	tween.tween_property(self, "wind_direction", new_direction, transition_time)
