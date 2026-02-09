# bird.gd
extends Node3D

var fly_speed: float = 15.0
var fly_direction: Vector3 = Vector3.ZERO
var lifetime: float = 5.0  # Despawn after 5 seconds

func _ready():
	$bird/AnimationPlayer.play("fly")
	randomize_bird_colors()
	
	# Random horizontal direction
	var angle = randf() * TAU
	fly_direction = Vector3(
		cos(angle),
		randf_range(0.5, 1.0),  # Upward component (0.5 to 1.0)
		sin(angle)
	).normalized()
	
	# Rotate bird to face flight direction
	look_at(global_position + fly_direction, Vector3.UP)
	
	# Auto-despawn after lifetime
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _process(delta):
	# Fly in the direction
	global_position += fly_direction * fly_speed * delta
	
	# Optional: Add slight bobbing animation
	global_position.y += sin(Time.get_ticks_msec() / 100.0) * 0.01
	
	
	
func randomize_bird_colors():
	# Create instance-specific RNG for unique colors per horse
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(get_instance_id())
	
	var mesh = $bird/rig/Skeleton3D/lowpoly_bird
	
	var body_color_index = rng.randi() % 7

	var body_shader = load("res://Shaders/Animals/bird.gdshader")
	var body_material = ShaderMaterial.new()
	body_material.shader = body_shader
	body_material.set_shader_parameter("selected_color", body_color_index)
	mesh.material_override = body_material
