extends Node

var recipes : Dictionary = {}  # Store recipes by name

func _ready():
	load_all_recipes()

func load_all_recipes():
	print("=== Loading recipes ===")
	
	var file = FileAccess.open("res://Data/recipes.json", FileAccess.READ)
	if file == null:
		print("ERROR: Failed to open recipes.json")
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		print("ERROR: Failed to parse recipes.json")
		return
	
	var data = json.data
	
	for recipe_data in data["recipes"]:
		var recipe = Recipe.new()
		recipe.recipe_name = recipe_data["recipe_name"]
		recipe.type = recipe_data["type"]
		recipe.ingredients = recipe_data["ingredients"]
		recipe.prerequisites = recipe_data.get("prerequisites", [])
		recipe.placeable = recipe_data.get("placeable", false)
		
		recipes[recipe.recipe_name] = recipe
		print("✓ Loaded recipe: ", recipe.recipe_name)
	
	print("=== Total recipes loaded: ", recipes.size(), " ===")

func get_recipe(recipe_name: String) -> Recipe:
	if recipes.has(recipe_name):
		return recipes[recipe_name]
	return null

func get_all_recipes() -> Array:
	return recipes.values()

func get_recipes_by_type(type: String) -> Array:
	var filtered = []
	for recipe in recipes.values():
		if recipe.type == type:
			filtered.append(recipe)
	return filtered

func get_craftable_recipes(inventory_items: Dictionary) -> Array:
	var craftable = []
	for recipe in recipes.values():
		if recipe.can_craft(inventory_items):
			craftable.append(recipe)
	return craftable

func get_uncraftable_recipes(inventory_items: Dictionary) -> Array:
	var uncraftable = []
	for recipe in recipes.values():
		if not recipe.can_craft(inventory_items):
			uncraftable.append(recipe)
	return uncraftable

func get_recipes_without_prereqs() -> Array:
	var no_prereq_recipes = []
	for recipe in recipes.values():
		if recipe.prerequisites.size() == 0:
			no_prereq_recipes.append(recipe)
	return no_prereq_recipes
