extends CanvasLayer

@onready var grid_container = $Panel/HBoxContainer/RightPanel/ScrollContainer/GridContainer
@onready var recipe_name_label = $Panel/HBoxContainer/LeftPanel/VBoxContainer/RecipeName
@onready var ingredients_container = $Panel/HBoxContainer/LeftPanel/VBoxContainer/MarginContainer2/ScrollContainer/VBoxContainer
@onready var craft_button = $Panel/HBoxContainer/LeftPanel/VBoxContainer/MarginContainer/CraftButton

var recipe_icon_scene = preload("res://UI/Building_Menu/recipe_button.tscn")

var selected_recipe: Dictionary = {}  # Changed from Recipe to Dictionary
var available_stations: Array = []

var currently_selected_button: Control = null

var audio_player: AudioStreamPlayer = null
var craft_sounds: Array = []

func _ready():
	craft_button.pressed.connect(_on_craft_pressed)
	craft_button.disabled = true
	visible = false
	
	setup_audio()
	
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
	
	# Find and store the selected button for animation later
	for child in grid_container.get_children():
		if child.has_method("get_recipe_data"):
			if child.get_recipe_data() == recipe_data:
				currently_selected_button = child
				break

func display_recipe_details(recipe_data: Dictionary):  # Changed from Recipe to Dictionary
	# Set recipe name
	var item_name = recipe_data.get("recipe_name", "Unknown")
	recipe_name_label.text = ItemManager.get_item_name(item_name)
	
	# Clear previous ingredients
	for child in ingredients_container.get_children():
		child.queue_free()
	
	# Add description first
	var description = ItemManager.get_item_description(item_name)
	if description and description != "":
		var desc_label = Label.new()
		desc_label.text = description
		desc_label.modulate = Color(0.8, 0.8, 0.8)  # Slightly gray
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.add_theme_font_size_override("font_size", 14)
		desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ingredients_container.add_child(desc_label)
		
		# Add spacing after description
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 10)
		ingredients_container.add_child(spacer)
	
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
			
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ingredients_container.add_child(label)
	
	# Enable/disable craft button
	craft_button.disabled = not ItemManager.can_craft_recipe(recipe_data, all_items)

func clear_details():
	recipe_name_label.text = "Select a recipe"
	for child in ingredients_container.get_children():
		child.queue_free()
	craft_button.disabled = true

func _on_craft_pressed():
	print("=== CRAFT PRESSED ===")
	
	if selected_recipe and selected_recipe.size() > 0:
		# Animate the selected button BEFORE crafting/refreshing
		if currently_selected_button:
			print("Animating button!")
			animate_craft_button(currently_selected_button)
			# Wait for animation to finish
			await get_tree().create_timer(0.3).timeout
		
		craft_recipe(selected_recipe)
		
		# Refresh after crafting (this destroys the old button)
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
		
	if craft_sounds.size() > 0 and audio_player:
		audio_player.stream = craft_sounds[0] 
		audio_player.play()
		print("playing sound")	

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

func animate_craft_button(button: Control):
	if not button:
		return

	# Create a bounce/scale animation
	var original_scale = button.scale
	var original_rotation = button.rotation
	var original_position = button.global_position
	var original_z_index = button.z_index
	
	button.top_level = true
	button.global_position = original_position
	button.z_index = 100
	
	var tween = create_tween()
	
	tween.tween_property(button, "scale", original_scale * 1.4, 0.1)
	tween.parallel().tween_property(button, "rotation", deg_to_rad(10), 0.05)
	
	# Wiggle back and forth
	tween.tween_property(button, "rotation", deg_to_rad(-10), 0.1)
	tween.tween_property(button, "rotation", deg_to_rad(8), 0.08)
	tween.tween_property(button, "rotation", deg_to_rad(-8), 0.08)
	tween.tween_property(button, "rotation", deg_to_rad(5), 0.06)
	tween.tween_property(button, "rotation", deg_to_rad(-5), 0.06)
	
	# Settle back down
	tween.tween_property(button, "scale", original_scale, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	tween.parallel().tween_property(button, "rotation", original_rotation, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	
	tween.tween_callback(func(): 
		if is_instance_valid(button):
			button.top_level = false
			button.z_index = original_z_index
	)


func setup_audio():
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	
	var craft1 = load("res://Assets/SFX/craft.mp3")
	
	if craft1:
		craft_sounds.append(craft1)
