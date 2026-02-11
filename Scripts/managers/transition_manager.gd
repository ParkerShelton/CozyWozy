extends CanvasLayer

var fade_rect: ColorRect
var loading_container: VBoxContainer
var loading_label: Label
var progress_bar: ProgressBar

func _ready():
	layer = 100  # On top of everything
	
	# Create fullscreen black rectangle
	fade_rect = ColorRect.new()
	add_child(fade_rect)
	
	fade_rect.anchor_right = 1.0
	fade_rect.anchor_bottom = 1.0
	fade_rect.color = Color.BLACK
	fade_rect.modulate.a = 0.0
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Create loading UI (centered on screen)
	loading_container = VBoxContainer.new()
	add_child(loading_container)
	loading_container.anchor_left = 0.5
	loading_container.anchor_top = 0.5
	loading_container.anchor_right = 0.5
	loading_container.anchor_bottom = 0.5
	loading_container.offset_left = -150
	loading_container.offset_top = -50
	loading_container.offset_right = 150
	loading_container.offset_bottom = 50
	loading_container.visible = false
	loading_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Loading label
	loading_label = Label.new()
	loading_container.add_child(loading_label)
	loading_label.text = "Loading..."
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_label.add_theme_font_size_override("font_size", 32)
	
	# Progress bar
	progress_bar = ProgressBar.new()
	loading_container.add_child(progress_bar)
	progress_bar.custom_minimum_size = Vector2(300, 30)
	progress_bar.max_value = 100
	progress_bar.value = 0
	progress_bar.show_percentage = false
	
	await get_tree().process_frame
	print("FadeManager ready")

func fade_to_black(duration: float = 1.0):
	"""Fade screen to black"""
	loading_container.visible = false
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, duration)
	return tween

func fade_from_black(duration: float = 1.0):
	"""Fade from black to clear"""
	loading_container.visible = false
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 0.0, duration)
	return tween

func fade_transition(fade_in: float = 0.5, hold: float = 0.5, fade_out: float = 0.5):
	"""Complete fade transition: in -> hold -> out"""
	loading_container.visible = false
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, fade_in)
	tween.tween_interval(hold)
	tween.tween_property(fade_rect, "modulate:a", 0.0, fade_out)
	return tween

func show_loading_screen(duration: float = 1.0):
	"""Fade to black and show loading screen with progress bar"""
	var tween = create_tween()
	
	# Fade to black
	tween.tween_property(fade_rect, "modulate:a", 1.0, duration)
	
	# Show loading UI after fade completes
	tween.tween_callback(func():
		loading_container.visible = true
		progress_bar.value = 0
	)
	
	return tween

func hide_loading_screen(duration: float = 1.0):
	"""Hide loading screen and fade from black"""
	var tween = create_tween()
	
	# Hide loading UI first
	loading_container.visible = false
	
	# Fade from black
	tween.tween_property(fade_rect, "modulate:a", 0.0, duration)
	
	return tween

func set_loading_progress(value: float, duration: float = 0.3):
	"""Update loading progress bar (0-100)"""
	var target_value = clamp(value, 0, 100)
	
	var tween = create_tween()
	tween.tween_property(progress_bar, "value", target_value, duration)
	
	return tween

func set_loading_text(text: String):
	"""Change loading text (default is 'Loading...')"""
	loading_label.text = text

func set_color(new_color: Color):
	"""Change fade color (e.g., white, red)"""
	fade_rect.color = new_color
