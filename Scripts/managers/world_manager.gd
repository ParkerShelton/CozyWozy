extends Node

const SAVE_DIR = "user://worlds/"
const SAVE_EXTENSION = ".world"

var current_world_name: String = ""
var current_world_data: Dictionary = {}

var is_new_world = false

func _ready():
	# Ensure save directory exists
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("worlds"):
		dir.make_dir("worlds")

func initialize_world_generation():
	if current_world_data.has("world_seed"):
		seed(current_world_data["world_seed"])
		print("World seed set to: ", current_world_data["world_seed"])
	else:
		# Generate a new seed if one doesn't exist
		var new_seed = randi()
		current_world_data["world_seed"] = new_seed
		seed(new_seed)
		print("Generated new world seed: ", new_seed)
		
		# Save immediately so the seed is persisted
		save_world()

func get_world_seed() -> int:
	return current_world_data.get("world_seed", 0)

# Create a new world with default data
func create_new_world(world_name: String) -> bool:
	print("=== CREATE NEW WORLD ===")
	print("World name: ", world_name)
	print("Save directory: ", SAVE_DIR)
	
	if world_exists(world_name):
		push_error("World already exists: " + world_name)
		return false
	
	current_world_name = world_name
	current_world_data = {
		"world_name": world_name,
		"created_at": Time.get_datetime_string_from_system(),
		"last_played": Time.get_datetime_string_from_system(),
		"player_position": Vector3.ZERO,
		"player_rotation": Vector3.ZERO,
		"placed_objects": [],
		"inventory": [],
		"hotbar": [],
		"time_played": 0.0,
		"game_time": 0.0,
		"world_seed": randi(),
		"unlocked_recipes": [],
		"completed_quests": [],
	}
	
	print("Calling save_world()...")
	var save_result = save_world()
	print("Save result: ", save_result)
	
	return save_result

# Load an existing world
func load_world(world_name: String) -> bool:
	var file_path = SAVE_DIR + world_name + SAVE_EXTENSION
	
	if not FileAccess.file_exists(file_path):
		push_error("World file doesn't exist: " + file_path)
		return false
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("Failed to open world file: " + file_path)
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_error("Failed to parse world data")
		return false
	
	current_world_data = json.data
	current_world_name = world_name
	
	print("Loaded placed_objects count: ", current_world_data.get("placed_objects", []).size())
	
	# Update last played time
	current_world_data["last_played"] = Time.get_datetime_string_from_system()
	
	return true

# Save the current world
func save_world() -> bool:	
	if current_world_name.is_empty():
		push_error("No world loaded to save")
		return false
	
	var file_path = SAVE_DIR + current_world_name + SAVE_EXTENSION
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	
	if file == null:
		push_error("Failed to create save file: " + file_path)
		return false
	
	# Update save time
	current_world_data["last_played"] = Time.get_datetime_string_from_system()
	
	print("Saving placed_objects count: ", current_world_data.get("placed_objects", []).size())
	
	var json_string = JSON.stringify(current_world_data, "\t")
	file.store_string(json_string)
	file.close()
	return true

# Get list of all saved worlds
func get_world_list() -> Array:
	var worlds = []
	var dir = DirAccess.open(SAVE_DIR)
	
	if dir == null:
		return worlds
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(SAVE_EXTENSION):
			var world_name = file_name.trim_suffix(SAVE_EXTENSION)
			
			# Load basic info about this world
			var world_info = get_world_info(world_name)
			if world_info:
				worlds.append(world_info)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	return worlds

# Get info about a specific world without fully loading it
func get_world_info(world_name: String) -> Dictionary:
	var file_path = SAVE_DIR + world_name + SAVE_EXTENSION
	
	if not FileAccess.file_exists(file_path):
		return {}
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {}
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		return {}
	
	var data = json.data
	
	# Return just the summary info
	return {
		"world_name": data.get("world_name", world_name),
		"created_at": data.get("created_at", "Unknown"),
		"last_played": data.get("last_played", "Unknown"),
		"time_played": data.get("time_played", 0.0),
	}

# Check if a world exists
func world_exists(world_name: String) -> bool:
	var file_path = SAVE_DIR + world_name + SAVE_EXTENSION
	return FileAccess.file_exists(file_path)

# Delete a world
func delete_world(world_name: String) -> bool:
	var file_path = SAVE_DIR + world_name + SAVE_EXTENSION
	
	if not FileAccess.file_exists(file_path):
		return false
	
	var dir = DirAccess.open(SAVE_DIR)
	var result = dir.remove(world_name + SAVE_EXTENSION)
	
	if result == OK:
		return true
	else:
		push_error("Failed to delete world: " + world_name)
		return false

# Update player data in current world
func update_player_data(position: Vector3, rotation: Vector3, hunger: float = 100.0):
	current_world_data["player_position"] = {
		"x": position.x,
		"y": position.y,
		"z": position.z
	}
	current_world_data["player_rotation"] = {
		"x": rotation.x,
		"y": rotation.y,
		"z": rotation.z
	}
	current_world_data["player_hunger"] = hunger

# Add placed object to world data
func add_placed_object(object_data: Dictionary):
	if not current_world_data.has("placed_objects"):
		current_world_data["placed_objects"] = []
	current_world_data["placed_objects"].append(object_data)

# Get all placed objects
func get_placed_objects() -> Array:
	return current_world_data.get("placed_objects", [])
