# workbench_ui.gd
extends Control

@onready var subviewport = $SubViewportContainer/SubViewport
#@onready var input_grid = $Panel/HBoxContainer/LeftPanel/InputArea/GridContainer
#@onready var recipe_list = $Panel/HBoxContainer/RightPanel/RecipeArea/ScrollContainer/VBoxContainer

var background_scene = preload("res://Scenes/Workbenches/workbench_scene.tscn")
var background_instance: Node3D = null

var station_name: String = ""
var player: Node3D = null
var input_slots: Array = []

signal crafting_complete

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Setup SubViewport
	subviewport.size = Vector2i(1920, 1080)
	subviewport.transparent_bg = false
	subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	
	# Load the 3D background scene
	background_instance = background_scene.instantiate()
	subviewport.add_child(background_instance)
	
	# Setup input slots (your existing code)
	setup_input_slots()

func setup_input_slots():
	# Create your input slots here
	pass

func open_station(station: String, player_ref: Node3D):
	station_name = station
	player = player_ref
	
	visible = true
	get_tree().paused = true
	
	# Optional: animate the 3D scene (rotate workbench, etc.)
	if background_instance:
		animate_background()

func close_station():
	visible = false
	get_tree().paused = false
	
	# Return items to player
	return_all_items()

func animate_background():
	# Add some life to the background
	var workbench = background_instance.find_child("Workbench", true, false)
	if workbench:
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(workbench, "rotation:y", workbench.rotation.y + TAU, 20.0)

func return_all_items():
	# Your existing code to return items
	pass

func _input(event):
	if visible and event.is_action_pressed("ui_cancel"):
		close_station()
