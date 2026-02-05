extends Node3D

var player_scene = preload("res://Scenes/player.tscn")
var ground_scene = preload("res://Scenes/ground.tscn")

var box_scene = preload("res://Scenes/Craftables/Building/chest.tscn")

var player_instance: Node3D = null

func _ready():
	ChunkManager.clear_chunks()
	WorldManager.initialize_world_generation()
	ChunkManager.initialize(ground_scene)
	WorldNoise.initialize(WorldManager.get_world_seed())
	load_world_data()
	
	var chunk_timer = Timer.new()
	chunk_timer.wait_time = 0.5
	chunk_timer.timeout.connect(_on_chunk_timer_timeout)
	add_child(chunk_timer)
	chunk_timer.start()

func _on_chunk_timer_timeout():
	if player_instance:
		# Pass player velocity for smarter chunk loading
		ChunkManager.update_chunks(player_instance.global_position, self, player_instance.velocity)

func load_world_data():
	var world_data = WorldManager.current_world_data
	var spawn_pos: Vector3
	
	print("world_data player_position: ", world_data.get("player_position", "NOT FOUND"))
	
	if world_data.has("player_position"):
		var pos = world_data["player_position"]
		print("pos type: ", typeof(pos))
		print("pos value: ", pos)
		if pos is Vector3:
			spawn_pos = pos
		elif pos is Dictionary:
			spawn_pos = Vector3(pos["x"], pos["y"], pos["z"])
	else:
		spawn_pos = Vector3(0, 10, 0)
	
	print("Final spawn_pos: ", spawn_pos)
	
	player_instance = player_scene.instantiate()
	player_instance.add_to_group("player")
	add_child(player_instance)
	
	await get_tree().process_frame
	
	player_instance.position = spawn_pos
	
	player_instance.set_physics_process(false)
	
	var box = box_scene.instantiate()
	add_child(box)
	box.position.x = player_instance.position.x + 20
	
	if world_data.has("player_rotation"):
		var rot = world_data["player_rotation"]
		if rot is Vector3:
			player_instance.rotation = rot
		elif rot is Dictionary:
			player_instance.rotation = Vector3(rot["x"], rot["y"], rot["z"])
	
	if world_data.has("player_hunger"):
		player_instance.current_hunger = world_data["player_hunger"]

	if world_data.has("player_health"):
		player_instance.player_health = world_data["player_health"]

	if world_data.has("game_time"):
		var day_night_cycle = get_node_or_null("/root/main/day_night_overlay/ColorRect")
		if day_night_cycle and day_night_cycle.has_method("set_time"):
			day_night_cycle.set_time(world_data["game_time"])
	
	load_placed_objects()

	preload_chunks_around_player()
	print("Chunks pre-loaded!")
	
	await get_tree().create_timer(0.5).timeout
	EnemyManager.despawn_enemies_near_player(30.0)
	AnimalManager.enable_spawning()
	player_instance.set_physics_process(true)
	TransitionManager.fade_from_black(1.5)
	
	await get_tree().create_timer(2.0).timeout
	EnemyManager.enable_spawning()


func preload_chunks_around_player():
	if not player_instance:
		return
	
	# Force load all chunks in render distance
	var player_chunk = ChunkManager.world_pos_to_chunk(player_instance.global_position)
	var render_dist = ChunkManager.render_distance
	
	for x in range(player_chunk.x - render_dist, player_chunk.x + render_dist + 1):
		for z in range(player_chunk.y - render_dist, player_chunk.y + render_dist + 1):
			var chunk_coord = Vector2i(x, z)
			if not ChunkManager.is_chunk_loaded(chunk_coord):
				ChunkManager.load_chunk(chunk_coord)
	
	# Wait a frame for everything to settle
	await get_tree().process_frame

func load_placed_objects():
	var placed_objects = WorldManager.get_placed_objects()
	
	if placed_objects.size() == 0:
		print("No placed objects to load")
		return
	
	print("Loading ", placed_objects.size(), " placed objects...")
	
	for obj_data in placed_objects:
		var item_name = obj_data.get("item_name", "")
		
		if item_name == "":
			continue
		
		if not ItemManager.has_model(item_name):
			print("Warning: Item '", item_name, "' not found, skipping")
			continue
		
		var model_scene = ItemManager.get_model(item_name)
		var placed_obj = model_scene.instantiate()
		
		add_child(placed_obj)
		
		var pos_data = obj_data.get("position", {"x": 0, "y": 0, "z": 0})
		placed_obj.global_position = Vector3(pos_data["x"], pos_data["y"], pos_data["z"])
		
		var rot_data = obj_data.get("rotation", {"x": 0, "y": 0, "z": 0})
		placed_obj.global_rotation = Vector3(rot_data["x"], rot_data["y"], rot_data["z"])
		
		
		if placed_obj.has_method("enable_light"):
			placed_obj.enable_light()
	
	print("Finished loading placed objects")
