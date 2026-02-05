# workbench.gd
extends Node3D

@export var station_name: String = "workbench"
@export var crafting_scene_path: String = "res://UI/workbench_crafting_scene.tscn"

var nearby_player: Node3D = null

func _ready():
	var area = $Area3D
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.is_in_group("player"):
		nearby_player = body
		if body.has_method("add_crafting_station"):
			body.add_crafting_station(station_name)
		print("Player entered workbench area")

func _on_body_exited(body):
	if body.is_in_group("player"):
		nearby_player = null
		if body.has_method("remove_crafting_station"):
			body.remove_crafting_station(station_name)
		print("Player left workbench area")

func _input(event):
	if nearby_player and event.is_action_pressed("click"):
		open_crafting_scene()

func open_crafting_scene():
	# Save the current game state before switching
	save_game_state()
	
	# Switch to the crafting scene
	get_tree().change_scene_to_file(crafting_scene_path)

func save_game_state():
	# Create a temporary state to pass to the crafting scene
	var crafting_state = {
		"station_name": station_name,
		"player_position": nearby_player.global_position if nearby_player else Vector3.ZERO,
		"player_rotation": nearby_player.rotation if nearby_player else Vector3.ZERO,
		"return_scene": get_tree().current_scene.scene_file_path
	}
	
	# Store in an autoload (you'll need to create this)
	if has_node("/root/CraftingState"):
		get_node("/root/CraftingState").set_state(crafting_state)
	else:
		# Fallback: store in a global variable
		# You can create a simple autoload script for this
		print("Warning: CraftingState autoload not found")
		print("Crafting state: ", crafting_state)
