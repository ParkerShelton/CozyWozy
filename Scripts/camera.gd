extends Camera3D
var target_group : String = "player"
var follow_speed : float = 6.0
var target : Node3D = null
var offset : Vector3 = Vector3(-25, 15, 0)
var first_frame : bool = true

var target_rotation : Vector3 = Vector3(-30, -90, 0)  # Default outdoor rotation
var target_offset : Vector3 = Vector3(-25, 15, 0)      # Default outdoor offset
var rotation_speed : float = 3.0


# Add zoom control
var camera_size : float = 20.0  # Starting zoom level (higher = more zoomed out)

var do_zoom = false

func _ready():
	find_target()
	
	# Set to orthogonal projection
	projection = PROJECTION_ORTHOGONAL
	size = camera_size  # Set initial zoom

func _process(_delta):
	if do_zoom:
		if camera_size > 10.0:
			camera_size -= 0.1
		else:
			camera_size = 10.0
			do_zoom = false

func find_target():
	var nodes = get_tree().get_nodes_in_group(target_group)
	if nodes.size() > 0:
		target = nodes[0]
		first_frame = true

func zoom_workbench():
	do_zoom = true

func _physics_process(delta):
	if target == null:
		find_target()
		return
	
	if first_frame:
		global_position = target.global_position + offset
		rotation_degrees = Vector3(-30, -90, 0)
		first_frame = false
		return
	
	offset = offset.lerp(target_offset, rotation_speed * delta)
	rotation_degrees = rotation_degrees.lerp(target_rotation, rotation_speed * delta)
	
	var target_position = target.global_position + offset
	global_position = global_position.lerp(target_position, follow_speed * delta)
	
	# Optional: Add zoom controls with mouse wheel
	handle_zoom(delta)

func handle_zoom(delta):
	# Mouse wheel zoom
	if Input.is_key_pressed(KEY_CTRL):
		if Input.is_action_just_released("zoom_in"):  # Mouse wheel up
			camera_size = max(10.0, camera_size - 2.0)  # Min zoom
		
		if Input.is_action_just_released("zoom_out"):  # Mouse wheel down
			camera_size = min(30.0, camera_size + 2.0)  # Max zoom
	
	# Smooth zoom
	size = lerp(size, camera_size, 10.0 * delta)
	
	
	
	
func enter_house():
	target_rotation = Vector3(-70, -90, 0)  # More top-down
	target_offset = Vector3(-8, 20, 0)       # Closer and higher

func exit_house():
	target_rotation = Vector3(-30, -90, 0)
	target_offset = Vector3(-25, 15, 0)
