# chest.gd
extends Node3D

@export var chest_id: String = ""  # Unique ID for this chest
@export var max_slots: int = 28  # Same as player inventory

var nearby_player: Node3D = null
var chest_inventory: Array = []
var chest_ui: CanvasLayer = null

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
	
	var area = $Area3D
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	
	# Get reference to chest UI
	await get_tree().process_frame
	chest_ui = get_tree().get_first_node_in_group("chest_ui")
	print(chest_ui)

func _on_body_entered(body):
	if body.is_in_group("player"):
		anim_player.play("lidAction")
		nearby_player = body
		print("Press Click to open chest")

func _on_body_exited(body):
	if body == nearby_player:
		anim_player.play_backwards("lidAction")
		nearby_player = null

func _input(event):
	if nearby_player and event.is_action_pressed("click"):		
		open_chest()

func open_chest():
	
	if chest_ui:
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
