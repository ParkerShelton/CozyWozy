extends Panel

@onready var icon = $TextureRect
@onready var quantity_label = $Label
@onready var highlight = $highlight

var audio_player: AudioStreamPlayer = null

var empty_slot = preload("res://UI/Inventory/empty_slot.png")
var slot_index : int = 0
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
	if audio_player and audio_player.stream:
		audio_player.play()
	
	if data["source"] == "inventory":
		move_inventory_to_hotbar(data["slot_index"], slot_index)
	elif data["source"] == "hotbar":
		swap_hotbar_slots(data["slot_index"], slot_index)
	elif data["source"] == "box":
		move_box_to_hotbar(data["slot_index"], slot_index)
		
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



func shift_click_move():
	var slot_data = Hotbar.get_slot(slot_index)
	
	# Don't move empty slots
	if slot_data["item_name"] == "":
		return
	
	# Play sound
	if audio_player and audio_player.stream:
		audio_player.play()
	
	# Try to find matching item in inventory first (for stacking)
	for i in range(Inventory.slots.size()):
		var inv_slot = Inventory.slots[i]
		
		if inv_slot["item_name"] == slot_data["item_name"]:
			# Found matching item - stack it
			inv_slot["quantity"] += slot_data["quantity"]
			Inventory.inventory_changed.emit()
			
			# Clear hotbar slot
			Hotbar.clear_slot(slot_index)
			
			print("Shift+clicked item stacked to inventory slot ", i)
			return
	
	# No matching items - find empty slot
	for i in range(Inventory.slots.size()):
		var inv_slot = Inventory.slots[i]
		
		if inv_slot["item_name"] == "":
			# Found empty slot - move item there
			Inventory.slots[i] = {
				"item_name": slot_data["item_name"],
				"quantity": slot_data["quantity"],
				"icon": slot_data["icon"]
			}
			Inventory.inventory_changed.emit()
			
			# Clear hotbar slot
			Hotbar.clear_slot(slot_index)
			
			print("Shift+clicked item to inventory slot ", i)
			return
	
	print("Inventory is full!")
	
	
func move_box_to_hotbar(box_slot: int, hotbar_slot: int):
	var box_item = BoxInventoryManager.get_box_slot(box_slot).duplicate()
	var hotbar_item = Hotbar.get_slot(hotbar_slot).duplicate()
	
	# If hotbar slot is empty, move item
	if hotbar_item["item_name"] == "":
		Hotbar.set_slot(hotbar_slot, box_item["item_name"], box_item["quantity"], box_item["icon"])
		BoxInventoryManager.clear_box_slot(box_slot)
	
	# If same item, stack
	elif hotbar_item["item_name"] == box_item["item_name"]:
		Hotbar.set_slot(hotbar_slot, hotbar_item["item_name"], hotbar_item["quantity"] + box_item["quantity"], hotbar_item["icon"])
		BoxInventoryManager.clear_box_slot(box_slot)
	
	# Different items, swap
	else:
		Hotbar.set_slot(hotbar_slot, box_item["item_name"], box_item["quantity"], box_item["icon"])
		BoxInventoryManager.current_box_inventory[box_slot] = hotbar_item
		BoxInventoryManager.box_inventory_changed.emit()
