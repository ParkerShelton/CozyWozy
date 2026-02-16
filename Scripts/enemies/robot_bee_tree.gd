extends Node3D

@onready var bee_hive = $robot_bee_tree/Cube
var bee_scene = preload("res://Scenes/Enemies/robot_bees.tscn")

var player_near = false
var spawned_bees = false

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if player_near and not spawned_bees:
		spawned_bees = true
		var bee = bee_scene.instantiate()
		add_child(bee)
		bee.global_position = bee_hive.global_position
		get_tree().create_timer(3)


func _on_area_3d_body_entered(body):
	if body.is_in_group("player"):
		player_near = true


func _on_area_3d_body_exited(body):
	if body.is_in_group("player"):
		player_near = false
