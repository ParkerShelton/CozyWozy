extends Control

@onready var recipe_container = $MarginContainer/VBoxContainer/ScrollContainer/RecipeContainer

var recipe_button_scene =  preload("res://UI/Building_Menu/recipe_button.tscn")

var is_now_visible = false

func _process(_delta):
	if !is_now_visible:
		if visible:
			is_now_visible = true
			populate_recipes()
	else:
		if !visible:
			is_now_visible = false

func populate_recipes():
	print("=== Populating recipes ===")
	
	# Clear existing buttons
	for child in recipe_container.get_children():
		child.queue_free()
	
	# Get player's current inventory + hotbar as combined dictionary
	var inventory_items = Inventory.get_items_as_dict()
	var hotbar_items = Hotbar.get_items_as_dict()
	
	# Combine both inventories
	var all_items = inventory_items.duplicate()
	for item_name in hotbar_items:
		if all_items.has(item_name):
			all_items[item_name] += hotbar_items[item_name]
		else:
			all_items[item_name] = hotbar_items[item_name]
	
	print("Combined items: ", all_items)
	
	# Get recipes without prerequisites
	var available_recipes = RecipeManager.get_recipes_without_prereqs()
	print("Available recipes (no prereqs) count: ", available_recipes.size())
	
	for recipe in available_recipes:
		var can_craft = recipe.can_craft(all_items)
		
		var recipe_btn = recipe_button_scene.instantiate()
		recipe_container.add_child(recipe_btn)
		recipe_btn.setup(recipe, can_craft)

func craft_recipe(recipe: Recipe):
	print("Attempting to craft: ", recipe.recipe_name)
	
	# Get combined inventory
	var inventory_items = Inventory.get_items_as_dict()
	var hotbar_items = Hotbar.get_items_as_dict()
	var all_items = inventory_items.duplicate()
	for item_name in hotbar_items:
		if all_items.has(item_name):
			all_items[item_name] += hotbar_items[item_name]
		else:
			all_items[item_name] = hotbar_items[item_name]
	
	# Check if player has ingredients
	if not recipe.can_craft(all_items):
		print("Not enough materials!")
		return
	
	# Remove ingredients (try inventory first, then hotbar)
	for ingredient in recipe.ingredients:
		var item_name = ingredient["item"]
		var amount_needed = ingredient["amount"]
		
		# Try to remove from inventory first
		var removed_from_inventory = 0
		for slot in Inventory.slots:
			if slot["item_name"] == item_name and amount_needed > 0:
				var amount_to_remove = min(slot["quantity"], amount_needed)
				slot["quantity"] -= amount_to_remove
				amount_needed -= amount_to_remove
				removed_from_inventory += amount_to_remove
				
				if slot["quantity"] <= 0:
					slot["item_name"] = ""
					slot["quantity"] = 0
					slot["icon"] = null
		
		# If still need more, remove from hotbar
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
		
		if removed_from_inventory > 0:
			Inventory.inventory_changed.emit()
	
	# Get icon using helper function
	var item_icon = recipe.get_icon(recipe.recipe_name, recipe.type)
	
	# Add crafted item to inventory
	if Inventory.add_item(recipe.recipe_name, item_icon, 1):
		print("Crafted and added to inventory: ", recipe.recipe_name)
	else:
		print("Inventory full!")
		return
	
	populate_recipes()

func get_mouse_world_position() -> Variant:
	var camera = get_viewport().get_camera_3d()
	if !camera:
		return null
	
	var mouse_pos = get_viewport().get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000
	
	var space_state = get_tree().root.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1  # Adjust this to match your ground layer
	
	var result = space_state.intersect_ray(query)
	if result:
		return result.position + Vector3(0, 0.3, 0)  # Slight offset above ground
	
	return null
