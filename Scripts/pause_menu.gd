extends CanvasLayer

@onready var resume_button = $ColorRect/CenterContainer/PanelContainer/VBoxContainer/ResumeButton
@onready var save_button = $ColorRect/CenterContainer/PanelContainer/VBoxContainer/SaveButton

func _ready():
	# Start hidden
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS  # Keep processing when paused
	
	# Connect buttons
	resume_button.pressed.connect(_on_resume_pressed)
	save_button.pressed.connect(_on_save_pressed)

func _input(event):
	if event.is_action_pressed("pause_menu"):  # ESC key by default
		toggle_pause()

func toggle_pause():
	if visible:
		resume_game()
	else:
		pause_game()

func pause_game():
	show()
	get_tree().paused = true

func resume_game():
	hide()
	get_tree().paused = false

func _on_resume_pressed():
	resume_game()

func _on_save_pressed():
	save_game()
	
	EnemyManager.disable_spawning()
	EnemyManager.clear_all_enemies()

	print("Game saved!")
	await get_tree().create_timer(1).timeout
	get_tree().paused = false
	get_tree().change_scene_to_file("res://UI/main_menu/main_menu.tscn")


func save_game():
	# Get references to your game systems (adjust paths as needed)
	var player = get_tree().get_first_node_in_group("player")
	var world = get_tree().get_first_node_in_group("world")
	
	if player:
		# Save player data
		WorldManager.update_player_data(player.position, player.rotation, player.current_hunger)
	
	var day_night_cycle = get_node_or_null("/root/main/day_night_overlay/ColorRect")
	if day_night_cycle and day_night_cycle.has_method("get_time"):
		WorldManager.current_world_data["game_time"] = day_night_cycle.get_time()
		print("Saved time: ", day_night_cycle.get_time())
	
	# Save inventory and hotbar (adjust to your actual system names)
	# Replace these with your actual inventory/hotbar references
	if has_node("/root/InventoryManager"):  # Example if you have a singleton
		WorldManager.current_world_data["inventory"] = get_node("/root/InventoryManager").get_save_data()
	
	if has_node("/root/HotbarManager"):  # Example if you have a singleton
		WorldManager.current_world_data["hotbar"] = get_node("/root/HotbarManager").get_save_data()
	
	# Save placed objects
	if world and world.has_method("get_all_placed_objects"):
		WorldManager.current_world_data["placed_objects"] = world.get_all_placed_objects()
	
	# Update play time
	if WorldManager.current_world_data.has("time_played"):
		WorldManager.current_world_data["time_played"] += get_tree().get_frame()  # Or track properly
	
	# Actually save to disk
	WorldManager.save_world()
