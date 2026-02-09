# explorable_buildings_manager.gd
extends Node

# Building definitions with weights and spawn constraints
var building_types: Dictionary = {
	"shipping_container": {
		"scene": "res://Scenes/Explorable_Buildings/shipping_container.tscn",
		"weight": 30,  
		"min_distance_from_spawn": 30.0,
		"min_distance_between_same": 100.0,
		"min_distance_between_any": 20.0,
	},
	"scavenger_container": {
		"scene": "res://Scenes/Explorable_Buildings/scavenger_crate.tscn",
		"weight": 100, # Very common
		"min_distance_from_spawn": 5.0,
		"min_distance_between_same": 5.0,
		"min_distance_between_any": 5.0,
	},
	"broken_car_1": {
		"scene": "res://Scenes/Explorable_Buildings/broken_car_1.tscn",
		"weight": 100, # Very common
		"min_distance_from_spawn": 5.0,
		"min_distance_between_same": 5.0,
		"min_distance_between_any": 5.0,
	},
	"scavenger_container_double": {
		"scene": "res://Scenes/Explorable_Buildings/scavenger_crate_double.tscn",
		"weight": 100,
		"min_distance_from_spawn": 15.0,
		"min_distance_between_same": 50.0,
		"min_distance_between_any": 20.0,
	},
	"abandoned_factory_1": {
		"scene": "res://Scenes/Explorable_Buildings/abandoned_factory_1.tscn",
		"weight": 10,  # Uncommon 
		"min_distance_from_spawn": 50.0,
		"min_distance_between_same": 200.0,  # Don't spawn same building too close
		"min_distance_between_any": 30.0,  # Minimum distance from any other building
	},
}

# Spawn settings
var spawn_chance: float = 0.3  # 30% chance per chunk to attempt spawn
var max_attempts_per_chunk: int = 3  # Try up to 3 times to find valid position

# Tracking
var spawned_buildings: Array = []  # {type: String, position: Vector3, instance: Node3D}

func _ready():
	print("ExplorableBuildingsManager initialized with ", building_types.size(), " building types")

# Main spawn function - call this when generating chunks
func try_spawn_building_in_chunk(_chunk_coord: Vector2i, chunk_world_pos: Vector3, chunk_size: Vector2) -> bool:
	# Random chance to spawn
	if randf() > spawn_chance:
		return false
	
	# Choose a building type based on weights
	var building_type = choose_weighted_building()
	if building_type == "":
		return false
	
	# Try to find a valid spawn position
	for attempt in range(max_attempts_per_chunk):
		var spawn_pos = get_random_position_in_chunk(chunk_world_pos, chunk_size)
		
		# Check if position is valid
		if is_valid_spawn_position(building_type, spawn_pos):
			spawn_building(building_type, spawn_pos)
			return true
	
	return false

# Choose a building type using weighted random selection
func choose_weighted_building() -> String:
	var total_weight = 0.0
	
	# Calculate total weight
	for building_type in building_types.keys():
		total_weight += building_types[building_type]["weight"]
	
	# Random value between 0 and total weight
	var random_value = randf() * total_weight
	
	# Select based on weight
	var current_weight = 0.0
	for building_type in building_types.keys():
		current_weight += building_types[building_type]["weight"]
		if random_value <= current_weight:
			return building_type
	
	return ""

# Get a random position within a chunk
func get_random_position_in_chunk(chunk_world_pos: Vector3, chunk_size: Vector2) -> Vector3:
	var random_x = randf_range(0, chunk_size.x * 300)  # Adjust multiplier based on your chunk size
	var random_z = randf_range(0, chunk_size.y * 300)
	
	return chunk_world_pos + Vector3(random_x, 0, random_z)

# Check if a position is valid for spawning a building
func is_valid_spawn_position(building_type: String, position: Vector3) -> bool:
	var building_config = building_types[building_type]
	
	# Check distance from spawn point (0,0,0)
	var distance_from_spawn = position.distance_to(Vector3.ZERO)
	if distance_from_spawn < building_config["min_distance_from_spawn"]:
		return false
	
	# Check distance from other buildings
	for spawned in spawned_buildings:
		var distance = position.distance_to(spawned["position"])
		
		# Check if too close to same building type
		if spawned["type"] == building_type:
			if distance < building_config["min_distance_between_same"]:
				return false
		
		# Check if too close to any building
		if distance < building_config["min_distance_between_any"]:
			return false
	
	# Raycast down to check if there's ground
	var space_state = get_tree().root.get_world_3d().direct_space_state
	var from = Vector3(position.x, 50, position.z)
	var to = Vector3(position.x, -10, position.z)
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1  # Ground layer
	
	var result = space_state.intersect_ray(query)
	if not result:
		return false  # No ground found
	
	return true

# Spawn a building at a position
func spawn_building(building_type: String, position: Vector3):
	var building_config = building_types[building_type]
	var scene_path = building_config["scene"]
	
	# Check if scene exists
	if not ResourceLoader.exists(scene_path):
		push_error("Building scene not found: " + scene_path)
		return
	
	# Load and instantiate
	var building_scene = load(scene_path)
	var building = building_scene.instantiate()
	
	# Add to world
	get_tree().root.add_child(building)
	
	# Raycast to find exact ground position
	var space_state = get_tree().root.get_world_3d().direct_space_state
	var from = Vector3(position.x, 50, position.z)
	var to = Vector3(position.x, -10, position.z)
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	
	var result = space_state.intersect_ray(query)
	if result:
		building.global_position = result.position
	else:
		building.global_position = position
	
	# Random rotation for variety
	building.rotation.y = randf() * TAU
	
	# Track the spawned building
	spawned_buildings.append({
		"type": building_type,
		"position": building.global_position,
		"instance": building
	})
	
	print("✓ Spawned ", building_type, " at ", building.global_position)

# Get all spawned buildings of a specific type
func get_buildings_by_type(building_type: String) -> Array:
	var buildings = []
	for spawned in spawned_buildings:
		if spawned["type"] == building_type:
			buildings.append(spawned["instance"])
	return buildings

# Get closest building to a position
func get_closest_building(position: Vector3) -> Node3D:
	if spawned_buildings.is_empty():
		return null
	
	var closest = null
	var closest_distance = INF
	
	for spawned in spawned_buildings:
		var distance = position.distance_to(spawned["position"])
		if distance < closest_distance:
			closest_distance = distance
			closest = spawned["instance"]
	
	return closest

# Clear all spawned buildings (for world reset)
func clear_all_buildings():
	for spawned in spawned_buildings:
		if is_instance_valid(spawned["instance"]):
			spawned["instance"].queue_free()
	
	spawned_buildings.clear()
	print("All buildings cleared")

# Remove buildings far from player (for performance)
func cleanup_distant_buildings(player_position: Vector3, max_distance: float = 500.0):
	var buildings_to_remove = []
	
	for i in range(spawned_buildings.size() - 1, -1, -1):
		var spawned = spawned_buildings[i]
		var distance = player_position.distance_to(spawned["position"])
		
		if distance > max_distance:
			if is_instance_valid(spawned["instance"]):
				spawned["instance"].queue_free()
			spawned_buildings.remove_at(i)
			buildings_to_remove.append(spawned["type"])
	
	if buildings_to_remove.size() > 0:
		print("Cleaned up ", buildings_to_remove.size(), " distant buildings")
