extends Node3D

var tile_x: int = 0
var tile_z: int = 0

# PRE-LOAD SCENES AT CLASS LEVEL (only loaded once per script, not per tile!)
const SCENES = {
	"rocks": preload("res://Scenes/rock.tscn"),
	"trees": preload("res://Scenes/tree.tscn"),
	"grass": preload("res://Scenes/tall_grass.tscn"),
	"tree_2": preload("res://Scenes/tree_2.tscn"),
	"apple_tree": preload("res://Scenes/apple_tree.tscn")
}

func _ready():
	pass

func generate_foliage():
	if not Network.is_host:
		return
	
	# PREVENT DOUBLE GENERATION
	if get_meta("foliage_generated", false):
		return
	
	set_meta("foliage_generated", true)
	
	# CHECK IF THIS TILE IS INSIDE A CITY - SKIP ALL FOLIAGE IF SO
	if CityManager and CityManager.is_in_city(position):
		return
	
	var base_seed = WorldManager.get_world_seed()
	var tile_global_pos = position
	
	# Your original foliage types
	var foliage_types = {
		"rocks": {"min": 0, "max": 2, "scene": SCENES["rocks"]},
		"trees": {"min": 3, "max": 5, "scene": SCENES["trees"]},
		"grass": {"min": 5, "max": 15, "scene": SCENES["grass"]},
		"tree_2": {"min": 2, "max": 4, "scene": SCENES["tree_2"]},
		"apple_tree": {"min": 0, "max": 1, "scene": SCENES["apple_tree"]}
	}
	
	var foliage_offset = 0
	
	for foliage_name in foliage_types.keys():
		var foliage_config = foliage_types[foliage_name]
		
		var foliage_rng = RandomNumberGenerator.new()
		var coord_hash = hash(Vector2i(tile_x, tile_z))
		foliage_rng.seed = base_seed + coord_hash + foliage_offset
		foliage_offset += 100000
		
		var count = foliage_rng.randi_range(foliage_config["min"], foliage_config["max"])
		var foliage_scene = foliage_config["scene"]
		
		if not foliage_scene:
			continue
		
		for i in range(count):
			var random_x = foliage_rng.randf_range(-5, 5)
			var random_z = foliage_rng.randf_range(-5, 5)
			var spawn_pos = tile_global_pos + Vector3(random_x * 3, 0, random_z * 3)
			
			# ALSO CHECK IF INDIVIDUAL SPAWN POSITION IS IN A CITY
			if CityManager and CityManager.is_in_city(spawn_pos):
				continue  # Skip this individual tree/rock
			
			var item = foliage_scene.instantiate()
			item.position = spawn_pos
			item.add_to_group(foliage_name)
			add_child(item)
			
			# REGISTER WITH NETWORK
			if foliage_name in ["trees", "rocks", "apple_tree", "tree_2"]:
				var scene_path = "res://Scenes/" + foliage_name + ".tscn"
				if foliage_name == "apple_tree":
					scene_path = "res://Scenes/apple_tree.tscn"
				elif foliage_name == "trees":
					scene_path = "res://Scenes/tree.tscn"
				elif foliage_name == "tree_2":
					scene_path = "res://Scenes/tree_2.tscn"
				elif foliage_name == "rocks":
					scene_path = "res://Scenes/rock.tscn"
				
				Network.register_resource(item, foliage_name, scene_path)
