extends Control

@onready var create_button = $VBoxContainer/CreateButton
@onready var join_button = $VBoxContainer/JoinButton
@onready var start_single_button = $VBoxContainer/StartSingleButton
@onready var status_label = $VBoxContainer/StatusLabel

func _ready():
	create_button.pressed.connect(_on_create_pressed)
	join_button.pressed.connect(_on_join_pressed)
	start_single_button.pressed.connect(_on_single_pressed)
	
	# Connect Network signals
	Network.lobby_created_success.connect(_on_lobby_created)
	Network.lobby_joined_success.connect(_on_lobby_joined)
	Network.player_connected.connect(_on_player_connected)
	
	status_label.text = "Welcome, " + Steam.getPersonaName()

func _on_create_pressed():
	status_label.text = "Creating lobby..."
	create_button.disabled = true
	join_button.disabled = true
	Network.create_lobby()

func _on_join_pressed():
	status_label.text = "Searching for lobbies..."
	
	# Request lobby list
	Network.request_lobby_list()
	
	# Wait for results
	await get_tree().create_timer(2.0).timeout
	
	# Check if we got any lobbies
	print("Opening lobby browser...")
	get_tree().change_scene_to_file("res://UI/Multiplayer/lobby_browser.tscn")

func _on_single_pressed():
	get_tree().change_scene_to_file("res://UI/main_menu/world_choice.tscn")

func _on_lobby_created(lobby_id: int):
	status_label.text = "✓ Lobby Created! (You are HOST)\nLobby ID: " + str(lobby_id) + "\n\nWaiting for players to join..."
	print("UI: I AM THE HOST - Lobby created with ID ", lobby_id)

func _on_lobby_joined(lobby_id: int):
	status_label.text = "✓ Joined Lobby!\nLobby ID: " + str(lobby_id)
	print("UI: I AM A CLIENT - Joined lobby with ID ", lobby_id)
	
	# CLIENT LOADS GAME IMMEDIATELY!
	status_label.text += "\n\n🎮 Loading game..."
	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://Scenes/main.tscn")

func _on_player_connected(steam_id: int, player_name: String):
	status_label.text += "\n✓ " + player_name + " joined"
	
	# HOST LOADS GAME WHEN CLIENT JOINS
	if Network.is_host:
		status_label.text += "\n\n🎮 Starting game in 2 seconds..."
		await get_tree().create_timer(2.0).timeout
		get_tree().change_scene_to_file("res://Scenes/main.tscn")
	
	# CLIENT ALSO LOADS GAME!
	elif not Network.is_host and Network.player_list.size() >= 2:
		status_label.text += "\n\n🎮 Host is starting..."
		await get_tree().create_timer(2.0).timeout
		get_tree().change_scene_to_file("res://Scenes/main.tscn")

func start_game():
	print("UI: Starting game...")
	
	# If we're the host, send world seed to clients FIRST
	if Network.is_host:
		print("I AM HOST - Broadcasting world seed BEFORE loading")
		var world_seed = WorldManager.get_world_seed()
		if world_seed == 0:
			world_seed = randi()
			WorldManager.current_world_data["world_seed"] = world_seed
		
		Network.broadcast_to_all({
			"type": "world_seed",
			"seed": world_seed
		}, true)
		print("Host broadcasting world seed: ", world_seed)
		
		# Host loads immediately
		get_tree().change_scene_to_file("res://Scenes/main.tscn")
	else:
		# Client waits for seed (will load in _on_world_seed_received)
		print("I AM CLIENT - Waiting for world seed from host")
		status_label.text = "Waiting for world seed from host..."

func _on_world_seed_received(seed: int):
	"""Called when client receives world seed from host"""
	print("✓ Received world seed: ", seed, " - NOW loading game!")
	
	# Set the seed
	WorldManager.current_world_data["world_seed"] = seed
	
	# NOW load the game
	get_tree().change_scene_to_file("res://Scenes/main.tscn")
