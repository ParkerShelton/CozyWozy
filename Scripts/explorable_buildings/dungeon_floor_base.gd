# dungeon_floor.gd
extends Node3D

# Paths to floor scene variations
var floor_scene_paths: Array[String] = [
	"res://Scenes/Explorable_Buildings/Floors/floor_1.tscn",
	"res://Scenes/Explorable_Buildings/Floors/floor_2.tscn",
	"res://Scenes/Explorable_Buildings/Floors/floor_3.tscn",
	"res://Scenes/Explorable_Buildings/Floors/floor_4.tscn",
	"res://Scenes/Explorable_Buildings/Floors/floor_5.tscn",
	"res://Scenes/Explorable_Buildings/Floors/floor_6.tscn",
]

# Optional: Random rotation (rotates by 0°, 90°, 180°, or 270°)
@export var random_rotation: bool = true

func _ready():
	if floor_scene_paths.size() == 0:
		push_error("No floor scene paths defined in dungeon_floor.gd!")
		return
	
	# Choose random scene (equal probability)
	var chosen_scene_path = floor_scene_paths[randi() % floor_scene_paths.size()]
	
	# Check if scene exists
	if not ResourceLoader.exists(chosen_scene_path):
		push_error("Floor scene not found: " + chosen_scene_path)
		return
	
	# Load and instantiate
	var floor_scene = load(chosen_scene_path)
	var floor_instance = floor_scene.instantiate()
	add_child(floor_instance)
	
	# Optional: Random Y rotation (0°, 90°, 180°, or 270°)
	if random_rotation:
		var rotations = [0, 90, 180, 270]
		floor_instance.rotation_degrees.y = rotations[randi() % rotations.size()]
