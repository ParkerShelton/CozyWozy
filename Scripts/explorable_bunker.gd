extends Node3D

var player_nearby = false




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
