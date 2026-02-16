extends HBoxContainer
@onready var checkbox: CheckButton = $CheckButton
@onready var desc_label: Label = $Label

func setup(task_data: Dictionary, current: int):
	var required = task_data["required"]
	desc_label.text = task_data["description"] + " (%d/%d)" % [current, required]
	checkbox.button_pressed = (current >= required)  # Checked if complete
	checkbox.disabled = true
