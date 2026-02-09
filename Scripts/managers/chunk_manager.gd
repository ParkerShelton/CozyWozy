extends Node

# Chunk settings
var chunk_size: Vector2 = Vector2(3, 3)
var render_distance: int = 3
var unload_distance: int = 8

# Chunk tracking
var loaded_chunks: Dictionary = {}
var ground_width: float = 0.0
var ground_depth: float = 0.0

var ground_scene = preload("res://Scenes/ground.tscn")

func initialize(ground_scene_to_use):
	ground_scene = ground_scene_to_use
	calculate_ground_size()

func calculate_ground_size():
	var sample_ground = ground_scene.instantiate()
	var mesh_node = sample_ground.get_node("ground")
	var aabb = mesh_node.mesh.get_aabb()
	ground_width = aabb.size.x
	ground_depth = aabb.size.z
	sample_ground.queue_free()

func update_chunks(player_position: Vector3, _world_root: Node3D, player_velocity: Vector3 = Vector3.ZERO):
	var player_chunk = world_pos_to_chunk(player_position)
	# Determine which chunks to load based on priority
	var chunks_to_load = []
	
	for x in range(player_chunk.x - render_distance, player_chunk.x + render_distance + 1):
		for z in range(player_chunk.y - render_distance, player_chunk.y + render_distance + 1):
			var chunk_coord = Vector2i(x, z)
			if not is_chunk_loaded(chunk_coord):
				# Calculate priority based on distance and player direction
				var chunk_world_pos = chunk_to_world_pos(chunk_coord)
				var to_chunk = chunk_world_pos - player_position
				var distance = to_chunk.length()
				
				# Higher priority if chunk is in direction of movement
				var priority = distance
				if player_velocity.length() > 0.1:
					var velocity_normalized = player_velocity.normalized()
					var to_chunk_normalized = to_chunk.normalized()
					var dot_product = velocity_normalized.dot(to_chunk_normalized)
					
					# Chunks ahead have higher priority (lower number = load first)
					priority = distance * (1.0 - dot_product * 0.5)
				
				chunks_to_load.append({"coord": chunk_coord, "priority": priority})
	
	# Sort by priority (closest/ahead chunks load first)
	chunks_to_load.sort_custom(func(a, b): return a.priority < b.priority)
	
	# ========== CHANGED: Load more chunks per frame ==========
	var loaded_this_frame = 0
	var max_chunks_per_frame = 10  # Increased from 2 to 10
	
	for chunk_data in chunks_to_load:
		if loaded_this_frame >= max_chunks_per_frame:
			break
		load_chunk(chunk_data.coord)
		loaded_this_frame += 1
	# =========================================================
	
	# Unload far chunks
	var chunks_to_unload = []
	for chunk_key in loaded_chunks.keys():
		var chunk_coord = key_to_coord(chunk_key)
		var distance = chunk_coord.distance_to(player_chunk)
		
		if distance > unload_distance:
			chunks_to_unload.append(chunk_key)
	
	for chunk_key in chunks_to_unload:
		unload_chunk(chunk_key)

func chunk_to_world_pos(chunk_coord: Vector2i) -> Vector3:
	var chunk_world_width = ground_width * 15 * chunk_size.x
	var chunk_world_depth = ground_depth * 13 * chunk_size.y
	
	return Vector3(
		chunk_coord.x * chunk_world_width,
		0,
		chunk_coord.y * chunk_world_depth
	)

func load_chunk(chunk_coord: Vector2i):
	var chunk_key = coord_to_key(chunk_coord)
	
	if loaded_chunks.has(chunk_key):
		return
	
	var chunk_container = Node3D.new()
	chunk_container.name = "Chunk_" + chunk_key
	add_child(chunk_container)
	
	# Calculate chunk world position
	var chunk_world_pos = chunk_to_world_pos(chunk_coord)
	
	for local_x in range(chunk_size.x):
		for local_z in range(chunk_size.y):
			var ground = ground_scene.instantiate()
			
			var tile_x = chunk_coord.x * int(chunk_size.x) + local_x
			var tile_z = chunk_coord.y * int(chunk_size.y) + local_z
			
			ground.position = Vector3(
				tile_x * ground_width * 15,
				0,
				tile_z * ground_depth * 13
			)
			
			ground.tile_x = tile_x
			ground.tile_z = tile_z
			
			chunk_container.add_child(ground)
			ground.call_deferred("generate_foliage")
	
	loaded_chunks[chunk_key] = chunk_container
	
	# Try to spawn building in this chunk
	ExplorableBuildingsManager.try_spawn_building_in_chunk(chunk_coord, chunk_world_pos, chunk_size)

func world_pos_to_chunk(pos: Vector3) -> Vector2i:
	var chunk_world_width = ground_width * 15 * chunk_size.x
	var chunk_world_depth = ground_depth * 13 * chunk_size.y
	
	var chunk_x = int(floor(pos.x / chunk_world_width))
	var chunk_z = int(floor(pos.z / chunk_world_depth))
	
	return Vector2i(chunk_x, chunk_z)

func coord_to_key(coord: Vector2i) -> String:
	return "%d_%d" % [coord.x, coord.y]

func key_to_coord(key: String) -> Vector2i:
	var parts = key.split("_")
	return Vector2i(int(parts[0]), int(parts[1]))

func is_chunk_loaded(coord: Vector2i) -> bool:
	return loaded_chunks.has(coord_to_key(coord))

func unload_chunk(chunk_key: String):
	if not loaded_chunks.has(chunk_key):
		return
	
	var chunk = loaded_chunks[chunk_key]
	if is_instance_valid(chunk):
		chunk.queue_free()
	loaded_chunks.erase(chunk_key)


func clear_chunks():
	loaded_chunks.clear()
