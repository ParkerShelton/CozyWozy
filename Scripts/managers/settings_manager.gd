# settings_manager.gd — Add as Autoload singleton named "SettingsManager"
extends Node

const SETTINGS_PATH = "user://settings.cfg"

# Tracks where settings menu was opened from (persists across scene changes)
var opened_from: String = "game"

# Audio
var master_volume: float = 80.0
var music_volume: float = 80.0
var sfx_volume: float = 80.0

# Display
var fullscreen: bool = false
var pixel_shader_enabled: bool = false
var pixel_shader_strength: int = 1  # 0=Low(320x180), 1=Medium(640x360), 2=High(960x540)
var leaf_particles_enabled: bool = true

var pixel_resolutions: Array = [
	Vector2(320.0, 180.0),  # Low
	Vector2(640.0, 360.0),  # Medium
	Vector2(960.0, 540.0),  # High
]

# Controls
var mouse_sensitivity: float = 50.0

# Keybinds — action_name : default scancode
# These are the defaults. Saved bindings override them.
var default_keybinds: Dictionary = {
	"walk_up": KEY_W,
	"walk_down": KEY_S,
	"walk_left": KEY_A,
	"walk_right": KEY_D,
	"sprint": KEY_SHIFT,
	"dash_roll": KEY_SPACE,
	"inventory": KEY_TAB,
	"eat": KEY_E,
	"block": KEY_Q,
	"rotate_clockwise": KEY_R,
	"rotate_counter_clockwise": KEY_T,
}

var keybinds: Dictionary = {}

func _ready():
	# Copy defaults
	for action in default_keybinds:
		keybinds[action] = default_keybinds[action]
	
	load_settings()
	apply_all_settings()

# --- Audio ---

func set_master_volume(value: float):
	master_volume = value
	_apply_bus_volume("Master", value)

func set_music_volume(value: float):
	music_volume = value
	_apply_bus_volume("Music", value)

func set_sfx_volume(value: float):
	sfx_volume = value
	_apply_bus_volume("SFX", value)

func _apply_bus_volume(bus_name: String, value: float):
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx == -1:
		return
	
	if value <= 0.0:
		AudioServer.set_bus_mute(bus_idx, true)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		# Convert 0-100 to dB (0 = -40dB, 100 = 0dB)
		var db = lerp(-40.0, 0.0, value / 100.0)
		AudioServer.set_bus_volume_db(bus_idx, db)

# --- Display ---

func set_fullscreen(enabled: bool):
	fullscreen = enabled
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func set_pixel_shader_enabled(enabled: bool):
	pixel_shader_enabled = enabled
	_apply_pixel_shader()

func set_leaf_particles_enabled(enabled: bool):
	leaf_particles_enabled = enabled
	_apply_leaf_particles()

func _apply_leaf_particles():
	var overlay = get_tree().root.find_child("leaf_particles", true, false)
	if not overlay:
		return
	overlay.visible = leaf_particles_enabled

func set_pixel_shader_strength(strength: int):
	pixel_shader_strength = clampi(strength, 0, 2)
	_apply_pixel_shader()

func _apply_pixel_shader():
	# pixel_overlay may not exist yet (e.g. settings opened from main menu)
	# Settings are saved and will be applied when the game scene loads
	var overlay = get_tree().root.find_child("pixel_overlay", true, false)
	if not overlay:
		return
	
	overlay.visible = pixel_shader_enabled
	
	if pixel_shader_enabled:
		for child in overlay.get_children():
			if child is ColorRect or child is TextureRect:
				if child.material and child.material is ShaderMaterial:
					child.material.set_shader_parameter("target_resolution", pixel_resolutions[pixel_shader_strength])
					break

# --- Controls ---

func set_mouse_sensitivity(value: float):
	mouse_sensitivity = value

func get_mouse_sensitivity_multiplier() -> float:
	return mouse_sensitivity / 50.0  # 50 = 1.0x, 100 = 2.0x, 0 = 0.0x

# --- Keybinds ---

func set_keybind(action: String, keycode: int):
	keybinds[action] = keycode
	_apply_keybind(action, keycode)

func _apply_keybind(action: String, keycode: int):
	if not InputMap.has_action(action):
		return
	
	# Remove existing key events (keep mouse button events)
	var events = InputMap.action_get_events(action)
	for event in events:
		if event is InputEventKey:
			InputMap.action_erase_event(action, event)
	
	# Add new key
	var new_event = InputEventKey.new()
	new_event.keycode = keycode
	InputMap.action_add_event(action, new_event)

func reset_keybind(action: String):
	if default_keybinds.has(action):
		set_keybind(action, default_keybinds[action])

func reset_all_keybinds():
	for action in default_keybinds:
		set_keybind(action, default_keybinds[action])
	keybinds = default_keybinds.duplicate()

func get_key_name(action: String) -> String:
	if keybinds.has(action):
		return OS.get_keycode_string(keybinds[action])
	return "Unset"

func get_action_display_name(action: String) -> String:
	var names = {
		"walk_up": "Move Up",
		"walk_down": "Move Down",
		"walk_left": "Move Left",
		"walk_right": "Move Right",
		"sprint": "Sprint",
		"dash_roll": "Dash / Roll",
		"inventory": "Inventory",
		"eat": "Eat",
		"block": "Block",
		"rotate_clockwise": "Rotate CW",
		"rotate_counter_clockwise": "Rotate CCW",
	}
	return names.get(action, action)

# --- Apply All ---

func apply_all_settings():
	set_master_volume(master_volume)
	set_music_volume(music_volume)
	set_sfx_volume(sfx_volume)
	set_fullscreen(fullscreen)
	set_mouse_sensitivity(mouse_sensitivity)
	_apply_pixel_shader()
	_apply_leaf_particles()
	
	for action in keybinds:
		_apply_keybind(action, keybinds[action])

# --- Save / Load ---

func save_settings():
	var config = ConfigFile.new()
	
	# Audio
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	
	# Display
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "pixel_shader_enabled", pixel_shader_enabled)
	config.set_value("display", "pixel_shader_strength", pixel_shader_strength)
	config.set_value("display", "leaf_particles_enabled", leaf_particles_enabled)
	
	# Controls
	config.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	
	# Keybinds
	for action in keybinds:
		config.set_value("keybinds", action, keybinds[action])
	
	config.save(SETTINGS_PATH)

func load_settings():
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH)
	
	if err != OK:
		# No settings file yet — use defaults
		return
	
	# Audio
	master_volume = config.get_value("audio", "master_volume", 80.0)
	music_volume = config.get_value("audio", "music_volume", 80.0)
	sfx_volume = config.get_value("audio", "sfx_volume", 80.0)
	
	# Display
	fullscreen = config.get_value("display", "fullscreen", false)
	pixel_shader_enabled = config.get_value("display", "pixel_shader_enabled", false)
	pixel_shader_strength = config.get_value("display", "pixel_shader_strength", 1)
	leaf_particles_enabled = config.get_value("display", "leaf_particles_enabled", true)
	
	# Controls
	mouse_sensitivity = config.get_value("controls", "mouse_sensitivity", 50.0)
	
	# Keybinds
	for action in default_keybinds:
		keybinds[action] = config.get_value("keybinds", action, default_keybinds[action])
