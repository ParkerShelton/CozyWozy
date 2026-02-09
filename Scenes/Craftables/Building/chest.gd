# chest.gd
extends Node3D

@export var chest_id: String = ""  # Unique ID for this chest
@export var max_slots: int = 28  # Same as player inventory

var nearby_player: Node3D = null
var chest_inventory: Array = []
var chest_ui: CanvasLayer = null

var audio_player: AudioStreamPlayer = null
var open_sounds: Array = []
var close_sounds: Array = []

@onready var anim_player : AnimationPlayer = $chest2/AnimationPlayer

func _ready():
	# Generate unique ID if not set
	if chest_id == "":
		chest_id = "chest_" + str(global_position).replace(" ", "_").replace("(", "").replace(")", "").replace(",", "_")
	
	# Initialize empty inventory
	for i in range(max_slots):
		chest_inventory.append({"item_name": "", "quantity": 0, "icon": null})
	
	# Load saved inventory
	load_chest_inventory()
	
	setup_audio()
	
	var area = $Area3D
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	
	# Get reference to chest UI
	await get_tree().process_frame
	chest_ui = get_tree().get_first_node_in_group("chest_ui")
	print(chest_ui)



func setup_audio():
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	audio_player.volume_db = 0.0
	
	# Load the 3 chest open sounds
	for i in range(1, 4):
		var sound = load("res://Assets/SFX/chest_open_" + str(i) + ".mp3")
		if sound:
			open_sounds.append(sound)
		else:
			print("Failed to load chest_open_", i)
	
	# Load the 2 chest close sounds

	var sound_2 = load("res://Assets/SFX/chest_close_2.mp3")
	if sound_2:
		close_sounds.append(sound_2)



func play_random_open_sound():
	if open_sounds.size() > 0 and audio_player:
		var random_sound = open_sounds[randi() % open_sounds.size()]
		audio_player.stream = random_sound
		audio_player.play()

func play_random_close_sound():
	if close_sounds.size() > 0 and audio_player:
		var random_sound = close_sounds[randi() % close_sounds.size()]
		audio_player.stream = random_sound
		audio_player.play()


func _on_body_entered(body):
	if body.is_in_group("player"):
		nearby_player = body
		print("Press Click to open chest")

func _on_body_exited(body):
	if body == nearby_player:
		anim_player.play_backwards("lidAction")
		play_random_close_sound()
		nearby_player = null

func _input(event):
	if nearby_player and event.is_action_pressed("click"):
		anim_player.play("lidAction")
		play_random_open_sound()
		open_chest()

func open_chest():
	if chest_ui:
		play_random_open_sound()
		chest_ui.open_chest(self, nearby_player)

func get_inventory() -> Array:
	return chest_inventory

func save_chest_inventory():
	# Save to world manager
	if not WorldManager.current_world_data.has("chests"):
		WorldManager.current_world_data["chests"] = {}
	
	WorldManager.current_world_data["chests"][chest_id] = chest_inventory.duplicate(true)
	WorldManager.save_world()

func load_chest_inventory():
	if WorldManager.current_world_data.has("chests"):
		if WorldManager.current_world_data["chests"].has(chest_id):
			chest_inventory = WorldManager.current_world_data["chests"][chest_id].duplicate(true)
			print("Loaded chest inventory for: ", chest_id)
