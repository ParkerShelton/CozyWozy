extends ProgressBar

func _ready():
	# Background
	var style_bg = StyleBoxFlat.new()
	style_bg.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	add_theme_stylebox_override("background", style_bg)
	
	# Start with green fill
	var style_fill = StyleBoxFlat.new()
	style_fill.bg_color = Color(0.2, 0.8, 0.2, 1.0)  # Green
	add_theme_stylebox_override("fill", style_fill)
	
	custom_minimum_size = Vector2(200, 20)

func _process(_delta):
	# Change color based on health level
	var style_fill = get_theme_stylebox("fill")
	if style_fill is StyleBoxFlat:
		if value > 60:
			style_fill.bg_color = Color(0.2, 0.8, 0.2)  # Green (healthy)
		elif value > 30:
			style_fill.bg_color = Color(0.9, 0.9, 0.2)  # Yellow (hurt)
		else:
			style_fill.bg_color = Color(0.9, 0.2, 0.2)  # Red (critical)
