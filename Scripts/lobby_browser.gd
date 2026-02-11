extends Control

@onready var lobby_list_container = $VBoxContainer/ScrollContainer/LobbyListContainer
@onready var status_label = $VBoxContainer/StatusLabel
@onready var refresh_button = $VBoxContainer/HBoxContainer/RefreshButton
@onready var back_button = $VBoxContainer/HBoxContainer/BackButton

func _ready():
	refresh_button.pressed.connect(_on_refresh_pressed)
	back_button.pressed.connect(_on_back_pressed)
	
	# Connect to network signal
	Network.lobby_match_list.connect(_on_lobby_list_received)
	
	# Request lobbies immediately
	refresh_lobbies()

func refresh_lobbies():
	status_label.text = "Searching for lobbies..."
	
	# Clear old lobbies
	for child in lobby_list_container.get_children():
		child.queue_free()
	
	# ADD DISTANCE FILTER TO GET FRESH RESULTS
	Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
	
	# Request new list
	Network.request_lobby_list()

func _on_lobby_list_received(lobbies: Array):
	print("Lobby browser received ", lobbies.size(), " lobbies")
	
	status_label.text = "Found " + str(lobbies.size()) + " lobbies"
	
	# Clear old buttons
	for child in lobby_list_container.get_children():
		child.queue_free()
	
	# Create button for each lobby
	for lobby_id in lobbies:
		var lobby_name = Steam.getLobbyData(lobby_id, "name")
		var num_members = Steam.getNumLobbyMembers(lobby_id)
		
		var button = Button.new()
		button.text = lobby_name + " - " + str(num_members) + "/4 players"
		button.pressed.connect(_on_lobby_selected.bind(lobby_id))
		
		lobby_list_container.add_child(button)

func _on_lobby_selected(lobby_id: int):
	print("Joining lobby: ", lobby_id)
	Network.join_lobby(lobby_id)
	
	# Go back to multiplayer menu to see connection status
	get_tree().change_scene_to_file("res://UI/Multiplayer/multipayer_menu.tscn")

func _on_refresh_pressed():
	refresh_lobbies()

func _on_back_pressed():
	get_tree().change_scene_to_file("res://UI/Multiplayer/multipayer_menu.tscn")
