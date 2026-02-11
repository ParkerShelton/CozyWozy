# shield_slot.gd
extends Panel

@onready var icon = $MarginContainer/TextureRect

var empty_slot = preload("res://UI/icons/shield.png")
var slot_data: Dictionary = {"item_name": "", "quantity": 0, "icon": null} 

signal shield_equipped(shield_name: String)
signal shield_unequipped

func set_slot_data(data: Dictionary):
	slot_data = data
	update_visual()

func update_visual():
	if slot_data["item_name"] == "":
		icon.texture = empty_slot
	else:
		var item_icon = ItemManager.get_item_icon(slot_data["item_name"])
		icon.texture = item_icon if item_icon else empty_slot

func _can_drop_data(_at_position, data):
	if not (data is Dictionary and "item_name" in data):
		return false
	
	# Only accept shields
	var item_type = ItemManager.get_item_type(data["item_name"])
	return item_type == "shield"

func _drop_data(_at_position, data):
	# If shield slot already has a shield, swap with source
	if slot_data["item_name"] != "":
		# Swap shields
		swap_with_source(data)
	else:
		# Move shield to this slot
		move_to_shield_slot(data)
	
	# Emit signal to equip shield
	shield_equipped.emit(slot_data["item_name"])

func swap_with_source(data: Dictionary):
	var temp_shield = slot_data.duplicate()
	
	# Put incoming shield in this slot
	slot_data = {
		"item_name": data["item_name"],
		"quantity": 1,
		"icon": ItemManager.get_item_icon(data["item_name"])
	}
	
	# Put old shield back to source
	if data["source"] == "inventory":
		Inventory.slots[data["slot_index"]] = temp_shield
		Inventory.inventory_changed.emit()
	elif data["source"] == "hotbar":
		Hotbar.set_slot(data["slot_index"], temp_shield["item_name"], temp_shield["quantity"], temp_shield["icon"])
	
	update_visual()

func move_to_shield_slot(data: Dictionary):
	# Move shield to this slot
	slot_data = {
		"item_name": data["item_name"],
		"quantity": 1,
		"icon": ItemManager.get_item_icon(data["item_name"])
	}
	
	# Clear from source
	if data["source"] == "inventory":
		Inventory.slots[data["slot_index"]] = {"item_name": "", "quantity": 0, "icon": null}
		Inventory.inventory_changed.emit()
	elif data["source"] == "hotbar":
		Hotbar.clear_slot(data["slot_index"])
	
	update_visual()

func _get_drag_data(_at_position):
	if slot_data["item_name"] == "":
		return null
	
	var item_icon = ItemManager.get_item_icon(slot_data["item_name"])
	
	var preview = TextureRect.new()
	preview.texture = item_icon
	preview.custom_minimum_size = Vector2(64, 64)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	set_drag_preview(preview)
	
	var drag_data = slot_data.duplicate()
	drag_data["source"] = "shield_slot"
	drag_data["icon"] = item_icon
	
	slot_data = {"item_name": "", "quantity": 0, "icon": null}
	update_visual()
	
	# Unequip shield when dragging out
	shield_unequipped.emit()
	
	return drag_data

func clear_slot():
	slot_data = {"item_name": "", "quantity": 0, "icon": null}
	update_visual()
	shield_unequipped.emit()
