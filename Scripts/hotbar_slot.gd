extends Panel

@onready var icon = $TextureRect
@onready var quantity_label = $Label
@onready var highlight = $highlight

var empty_slot = preload("res://UI/Inventory/empty_slot.png")
var slot_index : int = 0
var is_dragging : bool = false
var drag_data : Dictionary = {}

func set_slot_index(index: int):
	slot_index = index

func set_slot_data(slot_data: Dictionary):
	if slot_data["item_name"] == "":
		icon.texture = empty_slot
		quantity_label.text = ""
	else:
		icon.texture = slot_data["icon"]
		quantity_label.text = str(slot_data["quantity"])

func set_selected(is_selected: bool):
	highlight.visible = is_selected
	if is_selected:
		modulate = Color(1.2, 1.2, 1.2)
	else:
		modulate = Color.WHITE

func _get_drag_data(_at_position):
	var slot_data = Hotbar.get_slot(slot_index)
	
	if slot_data["item_name"] == "":
		return null
	
	# Store drag data for potential drop
	drag_data = {
		"source": "hotbar",
		"slot_index": slot_index,
		"item_name": slot_data["item_name"],
		"quantity": slot_data["quantity"],
		"icon": slot_data["icon"]
	}
	is_dragging = true
	
	# Create preview
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
	
	# Clear hotbar slot
	Hotbar.clear_slot(slot_index)

func _can_drop_data(_at_position, data):
	return data is Dictionary and ("source" in data)

func _drop_data(_at_position, data):
	if data["source"] == "inventory":
		move_inventory_to_hotbar(data["slot_index"], slot_index)
	elif data["source"] == "hotbar":
		swap_hotbar_slots(data["slot_index"], slot_index)

func move_inventory_to_hotbar(inventory_slot: int, hotbar_slot: int):
	var inventory_data = Inventory.slots[inventory_slot].duplicate()
	var hotbar_data = Hotbar.get_slot(hotbar_slot).duplicate()
	
	Hotbar.set_slot(hotbar_slot, inventory_data["item_name"], inventory_data["quantity"], inventory_data["icon"])
	
	Inventory.slots[inventory_slot] = {
		"item_name": hotbar_data["item_name"],
		"quantity": hotbar_data["quantity"],
		"icon": hotbar_data["icon"]
	}
	
	Inventory.inventory_changed.emit()

func swap_hotbar_slots(from_slot: int, to_slot: int):
	var from_data = Hotbar.get_slot(from_slot)
	var to_data = Hotbar.get_slot(to_slot)
	
	Hotbar.set_slot(to_slot, from_data["item_name"], from_data["quantity"], from_data["icon"])
	Hotbar.set_slot(from_slot, to_data["item_name"], to_data["quantity"], to_data["icon"])
