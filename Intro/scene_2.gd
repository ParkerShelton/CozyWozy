extends Node3D

@export var world_seed: int = 98546
@export var clear_radius: float = 25.0  # Radius of cleared area

var foliage_types = {
	"rocks": {"min": 0, "max": 2, "scene": "res://Scenes/rock.tscn"},
	"trees": {"min": 3, "max": 5, "scene": "res://Scenes/tree.tscn"},
	"apple_trees": {"min": 0, "max": 1, "scene": "res://Scenes/apple_tree.tscn"},
	"grass": {"min": 5, "max": 15, "scene": "res://Scenes/tall_grass.tscn"},
	"trees_2": {"min": 3, "max": 5, "scene": "res://Scenes/tree_2.tscn"},
	"flowers": {"min": 3, "max": 5, "scene": "res://Scenes/flowers.tscn"}
}

var ground_scene = preload("res://Scenes/ground.tscn")
var player_scene = preload("res://Intro/house_scene.tscn")
var robot_scene = preload("res://Scenes/Enemies/flying_robot.tscn")


@onready var camera_follow = $camera_follow
var rng: RandomNumberGenerator
var center_position: Vector3 = Vector3.ZERO

var grid_center

func find_center_from_camera():
	var camera = get_viewport().get_camera_3d()
	if not camera:
		print("❌ No camera found!")
		center_position = Vector3(25, 0, 25)  # Default to grid center
		return
	
	# Raycast from camera center
	var viewport_size = get_viewport().get_visible_rect().size
	var screen_center = viewport_size / 2.0
	
	var from = camera.project_ray_origin(screen_center)
	var to = from + camera.project_ray_normal(screen_center) * 1000.0
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1  # Ground layer
	
	var result = space_state.intersect_ray(query)
	
	if result:
		center_position = result.position
		print("✅ Camera pointing at: ", center_position)
	else:
		print("❌ No ground hit!")
		center_position = Vector3(25, 0, 25)
		
		
# Called when the node enters the scene tree for the first time.
func _ready():
	rng = RandomNumberGenerator.new()
	rng.seed = world_seed
	
	for i in range(5):
		for k in range(5):
			var ground = ground_scene.instantiate()
			add_child(ground)
			
			var tile_size = 25.0
			ground.global_position = Vector3(i * tile_size, 0, k * tile_size)
	
	# Calculate center of the grid
	grid_center = Vector3(2.5 * 25.0, 0, 2.5 * 25.0)
	
	# Position camera above and back from center to see all ground
	camera_follow.global_position = grid_center + Vector3(-55, 35, 0)
	
	# Wait another frame for camera to be ready
	await get_tree().process_frame
	
	# NOW find where camera is pointing
	find_center_from_camera()
	
	# Spawn all foliage (trees will be cleared around center)
	for i in range(5):
		for k in range(5):
			var tile_size = 25.0
			var tile_position = Vector3(i * tile_size, 0, k * tile_size)
			spawn_foliage_on_tile(tile_position, tile_size)
	
	var player = player_scene.instantiate()
	add_child(player)
	player.add_to_group("player")
	player.global_position = grid_center
	
	await get_tree().create_timer(1).timeout
	TransitionManager.fade_from_black(2)
	await get_tree().create_timer(5).timeout
	await TransitionManager.fade_to_black(2).finished
	WorldManager.is_new_world = true
	get_tree().change_scene_to_file("res://Scenes/main.tscn")
	
func _physics_process(delta):
	$camera_follow/SpringArm3D/Camera3D.size -= 1 * delta
	
	
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
