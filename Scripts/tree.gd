extends Node3D

var tree_health : int = 25
var current_health : int
var is_chopped : bool = false
var is_being_destroyed: bool = false

var fall_duration : float = 0.75

var min_logs : int = 2
var max_logs : int = 5
var min_plant_fiber : int = 0
var max_plant_fiber : int = 2

@onready var trunk = $trunk
@onready var leaves = $leaves
@onready var stump = $stump

func _ready():
	current_health = tree_health

func take_damage(dmg):
	if is_chopped:
		return
		
	current_health -= dmg
	if current_health <= 0:
		chop_down()
	else:
		shake_tree()

func chop_down():
	if is_being_destroyed:
		return
	
	is_being_destroyed = true
	is_chopped = true
	
	# BROADCAST TO NETWORK (only if we're host)
	var resource_id = get_meta("resource_id", -1)
	if resource_id != -1 and Network.is_host:
		Network.broadcast_resource_destroyed(resource_id, "trees")
	
	# Create falling animation
	var falling_part = Node3D.new()
	get_parent().add_child(falling_part)
	falling_part.global_position = global_position
	
	var trunk_ref = trunk
	trunk.reparent(falling_part)
	leaves.reparent(falling_part)
	
	var player = get_tree().get_first_node_in_group("player")
	var fall_angle = 0.0
	
	if player:
		var to_player = player.global_position - global_position
		to_player.y = 0
		fall_angle = atan2(to_player.z, to_player.x)
	
	var tween = create_tween()
	falling_part.rotation.y = fall_angle
	tween.tween_property(falling_part, "rotation:x", PI / 2, fall_duration)
	tween.parallel().tween_property(falling_part, "position:y", 0.5, fall_duration)
	tween.tween_interval(1.5)
	
	tween.tween_callback(func(): spawn_logs(trunk_ref.global_position))
	tween.tween_callback(func(): spawn_plant_fiber(trunk_ref.global_position))
	tween.tween_callback(falling_part.queue_free)
	
	remove_from_group("tree")
	$leaves2.queue_free()
	$falling_leaves.queue_free()

func destroy_without_drops():
	"""Called when OTHER player destroys this tree"""
	if is_being_destroyed:
		return
	
	is_being_destroyed = true
	is_chopped = true
	
	var falling_part = Node3D.new()
	get_parent().add_child(falling_part)
	falling_part.global_position = global_position
	
	var trunk_ref = trunk
	trunk.reparent(falling_part)
	leaves.reparent(falling_part)
	
	var player = get_tree().get_first_node_in_group("player")
	var fall_angle = 0.0
	
	if player:
		var to_player = player.global_position - global_position
		to_player.y = 0
		fall_angle = atan2(to_player.z, to_player.x)
	
	var tween = create_tween()
	falling_part.rotation.y = fall_angle
	tween.tween_property(falling_part, "rotation:x", PI / 2, fall_duration)
	tween.parallel().tween_property(falling_part, "position:y", 0.5, fall_duration)
	tween.tween_interval(1.5)
	tween.tween_callback(falling_part.queue_free)
	
	remove_from_group("tree")
	$leaves2.queue_free()
	$falling_leaves.queue_free()

func spawn_logs(spawn_position: Vector3):
	var num_logs = randi_range(min_logs, max_logs)
	
	var player = get_tree().get_first_node_in_group("player")
	var fall_angle = 0.0
	if player:
		var to_player = player.global_position - global_position
		to_player.y = 0
		to_player = to_player.normalized()
		fall_angle = atan2(to_player.x, to_player.z) + PI
	
	var fall_direction = Vector3(sin(fall_angle), 0, cos(fall_angle))
	
	var dropped_item_scene = load("res://Scenes/dropped_item.tscn")
	var log_icon = load("res://Assets/Icons/log.png")
	
	for i in range(num_logs):
		if dropped_item_scene:
			var trunk_length = 3.0
			var distance_along_trunk = randf_range(0, trunk_length)
			var side_offset = Vector3(
				randf_range(-0.3, 0.3),
				0,
				randf_range(-0.3, 0.3)
			)
			
			var log_position = spawn_position + (fall_direction * distance_along_trunk) + side_offset
			log_position.y = 0.3
			
			var log_drop = dropped_item_scene.instantiate()
			get_parent().add_child(log_drop)
			log_drop.global_position = log_position
			log_drop.rotation.y = randf_range(0, TAU)
			
			if log_drop.has_method("setup"):
				log_drop.setup("log", 1, log_icon)
			
			if Network.is_host:
				Network.broadcast_item_spawned("log", log_position, 1)

func spawn_plant_fiber(spawn_position: Vector3):
	var num_plant_fiber = randi_range(min_plant_fiber, max_plant_fiber)

	var dropped_item_scene = load("res://Scenes/dropped_item.tscn")
	var plant_fiber_icon = load("res://Assets/Icons/plant_fiber.png")
	var wheat_seed_icon = load("res://Assets/Icons/Plant/wheat_seed.png")

	for i in range(num_plant_fiber):
		if dropped_item_scene:
			var side_offset = Vector3(
				randf_range(-0.3, 0.3),
				0,
				randf_range(-0.3, 0.3)
			)
			
			var item_position = spawn_position + side_offset
			item_position.y = 0.3
			
			var plant_fiber = dropped_item_scene.instantiate()
			get_parent().add_child(plant_fiber)
			plant_fiber.global_position = item_position
			plant_fiber.rotation.y = randf_range(0, TAU)
			
			if plant_fiber.has_method("setup"):
				plant_fiber.setup("plant_fiber", 1, plant_fiber_icon)
			
			var wheat_seed = dropped_item_scene.instantiate()
			get_parent().add_child(wheat_seed)
			wheat_seed.global_position = item_position
			wheat_seed.rotation.y = randf_range(0, TAU)
			
			if wheat_seed.has_method("setup"):
				wheat_seed.setup("wheat_seed", 1, wheat_seed_icon)
			
			if Network.is_host:
				Network.broadcast_item_spawned("plant_fiber", item_position, 1)
				Network.broadcast_item_spawned("wheat_seed", item_position, 1)

func shake_tree():
	var tween = create_tween()
	tween.tween_property(self, "rotation:z", 0.1, 0.1)
	tween.tween_property(self, "rotation:z", -0.1, 0.1)
	tween.tween_property(self, "rotation:z", 0, 0.1)
