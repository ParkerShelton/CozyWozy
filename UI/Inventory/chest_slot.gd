# chest_inventory_slot.gd (copying box_inventory_slot.gd pattern)
extends Panel

@onready var icon = $MarginContainer/TextureRect
@onready var quantity_label = $MarginContainer/Label

var empty_slot = preload("res://UI/Inventory/empty_slot.png")
var slot_index: int = 0
var slot_data: Dictionary = {}
var chest_ui: CanvasLayer = null  # Reference to parent UI

func set_slot_index(index: int):
	slot_index = index

func get_slot_data() -> Dictionary:
	return slot_data

func set_slot_data(data: Dictionary):
	slot_data = data
	update_visual()

func update_visual():
	if slot_data["item_name"] == "":
		icon.texture = empty_slot
		quantity_label.text = ""
	else:
		# Get icon from ItemManager (safest approach)
		var item_icon = ItemManager.get_item_icon(slot_data["item_name"])
		icon.texture = item_icon if item_icon else empty_slot
		quantity_label.text = str(int(slot_data["quantity"]))

func _can_drop_data(_at_position, data):
	return data is Dictionary and "item_name" in data

func _drop_data(_at_position, data):
	if not chest_ui:
		chest_ui = get_tree().get_first_node_in_group("chest_ui")
	
	# Handle different sources (copy box pattern exactly)
	if data["source"] == "inventory":
		chest_ui.transfer_from_inventory_to_chest(data["slot_index"], slot_index)
	elif data["source"] == "hotbar":
		chest_ui.transfer_from_hotbar_to_chest(data["slot_index"], slot_index)
	elif data["source"] == "chest":
		chest_ui.swap_chest_slots(data["slot_index"], slot_index)

func _get_drag_data(_at_position):
	if slot_data["item_name"] == "":
		return null
	
	# Get icon from ItemManager instead of slot_data
	var item_icon = ItemManager.get_item_icon(slot_data["item_name"])
	
	if not item_icon:
		return null
	
	var preview = TextureRect.new()
	preview.texture = item_icon
	preview.custom_minimum_size = Vector2(64, 64)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	set_drag_preview(preview)
	
	var drag_data = slot_data.duplicate()
	drag_data["source"] = "chest"
	drag_data["slot_index"] = slot_index
	drag_data["icon"] = item_icon  # Use the fresh icon
	
	return drag_data

# ADD THIS NEW FUNCTION
func _gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and Input.is_key_pressed(KEY_SHIFT):
			# Shift-click to quick transfer to inventory
			quick_transfer_to_inventory()

func quick_transfer_to_inventory():
	if slot_data["item_name"] == "":
		return
	
	if not chest_ui:
		chest_ui = get_tree().get_first_node_in_group("chest_ui")
	
	if not chest_ui or not chest_ui.current_chest:
		return
	
	# Try to add to inventory
	var item_icon = ItemManager.get_item_icon(slot_data["item_name"])
	var success = Inventory.add_item(slot_data["item_name"], item_icon, slot_data["quantity"])
	
	if success:
		# Remove from chest
		var chest_inventory = chest_ui.current_chest.get_inventory()
		chest_inventory[slot_index] = {"item_name": "", "quantity": 0, "icon": null}
		chest_ui.update_chest_display()
		print("Quick transferred ", slot_data["item_name"], " to inventory")
	else:
		print("Inventory full!")
