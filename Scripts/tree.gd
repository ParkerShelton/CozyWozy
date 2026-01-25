extends Node3D

var tree_health : int = 3
var current_health : int
var is_chopped : bool = false

var fall_duration : float = 0.75  # How long the fall animation takes

var min_logs : int = 2
var max_logs : int = 5

@onready var trunk = $trunk
@onready var leaves = $leaves
@onready var stump = $stump

func _ready():
	current_health = tree_health

func take_damage():
	if is_chopped:
		return
		
	current_health -= 1
	if current_health <= 0:
		chop_down()
	else:
		shake_tree()

func chop_down():
	is_chopped = true
	
	# Create a new Node3D to hold trunk and leaves for falling
	var falling_part = Node3D.new()
	get_parent().add_child(falling_part)
	falling_part.global_position = global_position
	
	# Move trunk and leaves to the falling part
	var trunk_ref = trunk  # Store reference to trunk
	trunk.reparent(falling_part)
	leaves.reparent(falling_part)
	
	# Find player and calculate fall direction away from them
	var player = get_tree().get_first_node_in_group("player")
	var fall_angle = 0.0
	
	if player:
		var to_player = player.global_position - global_position
		to_player.y = 0
		to_player = to_player.normalized()
		fall_angle = atan2(to_player.x, to_player.z) + PI
	
	# Animate the fall
	var tween = create_tween()
	falling_part.rotation.y = fall_angle
	tween.tween_property(falling_part, "rotation:x", PI / 2, fall_duration)
	tween.parallel().tween_property(falling_part, "position:y", 0.5, fall_duration)
	
	# Wait on the ground before disappearing
	tween.tween_interval(2.0)
	
	# Spawn logs at the trunk's actual position after falling
	tween.tween_callback(func(): spawn_logs(trunk_ref.global_position))
	
	# Delete the fallen part after spawning logs
	tween.tween_callback(falling_part.queue_free)
	
	# Remove this tree from the group so it can't be hit again
	remove_from_group("tree")
	
	$leaves2.queue_free()
	$falling_leaves.queue_free()

func spawn_logs(spawn_position: Vector3):
	var num_logs = randi_range(min_logs, max_logs)
	
	# Get the fall direction to spread logs along the trunk
	var player = get_tree().get_first_node_in_group("player")
	var fall_angle = 0.0
	if player:
		var to_player = player.global_position - global_position
		to_player.y = 0
		to_player = to_player.normalized()
		fall_angle = atan2(to_player.x, to_player.z) + PI
	
	var fall_direction = Vector3(sin(fall_angle), 0, cos(fall_angle))
	
	# Load the generic dropped item scene
	var dropped_item_scene = load("res://Scenes/dropped_item.tscn")  # Adjust path
	var log_icon = load("res://Assets/Icons/log.png")  # Adjust to your log icon path
	
	for i in range(num_logs):
		if dropped_item_scene:
			var log = dropped_item_scene.instantiate()
			get_parent().add_child(log)
			
			# Spread logs along the trunk length
			var trunk_length = 3.0
			var distance_along_trunk = randf_range(0, trunk_length)
			
			# Small perpendicular offset for variety
			var side_offset = Vector3(
				randf_range(-0.3, 0.3),
				0,
				randf_range(-0.3, 0.3)
			)
			
			log.global_position = spawn_position + (fall_direction * distance_along_trunk) + side_offset
			log.global_position.y = 0.3
			
			# Setup the log
			if log.has_method("setup"):
				log.setup("log", 1, log_icon)
			
			# Random rotation for variety
			log.rotation.y = randf_range(0, TAU)

func shake_tree():
	var tween = create_tween()
	tween.tween_property(self, "rotation:z", 0.1, 0.1)
	tween.tween_property(self, "rotation:z", -0.1, 0.1)
	tween.tween_property(self, "rotation:z", 0, 0.1)
