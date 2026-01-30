extends ProgressBar

func _ready():
	# Customize appearance
	var style_bg = StyleBoxFlat.new()
	style_bg.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	add_theme_stylebox_override("background", style_bg)
	
	var style_fill = StyleBoxFlat.new()
	style_fill.bg_color = Color(0.8, 0.6, 0.2, 1.0)  # Orange/yellow
	add_theme_stylebox_override("fill", style_fill)
	
	custom_minimum_size = Vector2(200, 20)

func _process(_delta):
	# Change color based on hunger level
	var style_fill = get_theme_stylebox("fill")
	if style_fill is StyleBoxFlat:
		if value > 50:
			style_fill.bg_color = Color(0.8, 0.6, 0.2)  # Orange
		elif value > 30:
			style_fill.bg_color = Color(0.9, 0.7, 0.3)  # Yellow
		else:
			style_fill.bg_color = Color(0.9, 0.3, 0.3)  # Red
