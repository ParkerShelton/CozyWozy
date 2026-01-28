extends Camera3D
var target_group : String = "player"
var follow_speed : float = 6.0
var target : Node3D = null
var offset : Vector3 = Vector3(-25, 15, 0)  # Back to original
var first_frame : bool = true

func _ready():
	find_target()

func find_target():
	var nodes = get_tree().get_nodes_in_group(target_group)
	if nodes.size() > 0:
		target = nodes[0]
		first_frame = true

func _physics_process(delta):
	if target == null:
		find_target()
		return
	
	if first_frame:
		global_position = target.global_position + offset
		rotation_degrees = Vector3(-30, -90, 0)  # Try rotating 180 degrees
		print("Offset: ", offset)
		print("Rotation: ", rotation_degrees)
		first_frame = false
		return
	
	var target_position = target.global_position + offset
	global_position = global_position.lerp(target_position, follow_speed * delta)
