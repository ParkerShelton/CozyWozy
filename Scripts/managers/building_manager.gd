# building_manager.gd (Autoload)
extends Node

const BUILDING_PIECES_FILE = "res://Data/building_pieces.json"
var building_pieces: Dictionary = {}

# Snap settings
var snap_distance: float = 0.5  # How close to snap point before snapping
var grid_size: float = 1.0  # Grid cell size for free placement

func _ready():
	load_building_pieces()

func load_building_pieces():
	if not FileAccess.file_exists(BUILDING_PIECES_FILE):
		push_error("Building pieces file not found: " + BUILDING_PIECES_FILE)
		return
	
	var file = FileAccess.open(BUILDING_PIECES_FILE, FileAccess.READ)
	if file == null:
		push_error("Failed to open building pieces file")
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_error("Failed to parse building pieces JSON")
		return
	
	building_pieces = json.data

# Get building piece data
func get_piece_data(piece_name: String) -> Dictionary:
	return building_pieces.get(piece_name, {})

# Get all pieces of a category
func get_pieces_by_category(category: String) -> Array:
	var result = []
	for piece_name in building_pieces.keys():
		var piece = building_pieces[piece_name]
		if piece.get("category", "") == category:
			result.append({
				"name": piece_name,
				"data": piece
			})
	return result

# Get all categories
func get_all_categories() -> Array:
	var categories = []
	for piece_name in building_pieces.keys():
		var category = building_pieces[piece_name].get("category", "")
		if category != "" and not categories.has(category):
			categories.append(category)
	return categories

# Check if piece can be crafted
func can_craft_piece(piece_name: String, available_items: Dictionary) -> bool:
	var piece_data = get_piece_data(piece_name)
	if piece_data.is_empty():
		return false
	
	var recipe = piece_data.get("recipe", {})
	var ingredients = recipe.get("ingredients", [])
	
	for ingredient in ingredients:
		var item_name = ingredient.get("item", "")
		var amount_needed = ingredient.get("amount", 0)
		
		if not available_items.has(item_name):
			return false
		if available_items[item_name] < amount_needed:
			return false
	
	return true
