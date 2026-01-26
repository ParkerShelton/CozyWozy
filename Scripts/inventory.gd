extends Node

var slots : Array = []
var max_slots : int = 28
# Signal to notify UI when inventory changes
signal inventory_changed

func _ready():
	# Initialize empty slots
	for i in range(max_slots):
		slots.append({"item_name": "", "quantity": 0, "icon": null})

func add_item(item_name: String, icon: Texture2D, amount: int = 1) -> bool:
	for i in range(Hotbar.max_hotbar_slots):
		var hotbar_slot = Hotbar.get_slot(i)
		
		if hotbar_slot["item_name"] == item_name:
			var new_quantity = hotbar_slot["quantity"] + amount
			# Use Hotbar.set_slot to actually update it
			Hotbar.set_slot(i, hotbar_slot["item_name"], new_quantity, hotbar_slot["icon"])
			inventory_changed.emit()
			return true
	
	# Then try to stack with existing item in INVENTORY
	for slot in slots:
		if slot["item_name"] == item_name:
			slot["quantity"] += amount
			inventory_changed.emit()
			return true
	
	# Find empty slot in INVENTORY
	for slot in slots:
		if slot["item_name"] == "":
			slot["item_name"] = item_name
			slot["quantity"] = amount
			slot["icon"] = icon
			inventory_changed.emit()
			return true
	
	print("Inventory full!")
	return false

func remove_item(item_name: String, amount: int = 1) -> bool:
	for slot in slots:
		if slot["item_name"] == item_name and slot["quantity"] >= amount:
			slot["quantity"] -= amount
			if slot["quantity"] <= 0:
				slot["item_name"] = ""
				slot["quantity"] = 0
				slot["icon"] = null
			inventory_changed.emit()
			return true
	return false

func get_item_count(item_name: String) -> int:
	var count = 0
	for slot in slots:
		if slot["item_name"] == item_name:
			count += slot["quantity"]
	return count

func get_items_as_dict() -> Dictionary:
	var items_dict = {}
	for slot in slots:
		if slot["item_name"] != "":
			if items_dict.has(slot["item_name"]):
				items_dict[slot["item_name"]] += slot["quantity"]
			else:
				items_dict[slot["item_name"]] = slot["quantity"]
	return items_dict
	
