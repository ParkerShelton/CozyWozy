extends Node3D

var ground_scene = preload("res://Scenes/ground.tscn")

# Called when the node enters the scene tree for the first time.
func _ready():
	first_line()

func first_line():
	TransitionManager.fade_to_black()
