extends Control

@onready var grid_container = $inventory_container/GridContainer  # GridContainer to hold slots
var slot_scene = preload("res://UI/Inventory/inventory_slot.tscn")

var slot_nodes : Array = []

func _ready():
	# Create slot UI elements
	for i in range(Inventory.max_slots):
		var slot = slot_scene.instantiate()
		grid_container.add_child(slot)
		slot_nodes.append(slot)
		slot.set_slot_index(i)  # IMPORTANT: Set the index
	
	# Connect to inventory changes
	Inventory.inventory_changed.connect(update_display)
	update_display()

func update_display():
	for i in range(Inventory.slots.size()):
		slot_nodes[i].set_slot_data(Inventory.slots[i])
