extends Panel

@onready var icon = $MarginContainer/TextureRect
@onready var quantity_label = $MarginContainer/Label

var audio_player: AudioStreamPlayer = null

var empty_slot = preload("res://UI/Inventory/empty_slot.png")
var slot_index : int = 0
var slot_data : Dictionary = {}
var is_dragging : bool = false
var drag_data : Dictionary = {}


func _ready():
	setup_audio()

func setup_audio():
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	
	var move_sound = load("res://Assets/SFX/move_item.wav")  # or .wav
	if move_sound:
		audio_player.stream = move_sound
		audio_player.volume_db = -10.0  # Adjust as needed
	else:
		push_error("✗ Failed to load move_item sound")
		
func _gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Check for shift+click
		if event.shift_pressed:
			shift_click_move()
		
func set_slot_index(index: int):
	slot_index = index

func set_slot_data(data: Dictionary):
	slot_data = data
	
	if slot_data["item_name"] == "":
		icon.texture = empty_slot
		quantity_label.text = ""
	else:
		# Get icon from ItemManager instead of slot_data
		var item_icon = ItemManager.get_item_icon(slot_data["item_name"])
		icon.texture = item_icon if item_icon else empty_slot
		quantity_label.text = str(int(slot_data["quantity"]))

func _get_drag_data(_at_position):
	if slot_data["item_name"] == "":
		return null
	
	# Get icon from ItemManager
	var item_icon = ItemManager.get_item_icon(slot_data["item_name"])
	
	if not item_icon:
		return null
	
	# Store drag data for potential drop
	drag_data = {
		"source": "inventory",
		"slot_index": slot_index,
		"item_name": slot_data["item_name"],
		"quantity": slot_data["quantity"],
		"icon": item_icon  # Use fresh icon from ItemManager
	}
	is_dragging = true
	
	var preview = TextureRect.new()
	preview.texture = item_icon  # Use fresh icon
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
	if audio_player and audio_player.stream:
		audio_player.play()
		
	if data["source"] == "inventory":
		swap_inventory_slots(data["slot_index"], slot_index)
	elif data["source"] == "hotbar":
		move_hotbar_to_inventory(data["slot_index"], slot_index)
	elif data["source"] == "box":
		move_box_to_inventory(data["slot_index"], slot_index)
	elif data["source"] == "chest":
		move_chest_to_inventory(data["slot_index"], slot_index)

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
	
	
	
func shift_click_move():
	# Don't move empty slots
	if slot_data["item_name"] == "":
		return
	
	# Play sound
	if audio_player and audio_player.stream:
		audio_player.play()
	
	# First check if chest is open
	var chest_ui = get_tree().get_first_node_in_group("chest_ui")
	if chest_ui and chest_ui.visible and chest_ui.current_chest:
		quick_transfer_to_chest()
		return
	
	# Then check if box is open
	var box_ui = get_tree().get_first_node_in_group("box_inventory_ui")
	if box_ui and box_ui.visible:
		quick_transfer_to_box()
		return
	
	# Get fresh icon from ItemManager
	var item_icon = ItemManager.get_item_icon(slot_data["item_name"])
	
	# Otherwise move to hotbar (original behavior)
	# Try to find an empty hotbar slot
	for i in range(Hotbar.max_hotbar_slots):
		var hotbar_slot = Hotbar.get_slot(i)
		
		if hotbar_slot["item_name"] == "":
			# Found empty slot - move item there
			Hotbar.set_slot(i, slot_data["item_name"], slot_data["quantity"], item_icon)  # Use item_icon
			
			# Clear inventory slot
			Inventory.slots[slot_index] = {"item_name": "", "quantity": 0, "icon": null}
			Inventory.inventory_changed.emit()
			
			print("Shift+clicked item to hotbar slot ", i)
			return
		
		elif hotbar_slot["item_name"] == slot_data["item_name"]:
			# Found matching item - try to stack
			Hotbar.set_slot(i, hotbar_slot["item_name"], hotbar_slot["quantity"] + slot_data["quantity"], item_icon)  # Use item_icon
			
			# Clear inventory slot
			Inventory.slots[slot_index] = {"item_name": "", "quantity": 0, "icon": null}
			Inventory.inventory_changed.emit()
			
			print("Shift+clicked item stacked to hotbar slot ", i)
			return
	
	print("No empty hotbar slots available!")

func quick_transfer_to_chest():
	if slot_data["item_name"] == "":
		return
	
	var chest_ui = get_tree().get_first_node_in_group("chest_ui")
	if not chest_ui or not chest_ui.current_chest:
		return
	
	var chest_inventory = chest_ui.current_chest.get_inventory()
	var item_icon = ItemManager.get_item_icon(slot_data["item_name"])
	
	# Try to stack with existing item first
	for i in range(chest_inventory.size()):
		if chest_inventory[i]["item_name"] == slot_data["item_name"]:
			chest_inventory[i]["quantity"] += slot_data["quantity"]
			Inventory.slots[slot_index] = {"item_name": "", "quantity": 0, "icon": null}
			Inventory.inventory_changed.emit()
			chest_ui.update_chest_display()
			print("Stacked ", slot_data["item_name"], " in chest")
			return
	
	# Find empty slot
	for i in range(chest_inventory.size()):
		if chest_inventory[i]["item_name"] == "":
			chest_inventory[i] = {
				"item_name": slot_data["item_name"],
				"quantity": slot_data["quantity"],
				"icon": item_icon
			}
			Inventory.slots[slot_index] = {"item_name": "", "quantity": 0, "icon": null}
			Inventory.inventory_changed.emit()
			chest_ui.update_chest_display()
			print("Moved ", slot_data["item_name"], " to chest")
			return
	
	print("Chest is full!")

func quick_transfer_to_box():
	if slot_data["item_name"] == "":
		return
	
	var box_ui = get_tree().get_first_node_in_group("box_inventory_ui")
	if not box_ui:
		return
	
	var item_icon = ItemManager.get_item_icon(slot_data["item_name"])
	
	# Try to stack with existing item first
	for i in range(BoxInventoryManager.max_box_slots):
		var box_slot = BoxInventoryManager.get_box_slot(i)
		if box_slot["item_name"] == slot_data["item_name"]:
			box_slot["quantity"] += slot_data["quantity"]
			Inventory.slots[slot_index] = {"item_name": "", "quantity": 0, "icon": null}
			Inventory.inventory_changed.emit()
			BoxInventoryManager.box_inventory_changed.emit()
			print("Stacked ", slot_data["item_name"], " in box")
			return
	
	# Find empty slot
	for i in range(BoxInventoryManager.max_box_slots):
		var box_slot = BoxInventoryManager.get_box_slot(i)
		if box_slot["item_name"] == "":
			BoxInventoryManager.current_box_inventory[i] = {
				"item_name": slot_data["item_name"],
				"quantity": slot_data["quantity"],
				"icon": item_icon
			}
			Inventory.slots[slot_index] = {"item_name": "", "quantity": 0, "icon": null}
			Inventory.inventory_changed.emit()
			BoxInventoryManager.box_inventory_changed.emit()
			print("Moved ", slot_data["item_name"], " to box")
			return
	
	print("Box is full!")
	
	
func move_box_to_inventory(box_slot: int, inventory_slot: int):
	var box_item = BoxInventoryManager.get_box_slot(box_slot).duplicate()
	var inventory_item = Inventory.slots[inventory_slot].duplicate()
	
	# If inventory slot is empty, move item
	if inventory_item["item_name"] == "":
		Inventory.slots[inventory_slot] = box_item
		BoxInventoryManager.clear_box_slot(box_slot)
		Inventory.inventory_changed.emit()
	
	# If same item, stack
	elif inventory_item["item_name"] == box_item["item_name"]:
		inventory_item["quantity"] += box_item["quantity"]
		Inventory.slots[inventory_slot] = inventory_item
		BoxInventoryManager.clear_box_slot(box_slot)
		Inventory.inventory_changed.emit()
	
	# Different items, swap
	else:
		Inventory.slots[inventory_slot] = box_item
		BoxInventoryManager.current_box_inventory[box_slot] = inventory_item
		Inventory.inventory_changed.emit()
		BoxInventoryManager.box_inventory_changed.emit()
		
		
func move_chest_to_inventory(chest_slot_index: int, inventory_slot_index: int):
	var chest_ui = get_tree().get_first_node_in_group("chest_ui")
	if not chest_ui or not chest_ui.current_chest:
		return
	
	var chest_inventory = chest_ui.current_chest.get_inventory()
	var chest_item = chest_inventory[chest_slot_index]
	
	if chest_item["item_name"] == "":
		return
	
	var inventory_slot = Inventory.slots[inventory_slot_index]
	
	# If inventory slot is empty, just move the item
	if inventory_slot["item_name"] == "":
		Inventory.slots[inventory_slot_index] = chest_item.duplicate()
		chest_inventory[chest_slot_index] = {"item_name": "", "quantity": 0, "icon": null}
		Inventory.inventory_changed.emit()
		chest_ui.update_chest_display()
	
	# If same item, stack them
	elif inventory_slot["item_name"] == chest_item["item_name"]:
		inventory_slot["quantity"] += chest_item["quantity"]
		chest_inventory[chest_slot_index] = {"item_name": "", "quantity": 0, "icon": null}
		Inventory.inventory_changed.emit()
		chest_ui.update_chest_display()
	
	# If different items, swap them
	else:
		var temp = inventory_slot.duplicate()
		Inventory.slots[inventory_slot_index] = chest_item.duplicate()
		chest_inventory[chest_slot_index] = temp
		Inventory.inventory_changed.emit()
		chest_ui.update_chest_display()
