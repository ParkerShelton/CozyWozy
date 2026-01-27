extends Control

@onready var grid_container = $Panel/HBoxContainer/RightPanel/ScrollContainer/GridContainer
@onready var recipe_name_label = $Panel/HBoxContainer/LeftPanel/VBoxContainer/RecipeName
@onready var ingredients_container = $Panel/HBoxContainer/LeftPanel/VBoxContainer/ScrollContainer/VBoxContainer
@onready var craft_button = $Panel/HBoxContainer/LeftPanel/VBoxContainer/MarginContainer/CraftButton

var recipe_icon_scene = preload("res://UI/Building_Menu/recipe_button.tscn")

var selected_recipe : Recipe = null
var available_stations : Array = []

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

func populate_recipes():
	print("=== POPULATE RECIPES ===")
	
	# Clear existing icons
	for child in grid_container.get_children():
		child.queue_free()
	
	# Get combined inventory
	var inventory_items = Inventory.get_items_as_dict()
	var hotbar_items = Hotbar.get_items_as_dict()
	var all_items = inventory_items.duplicate()
	for item_name in hotbar_items:
		if all_items.has(item_name):
			all_items[item_name] += hotbar_items[item_name]
		else:
			all_items[item_name] = hotbar_items[item_name]
	
	# Get all recipes that match available stations
	var available_recipes = []
	
	for recipe in RecipeManager.get_all_recipes():
		# No prerequisites - always available
		if recipe.prerequisites.size() == 0:
			available_recipes.append(recipe)
		# Has prerequisites - check if we're near the right station
		else:
			for prereq in recipe.prerequisites:
				if prereq in available_stations:
					available_recipes.append(recipe)
					break
	
	print("Available recipes count: ", available_recipes.size())
	
	for recipe in available_recipes:
		var can_craft = recipe.can_craft(all_items)
		
		if not recipe_icon_scene:
			print("ERROR: recipe_icon_scene not assigned!")
			return
		
		var icon_btn = recipe_icon_scene.instantiate()
		grid_container.add_child(icon_btn)
		icon_btn.setup(recipe, can_craft)
		icon_btn.recipe_selected.connect(_on_recipe_selected)
	
	print("=== END POPULATE ===")

func _on_recipe_selected(recipe: Recipe):
	selected_recipe = recipe
	display_recipe_details(recipe)

func display_recipe_details(recipe: Recipe):
	# Set recipe name
	recipe_name_label.text = recipe.recipe_name
	
	# Clear previous ingredients
	for child in ingredients_container.get_children():
		child.queue_free()
	
	# Get combined inventory
	var inventory_items = Inventory.get_items_as_dict()
	var hotbar_items = Hotbar.get_items_as_dict()
	var all_items = inventory_items.duplicate()
	for item_name in hotbar_items:
		if all_items.has(item_name):
			all_items[item_name] += hotbar_items[item_name]
		else:
			all_items[item_name] = hotbar_items[item_name]
	
	# Show ingredients
	for ingredient in recipe.ingredients:
		var item_name = ingredient["item"]
		var required = ingredient["amount"]
		var current = all_items.get(item_name, 0)
		
		var label = Label.new()
		if current >= required:
			label.text = "%s: %d/%d ✓" % [item_name, current, required]
			label.modulate = Color.GREEN
		else:
			label.text = "%s: %d/%d ✗" % [item_name, current, required]
			label.modulate = Color.RED
		
		ingredients_container.add_child(label)
	
	# Enable/disable craft button
	craft_button.disabled = not recipe.can_craft(all_items)

func clear_details():
	recipe_name_label.text = "Select a recipe"
	for child in ingredients_container.get_children():
		child.queue_free()
	craft_button.disabled = true

func _on_craft_pressed():
	if selected_recipe:
		craft_recipe(selected_recipe)
		# Refresh after crafting
		populate_recipes()
		if selected_recipe:
			display_recipe_details(selected_recipe)

func craft_recipe(recipe: Recipe):
	print("Attempting to craft: ", recipe.recipe_name)
	
	var inventory_items = Inventory.get_items_as_dict()
	var hotbar_items = Hotbar.get_items_as_dict()
	var all_items = inventory_items.duplicate()
	for item_name in hotbar_items:
		if all_items.has(item_name):
			all_items[item_name] += hotbar_items[item_name]
		else:
			all_items[item_name] = hotbar_items[item_name]
	
	if not recipe.can_craft(all_items):
		print("Not enough materials!")
		return
	
	# Remove ingredients (your existing removal code)
	for ingredient in recipe.ingredients:
		var item_name = ingredient["item"]
		var amount_needed = ingredient["amount"]
		
		# Try inventory first
		for slot in Inventory.slots:
			if slot["item_name"] == item_name and amount_needed > 0:
				var amount_to_remove = min(slot["quantity"], amount_needed)
				slot["quantity"] -= amount_to_remove
				amount_needed -= amount_to_remove
				
				if slot["quantity"] <= 0:
					slot["item_name"] = ""
					slot["quantity"] = 0
					slot["icon"] = null
		
		# Then hotbar
		if amount_needed > 0:
			for i in range(Hotbar.max_hotbar_slots):
				var slot = Hotbar.get_slot(i)
				if slot["item_name"] == item_name and amount_needed > 0:
					var amount_to_remove = min(slot["quantity"], amount_needed)
					slot["quantity"] -= amount_to_remove
					amount_needed -= amount_to_remove
					
					if slot["quantity"] <= 0:
						Hotbar.clear_slot(i)
					else:
						Hotbar.set_slot(i, slot["item_name"], slot["quantity"], slot["icon"])
		
		Inventory.inventory_changed.emit()
	
	# Add crafted item
	var item_icon = recipe.get_icon(recipe.recipe_name, recipe.type)
	if Inventory.add_item(recipe.recipe_name, item_icon, 1):
		print("Crafted and added to inventory: ", recipe.recipe_name)
	else:
		print("Inventory full!")

func _input(event):
	if Input.is_action_just_pressed("building_menu"):
		print("Building menu key pressed! Visible: ", visible)
		if visible:
			close_menu()
		else:
			open_menu()
