extends Node3D

var ground_scene = preload("res://Scenes/ground.tscn")
var enemy_scene = preload("res://Scenes/Enemies/flying_robot.tscn")

@export var is_intro_scene: bool = true
@export var slow_motion_scale: float = 0.4

# Foliage types with spawn settings
var foliage_types = {
	"rocks": {"min": 0, "max": 2, "scene": "res://Scenes/rock.tscn"},
	"trees": {"min": 3, "max": 5, "scene": "res://Scenes/tree.tscn"},
	"apple_trees": {"min": 0, "max": 1, "scene": "res://Scenes/apple_tree.tscn"},
	"grass": {"min": 5, "max": 15, "scene": "res://Scenes/tall_grass.tscn"},
	"trees_2": {"min": 3, "max": 5, "scene": "res://Scenes/tree_2.tscn"},
	"flowers": {"min": 3, "max": 5, "scene": "res://Scenes/flowers.tscn"}
}

@export var world_seed: int = 12345
@export var clear_radius: float = 9.0  # Radius of cleared area

@export var camera_start_position: Vector3 = Vector3(-27, 35, 91)
@export var camera_end_position: Vector3 = Vector3(-27, 35, 300)
@export var camera_move_duration: float = 15.0
@export var spin_attack_delay: float = 8.0  # Delay before robot spins (camera approaches)

var rng: RandomNumberGenerator
var center_position: Vector3 = Vector3.ZERO
@onready var spawned_robot = $flying_robot

@onready var camera = $camera_follow

func _ready():
	TransitionManager.fade_from_black(4)
	if is_intro_scene:
		Engine.time_scale = slow_motion_scale
		
	# Initialize RNG with seed
	rng = RandomNumberGenerator.new()
	rng.seed = world_seed
	# Set center position to where camera will end
	center_position = Vector3(camera_end_position.x, 0, camera_end_position.z)
	print("🎯 Center position set to camera end: ", center_position)
	
	# Spawn ground tiles
	for i in range(3):
		for k in range(15):
			var ground = ground_scene.instantiate()
			add_child(ground)
			
			var tile_size = 25.0
			ground.global_position = Vector3(i * tile_size, 0, k * tile_size)
	
	# Spawn all foliage (trees will be cleared around center)
	for i in range(3):
		for k in range(15):
			var tile_size = 25.0
			var tile_position = Vector3(i * tile_size, 0, k * tile_size)
			spawn_foliage_on_tile(tile_position, tile_size)
	
	
	# Wait for physics to update
	await get_tree().physics_frame
	
	# Start camera movement
	move_camera()
	await get_tree().create_timer(spin_attack_delay).timeout
	spawned_robot.is_intro_mode = true
	trigger_robot_spin_attack()

func move_camera():
	# Tween camera position
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	
	# Move camera
	tween.tween_property(camera, "global_position", camera_end_position, camera_move_duration)
	tween.parallel().tween_callback(call_fade_to).set_delay(5)
	tween.parallel().tween_callback(call_fade_from).set_delay(7)

	tween.parallel().tween_callback(call_fade_to_2).set_delay(9)
	



func call_fade_to():
	TransitionManager.fade_to_black(1)

func call_fade_from():
	TransitionManager.fade_from_black(1)
	$CenterContainer/Label.visible = false
	$CenterContainer/Label2.visible = true
	

func call_fade_to_2():
	await TransitionManager.fade_to_black(1.5).finished
	get_tree().change_scene_to_file("res://Intro/scene_2.tscn")

func spawn_foliage_on_tile(tile_position: Vector3, tile_size: float):
	# Spawn each foliage type
	for foliage_name in foliage_types.keys():
		var foliage_config = foliage_types[foliage_name]
		
		var min_count = foliage_config.get("min", 0)
		var max_count = foliage_config.get("max", 5)
		var scene_path = foliage_config.get("scene", "")
		
		# Check if scene exists
		if scene_path == "" or not ResourceLoader.exists(scene_path):
			continue
		
		# Random count for this foliage type
		var count = rng.randi_range(min_count, max_count)
		
		# Load scene
		var foliage_scene = load(scene_path)
		
		# Spawn instances
		for i in range(count):
			# Random position within the tile (with some padding from edges)
			var padding = tile_size * 0.1
			var random_x = rng.randf_range(padding, tile_size - padding)
			var random_z = rng.randf_range(padding, tile_size - padding)
			
			var spawn_pos = tile_position + Vector3(random_x, 0, random_z)
			
			# CHECK: Skip if inside clear radius around center
			var distance_to_center = spawn_pos.distance_to(center_position)
			if distance_to_center < clear_radius:
				continue  # Don't spawn here - too close to center
			
			var foliage = foliage_scene.instantiate()
			add_child(foliage)
			
			foliage.global_position = spawn_pos
			
			# Random rotation
			foliage.rotation_degrees.y = rng.randf_range(0, 360)
			
			# Optional: Slight random scale for variety (skip for rocks)
			if foliage_name != "rocks":
				var scale_variation = rng.randf_range(0.8, 1.2)
				foliage.scale = Vector3(scale_variation, scale_variation, scale_variation)
			
			# Add to appropriate group for easy reference
			foliage.add_to_group(foliage_name)
			
			# Add all tree types to generic "trees" group
			if foliage_name in ["trees", "trees_2", "apple_trees"]:
				foliage.add_to_group("trees")
			
			# Disable drops in intro
			if is_intro_scene and foliage_name in ["trees", "trees_2", "apple_trees"]:
				if "disable_drops" in foliage:
					foliage.disable_drops = true

func spawn_enemy_in_center():
	var enemy = enemy_scene.instantiate()
	add_child(enemy)
	
	# Spawn on the ground at center
	enemy.global_position = center_position + Vector3(0, 0.5, 0)
	
	# Enable intro mode (no warning flashes)
	if "is_intro_mode" in enemy:
		enemy.is_intro_mode = true
	
	# Store reference
	spawned_robot = enemy
	
	print("🤖 Enemy spawned at center: ", enemy.global_position)

func trigger_robot_spin_attack():
	if spawned_robot and is_instance_valid(spawned_robot):
		if spawned_robot.has_method("_start_ground_spin_attack"):
			spawned_robot._start_ground_spin_attack()
			print("⚡ Robot spin attack triggered!")
		else:
			print("⚠️ Robot doesn't have _start_ground_spin_attack method")
	else:
		print("❌ Robot not found or invalid")

func _exit_tree():
	# Reset time scale when leaving the scene
	Engine.time_scale = 1.0
