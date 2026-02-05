# fade_manager.gd
extends CanvasLayer

var fade_rect: ColorRect

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
	
	await get_tree().process_frame
	print("FadeManager mouse_filter: ", fade_rect.mouse_filter)
	print("Should be 2 (MOUSE_FILTER_IGNORE)")

func fade_to_black(duration: float = 1.0):
	"""Fade screen to black"""
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, duration)
	return tween  # Return tween so you can await it

func fade_from_black(duration: float = 1.0):
	"""Fade from black to clear"""
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 0.0, duration)
	return tween

func fade_transition(fade_in: float = 0.5, hold: float = 0.5, fade_out: float = 0.5):
	"""Complete fade transition: in -> hold -> out"""
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, fade_in)
	tween.tween_interval(hold)
	tween.tween_property(fade_rect, "modulate:a", 0.0, fade_out)
	return tween

func set_color(new_color: Color):
	"""Change fade color (e.g., white, red)"""
	fade_rect.color = new_color
