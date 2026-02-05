extends CanvasLayer

@export var leaf_texture: Texture2D  # Assign any leaf sprite in the inspector
@export var amount: int = 50
@export var speed_min: float = 40.0
@export var speed_max: float = 90.0
@export var leaf_lifetime: float = 8.0
@export var spin_speed: float = 2.0
@export var color: Color = Color(0.85, 0.55, 0.2)

var particles: CPUParticles2D

func _ready():
	layer = 2

	var vp = get_viewport().get_visible_rect().size
	print("Leaf particle viewport size: ", vp)  # <-- check this in the output

	particles = CPUParticles2D.new()
	add_child(particles)
	particles.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	particles.amount = amount

	if leaf_texture:
		var image = leaf_texture.get_image()
		var new_width = int(image.get_width() * 0.05)
		var new_height = int(image.get_height() * 0.05)
		image.resize(new_width, new_height)
		particles.texture = ImageTexture.create_from_image(image)

	# Top-right corner
	particles.position = Vector2(vp.x + 50.0, -50.0)
	particles.emission_rect_extents = Vector2(vp.x * 0.4, vp.y * 0.3)

	# Long lifetime — gives them time to cross the full diagonal
	particles.lifetime = 14.0
	particles.lifetime_randomness = 0.1

	# Moderate initial speed
	particles.initial_velocity_min = 120.0
	particles.initial_velocity_max = 180.0

	# Mostly leftward
	particles.direction = Vector2(-1.0, 0.3)
	particles.spread = 55.0

	# Strong leftward pull, moderate downward
	particles.gravity = Vector2(-45.0, 30.0)

	# Explicitly zero — rules out hidden damping slowing them
	particles.damping_min = 0.0
	particles.damping_max = 0.0

	particles.color = color
	
	particles.scale = Vector2(0.3, 0.3)
	
	particles.emitting = randf() < 0.5

	# Re-roll every 3 in-game days
	var day_night = get_node_or_null("/root/main/day_night_overlay/ColorRect")
	var day_duration = day_night.day_duration if day_night else 300.0

	var roll_timer = Timer.new()
	roll_timer.wait_time = day_duration * 3.0
	roll_timer.timeout.connect(_on_leaf_roll)
	add_child(roll_timer)
	roll_timer.start()




func _on_leaf_roll():
	particles.emitting = randf() < 0.5
