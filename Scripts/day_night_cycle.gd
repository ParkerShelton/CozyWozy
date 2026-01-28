extends CanvasModulate

@export var day_duration : float = 300.0  # 5 minutes in seconds
@export var night_color : Color = Color(0.3, 0.3, 0.5, 1.0)  # Blueish night
@export var day_color : Color = Color(1.0, 1.0, 1.0, 1.0)    # Normal day
@export var sunrise_color : Color = Color(1.0, 0.7, 0.5, 1.0)  # Orange sunrise
@export var sunset_color : Color = Color(1.0, 0.6, 0.4, 1.0)   # Orange sunset

var time : float = 0.0  # Time in seconds (0 = midnight, day_duration/2 = noon)

func _process(delta):
	time += delta
	#print("Time: ", time, " Color: ", color)
	# Loop time within day duration
	if time >= day_duration:
		time = 0.0
	
	# Calculate time of day (0.0 = midnight, 0.5 = noon, 1.0 = midnight)
	var time_of_day = time / day_duration
	
	# Determine which color to use based on time
	var current_color : Color
	
	if time_of_day < 0.25:  # Night -> Sunrise (midnight to 6am)
		var t = time_of_day / 0.25
		current_color = night_color.lerp(sunrise_color, t)
	elif time_of_day < 0.3:  # Sunrise -> Day (6am to 7:30am)
		var t = (time_of_day - 0.25) / 0.05
		current_color = sunrise_color.lerp(day_color, t)
	elif time_of_day < 0.7:  # Day (7:30am to 4:30pm)
		current_color = day_color
	elif time_of_day < 0.75:  # Day -> Sunset (4:30pm to 6pm)
		var t = (time_of_day - 0.7) / 0.05
		current_color = day_color.lerp(sunset_color, t)
	elif time_of_day < 0.8:  # Sunset -> Night (6pm to 7:30pm)
		var t = (time_of_day - 0.75) / 0.05
		current_color = sunset_color.lerp(night_color, t)
	else:  # Night (7:30pm to midnight)
		current_color = night_color
	
	color = current_color
