extends Node3D

@onready var spawn_point = $spawn_point
@onready var indoor_camera = $Camera3D

@onready var anim_player = $house_basic_indoor/AnimationPlayer
@onready var floating_popup = $Label3D

var player_nearby: bool = false

var player_scene = preload("res://Scenes/player.tscn")
var player_instance: Node3D = null
var outdoor_player: Node3D = null

@onready var light = $DirectionalLight3D

func _ready():
	light.light_energy = 0.0
	floating_popup.visible = false
	indoor_camera.make_current()
	
	var mesh = $house_basic_indoor/void  # adjust path
	
	for i in range(mesh.mesh.get_surface_count()):
		# Get the original material (correct Godot 4 method)
		var original_mat = mesh.mesh.surface_get_material(i)
		
		# Duplicate it so it's editable
		var new_mat = original_mat.duplicate()
		new_mat.albedo_color = Color(0.0, 0.0, 0.0)  # Black
		new_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

		mesh.set_surface_override_material(i, new_mat)
		
	spawn_player()
	
	# Fade in from black
	await get_tree().create_timer(0.1).timeout
	TransitionManager.fade_from_black(1.0)
	
	await get_tree().create_timer(0.5).timeout
	light.light_energy = 2.0

func spawn_player():
	player_instance = player_scene.instantiate()
	player_instance.add_to_group("player")
	add_child(player_instance)
	
	if spawn_point:
		player_instance.global_position = spawn_point.global_position
		player_instance.global_rotation = spawn_point.global_rotation
	
	# Restore from WorldManager
	player_instance.current_hunger = WorldManager.current_world_data.get("player_hunger", 100.0)
	player_instance.player_health = WorldManager.current_world_data.get("player_health", 100.0)


func _on_area_3d_body_entered(body):
	if body.is_in_group("player"):
		player_nearby = true
		anim_player.play("doorAction")

		floating_popup.visible = true


func _on_area_3d_body_exited(body):
	if body.is_in_group("player"):
		player_nearby = false
		anim_player.play_backwards("doorAction")
		
		floating_popup.visible = false
			
func _input(event):
	if not player_nearby:
		return
	
	if Input.is_action_just_pressed("rotate_clockwise"):
		exit_house()
		
func exit_house():
	if player_instance:
		# Save hunger/health back — position is already the house door from when we entered
		WorldManager.current_world_data["player_hunger"] = player_instance.current_hunger
		WorldManager.current_world_data["player_health"] = player_instance.player_health
	
	await TransitionManager.fade_to_black(0.5).finished
	get_tree().change_scene_to_file("res://Scenes/main.tscn")
