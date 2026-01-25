extends Control

@onready var hotbar_container = $MarginContainer/HBoxContainer
var hotbar_slot_scene = preload("res://UI/hotbar_slot.tscn")

var slot_nodes : Array = []

func _ready():
	# Create 10 hotbar slot UI elements
	for i in range(Hotbar.max_hotbar_slots):
		var slot = hotbar_slot_scene.instantiate()
		hotbar_container.add_child(slot)
		slot_nodes.append(slot)
		slot.set_slot_index(i)  # Tell the slot what index it is
	
	# Connect signals
	Hotbar.hotbar_changed.connect(update_display)
	Hotbar.selected_slot_changed.connect(highlight_selected_slot)
	
	update_display()
	highlight_selected_slot(0)

func _input(event):
	# Number keys 1-0 to select slots
	if event is InputEventKey and event.pressed:
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var slot_index = event.keycode - KEY_1  # 1 = slot 0, 2 = slot 1, etc.
			Hotbar.select_slot(slot_index)
		elif event.keycode == KEY_0:
			Hotbar.select_slot(9)  # 0 = slot 9
			
	# Scroll wheel to cycle through slots
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				# Scroll up - move to previous slot
				var new_slot = Hotbar.selected_slot - 1
				if new_slot < 0:
					new_slot = Hotbar.max_hotbar_slots - 1  # Wrap to slot 9
				Hotbar.select_slot(new_slot)
			
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				# Scroll down - move to next slot
				var new_slot = Hotbar.selected_slot + 1
				if new_slot >= Hotbar.max_hotbar_slots:
					new_slot = 0  # Wrap to slot 0
				Hotbar.select_slot(new_slot)

func update_display():
	for i in range(Hotbar.hotbar_slots.size()):
		slot_nodes[i].set_slot_data(Hotbar.hotbar_slots[i])

func highlight_selected_slot(slot_index: int):
	for i in range(slot_nodes.size()):
		slot_nodes[i].set_selected(i == slot_index)
