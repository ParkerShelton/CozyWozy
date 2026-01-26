extends Button

var recipe : Recipe
var tool_tip : Panel

@onready var name_label = $MarginContainer/HBoxContainer/VBoxContainer/recipe_name
@onready var ingredients_label = $MarginContainer/HBoxContainer/VBoxContainer/ingredients

func setup(recipe_data: Recipe, can_craft: bool):
	recipe = recipe_data
	name_label.text = recipe.recipe_name
	ingredients_label.text = recipe.get_ingredient_text()
	
	if can_craft:
		modulate = Color.WHITE
		disabled = false
	else:
		modulate = Color(0.5, 0.5, 0.5)
		disabled = true
	
	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_pressed():
	var player = get_parent().get_parent().get_parent().get_parent().get_parent()
	player.craft_recipe(recipe)

func _on_mouse_entered():
	show_tooltip()

func _on_mouse_exited():
	hide_tooltip()
	
func show_tooltip():
	# Create tooltip
	tool_tip = Panel.new()
	var vbox = VBoxContainer.new()
	tool_tip.add_child(vbox)
	
	# Add tooltip to the root (so it's above everything)
	get_tree().root.add_child(tool_tip)
	
	# Build tooltip text
	for ingredient in recipe.ingredients:
		var item_name = ingredient["item"]
		var required = ingredient["amount"]
		
		# Check BOTH inventory and hotbar
		var inventory_count = Inventory.get_item_count(item_name)
		var hotbar_count = 0
		for i in range(Hotbar.max_hotbar_slots):
			var slot = Hotbar.get_slot(i)
			if slot["item_name"] == item_name:
				hotbar_count += slot["quantity"]
		
		var current = inventory_count + hotbar_count  # Combined total
		
		var label = Label.new()
		if current >= required:
			label.text = "%s: %d/%d ✓" % [item_name, current, required]
			label.modulate = Color.GREEN
		else:
			label.text = "%s: %d/%d ✗" % [item_name, current, required]
			label.modulate = Color.RED
		
		vbox.add_child(label)
	
	# Position tooltip at mouse
	update_tooltip_position()

func hide_tooltip():
	if tool_tip:
		tool_tip.queue_free()
		tool_tip = null

func update_tooltip_position():
	if tool_tip:
		tool_tip.global_position = get_global_mouse_position() + Vector2(10, 10)

func _process(_delta):
	# Keep tooltip following mouse
	if tool_tip:
		update_tooltip_position()
