extends Node

var hotbar_slots : Array = []
var max_hotbar_slots : int = 10
var selected_slot : int = 0  # Currently selected slot (0-9)

signal hotbar_changed
signal selected_slot_changed(slot_index)

func _ready():
	# Initialize empty hotbar slots
	for i in range(max_hotbar_slots):
		hotbar_slots.append({"item_name": "", "quantity": 0, "icon": null})

func set_slot(slot_index: int, item_name: String, quantity: int, icon: Texture2D):
	if slot_index >= 0 and slot_index < max_hotbar_slots:
		hotbar_slots[slot_index]["item_name"] = item_name
		hotbar_slots[slot_index]["quantity"] = quantity
		hotbar_slots[slot_index]["icon"] = icon
		hotbar_changed.emit()

func get_slot(slot_index: int) -> Dictionary:
	if slot_index >= 0 and slot_index < max_hotbar_slots:
		return hotbar_slots[slot_index]
	return {"item_name": "", "quantity": 0, "icon": null}

func clear_slot(slot_index: int):
	if slot_index >= 0 and slot_index < max_hotbar_slots:
		hotbar_slots[slot_index] = {"item_name": "", "quantity": 0, "icon": null}
		hotbar_changed.emit()

func select_slot(slot_index: int):
	if slot_index >= 0 and slot_index < max_hotbar_slots:
		selected_slot = slot_index
		selected_slot_changed.emit(slot_index)

func get_selected_item() -> Dictionary:
	return hotbar_slots[selected_slot]

func use_selected_item():
	var item = get_selected_item()
	if item["item_name"] != "":
		# Decrease quantity
		item["quantity"] -= 1
		if item["quantity"] <= 0:
			clear_slot(selected_slot)
		else:
			hotbar_changed.emit()
		return item
	return null

func get_items_as_dict() -> Dictionary:
	var items_dict = {}
	for slot in hotbar_slots:
		if slot["item_name"] != "":
			if items_dict.has(slot["item_name"]):
				items_dict[slot["item_name"]] += slot["quantity"]
			else:
				items_dict[slot["item_name"]] = slot["quantity"]
	return items_dict
	
	
	
func has_item(item_name: String) -> bool:
	for slot in hotbar_slots:
		if slot["item_name"] == item_name and slot["quantity"] > 0:
			return true
	return false

func remove_item(item_name: String, amount: int = 1) -> bool:
	for i in range(max_hotbar_slots):
		if hotbar_slots[i]["item_name"] == item_name and hotbar_slots[i]["quantity"] >= amount:
			hotbar_slots[i]["quantity"] -= amount
			if hotbar_slots[i]["quantity"] <= 0:
				clear_slot(i)
			else:
				hotbar_changed.emit()
			return true
	return false
