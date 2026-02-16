# explorable_buildings_manager.gd
extends Node

# PRE-LOAD ALL BUILDING SCENES (loaded once, not every spawn!)
const BUILDING_SCENES = {
	"shipping_container": preload("res://Scenes/Explorable_Buildings/shipping_container.tscn"),
	"scavenger_container": preload("res://Scenes/Explorable_Buildings/scavenger_crate.tscn"),
	"broken_car_1": preload("res://Scenes/Explorable_Buildings/broken_car_1.tscn"),
	"scavenger_container_double": preload("res://Scenes/Explorable_Buildings/scavenger_crate_double.tscn"),
	"abandoned_factory_1": preload("res://Scenes/Explorable_Buildings/abandoned_factory_1.tscn"),
	"bunker": preload("res://Scenes/Explorable_Buildings/explorable_bunker.tscn"),
	"crane": preload("res://Scenes/Explorable_Buildings/crane.tscn"),
}

# Building definitions with weights and spawn constraints
var building_types: Dictionary = {
	"shipping_container": {
		"weight": 30,
		"min_distance_from_spawn": 30.0,
		"min_distance_between_same": 100.0,
		"min_distance_between_any": 50.0,  # was 20
	},
	"scavenger_container": {
		"weight": 100,
		"min_distance_from_spawn": 5.0,
		"min_distance_between_same": 30.0,  # was 5
		"min_distance_between_any": 20.0,  # was 5
	},
	"broken_car_1": {
		"weight": 100,
		"min_distance_from_spawn": 5.0,
		"min_distance_between_same": 30.0,  # was 5
		"min_distance_between_any": 20.0,  # was 5
	},
	"scavenger_container_double": {
		"weight": 100,
		"min_distance_from_spawn": 15.0,
		"min_distance_between_same": 80.0,  # was 50
		"min_distance_between_any": 40.0,  # was 20
	},
	"abandoned_factory_1": {
		"weight": 5,
		"min_distance_from_spawn": 50.0,
		"min_distance_between_same": 500.0,
		"min_distance_between_any": 60.0,  # was 30
	},
	"bunker": {
		"weight": 10,
		"min_distance_from_spawn": 50.0,
		"min_distance_between_same": 200.0,
		"min_distance_between_any": 60.0,  # was 30
	},
	"crane": {
		"weight": 10,
		"min_distance_from_spawn": 50.0,
		"min_distance_between_same": 200.0,
		"min_distance_between_any": 60.0,  # was 30
	},
}

var spawn_chance: float = 0.05
var max_attempts_per_chunk: int = 1
var spawned_buildings: Array = []

# Cache for raycast query (reuse instead of creating new ones)
var raycast_query: PhysicsRayQueryParameters3D = null

func _ready():
	# Pre-create raycast query
	raycast_query = PhysicsRayQueryParameters3D.new()
	raycast_query.collision_mask = 1

func try_spawn_building_in_chunk(_chunk_coord: Vector2i, chunk_world_pos: Vector3, chunk_size: Vector2) -> bool:
	if randf() > spawn_chance:
		return false
	
	var building_type = choose_weighted_building()
	if building_type == "":
		return false
	
	for attempt in range(max_attempts_per_chunk):
		var spawn_pos = get_random_position_in_chunk(chunk_world_pos, chunk_size)
		
		if is_valid_spawn_position(building_type, spawn_pos):
			spawn_building(building_type, spawn_pos)
			return true
	
	return false

func choose_weighted_building() -> String:
	var total_weight = 0.0
	for building_type in building_types.keys():
		total_weight += building_types[building_type]["weight"]
	
	var random_value = randf() * total_weight
	var current_weight = 0.0
	
	for building_type in building_types.keys():
		current_weight += building_types[building_type]["weight"]
		if random_value <= current_weight:
			return building_type
	
	return ""

func get_random_position_in_chunk(chunk_world_pos: Vector3, chunk_size: Vector2) -> Vector3:
	var random_x = randf_range(0, chunk_size.x * 10)
	var random_z = randf_range(0, chunk_size.y * 10)
	return chunk_world_pos + Vector3(random_x, 0, random_z)

func is_valid_spawn_position(building_type: String, position: Vector3) -> bool:
	var building_config = building_types[building_type]
	
	# Quick distance check from spawn
	if position.length() < building_config["min_distance_from_spawn"]:
		return false
	
	# Check distance from other buildings (optimized)
	var min_same = building_config["min_distance_between_same"]
	var min_any = building_config["min_distance_between_any"]
	
	for spawned in spawned_buildings:
		var distance_sq = position.distance_squared_to(spawned["position"])  # Faster than distance()
		
		if spawned["type"] == building_type:
			if distance_sq < min_same * min_same:
				return false
		elif distance_sq < min_any * min_any:
			return false
	
	# Raycast check (reuse query object)
	var space_state = get_tree().root.get_world_3d().direct_space_state
	raycast_query.from = Vector3(position.x, 50, position.z)
	raycast_query.to = Vector3(position.x, -10, position.z)
	
	var result = space_state.intersect_ray(raycast_query)
	return result != null

func spawn_building(building_type: String, position: Vector3):
	# Use preloaded scene
	var building_scene = BUILDING_SCENES.get(building_type)
	if not building_scene:
		push_error("Building scene not preloaded: " + building_type)
		return
	
	var building = building_scene.instantiate()
	get_tree().root.add_child(building)
	
	# Raycast for exact ground position (reuse query)
	var space_state = get_tree().root.get_world_3d().direct_space_state
	raycast_query.from = Vector3(position.x, 50, position.z)
	raycast_query.to = Vector3(position.x, -10, position.z)
	
	var result = space_state.intersect_ray(raycast_query)
	building.global_position = result.position if result else position
	
	# Random rotation for small buildings
	if building_type in ["scavenger_container", "scavenger_container_double", "broken_car_1"]:
		building.rotation.y = randf() * TAU
	
	spawned_buildings.append({
		"type": building_type,
		"position": building.global_position,
		"instance": building
	})

func get_buildings_by_type(building_type: String) -> Array:
	var buildings = []
	for spawned in spawned_buildings:
		if spawned["type"] == building_type:
			buildings.append(spawned["instance"])
	return buildings

func get_closest_building(position: Vector3) -> Node3D:
	if spawned_buildings.is_empty():
		return null
	
	var closest = null
	var closest_distance_sq = INF
	
	for spawned in spawned_buildings:
		var distance_sq = position.distance_squared_to(spawned["position"])
		if distance_sq < closest_distance_sq:
			closest_distance_sq = distance_sq
			closest = spawned["instance"]
	
	return closest

func clear_all_buildings():
	for spawned in spawned_buildings:
		if is_instance_valid(spawned["instance"]):
			spawned["instance"].queue_free()
	spawned_buildings.clear()

func cleanup_distant_buildings(player_position: Vector3, max_distance: float = 500.0):
	var max_distance_sq = max_distance * max_distance
	
	for i in range(spawned_buildings.size() - 1, -1, -1):
		var spawned = spawned_buildings[i]
		var distance_sq = player_position.distance_squared_to(spawned["position"])
		
		if distance_sq > max_distance_sq:
			if is_instance_valid(spawned["instance"]):
				spawned["instance"].queue_free()
			spawned_buildings.remove_at(i)
