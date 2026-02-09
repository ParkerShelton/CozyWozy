extends Node3D

var tile_x: int = 0
var tile_z: int = 0

func _ready():
	pass

func generate_foliage():
	# ONLY HOST GENERATES WORLD
	if not Network.is_host:
		return
	
	# Use world seed for generation
	var base_seed = WorldManager.get_world_seed()
	var tile_global_pos = global_position
	
	# Define foliage to spawn
	var foliage_types = {
		"rocks": {"min": 0, "max": 2, "scene": "res://Scenes/rock.tscn"},
		"trees": {"min": 5, "max": 10, "scene": "res://Scenes/tree.tscn"},
		"grass": {"min": 5, "max": 15, "scene": "res://Scenes/tall_grass.tscn"},
		"cactus": {"min": 0, "max": 3, "scene": "res://Scenes/cactus.tscn"}
	}
	
	# Spawn each foliage type
	var foliage_offset = 0
	
	for foliage_name in foliage_types.keys():
		var foliage_config = foliage_types[foliage_name]
		
		var foliage_rng = RandomNumberGenerator.new()
		foliage_rng.seed = base_seed + tile_x * 1000 + tile_z + foliage_offset
		foliage_offset += 100000
		
		var min_count = foliage_config.get("min", 0)
		var max_count = foliage_config.get("max", 5)
		var count = foliage_rng.randi_range(min_count, max_count)
		
		var scene_path = foliage_config.get("scene", "")
		if scene_path == "" or not ResourceLoader.exists(scene_path):
			continue
		
		var foliage_scene = load(scene_path)
		
		for i in range(count):
			var item = foliage_scene.instantiate()
			var random_x = foliage_rng.randf_range(-10, 10)
			var random_z = foliage_rng.randf_range(-10, 10)
			
			get_node("/root/main/foliage").add_child(item)
			item.global_position = tile_global_pos + Vector3(random_x * 20, 0, random_z * 25)
			item.add_to_group(foliage_name)
			
			# REGISTER WITH NETWORK (only syncable resources)
			if foliage_name in ["trees", "rocks"]:
				Network.register_resource(item, foliage_name, scene_path)
