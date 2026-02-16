# HorseContextMenu.gd
extends PopupPanel

@onready var name_input: LineEdit = %NameInput
@onready var follow_button: Button = %FollowButton
@onready var stay_button: Button = %StayButton
@onready var rename_button: Button = %RenameButton

signal follow_toggled(should_follow: bool)
signal rename_requested(new_name: String)

var current_horse = null
var is_rename_mode: bool = false

func _ready() -> void:
	follow_button.pressed.connect(_on_follow_pressed)
	stay_button.pressed.connect(_on_stay_pressed)
	rename_button.pressed.connect(_on_rename_pressed)
	
	follow_button.toggle_mode = true
	stay_button.toggle_mode = true


func setup(horse, current_name: String, is_following: bool, is_ridden: bool = false) -> void:
	current_horse = horse
	name_input.text = current_name
	name_input.placeholder_text = "Current: " + current_name
	
	# Start in view-only mode
	name_input.editable = false
	name_input.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN   # ← fixed
	rename_button.text = "Rename"
	
	is_rename_mode = false
	
	follow_button.button_pressed = is_following
	stay_button.button_pressed = not is_following
	
	if has_node("%RideButton"):
		var ride_btn = %RideButton as Button
		ride_btn.visible = not is_ridden
		ride_btn.disabled = is_ridden
		# or ride_btn.text = "Already Riding"


func _on_follow_pressed() -> void:
	follow_toggled.emit(true)
	stay_button.button_pressed = false
	hide()


func _on_stay_pressed() -> void:
	follow_toggled.emit(false)
	follow_button.button_pressed = false
	hide()


func _on_rename_pressed() -> void:
	if not is_rename_mode:
		# Enter rename mode
		is_rename_mode = true
		name_input.editable = true
		name_input.grab_focus()
		name_input.select_all()
		rename_button.text = "Confirm"
		name_input.mouse_default_cursor_shape = Control.CURSOR_IBEAM   # ← fixed
	else:
		# Confirm rename
		var new_name = name_input.text.strip_edges()
		if not new_name.is_empty() and new_name != current_horse.horse_name:
			rename_requested.emit(new_name)
		# Exit rename mode
		is_rename_mode = false
		name_input.editable = false
		name_input.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
		rename_button.text = "Rename"
		hide()
