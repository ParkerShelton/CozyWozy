class_name PlayerHunger

var player: Node3D

# HUNGER
var max_hunger: float = 100.0
var current_hunger: float = 100.0
var hunger_drain_rate: float = 0.1  # Hunger lost per second
var hunger_damage_rate: float = 2.0  # Damage per second when starving
var low_hunger_threshold: float = 30.0  # When to show warning
var starving_threshold: float = 0.0  # When to start taking damage

var ui_container: CanvasLayer

var hunger_bar: ProgressBar
var health_bar: ProgressBar

func _init(_player: Node3D, _ui: CanvasLayer):
	player = _player
	ui_container = _ui
	current_hunger = max_hunger
	
	hunger_bar = ui_container.get_node("MarginContainer/VBoxContainer/ProgressBar")
	health_bar  = ui_container.get_node("MarginContainer/VBoxContainer2/ProgressBar")

func update_hunger(delta):
	current_hunger -= hunger_drain_rate * delta
	current_hunger = clamp(current_hunger, 0.0, max_hunger)
	
	if current_hunger <= starving_threshold:
		player.take_damage(hunger_damage_rate * delta)
	elif current_hunger <= low_hunger_threshold:
		# Low hunger - move slower (affects movement component indirectly via player vars)
		pass
	# Update UI
	update_hunger_health_ui()

func eat_food(item_name: String) -> bool:
	var food_value = ItemManager.get_food_value(item_name)
	if food_value > 0.0:
		current_hunger += food_value
		current_hunger = clamp(current_hunger, 0.0, max_hunger)
		return true
	return false
	
func try_eat_selected_item():
	var selected_item = Hotbar.get_selected_item()
	var item_name = selected_item["item_name"]
	if item_name == "":
		return
	if ItemManager.is_food(item_name):
		if eat_food(item_name):
			var selected_slot = Hotbar.selected_slot
			var slot_data = Hotbar.get_slot(selected_slot)
			var new_quantity = slot_data["quantity"] - 1
			if new_quantity <= 0:
				Hotbar.clear_slot(selected_slot)
			else:
				Hotbar.set_slot(selected_slot, item_name, new_quantity, slot_data["icon"])

func update_hunger_health_ui():
	var hunger_bar = ui_container.get_node("MarginContainer/VBoxContainer/ProgressBar")
	var health_bar  = ui_container.get_node("MarginContainer/VBoxContainer2/ProgressBar")
	if hunger_bar:  hunger_bar.value = current_hunger
	if health_bar:  health_bar.value = player.player_health
