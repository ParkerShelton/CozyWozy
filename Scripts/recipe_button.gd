extends TextureButton

var recipe: Dictionary = {}  # Changed from Recipe to Dictionary
var tooltip: Node = null
signal recipe_selected(recipe: Dictionary)  # Changed signal type

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

func setup(recipe_data: Dictionary, can_craft: bool):  # Changed parameter type
	recipe = recipe_data
	
	var recipe_name = recipe.get("recipe_name", "Unknown")
	
	# Get icon from ItemManager
	var icon = ItemManager.get_item_icon(recipe_name)
	texture_normal = icon
	
	# Gray out if can't craft
	if can_craft:
		modulate = Color.WHITE
	else:
		modulate = Color(0.5, 0.5, 0.5)
	
	# Connect signals
	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_pressed():
	recipe_selected.emit(recipe)

func _on_mouse_entered():
	var recipe_name = recipe.get("recipe_name", "Unknown")
	var display_name = ItemManager.get_item_name(recipe_name)
	
	# Simple tooltip with just name
	tooltip = Label.new()
	tooltip.text = display_name
	tooltip.add_theme_color_override("font_color", Color.WHITE)
	
	# Style tooltip
	var panel = Panel.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	
	# Set each border individually
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.3, 0.3, 0.3)
	
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(tooltip)
	
	get_tree().root.add_child(panel)
	tooltip = panel
	update_tooltip_position()

func _on_mouse_exited():
	if tooltip:
		tooltip.queue_free()
		tooltip = null

func update_tooltip_position():
	if tooltip:
		tooltip.global_position = get_global_mouse_position() + Vector2(10, 10)

func _process(_delta):
	if tooltip:
		update_tooltip_position()


func get_recipe_data() -> Dictionary:
	return recipe  # Return the stored recipe data
