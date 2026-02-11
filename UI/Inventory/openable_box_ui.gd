# box_inventory_ui.gd - SIMPLIFIED VERSION
extends CanvasLayer

@onready var panel = $MarginContainer/Panel
@onready var box_name_label = $MarginContainer/Panel/MarginContainer/VBoxContainer/BoxNameLabel
@onready var box_grid = $MarginContainer/Panel/MarginContainer/VBoxContainer/ScrollContainer/BoxGridContainer
@onready var inventory_ui = $inventory  # Direct reference to inventory child
@onready var take_all_button = $MarginContainer/Panel/MarginContainer/VBoxContainer/TakeAllButton

var box_slot_scene = preload("res://UI/Inventory/box_inventory_slot.tscn")

var box_slot_nodes: Array = []

var is_closing: bool = false

func _ready():
	print("=== BOX INVENTORY UI READY ===")
	add_to_group("box_inventory_ui")
	
	# Start hidden
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Connect signals
	take_all_button.pressed.connect(_on_take_all_pressed)
	
	BoxInventoryManager.box_inventory_changed.connect(update_box_display)
	
	# Create box inventory slots
	for i in range(BoxInventoryManager.max_box_slots):
		var slot = box_slot_scene.instantiate()
		box_grid.add_child(slot)
		box_slot_nodes.append(slot)
		slot.set_slot_index(i)
		slot.box_ui = self  # Give slot reference to this UI

func open_box_ui(box_type: String):
	visible = true
	get_tree().paused = true
	
	# Set box name
	box_name_label.text = BoxInventoryManager.get_box_name(box_type)
	
	if inventory_ui:
		if inventory_ui is CanvasLayer:
			inventory_ui.layer = layer + 1
		
		inventory_ui.visible = true
	
	update_box_display()

func close_box_ui():
	# Hide the inventory
	if inventory_ui:
		inventory_ui.visible = false
	
	visible = false
	get_tree().paused = false
	BoxInventoryManager.close_box()

func update_box_display():
	for i in range(box_slot_nodes.size()):
		var slot_data = BoxInventoryManager.get_box_slot(i)
		box_slot_nodes[i].set_slot_data(slot_data)

func transfer_from_box_to_inventory(box_slot_index: int, inventory_slot_index: int):
	var box_item = BoxInventoryManager.get_box_slot(box_slot_index)
	
	if box_item["item_name"] == "":
		return
	
	var inventory_slot = Inventory.slots[inventory_slot_index]
	
	# If inventory slot is empty, just move the item
	if inventory_slot["item_name"] == "":
		Inventory.slots[inventory_slot_index] = box_item.duplicate()
		BoxInventoryManager.clear_box_slot(box_slot_index)
		Inventory.inventory_changed.emit()
	
	# If same item, stack them
	elif inventory_slot["item_name"] == box_item["item_name"]:
		inventory_slot["quantity"] += box_item["quantity"]
		BoxInventoryManager.clear_box_slot(box_slot_index)
		Inventory.inventory_changed.emit()
	
	# If different items, swap them
	else:
		var temp = inventory_slot.duplicate()
		Inventory.slots[inventory_slot_index] = box_item.duplicate()
		BoxInventoryManager.current_box_inventory[box_slot_index] = temp
		Inventory.inventory_changed.emit()
		BoxInventoryManager.box_inventory_changed.emit()

func _on_take_all_pressed():
	# Transfer all items from box to inventory
	for i in range(BoxInventoryManager.max_box_slots):
		var box_item = BoxInventoryManager.get_box_slot(i)
		
		if box_item["item_name"] != "":
			# Try to add to inventory
			var success = Inventory.add_item(
				box_item["item_name"],
				box_item["icon"],
				box_item["quantity"]
			)
			
			if success:
				BoxInventoryManager.clear_box_slot(i)
			else:
				print("Inventory full! Could not take all items.")
				break

func _input(event):
	if visible and event.is_action_pressed("inventory"):
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_method("show_inventory_left_section"):
			player.show_inventory_left_section()
		
		is_closing = true
		visible = false
		get_tree().paused = false
		BoxInventoryManager.close_box()
		
		# Hide the inventory
		if inventory_ui:
			inventory_ui.visible = false
		
		await get_tree().process_frame
		is_closing = false
