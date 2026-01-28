extends Node3D

var world_size : Vector2 = Vector2(5, 5)

var player_scene = preload("res://Scenes/player.tscn")
var ground_scene = preload("res://Scenes/ground.tscn")
var robot_basic = preload("res://Scenes/Enemies/robot_basic.tscn")

var world_generated = false

func _ready():
	WorldManager.initialize_world_generation()	
	
	spawn_map_grid(world_size)
	
	load_world_data()


func load_world_data():
	var world_data = WorldManager.current_world_data
	var spawn_pos: Vector3
	
	if world_data.has("player_position"):
		var pos = world_data["player_position"]
		if pos is Vector3:
			spawn_pos = pos
		elif pos is Dictionary:
			spawn_pos = Vector3(pos["x"], pos["y"], pos["z"])
	else:
		spawn_pos = Vector3(0, 10, 0)
	
	var player = player_scene.instantiate()
	player.add_to_group("player")
	player.position = spawn_pos  # Set position BEFORE adding to tree
	add_child(player)
	
	print("Player spawned at: ", player.position)
	
	var enemy = robot_basic.instantiate()
	enemy.position = Vector3(-1, 0, -1)
	get_node("/root/main/enemies").add_child(enemy)
	
	# NOW wait a frame for camera to find and position itself
	await get_tree().process_frame
	
	# Reset camera after player is positioned
	var camera = $Camera3D
	if camera:
		camera.first_frame = true
		camera.find_target()
	
	# Load rotation
	if world_data.has("player_rotation"):
		var rot = world_data["player_rotation"]
		if rot is Vector3:
			player.rotation = rot
		elif rot is Dictionary:
			player.rotation = Vector3(rot["x"], rot["y"], rot["z"])

func spawn_map_grid(size: Vector2):
	var sample_ground = ground_scene.instantiate()
	var mesh_node = sample_ground.get_node("ground")
	var aabb = mesh_node.mesh.get_aabb()
	var ground_width = aabb.size.x
	var ground_depth = aabb.size.z
	sample_ground.queue_free()
	
	for x in range(size.x):
		for z in range(size.y):
			var ground = ground_scene.instantiate()
			ground.position = Vector3(x * ground_width * 15, 0, z * ground_depth * 13)
			
			# Add tile coordinates to the tile
			ground.tile_x = x
			ground.tile_z = z
			
			add_child(ground)
			ground.call_deferred("generate_foliage")

func save_game_data():
	# Save player
	WorldManager.update_player_data($Player.position, $Player.rotation)
	
	# Save inventory - adjust this to match YOUR actual inventory system
	WorldManager.current_world_data["inventory"] = $Player/InventorySystem.get_save_data()
	
	# Save hotbar - adjust this to match YOUR actual hotbar system
	WorldManager.current_world_data["hotbar"] = $Player/HotbarSystem.get_save_data()
	
	# Save placed objects
	var placed_objects = []
	for building in get_tree().get_nodes_in_group("placed_buildings"):
		placed_objects.append({
			"type": building.building_type,
			"position": building.position,
			"rotation": building.rotation,
			# Add any other data you need
		})
	WorldManager.current_world_data["placed_objects"] = placed_objects
	
	# Save game time
	WorldManager.current_world_data["game_time"] = $DayNightCycle.current_time  # If you have this
	
	# Actually write to disk
	WorldManager.save_world()
