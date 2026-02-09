extends Node3D

var player_nearby = false

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_area_3d_body_entered(body):
	if body.is_in_group("player"):
		player_nearby = true

func _input(event):
	if player_nearby and event.is_action_pressed("eat"):
		enter_dungeon()
		
func enter_dungeon():
	get_tree().change_scene_to_file("res://Scenes/Explorable_Buildings/dungeon_room.tscn")

func _on_area_3d_body_exited(body):
	if body.is_in_group("player"):
		player_nearby = false
