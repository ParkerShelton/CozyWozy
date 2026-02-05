extends CanvasLayer

@onready var grid_container = $Panel/HBoxContainer/RightPanel/ScrollContainer/GridContainer
@onready var recipe_name_label = $Panel/HBoxContainer/LeftPanel/VBoxContainer/RecipeName
@onready var ingredients_container = $Panel/HBoxContainer/LeftPanel/VBoxContainer/ScrollContainer/VBoxContainer
@onready var craft_button = $Panel/HBoxContainer/LeftPanel/VBoxContainer/MarginContainer/CraftButton

var recipe_icon_scene = preload("res://UI/Building_Menu/recipe_button.tscn")

var selected_recipe: Dictionary = {}  # Changed from Recipe to Dictionary
var available_stations: Array = []

func _ready():
	craft_button.pressed.connect(_on_craft_pressed)
	craft_button.disabled = true
	visible = false
	
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	print("Building menu ready!")

func open_menu():
	visible = true
	get_tree().paused = true
	populate_recipes()
	clear_details()

func close_menu():
	visible = false
	get_tree().paused = false

func set_available_stations(stations: Array):
	available_stations = stations
	print("Available stations: ", available_stations)
	
	if visible:
		populate_recipes()

func populate_recipes():
	print("=== POPULATE RECIPES ===")
	print("Available stations: ", available_stations)
	
	# Clear old recipe icons
	for child in grid_container.get_children():
		child.queue_free()
	
	# Get player's items from inventory + hotbar
	var inventory_items = Inventory.get_items_as_dict()
	var hotbar_items = Hotbar.get_items_as_dict()
	
	# Combine them
	var all_items = inventory_items.duplicate()
	for item_name in hotbar_items:
		if all_items.has(item_name):
			all_items[item_name] += hotbar_items[item_name]
		else:
			all_items[item_name] = hotbar_items[item_name]
	
	# Get ALL recipes from ItemManager
	var all_recipes = ItemManager.get_all_recipes()
	var available_recipes = []
	
	# Filter recipes based on available crafting stations
	for recipe_data in all_recipes:
		if ItemManager.has_prerequisites(recipe_data, available_stations):
			available_recipes.append(recipe_data)
	
	print("Available recipes: ", available_recipes.size())
	
	# Create UI icons for each available recipe
	for recipe_data in available_recipes:
		# Check if player can craft it
		var can_craft = ItemManager.can_craft_recipe(recipe_data, all_items)
		
		# Create the icon button
		var icon_btn = recipe_icon_scene.instantiate()
		grid_container.add_child(icon_btn)
		icon_btn.setup(recipe_data, can_craft)
		icon_btn.recipe_selected.connect(_on_recipe_selected)
	
	print("=== END POPULATE ===")

func _on_recipe_selected(recipe_data: Dictionary):  # Changed from Recipe to Dictionary
	selected_recipe = recipe_data
	display_recipe_details(recipe_data)

func display_recipe_details(recipe_data: Dictionary):  # Changed from Recipe to Dictionary
	# Set recipe name
	var item_name = recipe_data.get("recipe_name", "Unknown")
	recipe_name_label.text = ItemManager.get_item_name(item_name)
	
	# Clear previous ingredients
	for child in ingredients_container.get_children():
		child.queue_free()
	
	# Get combined inventory
	var inventory_items = Inventory.get_items_as_dict()
	var hotbar_items = Hotbar.get_items_as_dict()
	var all_items = inventory_items.duplicate()
	for item_name_key in hotbar_items:
		if all_items.has(item_name_key):
			all_items[item_name_key] += hotbar_items[item_name_key]
		else:
			all_items[item_name_key] = hotbar_items[item_name_key]
	
	# Show ingredients
	var ingredients = recipe_data.get("ingredients", [])
	for ingredient in ingredients:
		var ingredient_name = ingredient["item"]
		var required = ingredient["amount"]
		var current = all_items.get(ingredient_name, 0)
		
		var label = Label.new()
		var display_name = ItemManager.get_item_name(ingredient_name)
		
		if current >= required:
			label.text = "%s: %d/%d ✓" % [display_name, current, required]
			label.modulate = Color.GREEN
		else:
			label.text = "%s: %d/%d ✗" % [display_name, current, required]
			label.modulate = Color.RED
		
		ingredients_container.add_child(label)
	
	# Enable/disable craft button
	craft_button.disabled = not ItemManager.can_craft_recipe(recipe_data, all_items)

func clear_details():
	recipe_name_label.text = "Select a recipe"
	for child in ingredients_container.get_children():
		child.queue_free()
	craft_button.disabled = true

func _on_craft_pressed():
	if selected_recipe and selected_recipe.size() > 0:  # Check dictionary is not empty
		craft_recipe(selected_recipe)
		# Refresh after crafting
		populate_recipes()
		if selected_recipe and selected_recipe.size() > 0:
			display_recipe_details(selected_recipe)

func craft_recipe(recipe_data: Dictionary):
	print("Crafting: ", recipe_data["recipe_name"])
	
	# Check prerequisites (stations)
	var player = get_tree().get_first_node_in_group("player")
	if player:
		if not ItemManager.has_prerequisites(recipe_data, player.nearby_crafting_stations):
			print("❌ Missing required crafting station!")
			return
	
	# Get player's items again
	var inventory_items = Inventory.get_items_as_dict()
	var hotbar_items = Hotbar.get_items_as_dict()
	var all_items = inventory_items.duplicate()
	for item_name in hotbar_items:
		if all_items.has(item_name):
			all_items[item_name] += hotbar_items[item_name]
		else:
			all_items[item_name] = hotbar_items[item_name]
	
	# Check if player has materials
	if not ItemManager.can_craft_recipe(recipe_data, all_items):
		print("❌ Not enough materials!")
		return
	
	# REMOVE INGREDIENTS from inventory/hotbar
	for ingredient in recipe_data["ingredients"]:
		var item_name = ingredient["item"]
		var amount_needed = ingredient["amount"]
		
		# Remove from inventory first
		for slot in Inventory.slots:
			if slot["item_name"] == item_name and amount_needed > 0:
				var remove_amount = min(slot["quantity"], amount_needed)
				slot["quantity"] -= remove_amount
				amount_needed -= remove_amount
				
				if slot["quantity"] <= 0:
					slot["item_name"] = ""
					slot["quantity"] = 0
					slot["icon"] = null
		
		# Then remove from hotbar if needed
		if amount_needed > 0:
			for i in range(Hotbar.max_hotbar_slots):
				var slot = Hotbar.get_slot(i)
				if slot["item_name"] == item_name and amount_needed > 0:
					var remove_amount = min(slot["quantity"], amount_needed)
					slot["quantity"] -= remove_amount
					amount_needed -= remove_amount
					
					if slot["quantity"] <= 0:
						Hotbar.clear_slot(i)
					else:
						Hotbar.set_slot(i, slot["item_name"], slot["quantity"], slot["icon"])
		
		Inventory.inventory_changed.emit()
	
	# ADD CRAFTED ITEM to inventory
	var item_n = recipe_data["recipe_name"]
	var item_icon = ItemManager.get_item_icon(item_n)
	
	if Inventory.add_item(item_n, item_icon, 1):
		print("✓ Crafted: ", item_n)
	else:
		print("❌ Inventory full!")
	
	# Refresh the UI
	populate_recipes()

func _input(_event):
	if Input.is_action_just_pressed("building_menu"):
		print("Building menu key pressed! Visible: ", visible)
		if visible:
			close_menu()
		else:
			open_menu()




func open_station(station_name, nearby_player):
	print("OPENED " + station_name)
