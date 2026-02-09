# dungeon_room.gd
extends Node3D

@onready var dungeon_generator = $dungeon_generator
var player: CharacterBody3D = null
var dungeon_camera: Camera3D = null

var camera_offset = Vector3(-20, 20, 0)
var camera_rotation = Vector3(-45, -90, 0)
var camera_zoom = 50

func _ready():
	
	if not dungeon_generator:
		return
	
	# Generate dungeon
	var spawn_pos = dungeon_generator.generate_dungeon()
	
	await get_tree().process_frame
	
	spawn_new_player(spawn_pos)
	setup_camera()

func spawn_new_player(position: Vector3):
	var player_scene = load("res://Scenes/player.tscn")
	
	if player_scene:
		player = player_scene.instantiate()
		get_tree().root.add_child(player)
		player.global_position = position + Vector3(0, 6.5, 0)
	else:
		print("ERROR: Could not load player scene!")

func setup_camera():
	if not player:
		return
	
	dungeon_camera = Camera3D.new()
	add_child(dungeon_camera)
	dungeon_camera.make_current()
	dungeon_camera.fov = camera_zoom
	update_camera()

func _process(_delta):
	if player and dungeon_camera:
		update_camera()

func update_camera():
	dungeon_camera.global_position = player.global_position + camera_offset
	dungeon_camera.rotation_degrees = camera_rotation
