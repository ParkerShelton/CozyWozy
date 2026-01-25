extends Node3D

var world_size : Vector2 = Vector2(5, 5)

var player_scene = preload("res://Scenes/player.tscn")

var ground_scene = preload("res://Scenes/ground.tscn")

func _ready():
	spawn_map_grid(world_size)
	spawn_player()


func spawn_player():
	var player = player_scene.instantiate()
	player.position = Vector3(0,0,0)
	player.add_to_group("player")
	add_child(player)

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
			add_child(ground)
