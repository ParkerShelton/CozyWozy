extends Node3D

@onready var anim_player = $shipping_container/AnimationPlayer

# Enemy scenes
var robot_basic_scene = preload("res://Scenes/Enemies/robot_basic.tscn")
var robot_midget_scene = preload("res://Scenes/Enemies/robot_midget.tscn")

# Single spawn points
@onready var basic_spawn_point = $basic_spawn # Single Node3D for basics
@onready var midget_spawn_point = $midget_spawn  # Single Node3D for midgets

# Tracking
var spawned_basics: Array = []
var spawned_midgets: Array = []
var container_opened: bool = false
var player_inside: bool = false

# Wave system
var current_wave: int = 0
var max_waves: int = 2
var checking_wave_completion: bool = false

func _process(delta):
	if container_opened and player_inside and not checking_wave_completion:
		check_wave_completion()

func _on_area_3d_body_entered(body):
	if body.is_in_group("player"):
		# Open container
		if not container_opened:
			anim_player.play("Cube_001Action")
			container_opened = true
			start_wave_1()
		
		player_inside = true

func _on_area_3d_body_exited(body):
	if body.is_in_group("player"):
		player_inside = false

# Wave 1: 2 basics + 3 midgets
func start_wave_1():
	current_wave = 1
	print("=== WAVE 1: 2 Basics + 3 Midgets ===")
	
	# Spawn 2 basic robots
	for i in range(2):
		spawn_basic_robot()
	
	# Spawn 3 midgets
	for i in range(3):
		spawn_midget_robot()

# Wave 2: 5 midgets
func start_wave_2():
	current_wave = 2
	print("=== WAVE 2: 5 Midgets ===")
	
	# Spawn 5 midgets
	for i in range(5):
		spawn_midget_robot()

# Check if wave is complete
func check_wave_completion():
	checking_wave_completion = true
	
	# Clean up dead references
	spawned_basics = spawned_basics.filter(func(robot): return is_instance_valid(robot))
	spawned_midgets = spawned_midgets.filter(func(robot): return is_instance_valid(robot))
	
	# Check if all enemies are dead
	if spawned_basics.size() == 0 and spawned_midgets.size() == 0:
		if current_wave == 1:
			await get_tree().create_timer(2.0).timeout  # 2 second delay
			start_wave_2()
		elif current_wave == 2:
			current_wave = 3  # Set to 3 to prevent further checks
	
	checking_wave_completion = false

# Spawn a basic robot near the basic spawn point
func spawn_basic_robot():
	if not basic_spawn_point:
		push_error("✗ No basic_spawn_point found!")
		return
	
	var robot = robot_basic_scene.instantiate()
	get_tree().root.add_child(robot)
	
	# Spawn with small random offset so they don't overlap
	var offset = Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
	robot.global_position = basic_spawn_point.global_position + offset
	
	# Track the robot
	spawned_basics.append(robot)
	robot.tree_exited.connect(_on_basic_died.bind(robot))

# Spawn a midget robot near the midget spawn point
func spawn_midget_robot():
	if not midget_spawn_point:
		push_error("✗ No midget_spawn_point found!")
		return
	
	var robot = robot_midget_scene.instantiate()
	get_tree().root.add_child(robot)
	
	# Spawn with small random offset so they don't overlap
	var offset = Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
	robot.global_position = midget_spawn_point.global_position + offset
	
	# Track the robot
	spawned_midgets.append(robot)
	robot.tree_exited.connect(_on_midget_died.bind(robot))

# Called when a basic robot dies
func _on_basic_died(robot):
	spawned_basics.erase(robot)

# Called when a midget robot dies
func _on_midget_died(robot):
	spawned_midgets.erase(robot)
