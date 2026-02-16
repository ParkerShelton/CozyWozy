# box_inventory_manager.gd
extends Node

var item_categories: Dictionary = {
	"gun": ["basic_pistol"],
	"melee": ["bat", "knife", "crowbar", "machete"],
	"ammo": ["pistol_ammo", "shotgun_shells", "rifle_ammo"],
}

# Loot table configuration - item names must match items.json
var loot_tables: Dictionary = {
	"scavenger_crate": {
		"name": "Savenger Crate",
		"min_items": 2,
		"max_items": 4,
		"loot_table": [
			{"item": "log", "weight": 50, "min_amount": 1, "max_amount": 3},
			{"item": "plant_fiber", "weight": 40, "min_amount": 2, "max_amount": 5},
			{"item": "pebble", "weight": 35, "min_amount": 3, "max_amount": 6},
			{"item": "iron", "weight": 20, "min_amount": 1, "max_amount": 2},
			{"item": "electrical_component", "weight": 15, "min_amount": 1, "max_amount": 3}
		]
	},
	"broken_car": {
		"name": "Broken Car",
		"min_items": 3,
		"max_items": 5,
		"loot_table": [
			{"item": "rubber", "weight": 20, "min_amount": 2, "max_amount": 4},
			{"item": "pebble", "weight": 35, "min_amount": 3, "max_amount": 6},
			{"item": "iron", "weight": 20, "min_amount": 1, "max_amount": 2},
			{"item": "electrical_component", "weight": 15, "min_amount": 1, "max_amount": 3}
		]
	},
	"drawer": {
		"name": "Drawer",
		"min_items": 3,
		"max_items": 5,
		"loot_table": [
			{"item": "rubber", "weight": 20, "min_amount": 2, "max_amount": 4},
			{"item": "pebble", "weight": 35, "min_amount": 3, "max_amount": 6},
			{"item": "iron", "weight": 20, "min_amount": 1, "max_amount": 2},
			{"item": "electrical_component", "weight": 15, "min_amount": 1, "max_amount": 3},
			{"category": "gun", "weight": 2, "min_amount": 1, "max_amount": 1},
		]
	},
}

# Currently opened box data
var current_box_type: String = ""
var current_box_inventory: Array = []  # {item_name: String, quantity: int, icon: Texture2D}
var max_box_slots: int = 12

signal box_inventory_changed

# ========== LOOT GENERATION ==========

func generate_box_loot(box_type: String) -> Array:
	if not loot_tables.has(box_type):
		push_error("Unknown box type: " + box_type)
		return []
	
	var loot_config = loot_tables[box_type]
	var loot_table = loot_config.get("loot_table", [])
	var min_items = loot_config.get("min_items", 1)
	var max_items = loot_config.get("max_items", 3)
	
	var num_items = randi_range(min_items, max_items)
	var generated_loot: Array = []
	
	for i in range(num_items):
		var selected_item = select_weighted_item(loot_table)
		if selected_item:
			# Resolve the actual item name
			var item_name = resolve_item(selected_item)
			if item_name == "":
				continue
			
			var amount = randi_range(
				selected_item.get("min_amount", 1),
				selected_item.get("max_amount", 1)
			)
			
			var icon = ItemManager.get_item_icon(item_name)
			
			if icon:
				generated_loot.append({
					"item_name": item_name,
					"quantity": amount,
					"icon": icon
				})
	
	return generated_loot

func select_weighted_item(loot_table: Array) -> Dictionary:
	if loot_table.is_empty():
		return {}
	
	# Calculate total weight
	var total_weight = 0
	for item in loot_table:
		total_weight += item.get("weight", 1)
	
	# Random selection based on weight
	var roll = randf() * total_weight
	var current_weight = 0
	
	for item in loot_table:
		current_weight += item.get("weight", 1)
		if roll <= current_weight:
			return item
	
	# Fallback to first item
	return loot_table[0]

# ========== BOX INVENTORY MANAGEMENT ==========

func open_box(box_type: String):
	current_box_type = box_type
	current_box_inventory.clear()
	
	# Generate loot for this box
	var loot = generate_box_loot(box_type)
	
	# Fill inventory slots (limited to max_box_slots)
	for item in loot:
		if current_box_inventory.size() < max_box_slots:
			current_box_inventory.append(item)
	
	# Fill remaining slots with empty slots
	while current_box_inventory.size() < max_box_slots:
		current_box_inventory.append({"item_name": "", "quantity": 0, "icon": null})
	
	box_inventory_changed.emit()

func close_box():
	current_box_type = ""
	current_box_inventory.clear()
	box_inventory_changed.emit()

func get_box_slot(slot_index: int) -> Dictionary:
	if slot_index >= 0 and slot_index < current_box_inventory.size():
		return current_box_inventory[slot_index]
	return {"item_name": "", "quantity": 0, "icon": null}

func clear_box_slot(slot_index: int):
	if slot_index >= 0 and slot_index < current_box_inventory.size():
		current_box_inventory[slot_index] = {"item_name": "", "quantity": 0, "icon": null}
		box_inventory_changed.emit()

func is_box_empty() -> bool:
	for slot in current_box_inventory:
		if slot["item_name"] != "":
			return false
	return true

# ========== LOOT TABLE QUERIES ==========

func get_box_name(box_type: String) -> String:
	if loot_tables.has(box_type):
		return loot_tables[box_type].get("name", box_type)
	return box_type

func box_type_exists(box_type: String) -> bool:
	return loot_tables.has(box_type)
	
	
	
func resolve_item(loot_entry: Dictionary) -> String:
	# Direct item
	if loot_entry.has("item"):
		return loot_entry["item"]
	
	# Category - pick a random item from that category
	if loot_entry.has("category"):
		var category = loot_entry["category"]
		if item_categories.has(category):
			var options = item_categories[category]
			if options.size() > 0:
				return options[randi() % options.size()]
	
	return ""
