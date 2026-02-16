extends Node

const ANIMALS_FILE = "res://Data/animals.json"
var animals: Dictionary = {}
var discovered_animals: Array = []

# Spawn settings
var max_animals: int = 50
var spawn_cooldown: float = 5.0
var spawn_distance: float = 30.0  # Far enough for 2.5D camera view
var can_spawn: bool = false



# References
var player: Node3D = null
var camera: Camera3D = null

func _ready():
	load_animals()
	
	# Start spawn timer
	var spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_cooldown
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)
	spawn_timer.start()

func load_animals():
	if not FileAccess.file_exists(ANIMALS_FILE):
		push_error("Animals file not found: " + ANIMALS_FILE)
		return
	
	var file = FileAccess.open(ANIMALS_FILE, FileAccess.READ)
	if file == null:
		push_error("Failed to open animals file")
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_error("Failed to parse animals JSON")
		return
	
	animals = json.data

func _on_spawn_timer_timeout():
	# Get player reference
	if not player:
		player = get_tree().get_first_node_in_group("player")
		if not player:
			return
	
	if not camera:
		var main = get_node_or_null("/root/main")
		if main:
			camera = main.get_node_or_null("Camera3D")
			if not camera:
				camera = main.find_child("Camera3D", true, false)
				
	# Check current animal count
	var current_animals = get_tree().get_nodes_in_group("animals")
	
	if current_animals.size() >= max_animals:
		return
	
	# Choose which animal to spawn based on weights FROM JSON
	var eligible_animals = get_eligible_animals()
	if eligible_animals.size() == 0:
		return
	
	var chosen_animal = choose_weighted_animal(eligible_animals)

	
	# Try to find spawn position
	var spawn_pos = get_spawn_position_outside_camera()
	
	if spawn_pos == Vector3.ZERO:
		return
	
	# Spawn the animal
	spawn_animal(chosen_animal, spawn_pos)

func get_eligible_animals() -> Array:
	# For now, return all animals that exist in JSON
	# TODO: Filter by biome when biome system is implemented
	var eligible = []
	for animal_name in animals.keys():
		eligible.append(animal_name)
	return eligible

func choose_weighted_animal(eligible_animals: Array) -> String:
	# Build weighted list using spawn_chance from JSON
	var total_weight = 0.0
	var weights = []
	
	for animal_name in eligible_animals:
		var animal_data = animals[animal_name]
		# Use spawn_chance from JSON (defaults to 0.5 if not specified)
		var weight = animal_data.get("spawn_chance", 0.5)
		total_weight += weight
		weights.append({"name": animal_name, "weight": weight})
	
	# Random selection based on weights
	var roll = randf() * total_weight
	var cumulative = 0.0
	
	for entry in weights:
		cumulative += entry.weight
		if roll <= cumulative:
			return entry.name
	
	# Fallback to first animal
	return eligible_animals[0]

func get_spawn_position_outside_camera() -> Vector3:
	if not player:
		return Vector3.ZERO
	
	# Try up to 20 times to find a good position
	for attempt in range(20):
		var angle = randf() * TAU
		var distance = randf_range(spawn_distance * 0.8, spawn_distance * 1.2)
		
		var offset = Vector3(
			cos(angle) * distance,
			0,
			sin(angle) * distance
		)
		
		var potential_pos = player.global_position + offset
		
		# Check if position is in camera view
		var in_view = false
		if camera:
			in_view = is_position_in_camera_view(potential_pos)
		
		# ACCEPT if outside view OR if we've tried 15+ times (fallback)
		if not in_view or attempt >= 15:
			var ground_pos = find_ground_position(potential_pos)
			
			if ground_pos != Vector3.ZERO:
				return ground_pos
	return Vector3.ZERO

func is_position_in_camera_view(pos: Vector3) -> bool:
	if not camera:
		return false
	
	var screen_pos = camera.unproject_position(pos)
	var viewport = camera.get_viewport()
	
	if not viewport:
		return false
	
	var viewport_size = viewport.get_visible_rect().size
	
	# CRITICAL: Small margin so "outside view" is achievable
	var margin = 10
	
	var on_screen = (screen_pos.x >= -margin and 
					 screen_pos.x <= viewport_size.x + margin and
					 screen_pos.y >= -margin and 
					 screen_pos.y <= viewport_size.y + margin)
	
	return on_screen

func find_ground_position(pos: Vector3) -> Vector3:
	var space_state = get_tree().root.get_world_3d().direct_space_state
	var from = Vector3(pos.x, 50, pos.z)
	var to = Vector3(pos.x, -10, pos.z)
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1  # Ground layer
	
	var result = space_state.intersect_ray(query)
	if result:
		return result.position + Vector3(0, 0.5, 0)  # Slightly above ground
	
	return Vector3.ZERO

func spawn_animal(animal_name: String, position: Vector3):
	if not animals.has(animal_name):
		push_error("Animal not found in definitions: " + animal_name)
		return
	
	var animal_data = animals[animal_name]
	var scene_path = animal_data.get("scene", "")
	
	if scene_path == "" or not ResourceLoader.exists(scene_path):
		return
	
	# Load and instantiate animal
	var animal_scene = load(scene_path)
	var animal = animal_scene.instantiate()

	if "animal_definition" in animal:
		animal.animal_definition = animal_data
	
	# Add to world
	get_tree().root.add_child(animal)
	animal.global_position = position
	animal.add_to_group("animals")

# Control functions
func enable_spawning():
	can_spawn = true

func disable_spawning():
	can_spawn = false

func clear_all_animals():
	var animals_list = get_tree().get_nodes_in_group("animals")
	for animal in animals_list:
		animal.queue_free()
	
	
	
func is_animal_discovered(animal_id: String) -> bool:
	return discovered_animals.has(animal_id)

func discover_animal(animal_id: String):
	if discovered_animals.has(animal_id):
		return
	
	discovered_animals.append(animal_id)
	
	# Unlock taming recipe in ItemManager
	unlock_taming_recipe(animal_id)

func unlock_taming_recipe(animal_id: String):
	var animal_data = get_animal_data(animal_id)
	if animal_data.has("taming_totem"):
		var totem_name = animal_data["taming_totem"]
		# Recipe is already in items.json, just mark as discovered

func get_animal_data(animal_id: String) -> Dictionary:
	if animals.has(animal_id):
		return animals[animal_id]
	return {}

func get_animal_name(animal_id: String) -> String:
	var data = get_animal_data(animal_id)
	return data.get("name", animal_id)

func get_animal_diet(animal_id: String) -> String:
	var data = get_animal_data(animal_id)
	return data.get("diet", "Unknown")

func get_animal_description(animal_id: String) -> String:
	var data = get_animal_data(animal_id)
	return data.get("description", "")

func get_discovered_animals() -> Array:
	return discovered_animals
