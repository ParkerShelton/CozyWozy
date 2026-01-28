extends Control
@onready var world_list_container = $WorldChoiceScreen/MarginContainer/VBoxContainer/ScrollContainer/WorldListContainer
@onready var new_world_button = $WorldChoiceScreen/MarginContainer/VBoxContainer/HBoxContainer/NewWorldButton
@onready var back_button = $WorldChoiceScreen/MarginContainer/VBoxContainer/HBoxContainer/BackButton
@onready var delete_confirm_dialog = $WorldChoiceScreen/MarginContainer/DeleteConfirmDialog

@onready var new_world_dialog = $ConfirmationDialog
@onready var world_name_input = $ConfirmationDialog/VBoxContainer/LineEdit

var selected_world_to_delete: String = ""

func _ready():
	refresh_world_list()
	new_world_button.pressed.connect(_on_new_world_pressed)
	back_button.pressed.connect(_on_back_pressed)
	delete_confirm_dialog.confirmed.connect(_on_delete_confirmed)
	new_world_dialog.confirmed.connect(_on_create_world_confirmed)

func refresh_world_list():
	# Clear existing buttons
	for child in world_list_container.get_children():
		child.queue_free()
	
	# Get all saved worlds
	var worlds = WorldManager.get_world_list()
	
	if worlds.is_empty():
		var label = Label.new()
		label.text = "No worlds found. Create a new world to get started!"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		world_list_container.add_child(label)
		return
	
	# Create a button for each world
	for world_info in worlds:
		var world_button_container = create_world_button(world_info)
		world_list_container.add_child(world_button_container)

func create_world_button(world_info: Dictionary) -> HBoxContainer:
	var container = HBoxContainer.new()
	
	# Main play button
	var play_button = Button.new()
	play_button.text = world_info["world_name"]
	play_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_button.pressed.connect(_on_world_selected.bind(world_info["world_name"]))
	
	# Add world info as tooltip
	var tooltip = "Created: %s\nLast Played: %s\nTime Played: %.1f hours" % [
		world_info.get("created_at", "Unknown"),
		world_info.get("last_played", "Unknown"),
		world_info.get("time_played", 0.0) / 3600.0
	]
	play_button.tooltip_text = tooltip
	
	# Delete button
	var delete_button = Button.new()
	delete_button.text = "Delete"
	delete_button.pressed.connect(_on_delete_requested.bind(world_info["world_name"]))
	
	container.add_child(play_button)
	container.add_child(delete_button)
	
	return container

func _on_world_selected(world_name: String):
	print("Loading world: " + world_name)
	
	if WorldManager.load_world(world_name):
		# Successfully loaded world data, now switch to game scene
		get_tree().change_scene_to_file("res://Scenes/main.tscn")
	else:
		push_error("Failed to load world: " + world_name)

func _on_new_world_pressed():
	new_world_dialog.popup_centered()
	world_name_input.clear()
	world_name_input.grab_focus()	
	# Switch to new world creation screen
	#get_tree().change_scene_to_file("res://Scenes/main.tscn")
	
func _on_create_world_confirmed():  # Connect this to dialog's OK button
	var world_name = world_name_input.text.strip_edges()
	
	if world_name.is_empty():
		print("World name cannot be empty!")
		return
	
	if WorldManager.world_exists(world_name):
		print("World already exists!")
		return
	
	if WorldManager.create_new_world(world_name):
		print("Created new world: " + world_name)
		get_tree().change_scene_to_file("res://Scenes/main.tscn")
	else:
		push_error("Failed to create world")
		
func _on_delete_requested(world_name: String):
	selected_world_to_delete = world_name
	delete_confirm_dialog.dialog_text = "Are you sure you want to delete '%s'?\nThis cannot be undone!" % world_name
	delete_confirm_dialog.popup_centered()

func _on_delete_confirmed():
	if WorldManager.delete_world(selected_world_to_delete):
		print("Deleted world: " + selected_world_to_delete)
		refresh_world_list()
	else:
		push_error("Failed to delete world: " + selected_world_to_delete)
	selected_world_to_delete = ""

func _on_back_pressed():
	# Go back to main menu or quit
	get_tree().change_scene_to_file("res://UI/main_menu/main_menu.tscn")
