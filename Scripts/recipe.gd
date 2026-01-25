class_name Recipe
extends Resource

@export var recipe_name : String
@export var type : String
@export var ingredients : Array
@export var prerequisites : Array
@export var placeable : bool = false

func get_model(n, t) -> PackedScene:
	var model = load("res://Scenes/Craftables/" + t + "/" + n + ".tscn")
	return model

func get_icon(n, t) -> Texture2D:
	var icon = load("res://Assets/Icons/Craftables/" + t + "/" + n + ".png")
	return icon

func can_craft(inventory_items: Dictionary) -> bool:
	# Check if player has all ingredients
	for ingredient in ingredients:
		var item_name = ingredient["item"]
		var required_amount = ingredient["amount"]
		if not inventory_items.has(item_name) or inventory_items[item_name] < required_amount:
			return false
	return true

func get_ingredient_text() -> String:
	var text = ""
	for ingredient in ingredients:
		text += str(ingredient["amount"]) + "x " + ingredient["item"] + "\n"
	return text
