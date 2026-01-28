extends Node3D

var tree_scene = preload("res://Scenes/tree.tscn")
var tall_grass_scene = preload("res://Scenes/tall_grass.tscn")
var plant_fiber_grass_scene = preload("res://Scenes/plant_fiber_grass.tscn")
var rock_scene = preload("res://Scenes/rock.tscn")

var edge_padding : float = 0.5

# MIN / MAX
var min_trees : int = 5
var max_trees : int = 8

var min_rocks : int = 1
var max_rocks : int = 3

var min_tall_grass : int = 5
var max_tall_grass : int = 8

var min_plant_fiber_grass : int = 0
var max_plant_fiber_grass : int = 2

var tile_x: int = 0
var tile_z: int = 0

func _ready():
	#spawn_trees()
	#spawn_plant_fiber_grass()
	#generate_foliage()
	#call_deferred("generate_foliage")
	
	await get_tree().create_timer(0.25).timeout
	get_parent().world_generated = true


func spawn_trees():
	# Get the ground mesh dimensions
	var mesh_node = get_node("ground")  # Adjust path if needed
	var aabb = mesh_node.mesh.get_aabb()
	
	# Use AABB position and size for accurate bounds
	var min_x = aabb.position.x + edge_padding
	var max_x = aabb.position.x + aabb.size.x - edge_padding
	var min_z = aabb.position.z + edge_padding
	var max_z = aabb.position.z + aabb.size.z - edge_padding
	
	# Random number of trees
	var num_trees = randi_range(min_trees, max_trees)
	
	for i in range(num_trees):
		var tree = tree_scene.instantiate()
		
		# Random position across the full tile using actual bounds
		var random_x = randf_range(min_x, max_x)
		var random_z = randf_range(min_z, max_z)
		
		tree.position = Vector3(random_x * 20, 0, random_z * 25)
		tree.rotation.y = randf_range(0, TAU)  # Random rotation (TAU = 2*PI = 360 degrees)
		tree.add_to_group("tree")
		add_child(tree)


func spawn_plant_fiber_grass():
	# Get the ground mesh dimensions
	var mesh_node = get_node("ground")  # Adjust path if needed
	var aabb = mesh_node.mesh.get_aabb()
	
	# Use AABB position and size for accurate bounds
	var min_x = aabb.position.x + edge_padding
	var max_x = aabb.position.x + aabb.size.x - edge_padding
	var min_z = aabb.position.z + edge_padding
	var max_z = aabb.position.z + aabb.size.z - edge_padding
	
	# Random number of tall grass
	var num_grass = randi_range(min_plant_fiber_grass, max_plant_fiber_grass)
	
	for i in range(num_grass):
		var plant_fiber_grass = plant_fiber_grass_scene.instantiate()
		
		# Random position across the full tile using actual bounds
		var random_x = randf_range(min_x, max_x)
		var random_z = randf_range(min_z, max_z)
		
		plant_fiber_grass.position = Vector3(random_x * 20, 0, random_z * 25)
		
		add_child(plant_fiber_grass)


func generate_foliage():
	var mesh_node = get_node("ground")
	var aabb = mesh_node.mesh.get_aabb()
	
	# Use AABB position and size for accurate bounds
	var min_x = aabb.position.x + edge_padding
	var max_x = aabb.position.x + aabb.size.x - edge_padding
	var min_z = aabb.position.z + edge_padding
	var max_z = aabb.position.z + aabb.size.z - edge_padding
	
	var base_seed = WorldManager.get_world_seed()
	var rng = RandomNumberGenerator.new()
	rng.seed = base_seed + tile_x * 1000 + tile_z
	
	var num_rocks = rng.randi_range(min_rocks, max_rocks)
	var num_grass = rng.randi_range(min_tall_grass, max_tall_grass)
	var num_trees = rng.randi_range(min_trees, max_trees)
	
	for i in range(num_rocks):
		var rock = rock_scene.instantiate()
		var random_x = rng.randf_range(min_x, max_x)
		var random_z = rng.randf_range(min_z, max_z)

		rock.add_to_group("rock")
		get_node("/root/main/foliage").add_child(rock)
		rock.global_position = global_position + Vector3(random_x * 20, 0, random_z * 25)
		
	for i in range(num_grass):
		var tall_grass = tall_grass_scene.instantiate()
		var random_x = rng.randf_range(min_x, max_x)
		var random_z = rng.randf_range(min_z, max_z)

		tall_grass.add_to_group("tall_grass")
		get_node("/root/main/foliage").add_child(tall_grass)
		tall_grass.global_position = global_position + Vector3(random_x * 20, 0, random_z * 25)
		
	for i in range(num_trees):
		var tree = tree_scene.instantiate()
		var random_x = rng.randf_range(min_x, max_x)
		var random_z = rng.randf_range(min_z, max_z)
		
		tree.add_to_group("tree")
		get_node("/root/main/foliage").add_child(tree)
		tree.global_position = global_position + Vector3(random_x * 20, 0, random_z * 25)
		tree.rotation.y = rng.randf_range(0, TAU)  # Random rotation (TAU = 2*PI = 360 degrees)
