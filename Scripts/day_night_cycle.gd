extends ColorRect

@export var day_duration: float = 300.0
@export var day_color: Color = Color(0.0, 0.0, 0.0, 0.0)  # Transparent during day
@export var night_color: Color = Color(0.2, 0.2, 0.3, 0.8)  # Dark blue tint at night

var time: float = 0.0
var time_of_day: float = 0.5
var registered_lights: Array = []

var rain_overlay: ColorRect = null

func _ready():
	rain_overlay = get_node("/root/main/rain_overlay/ColorRect")
	
	# Make this cover the whole screen
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = MOUSE_FILTER_IGNORE  # Don't block mouse clicks
	
	# Load shader
	var light_shader = load("res://Shaders/day_night_with_lights.gdshader")
	var shader_material = ShaderMaterial.new()
	shader_material.shader = light_shader
	material = shader_material
	
	# Set parameters
	material.set_shader_parameter("day_color", day_color)
	material.set_shader_parameter("night_color", night_color)
	
	await get_tree().create_timer(3.0).timeout
	var rain = get_node("/root/main/rain_overlay/ColorRect")
	if rain:
		# Light rain with small splashes
		rain.rain_intensity = 0.35
		rain.rain_density = 25.0
		rain.wind_direction = Vector2(0.1, 1.0)
		rain.rain_alpha = 0.45
		
		rain.start_rain(0.35, 2.0)
		print("🌧️ Perfect rain!")

func _process(delta):
	time += delta
	
	if time >= day_duration:
		time = 0.0
	
	time_of_day = time / day_duration
	
	# Calculate brightness
	var brightness = 0.0
	if time_of_day < 0.25:
		brightness = 0.0
	elif time_of_day < 0.5:
		brightness = (time_of_day - 0.25) / 0.25
	elif time_of_day < 0.75:
		brightness = 1.0 - ((time_of_day - 0.5) / 0.25)
	else:
		brightness = 0.0
	
	material.set_shader_parameter("time_of_day", brightness)
	update_lights()

func update_lights():
	if registered_lights.size() == 0:
		material.set_shader_parameter("light_enabled", false)
		return
	
	# Find camera in SubViewport
	var camera = null
	var main = get_node_or_null("/root/main")
	if main:
		var subviewport = main.get_node_or_null("SubViewportContainer/SubViewport")
		if subviewport:
			camera = subviewport.get_camera_3d()
		
		if not camera:
			camera = main.find_child("Camera3D", true, false)
	
	if not camera:
		return
	
	# Use first light
	var light_data = registered_lights[0]
	var light_node = light_data.node
	
	if not is_instance_valid(light_node):
		material.set_shader_parameter("light_enabled", false)
		return
	
	# Get SubViewport size (convert Vector2i to Vector2)
	var viewport_size = Vector2.ZERO
	var subviewport = main.get_node_or_null("SubViewportContainer/SubViewport")
	if subviewport:
		viewport_size = Vector2(subviewport.size)  # Convert Vector2i to Vector2
	else:
		viewport_size = get_viewport_rect().size
	
	var screen_pos = camera.unproject_position(light_node.global_position)
	var uv = screen_pos / viewport_size
	
	material.set_shader_parameter("light_enabled", true)
	material.set_shader_parameter("light_position", uv)
	material.set_shader_parameter("light_radius", light_data.radius)
	material.set_shader_parameter("light_color", light_data.color)
	material.set_shader_parameter("light_intensity", light_data.intensity)

# Also add debug to register_light
func register_light(node: Node3D, radius: float = 0.2, light_color: Color = Color(1.0, 0.7, 0.4), intensity: float = 0.7):
	registered_lights.append({
		"node": node,
		"radius": radius,
		"color": light_color,
		"intensity": intensity
	})

func unregister_light(node: Node3D):
	for i in range(registered_lights.size() - 1, -1, -1):
		if registered_lights[i].node == node:
			registered_lights.remove_at(i)

func get_time() -> float:
	return time

func set_time(new_time: float):
	time = new_time
	time_of_day = time / day_duration


func start_light_rain():
	if rain_overlay:
		rain_overlay.start_rain(0.4, 2.0)  # 40% intensity, 2 second fade-in

func start_heavy_rain():
	if rain_overlay:
		rain_overlay.start_rain(0.9, 2.0)  # 90% intensity

func stop_rain():
	if rain_overlay:
		rain_overlay.stop_rain(3.0) 
