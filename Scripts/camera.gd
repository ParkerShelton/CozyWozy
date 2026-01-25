extends Camera3D

var target_group : String = "player"  # The group name to search for
var follow_speed : float = 6.0

var target : Node3D = null
var offset : Vector3
var offset_calculated : bool = false

func _ready():
	# Find the target when the scene starts
	find_target()

func find_target():
	# Get all nodes in the specified group
	var nodes = get_tree().get_nodes_in_group(target_group)
	if nodes.size() > 0:
		target = nodes[0]  # Use the first node found

func _physics_process(delta):
	# If we don't have a target yet, try to find one
	if target == null:
		find_target()
		return
	
	# Calculate offset once after target is found and positioned
	if not offset_calculated:
		await get_tree().process_frame  # Wait one frame for player to be positioned
		offset = global_position - target.global_position
		# Ensure camera is far enough back to avoid clipping
		if offset.length() < 25:  # Minimum distance of 25 units
			offset = offset.normalized() * 25
		offset_calculated = true
	
	if target and offset_calculated:
		# Calculate the target position using the stored offset
		var target_position = target.global_position + offset
		
		# Smoothly move camera towards target position
		global_position = global_position.lerp(target_position, follow_speed * delta)
