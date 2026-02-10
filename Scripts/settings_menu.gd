# settings_menu.gd
extends CanvasLayer

# Tabs
@onready var audio_tab = $Panel/MarginContainer/VBoxContainer/Content/AudioTab
@onready var display_tab = $Panel/MarginContainer/VBoxContainer/Content/DisplayTab
@onready var controls_tab = $Panel/MarginContainer/VBoxContainer/Content/ControlsTab

# Audio
@onready var master_slider = $Panel/MarginContainer/VBoxContainer/Content/AudioTab/MasterVolume/HSlider
@onready var master_label = $Panel/MarginContainer/VBoxContainer/Content/AudioTab/MasterVolume/ValueLabel
@onready var music_slider = $Panel/MarginContainer/VBoxContainer/Content/AudioTab/MusicVolume/HSlider
@onready var music_label = $Panel/MarginContainer/VBoxContainer/Content/AudioTab/MusicVolume/ValueLabel
@onready var sfx_slider = $Panel/MarginContainer/VBoxContainer/Content/AudioTab/SFXVolume/HSlider
@onready var sfx_label = $Panel/MarginContainer/VBoxContainer/Content/AudioTab/SFXVolume/ValueLabel

# Display
@onready var fullscreen_check = $Panel/MarginContainer/VBoxContainer/Content/DisplayTab/Fullscreen/CheckBox
@onready var pixel_shader_check = $Panel/MarginContainer/VBoxContainer/Content/DisplayTab/PixelShader/CheckBox
@onready var pixel_strength_option = $Panel/MarginContainer/VBoxContainer/Content/DisplayTab/PixelStrength/OptionButton
@onready var leaf_particles_check = $Panel/MarginContainer/VBoxContainer/Content/DisplayTab/LeafParticles/CheckBox

# Controls
@onready var sensitivity_slider = $Panel/MarginContainer/VBoxContainer/Content/ControlsTab/MouseSensitivity/HSlider
@onready var sensitivity_label = $Panel/MarginContainer/VBoxContainer/Content/ControlsTab/MouseSensitivity/ValueLabel

# Keybinds (inside controls tab)
@onready var keybinds_container = $Panel/MarginContainer/VBoxContainer/Content/ControlsTab/ScrollContainer/KeybindsList

# Tab buttons
@onready var audio_btn = $Panel/MarginContainer/VBoxContainer/TabBar/AudioBtn
@onready var display_btn = $Panel/MarginContainer/VBoxContainer/TabBar/DisplayBtn
@onready var controls_btn = $Panel/MarginContainer/VBoxContainer/TabBar/ControlsBtn

var waiting_for_key: bool = false
var rebinding_action: String = ""
var rebinding_button: Button = null

var main_menu_scene: String = "res://UI/main_menu/main_menu.tscn"

func _ready():
	visible = false
	# Connect tab buttons
	audio_btn.pressed.connect(func(): switch_tab("audio"))
	display_btn.pressed.connect(func(): switch_tab("display"))
	controls_btn.pressed.connect(func(): switch_tab("controls"))
	
	# Connect sliders
	master_slider.value_changed.connect(_on_master_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	
	# Connect fullscreen
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	
	# Connect pixel shader
	pixel_shader_check.toggled.connect(_on_pixel_shader_toggled)
	pixel_strength_option.add_item("Low (320x180)", 0)
	pixel_strength_option.add_item("Medium (640x360)", 1)
	pixel_strength_option.add_item("High (960x540)", 2)
	pixel_strength_option.item_selected.connect(_on_pixel_strength_changed)
	
	# Connect leaf particles
	leaf_particles_check.toggled.connect(_on_leaf_particles_toggled)
	
	# Load current values
	_load_current_settings()
	
	# Build keybind rows
	_build_keybind_rows()
	
	# Start on audio tab
	switch_tab("audio")

func _load_current_settings():
	master_slider.value = SettingsManager.master_volume
	master_label.text = str(int(SettingsManager.master_volume)) + "%"
	
	music_slider.value = SettingsManager.music_volume
	music_label.text = str(int(SettingsManager.music_volume)) + "%"
	
	sfx_slider.value = SettingsManager.sfx_volume
	sfx_label.text = str(int(SettingsManager.sfx_volume)) + "%"
	
	fullscreen_check.button_pressed = SettingsManager.fullscreen
	
	pixel_shader_check.button_pressed = SettingsManager.pixel_shader_enabled
	pixel_strength_option.selected = SettingsManager.pixel_shader_strength
	pixel_strength_option.disabled = not SettingsManager.pixel_shader_enabled
	
	leaf_particles_check.button_pressed = SettingsManager.leaf_particles_enabled
	
	sensitivity_slider.value = SettingsManager.mouse_sensitivity
	sensitivity_label.text = str(int(SettingsManager.mouse_sensitivity)) + "%"

func switch_tab(tab_name: String):
	audio_tab.visible = tab_name == "audio"
	display_tab.visible = tab_name == "display"
	controls_tab.visible = tab_name == "controls"
	
	# Update button styles
	audio_btn.modulate = Color.WHITE if tab_name == "audio" else Color(0.6, 0.6, 0.6)
	display_btn.modulate = Color.WHITE if tab_name == "display" else Color(0.6, 0.6, 0.6)
	controls_btn.modulate = Color.WHITE if tab_name == "controls" else Color(0.6, 0.6, 0.6)

# --- Audio callbacks ---

func _on_master_changed(value: float):
	SettingsManager.set_master_volume(value)
	master_label.text = str(int(value)) + "%"

func _on_music_changed(value: float):
	SettingsManager.set_music_volume(value)
	music_label.text = str(int(value)) + "%"

func _on_sfx_changed(value: float):
	SettingsManager.set_sfx_volume(value)
	sfx_label.text = str(int(value)) + "%"

# --- Display callbacks ---

func _on_fullscreen_toggled(enabled: bool):
	SettingsManager.set_fullscreen(enabled)

func _on_pixel_shader_toggled(enabled: bool):
	SettingsManager.set_pixel_shader_enabled(enabled)
	pixel_strength_option.disabled = not enabled

func _on_pixel_strength_changed(index: int):
	SettingsManager.set_pixel_shader_strength(index)

func _on_leaf_particles_toggled(enabled: bool):
	SettingsManager.set_leaf_particles_enabled(enabled)

# --- Controls callbacks ---

func _on_sensitivity_changed(value: float):
	SettingsManager.set_mouse_sensitivity(value)
	sensitivity_label.text = str(int(value)) + "%"

# --- Keybinds ---

func _build_keybind_rows():
	# Clear existing rows
	for child in keybinds_container.get_children():
		child.queue_free()
	
	for action in SettingsManager.keybinds:
		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# Action name label
		var label = Label.new()
		label.text = SettingsManager.get_action_display_name(action)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 14)
		row.add_child(label)
		
		# Current key button (click to rebind)
		var key_btn = Button.new()
		key_btn.text = SettingsManager.get_key_name(action)
		key_btn.custom_minimum_size = Vector2(120, 32)
		key_btn.pressed.connect(_start_rebind.bind(action, key_btn))
		key_btn.add_theme_font_size_override("font_size", 13)
		row.add_child(key_btn)
		
		# Reset button
		var reset_btn = Button.new()
		reset_btn.text = "Reset"
		reset_btn.custom_minimum_size = Vector2(60, 32)
		reset_btn.pressed.connect(_reset_keybind.bind(action, key_btn))
		reset_btn.add_theme_font_size_override("font_size", 12)
		row.add_child(reset_btn)
		
		keybinds_container.add_child(row)

func _start_rebind(action: String, btn: Button):
	waiting_for_key = true
	rebinding_action = action
	rebinding_button = btn
	btn.text = "Press a key..."

func _input(event):
	if not waiting_for_key:
		return
	
	if event is InputEventKey and event.pressed:
		# Cancel with Escape
		if event.keycode == KEY_ESCAPE:
			rebinding_button.text = SettingsManager.get_key_name(rebinding_action)
			waiting_for_key = false
			rebinding_action = ""
			rebinding_button = null
			get_viewport().set_input_as_handled()
			return
		
		# Set the new keybind
		SettingsManager.set_keybind(rebinding_action, event.keycode)
		rebinding_button.text = OS.get_keycode_string(event.keycode)
		
		waiting_for_key = false
		rebinding_action = ""
		rebinding_button = null
		get_viewport().set_input_as_handled()

func _reset_keybind(action: String, btn: Button):
	SettingsManager.reset_keybind(action)
	btn.text = SettingsManager.get_key_name(action)

func open(from: String = "game"):
	SettingsManager.opened_from = from
	visible = true
	_load_current_settings()
	_build_keybind_rows()
	switch_tab("audio")

# --- Bottom buttons ---

func _on_back_pressed():
	SettingsManager.save_settings()
	
	if SettingsManager.opened_from == "main_menu":
		get_tree().change_scene_to_file(main_menu_scene)
	else:
		visible = false

func _on_reset_all_pressed():
	SettingsManager.reset_all_keybinds()
	SettingsManager.master_volume = 80.0
	SettingsManager.music_volume = 80.0
	SettingsManager.sfx_volume = 80.0
	SettingsManager.fullscreen = false
	SettingsManager.pixel_shader_enabled = false
	SettingsManager.pixel_shader_strength = 1
	SettingsManager.leaf_particles_enabled = true
	SettingsManager.mouse_sensitivity = 50.0
	SettingsManager.apply_all_settings()
	_load_current_settings()
	_build_keybind_rows()
