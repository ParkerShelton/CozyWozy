extends Panel

@onready var icon = $MarginContainer/TextureRect
@onready var quantity_label = $MarginContainer/Label

var empty_slot = preload("res://UI/Inventory/empty_slot.png")
var slot_index : int = 0
var slot_data : Dictionary = {}
var is_dragging : bool = false
var drag_data : Dictionary = {}

func set_slot_index(index: int):
	slot_index = index

func set_slot_data(data: Dictionary):
	slot_data = data
	
	if slot_data["item_name"] == "":
		icon.texture = empty_slot
		quantity_label.text = ""
	else:
		icon.texture = slot_data["icon"]
		quantity_label.text = str(int(slot_data["quantity"]))

func _get_drag_data(_at_position):
	if slot_data["item_name"] == "":
		return null
	
	# Store drag data for potential drop
	drag_data = {
		"source": "inventory",
		"slot_index": slot_index,
		"item_name": slot_data["item_name"],
		"quantity": slot_data["quantity"],
		"icon": slot_data["icon"]
	}
	is_dragging = true
	
	var preview = TextureRect.new()
	preview.texture = slot_data["icon"]
	preview.custom_minimum_size = Vector2(64, 64)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	set_drag_preview(preview)
	
	return drag_data

func _notification(what):
	# Detect when drag ends
	if what == NOTIFICATION_DRAG_END:
		if is_dragging:
			# Check if drag was successful (landed on valid drop target)
			if not get_viewport().gui_is_drag_successful():
				# Drag failed - drop item in world
				drop_item_in_world()
			is_dragging = false

func drop_item_in_world():
	print("=== DROP ITEM IN WORLD ===")
	
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		print("ERROR: Player not found!")
		return
	
	# Always use generic dropped item with sprite
	var dropped_item_scene = load("res://Scenes/dropped_item.tscn")
	
	if dropped_item_scene:
		var dropped_item = dropped_item_scene.instantiate()
		get_tree().root.add_child(dropped_item)
		
		var spawn_pos = player.global_position + Vector3(randf_range(-1, 1), 0.5, randf_range(-1, 1))
		dropped_item.global_position = spawn_pos
		
		if dropped_item.has_method("setup"):
			dropped_item.setup(drag_data["item_name"], drag_data["quantity"], drag_data["icon"], true)
		
		print("Dropped ", drag_data["item_name"], " in world")
	else:
		print("ERROR: Could not load dropped_item scene!")
	
	# Clear inventory slot (or hotbar slot depending on which script this is)
	Inventory.slots[slot_index] = {"item_name": "", "quantity": 0, "icon": null}
	Inventory.inventory_changed.emit()

func _can_drop_data(_at_position, data):
	return data is Dictionary and ("source" in data)

func _drop_data(_at_position, data):
	if data["source"] == "inventory":
		swap_inventory_slots(data["slot_index"], slot_index)
	elif data["source"] == "hotbar":
		move_hotbar_to_inventory(data["slot_index"], slot_index)

func swap_inventory_slots(from_slot: int, to_slot: int):
	var temp = Inventory.slots[from_slot].duplicate()
	Inventory.slots[from_slot] = Inventory.slots[to_slot].duplicate()
	Inventory.slots[to_slot] = temp
	Inventory.inventory_changed.emit()

func move_hotbar_to_inventory(hotbar_slot: int, inventory_slot: int):
	var hotbar_data = Hotbar.get_slot(hotbar_slot).duplicate()
	var inventory_data = Inventory.slots[inventory_slot].duplicate()
	
	Inventory.slots[inventory_slot] = {
		"item_name": hotbar_data["item_name"],
		"quantity": hotbar_data["quantity"],
		"icon": hotbar_data["icon"]
	}
	
	Hotbar.set_slot(hotbar_slot, inventory_data["item_name"], inventory_data["quantity"], inventory_data["icon"])
	
	Inventory.inventory_changed.emit()
