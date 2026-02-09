# item_manager.gd
extends Node

const ITEMS_FILE = "res://Data/items.json"
var items: Dictionary = {}

func _ready():
	load_items()

# ========== LOADING ==========

func load_items():
	if not FileAccess.file_exists(ITEMS_FILE):
		push_error("Items file not found: " + ITEMS_FILE)
		return
	
	var file = FileAccess.open(ITEMS_FILE, FileAccess.READ)
	if file == null:
		push_error("Failed to open items file")
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_error("Failed to parse items JSON")
		return
	
	items = json.data
	print("✓ Loaded ", items.size(), " items from JSON")

# ========== ITEM DATA ==========

# Get all data for an item
func get_item_data(item_name: String) -> Dictionary:
	if items.has(item_name):
		return items[item_name]
	return {}

# Get item display name
func get_item_name(item_name: String) -> String:
	var data = get_item_data(item_name)
	return data.get("name", item_name)

# Get item type (weapon, tool, resource, building, seed)
func get_item_type(item_name: String) -> String:
	var data = get_item_data(item_name)
	return data.get("type", "")

# Get item damage value
func get_item_damage(item_name: String) -> float:
	var data = get_item_data(item_name)
	return data.get("damage", 0.0)

# Get item icon texture
func get_item_icon(item_name: String):
	var data = get_item_data(item_name)
	var icon_path = data.get("icon", "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		return load(icon_path)
	return null

# Check if item exists
func item_exists(item_name: String) -> bool:
	return items.has(item_name)

func get_item_description(item_name: String) -> String:
	if items.has(item_name):
		return items[item_name].get("description", "")
	return ""

# Get food value from item
func get_food_value(item_name: String) -> float:
	var data = get_item_data(item_name)
	return data.get("food_value", 0.0)

# Check if item is food
func is_food(item_name: String) -> bool:
	return get_food_value(item_name) > 0.0


# ========== RECIPE DATA ==========

# Check if an item has a crafting recipe
func has_recipe(item_name: String) -> bool:
	var data = get_item_data(item_name)
	return data.has("recipe")

# Get recipe data for an item (returns Dictionary)
func get_recipe(item_name: String) -> Dictionary:
	var data = get_item_data(item_name)
	if data.has("recipe"):
		var recipe = data["recipe"].duplicate()
		recipe["recipe_name"] = item_name
		recipe["item_type"] = data.get("type", "")
		return recipe
	return {}

# Get ALL craftable items (returns Array of recipe Dictionaries)
func get_all_recipes() -> Array:
	var recipes = []
	for item_name in items.keys():
		if has_recipe(item_name):
			recipes.append(get_recipe(item_name))
	return recipes

# ========== MODEL LOGIC ============
func has_model(item_name: String) -> bool:
	var data = get_item_data(item_name)
	return data.has("model")
	
func get_model(item_name: String) -> PackedScene:
	var data = get_item_data(item_name)
	return load(data.get("model"))


# ========== CRAFTING LOGIC ==========

# Check if player has enough materials to craft a recipe
func can_craft_recipe(recipe_data: Dictionary, available_items: Dictionary) -> bool:
	var ingredients = recipe_data.get("ingredients", [])
	
	for ingredient in ingredients:
		var item_name = ingredient["item"]
		var amount_needed = ingredient["amount"]
		
		# Check if player has enough
		if not available_items.has(item_name):
			return false
		if available_items[item_name] < amount_needed:
			return false
	
	return true

# Check if player has required crafting stations
func has_prerequisites(recipe_data: Dictionary, available_stations: Array) -> bool:
	var prerequisites = recipe_data.get("prerequisites", [])
	
	# No prerequisites needed - always craftable
	if prerequisites.size() == 0:
		return true
	
	# Check if player has ANY of the required stations
	for prereq in prerequisites:
		if prereq in available_stations:
			return true
	
	return false

# Check if item can be placed in world
func is_placeable(item_name: String) -> bool:
	var item_data = get_item_data(item_name)
	return item_data.get("placeable", false)
