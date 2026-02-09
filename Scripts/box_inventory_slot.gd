extends Panel

@onready var icon = $MarginContainer/TextureRect
@onready var quantity_label = $MarginContainer/Label

var empty_slot = preload("res://UI/Inventory/empty_slot.png")
var slot_index : int = 0
var slot_data : Dictionary = {}
var is_dragging : bool = false
var drag_data : Dictionary = {}
var box_ui = null  # Reference to the box UI
var audio_player: AudioStreamPlayer = null

func _ready():
	setup_audio()

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if event.shift_pressed:
				shift_click_move()

func shift_click_move():
	if slot_data["item_name"] == "":
		return
	
	var item_name = slot_data["item_name"]
	var quantity = slot_data["quantity"]
	icon = slot_data["icon"]
	
	# Try to add to inventory
	var success = Inventory.add_item(item_name, icon, quantity)
	
	if success:
		# Play sound
		if audio_player and audio_player.stream:
			audio_player.play()
		
		# Clear the box slot
		BoxInventoryManager.clear_box_slot(slot_index)
		print("Shift+clicked ", item_name, " from box to inventory")
	else:
		print("Inventory full! Cannot transfer.")

func setup_audio():
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	
	var move_sound = load("res://Assets/SFX/move_item.wav")
	if move_sound:
		audio_player.stream = move_sound
		audio_player.volume_db = -10.0
	else:
		push_error("✗ Failed to load move_item sound")

func set_slot_index(index: int):
	slot_index = index

func set_slot_data(data: Dictionary):
	slot_data = data
	
	if not icon or not quantity_label:
		return
	
	if slot_data["item_name"] == "":
		icon.texture = empty_slot
		quantity_label.text = ""
	else:
		icon.texture = slot_data["icon"]
		quantity_label.text = str(int(slot_data["quantity"]))

func _get_drag_data(_at_position):
	if slot_data["item_name"] == "":
		return null
	
	drag_data = {
		"source": "box",
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

func _can_drop_data(_at_position, data):
	return data is Dictionary and ("source" in data)

func _drop_data(_at_position, data):
	if audio_player and audio_player.stream:
		audio_player.play()
	
	if data["source"] == "inventory":
		transfer_inventory_to_box(data["slot_index"], slot_index)
	elif data["source"] == "hotbar":
		transfer_hotbar_to_box(data["slot_index"], slot_index)
	elif data["source"] == "box":
		swap_box_slots(data["slot_index"], slot_index)

func transfer_inventory_to_box(inventory_slot: int, box_slot: int):
	var inventory_item = Inventory.slots[inventory_slot].duplicate()
	var box_item = BoxInventoryManager.get_box_slot(box_slot)
	
	if box_item["item_name"] == "":
		BoxInventoryManager.current_box_inventory[box_slot] = inventory_item
		Inventory.slots[inventory_slot] = {"item_name": "", "quantity": 0, "icon": null}
		BoxInventoryManager.box_inventory_changed.emit()
		Inventory.inventory_changed.emit()
	elif box_item["item_name"] == inventory_item["item_name"]:
		box_item["quantity"] += inventory_item["quantity"]
		BoxInventoryManager.current_box_inventory[box_slot] = box_item
		Inventory.slots[inventory_slot] = {"item_name": "", "quantity": 0, "icon": null}
		BoxInventoryManager.box_inventory_changed.emit()
		Inventory.inventory_changed.emit()
	else:
		BoxInventoryManager.current_box_inventory[box_slot] = inventory_item
		Inventory.slots[inventory_slot] = box_item
		BoxInventoryManager.box_inventory_changed.emit()
		Inventory.inventory_changed.emit()

func transfer_hotbar_to_box(hotbar_slot: int, box_slot: int):
	var hotbar_item = Hotbar.get_slot(hotbar_slot).duplicate()
	var box_item = BoxInventoryManager.get_box_slot(box_slot)
	
	if box_item["item_name"] == "":
		BoxInventoryManager.current_box_inventory[box_slot] = hotbar_item
		Hotbar.clear_slot(hotbar_slot)
		BoxInventoryManager.box_inventory_changed.emit()
	elif box_item["item_name"] == hotbar_item["item_name"]:
		box_item["quantity"] += hotbar_item["quantity"]
		BoxInventoryManager.current_box_inventory[box_slot] = box_item
		Hotbar.clear_slot(hotbar_slot)
		BoxInventoryManager.box_inventory_changed.emit()
	else:
		BoxInventoryManager.current_box_inventory[box_slot] = hotbar_item
		Hotbar.set_slot(hotbar_slot, box_item["item_name"], box_item["quantity"], box_item["icon"])
		BoxInventoryManager.box_inventory_changed.emit()

func swap_box_slots(from_slot: int, to_slot: int):
	var from_data = BoxInventoryManager.get_box_slot(from_slot).duplicate()
	var to_data = BoxInventoryManager.get_box_slot(to_slot).duplicate()
	
	BoxInventoryManager.current_box_inventory[to_slot] = from_data
	BoxInventoryManager.current_box_inventory[from_slot] = to_data
	BoxInventoryManager.box_inventory_changed.emit()
