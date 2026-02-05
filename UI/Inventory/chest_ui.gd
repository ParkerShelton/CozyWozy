# chest_ui.gd
extends CanvasLayer

@onready var panel = $chest_inventory/Panel
@onready var chest_grid = $chest_inventory/Panel/VBoxContainer/GridContainer
@onready var inventory_ui = $inventory

var chest_slot_scene = preload("res://UI/Inventory/chest_slot.tscn")

var chest_slot_nodes: Array = []
var current_chest: Node3D = null
var current_player: Node3D = null

var is_closing: bool = false

func _ready():
	print("=== CHEST UI READY ===")
	add_to_group("chest_ui")
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Create chest slots
	for i in range(28):
		var slot = chest_slot_scene.instantiate()
		chest_grid.add_child(slot)
		slot.set_slot_index(i)
		slot.chest_ui = self  # Give slot reference to this UI
		chest_slot_nodes.append(slot)

func open_chest(chest: Node3D, player: Node3D):
	current_chest = chest
	current_player = player
	
	visible = true
	get_tree().paused = true
	
	# Show the inventory child
	if inventory_ui:
		if inventory_ui is CanvasLayer:
			inventory_ui.layer = layer + 1
		
		inventory_ui.visible = true
	
	# Update chest display
	update_chest_display()

func close_chest():
	if current_chest:
		current_chest.save_chest_inventory()
	
	# Hide the inventory
	if inventory_ui:
		inventory_ui.visible = false
	
	visible = false
	get_tree().paused = false
	
	current_chest = null
	current_player = null
	
	await get_tree().process_frame
	is_closing = false








func update_chest_display():
	if not current_chest:
		return
	
	var chest_inventory = current_chest.get_inventory()
	
	for i in range(chest_slot_nodes.size()):
		chest_slot_nodes[i].set_slot_data(chest_inventory[i])

# Transfer functions (copied from box_inventory_ui.gd)
func transfer_from_inventory_to_chest(inventory_slot_index: int, chest_slot_index: int):
	var inventory_item = Inventory.slots[inventory_slot_index]
	
	if inventory_item["item_name"] == "":
		return
	
	var chest_inventory = current_chest.get_inventory()
	var chest_slot = chest_inventory[chest_slot_index]
	
	# If chest slot is empty, just move the item
	if chest_slot["item_name"] == "":
		chest_inventory[chest_slot_index] = inventory_item.duplicate()
		Inventory.slots[inventory_slot_index] = {"item_name": "", "quantity": 0, "icon": null}
		Inventory.inventory_changed.emit()
	
	# If same item, stack them
	elif chest_slot["item_name"] == inventory_item["item_name"]:
		chest_slot["quantity"] += inventory_item["quantity"]
		Inventory.slots[inventory_slot_index] = {"item_name": "", "quantity": 0, "icon": null}
		Inventory.inventory_changed.emit()
	
	# If different items, swap them
	else:
		var temp = chest_slot.duplicate()
		chest_inventory[chest_slot_index] = inventory_item.duplicate()
		Inventory.slots[inventory_slot_index] = temp
		Inventory.inventory_changed.emit()
	
	update_chest_display()

func transfer_from_hotbar_to_chest(hotbar_slot_index: int, chest_slot_index: int):
	var hotbar_item = Hotbar.get_slot(hotbar_slot_index)
	
	if hotbar_item["item_name"] == "":
		return
	
	var chest_inventory = current_chest.get_inventory()
	var chest_slot = chest_inventory[chest_slot_index]
	
	# If chest slot is empty, just move the item
	if chest_slot["item_name"] == "":
		chest_inventory[chest_slot_index] = hotbar_item.duplicate()
		Hotbar.clear_slot(hotbar_slot_index)
	
	# If same item, stack them
	elif chest_slot["item_name"] == hotbar_item["item_name"]:
		chest_slot["quantity"] += hotbar_item["quantity"]
		Hotbar.clear_slot(hotbar_slot_index)
	
	# If different items, swap them
	else:
		var temp = chest_slot.duplicate()
		chest_inventory[chest_slot_index] = hotbar_item.duplicate()
		Hotbar.set_slot(hotbar_slot_index, temp["item_name"], temp["quantity"], temp["icon"])
	
	update_chest_display()

func swap_chest_slots(from_slot_index: int, to_slot_index: int):
	var chest_inventory = current_chest.get_inventory()
	
	var temp = chest_inventory[to_slot_index].duplicate()
	chest_inventory[to_slot_index] = chest_inventory[from_slot_index].duplicate()
	chest_inventory[from_slot_index] = temp
	
	update_chest_display()

func _input(event):
	if visible and event.is_action_pressed("inventory"):
		is_closing = true
		close_chest()
