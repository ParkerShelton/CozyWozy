extends Node

var day_length_minutes : float = 1.0
var start_time : float = 0.5

var time : float = 0.5
var world_env : WorldEnvironment
var sun : DirectionalLight3D

# Light settings
var day_color = Color(1.0, 0.95, 0.9)
var day_energy = 1.0

var night_color = Color(0.2, 0.2, 0.3)
var night_energy = 0.0  # Turn off at night

var sunrise_color = Color(1.0, 0.6, 0.3)

func _ready():
	time = start_time
	
	# Find nodes
	world_env = get_tree().get_first_node_in_group("world_env")
	sun = get_tree().get_first_node_in_group("sun")  # Add DirectionalLight3D to "sun" group
	
	if not world_env:
		print("ERROR: Add WorldEnvironment to 'world_env' group!")
	if not sun:
		print("ERROR: Add DirectionalLight3D to 'sun' group!")
	
	if world_env and world_env.environment == null:
		world_env.environment = Environment.new()

func _process(delta):
	# Update time
	var day_seconds = day_length_minutes * 60.0
	time += delta / day_seconds
	if time >= 1.0:
		time = 0.0
	
	# Calculate lighting
	var color : Color
	var energy : float
	
	if time < 0.25:  # Night
		color = night_color
		energy = night_energy
	elif time < 0.3:  # Sunrise
		var t = (time - 0.25) / 0.05
		color = night_color.lerp(sunrise_color, t)
		energy = lerp(night_energy, day_energy, t)
	elif time < 0.5:  # Morning
		var t = (time - 0.3) / 0.2
		color = sunrise_color.lerp(day_color, t)
		energy = day_energy
	elif time < 0.7:  # Afternoon
		color = day_color
		energy = day_energy
	elif time < 0.75:  # Sunset
		var t = (time - 0.7) / 0.05
		color = day_color.lerp(sunrise_color, t)
		energy = lerp(day_energy, night_energy, t)
	else:  # Evening
		var t = (time - 0.75) / 0.25
		color = sunrise_color.lerp(night_color, t)
		energy = night_energy
	
	# Apply to sun
	if sun:
		sun.light_color = color
		sun.light_energy = energy
		sun.visible = energy > 0.01  # Hide at night
	
	if energy  < 0.01:
		var t = (time - 0.75) / 0.05
		world_env.environment.sky.sky_material.energy_multiplier = lerpf(1,0.5,t)	
	
	# Apply ambient light
	if world_env and world_env.environment:
		var env = world_env.environment
		env.ambient_light_color = color
		env.ambient_light_energy = energy * 0.3  # Ambient is dimmer

func get_time_string() -> String:
	var hour = int(time * 24)
	var minute = int((time * 24 - hour) * 60)
	return "%02d:%02d" % [hour, minute]

func is_day() -> bool:
	return time >= 0.25 and time < 0.75
