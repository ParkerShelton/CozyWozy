extends Node

# Lobby settings
var lobby_id: int = 0
var lobby_max_members: int = 4

# Network state
var is_host: bool = false
var player_list: Dictionary = {}  # {steam_id: player_name}

# Authority-based resource tracking
var next_resource_id: int = 0
var spawned_resources: Array = []  # [{id, type, position, scene_path}, ...]

var steam_initialized: bool = false

# Signals
signal lobby_created_success(lobby_id: int)
signal lobby_joined_success(lobby_id: int)
signal player_connected(steam_id: int, player_name: String)
signal lobby_match_list(lobbies: Array)
signal world_state_received(resources: Array)

func _ready():
	print("=== STEAM INITIALIZATION ===")
	
	# Try to initialize Steam (returns bool)
	var init_success: bool = Steam.steamInit()
	
	if not init_success:
		print("⚠️ Steam initialization failed!")
		steam_initialized = false
		return
	
	steam_initialized = true
	print("✓ Steam initialized!")
	print("  Steam ID: ", Steam.getSteamID())
	print("  Username: ", Steam.getPersonaName())
	
	# Connect Steam callbacks
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_match_list.connect(_on_lobby_match_list)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.lobby_chat_update.connect(_on_lobby_chat_update)
	Steam.p2p_session_request.connect(_on_p2p_session_request)

func _process(_delta):
	Steam.run_callbacks()
	read_p2p_packets()

# ========== LOBBY MANAGEMENT ==========

func create_lobby():
	print("Creating lobby...")
	is_host = true
	Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, lobby_max_members)

func join_lobby(lobby_to_join: int):
	print("Joining lobby: ", lobby_to_join)
	is_host = false
	Steam.joinLobby(lobby_to_join)

func request_lobby_list():
	print("Requesting lobby list...")
	Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
	Steam.requestLobbyList()

# ========== STEAM CALLBACKS ==========

func _on_lobby_created(result: int, created_lobby_id: int):
	if result == 1:
		lobby_id = created_lobby_id
		print("✓ Lobby created successfully! ID: ", lobby_id)
		
		var my_steam_id = Steam.getSteamID()
		var my_name = Steam.getPersonaName()
		player_list[my_steam_id] = my_name
		
		Steam.setLobbyData(lobby_id, "name", my_name + "'s Game")
		
		lobby_created_success.emit(lobby_id)
	else:
		print("✗ Failed to create lobby. Error: ", result)

func _on_lobby_match_list(lobbies: Array):
	print("=== LOBBY LIST RECEIVED ===")
	print("Found ", lobbies.size(), " lobbies")
	
	for i in range(lobbies.size()):
		var lobby_id = lobbies[i]
		var lobby_name = Steam.getLobbyData(lobby_id, "name")
		var num_members = Steam.getNumLobbyMembers(lobby_id)
		print("  [", i, "] ", lobby_name, " - ", num_members, " players (ID: ", lobby_id, ")")
	
	print("===========================")
	lobby_match_list.emit(lobbies)

func _on_lobby_joined(joined_lobby_id: int, _permissions: int, _locked: bool, response: int):
	if lobby_id == joined_lobby_id and is_host:
		print("⚠️ Ignoring join callback - we created this lobby!")
		return
	
	if response == 1:
		lobby_id = joined_lobby_id
		print("✓ Successfully joined lobby: ", lobby_id)
		
		var num_members = Steam.getNumLobbyMembers(lobby_id)
		print("Lobby has ", num_members, " members:")
		
		for i in range(num_members):
			var member_id = Steam.getLobbyMemberByIndex(lobby_id, i)
			var member_name = Steam.getFriendPersonaName(member_id)
			player_list[member_id] = member_name
			print("  - ", member_name, " (", member_id, ")")
		
		lobby_joined_success.emit(lobby_id)
	else:
		print("✗ Failed to join lobby. Error: ", response)

func _on_lobby_chat_update(changed_lobby_id: int, changed_id: int, making_change_id: int, chat_state: int):
	if changed_lobby_id != lobby_id:
		return
	
	var changer_name = Steam.getFriendPersonaName(making_change_id)
	
	if chat_state == Steam.CHAT_MEMBER_STATE_CHANGE_ENTERED:
		var joiner_name = Steam.getFriendPersonaName(changed_id)
		print(joiner_name, " joined the lobby")
		player_list[changed_id] = joiner_name
		player_connected.emit(changed_id, joiner_name)
	
	elif chat_state == Steam.CHAT_MEMBER_STATE_CHANGE_LEFT:
		print(changer_name, " left the lobby")
		player_list.erase(changed_id)
	
	elif chat_state == Steam.CHAT_MEMBER_STATE_CHANGE_DISCONNECTED:
		print(changer_name, " disconnected")
		player_list.erase(changed_id)

func _on_p2p_session_request(remote_steam_id: int):
	var requester_name = Steam.getFriendPersonaName(remote_steam_id)
	print("P2P session request from: ", requester_name)
	Steam.acceptP2PSessionWithUser(remote_steam_id)

# ========== P2P PACKET HANDLING ==========

func send_p2p_packet(target_steam_id: int, packet_data: Dictionary, reliable: bool = true):
	var json_string = JSON.stringify(packet_data)
	var send_type = Steam.P2P_SEND_RELIABLE if reliable else Steam.P2P_SEND_UNRELIABLE
	
	var packet_bytes = json_string.to_utf8_buffer()
	Steam.sendP2PPacket(target_steam_id, packet_bytes, send_type)

func broadcast_to_all(packet_data: Dictionary, reliable: bool = true):
	for steam_id in player_list.keys():
		if steam_id != Steam.getSteamID():
			send_p2p_packet(steam_id, packet_data, reliable)

func read_p2p_packets():
	var packet_size = Steam.getAvailableP2PPacketSize(0)
	
	while packet_size > 0:
		var packet = Steam.readP2PPacket(packet_size, 0)
		
		if packet.is_empty() or not packet.has("data"):
			packet_size = Steam.getAvailableP2PPacketSize(0)
			continue
		
		var packet_data = packet["data"]
		var from_peer = packet["remote_steam_id"]
		
		var json = JSON.new()
		var parse_result = json.parse(packet_data.get_string_from_utf8())
		
		if parse_result == OK:
			var data = json.data
			handle_packet(data, from_peer)
		
		packet_size = Steam.getAvailableP2PPacketSize(0)

# ========== PACKET ROUTING ==========

func handle_packet(data: Dictionary, from_peer: int):
	if not data.has("type"):
		return
	
	var packet_type = data["type"]
	
	match packet_type:
		"world_state":
			handle_world_state(data)
		
		"player_state":
			handle_player_state(data, from_peer)
		
		"resource_destroyed":
			handle_resource_destroyed(data)
		
		"item_spawned":
			handle_item_spawned(data)


# ========== AUTHORITY-BASED RESOURCE TRACKING ==========

func register_resource(resource_node: Node3D, resource_type: String, scene_path: String):
	"""Host calls this when spawning a resource to track it"""
	if not is_host:
		return
	
	var resource_id = next_resource_id
	next_resource_id += 1
	
	var resource_data = {
		"id": resource_id,
		"type": resource_type,
		"position": {"x": resource_node.global_position.x, "y": resource_node.global_position.y, "z": resource_node.global_position.z},
		"scene_path": scene_path
	}
	spawned_resources.append(resource_data)
	
	resource_node.set_meta("resource_id", resource_id)
	
	return resource_id

func send_world_state_to_client(client_steam_id: int):
	"""Send all existing resources to a newly joined client"""
	if not is_host:
		return
	
	print("🌍 Sending world state to client (", spawned_resources.size(), " resources)")
	
	var packet = {
		"type": "world_state",
		"resources": spawned_resources
	}
	
	send_p2p_packet(client_steam_id, packet, true)

func handle_world_state(data: Dictionary):
	"""Client receives full world state from host"""
	var resources = data.get("resources", [])
	
	print("🌍 Received world state: ", resources.size(), " resources")
	
	world_state_received.emit(resources)

# ========== RESOURCE DESTRUCTION SYNC ==========

func broadcast_resource_destroyed(resource_id: int, resource_type: String):
	"""Host broadcasts that a resource was destroyed"""
	if not is_host:
		return
	
	for i in range(spawned_resources.size() - 1, -1, -1):
		if spawned_resources[i]["id"] == resource_id:
			spawned_resources.remove_at(i)
			break
	
	var packet = {
		"type": "resource_destroyed",
		"resource_id": resource_id,
		"resource_type": resource_type
	}
	
	print("🌲 Broadcasting resource destruction: #", resource_id, " (", resource_type, ")")
	broadcast_to_all(packet, true)

func handle_resource_destroyed(data: Dictionary):
	"""Receives notification that a resource was destroyed"""
	var resource_id = data.get("resource_id", -1)
	var resource_type = data.get("resource_type", "")
	
	print("🌲 Received resource destruction: #", resource_id, " (", resource_type, ")")
	
	destroy_resource_by_id(resource_id, resource_type)

func destroy_resource_by_id(resource_id: int, resource_type: String):
	"""Finds a resource by ID and destroys it"""
	var resources = get_tree().get_nodes_in_group(resource_type)
	
	for resource in resources:
		var res_id = resource.get_meta("resource_id", -1)
		
		if res_id == resource_id:
			print("✓ Found resource to destroy: ", resource.name, " (ID: ", resource_id, ")")
			
			if resource.has_method("destroy_without_drops"):
				resource.destroy_without_drops()
			else:
				resource.queue_free()
			return
	
	print("⚠️ Could not find resource with ID ", resource_id)

# ========== ITEM DROP SYNC ==========

func broadcast_item_spawned(item_name: String, position: Vector3, quantity: int = 1):
	"""Broadcast that an item was spawned in the world"""
	var packet = {
		"type": "item_spawned",
		"item_name": item_name,
		"position": {"x": position.x, "y": position.y, "z": position.z},
		"quantity": quantity
	}
	
	broadcast_to_all(packet, true)

func handle_item_spawned(data: Dictionary):
	"""Receive notification that an item was spawned"""
	var item_name = data.get("item_name", "")
	var pos_dict = data.get("position", {})
	var position = Vector3(pos_dict.x, pos_dict.y, pos_dict.z)
	var quantity = data.get("quantity", 1)
	
	spawn_item_drop(item_name, position, quantity)

func spawn_item_drop(item_name: String, position: Vector3, quantity: int):
	"""Actually spawn an item drop in the world"""
	var dropped_item_scene = load("res://Scenes/dropped_item.tscn")
	var item_icon = ItemManager.get_item_icon(item_name)
	
	if not dropped_item_scene or not item_icon:
		return
	
	var item_drop = dropped_item_scene.instantiate()
	get_tree().root.add_child(item_drop)
	item_drop.global_position = position
	
	if item_drop.has_method("setup"):
		item_drop.setup(item_name, quantity, item_icon, false)

# ========== PLAYER STATE SYNC ==========

func broadcast_player_state(position: Vector3, rotation: float):
	"""Send our player state to all other players"""
	var packet = {
		"type": "player_state",
		"position": {"x": position.x, "y": position.y, "z": position.z},
		"rotation": rotation
	}
	
	broadcast_to_all(packet, false)

func handle_player_state(data: Dictionary, from_peer: int):
	"""Receive another player's state update"""
	var pos_data = data.get("position", {})
	var position = Vector3(pos_data.x, pos_data.y, pos_data.z)
	var rotation = data.get("rotation", 0.0)
	
	var remote_players = get_tree().get_nodes_in_group("remote_player")
	
	for remote_player in remote_players:
		if remote_player.steam_id == from_peer:
			remote_player.global_position = position
			remote_player.rotation.y = rotation
			return
	
	spawn_remote_player(from_peer, position, rotation)

func spawn_remote_player(steam_id: int, position: Vector3, rotation: float):
	"""Spawn a remote player representation"""
	var remote_player_scene = load("res://Scenes/remote_player.tscn")
	if not remote_player_scene:
		return
	
	var remote_player = remote_player_scene.instantiate()
	get_tree().root.add_child(remote_player)
	remote_player.add_to_group("remote_player")
	remote_player.steam_id = steam_id
	remote_player.global_position = position
	remote_player.rotation.y = rotation
	
	var player_name = player_list.get(steam_id, "Unknown")
	print("Spawned remote player: ", player_name)
