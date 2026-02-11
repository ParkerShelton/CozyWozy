# main.gd - COMPLETE WITH AUTHORITY-BASED SYNC
extends Node3D

var world_size : Vector2 = Vector2(5, 5)

var player_scene = preload("res://Scenes/player.tscn")
var ground_scene = preload("res://Scenes/ground.tscn")
var robot_basic = preload("res://Scenes/Explorable_Buildings/dungeon_1.tscn")

# Chunk settings
var chunk_size: Vector2 = Vector2(1, 1)
var render_distance: int = 5
var unload_distance: int = 8

# Chunk tracking
var loaded_chunks: Dictionary = {}
var ground_width: float = 0.0
var ground_depth: float = 0.0

# Player instance
var player_instance: Node3D = null

func _ready():
	WorldManager.initialize_world_generation()
	calculate_ground_size()
	load_world_data()
	SettingsManager.apply_all_settings()
	
	var chunk_timer = Timer.new()
	chunk_timer.wait_time = 0.5
	chunk_timer.timeout.connect(_on_chunk_timer_timeout)
	add_child(chunk_timer)
	chunk_timer.start()
	
	# AUTHORITY-BASED: Connect to network signals
	Network.player_connected.connect(_on_player_joined_lobby)
	Network.world_state_received.connect(_on_world_state_received)

func _on_chunk_timer_timeout():
	update_chunks()

# AUTHORITY-BASED: When a player joins, send them the world state
func _on_player_joined_lobby(steam_id: int, player_name: String):
	print("🎮 Player ", player_name, " joined - sending world state")
	
	# Wait a moment for them to finish loading
	await get_tree().create_timer(1.0).timeout
	
	if Network.is_host:
		Network.send_world_state_to_client(steam_id)

# AUTHORITY-BASED: Client receives world state and spawns everything
func _on_world_state_received(resources: Array):
	print("🌍 Client spawning ", resources.size(), " resources from host")
	
	for resource_data in resources:
		spawn_resource_from_data(resource_data)
	
	print("✓ Client finished spawning world!")

func spawn_resource_from_data(data: Dictionary):
	"""Spawn a single resource from host data"""
	var resource_type = data.get("type", "")
	var pos_dict = data.get("position", {})
	var position = Vector3(pos_dict.x, pos_dict.y, pos_dict.z)
	var scene_path = data.get("scene_path", "")
	var resource_id = data.get("id", -1)
	
	if scene_path == "" or not ResourceLoader.exists(scene_path):
		print("⚠️ Invalid scene path: ", scene_path)
		return
	
	var resource_scene = load(scene_path)
	var resource_node = resource_scene.instantiate()
	
	# Add to foliage container
	var foliage_container = get_node_or_null("foliage")
	if not foliage_container:
		print("⚠️ No foliage container found!")
		return
	
	foliage_container.add_child(resource_node)
	resource_node.global_position = position
	resource_node.add_to_group(resource_type)
	
	# Set the resource ID so we can destroy it later
	resource_node.set_meta("resource_id", resource_id)

func update_chunks():
	if not player_instance:
		return
	
	var player_chunk = world_pos_to_chunk(player_instance.global_position)
	
	# Load chunks in render distance
	for x in range(player_chunk.x - render_distance, player_chunk.x + render_distance + 1):
		for z in range(player_chunk.y - render_distance, player_chunk.y + render_distance + 1):
			var chunk_coord = Vector2i(x, z)
			if not is_chunk_loaded(chunk_coord):
				load_chunk(chunk_coord)
	
	# Unload far chunks
	var chunks_to_unload = []
	for chunk_key in loaded_chunks.keys():
		var chunk_coord = key_to_coord(chunk_key)
		var distance = chunk_coord.distance_to(player_chunk)
		
		if distance > unload_distance:
			chunks_to_unload.append(chunk_key)
	
	for chunk_key in chunks_to_unload:
		unload_chunk(chunk_key)

func load_world_data():
	print("=== LOAD WORLD DATA START ===")
	print("Steam initialized: ", Network.steam_initialized)
	print("Is host: ", Network.is_host)
	print("Lobby ID: ", Network.lobby_id)
	
	# CLIENT: Don't load world data, wait for host to send it
	# BUT NOT IN SINGLEPLAYER!
	if Network.steam_initialized and not Network.is_host and Network.lobby_id != 0:
		print("⏸️ CLIENT: Skipping world load, waiting for host...")
		
		# Still spawn the player though
		player_instance = player_scene.instantiate()
		player_instance.add_to_group("player")
		add_child(player_instance)
		
		await get_tree().process_frame
		
		player_instance.position = Vector3(0, 1, 0)
		
		print("✓ CLIENT: Player spawned, waiting for world state...")
		return
	
	# HOST or SINGLEPLAYER: Load normally
	print("🌍 HOST/SINGLEPLAYER: Loading world data...")
	
	var world_data = WorldManager.current_world_data
	var spawn_pos: Vector3
	
	if world_data.has("player_position"):
		var pos = world_data["player_position"]
		if pos is Vector3:
			spawn_pos = pos
		elif pos is Dictionary:
			spawn_pos = Vector3(pos["x"], pos["y"], pos["z"])
	else:
		spawn_pos = Vector3(0, 1, 0)
	
	player_instance = player_scene.instantiate()
	player_instance.add_to_group("player")
	add_child(player_instance)
	
	await get_tree().process_frame
	
	player_instance.position = spawn_pos
	
	var dungeon = robot_basic.instantiate()
	add_child(dungeon)
	dungeon.position = spawn_pos + Vector3(5, 0, 0)
	
	if world_data.has("player_rotation"):
		var rot = world_data["player_rotation"]
		if rot is Vector3:
			player_instance.rotation = rot
		elif rot is Dictionary:
			player_instance.rotation = Vector3(rot["x"], rot["y"], rot["z"])
	
	if world_data.has("player_hunger"):
		player_instance.current_hunger = world_data["player_hunger"]
	
	if world_data.has("game_time"):
		var day_night_cycle = get_node_or_null("/root/main/day_night_overlay/ColorRect")
		if day_night_cycle and day_night_cycle.has_method("set_time"):
			day_night_cycle.set_time(world_data["game_time"])
	
	# Generate initial chunks
	print("Generating initial chunks...")
	update_chunks()
	
	await get_tree().create_timer(0.5).timeout  # Small delay for world to settle
	TransitionManager.fade_from_black(1.0)
	
	print("Enabling enemy spawning...")
	EnemyManager.enable_spawning()
	print("✓ World loaded - enemy spawning enabled")
	
	

func save_game_data():
	var player_node = get_tree().get_first_node_in_group("player")
	if player_node:
		WorldManager.update_player_data(player_node.position, player_node.rotation)
	
	var day_night_cycle = $CanvasModulate
	if day_night_cycle and day_night_cycle.has_method("get_time"):
		WorldManager.current_world_data["game_time"] = day_night_cycle.get_time()
	
	WorldManager.save_world()

func calculate_ground_size():
	var sample_ground = ground_scene.instantiate()
	var mesh_node = sample_ground.get_node("ground")
	var aabb = mesh_node.mesh.get_aabb()
	ground_width = aabb.size.x
	ground_depth = aabb.size.z
	sample_ground.queue_free()

# Convert world position to chunk coordinates
func world_pos_to_chunk(pos: Vector3) -> Vector2i:
	var chunk_world_width = ground_width * 15 * chunk_size.x
	var chunk_world_depth = ground_depth * 13 * chunk_size.y
	
	var chunk_x = int(floor(pos.x / chunk_world_width))
	var chunk_z = int(floor(pos.z / chunk_world_depth))
	
	return Vector2i(chunk_x, chunk_z)

# Convert chunk coordinates to world position
func chunk_to_world_pos(chunk_coord: Vector2i) -> Vector3:
	var chunk_world_width = ground_width * 15 * chunk_size.x
	var chunk_world_depth = ground_depth * 13 * chunk_size.y
	
	return Vector3(
		chunk_coord.x * chunk_world_width,
		0,
		chunk_coord.y * chunk_world_depth
	)

# Generate chunk key
func coord_to_key(coord: Vector2i) -> String:
	return "%d_%d" % [coord.x, coord.y]

# Convert key to coordinates
func key_to_coord(key: String) -> Vector2i:
	var parts = key.split("_")
	return Vector2i(int(parts[0]), int(parts[1]))

# Check if chunk is loaded
func is_chunk_loaded(coord: Vector2i) -> bool:
	return loaded_chunks.has(coord_to_key(coord))

# Load a chunk
func load_chunk(chunk_coord: Vector2i):
	var chunk_key = coord_to_key(chunk_coord)
	
	if loaded_chunks.has(chunk_key):
		return
	
	var chunk_container = Node3D.new()
	chunk_container.name = "Chunk_" + chunk_key
	add_child(chunk_container)
	
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
	
	# Try to spawn an explorable building in this chunk
	if ExplorableBuildingsManager:
		ExplorableBuildingsManager.try_spawn_building_in_chunk(chunk_coord, chunk_world_pos, chunk_size)
	
	loaded_chunks[chunk_key] = chunk_container

# Unload a chunk
func unload_chunk(chunk_key: String):
	if not loaded_chunks.has(chunk_key):
		return
	
	var chunk = loaded_chunks[chunk_key]
	chunk.queue_free()
	loaded_chunks.erase(chunk_key)
