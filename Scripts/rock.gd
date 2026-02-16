extends Node3D

var rock_health : int = 4
var current_health : int
var is_broken : bool = false

var min_pebbles : int = 1
var max_pebbles : int = 3

var rock_particles: GPUParticles3D

func _ready():
	current_health = rock_health

	var num_rock = randi_range(1,3)
	var rock = get_node("rock_" + str(num_rock))
	rock.rotation.y = randf_range(0, TAU) 
	rock.visible = true

func take_damage(dmg):
	if is_broken:
		return
		
	current_health -= dmg
	if current_health <= 0:
		break_rock()
	else:
		shake_rock()

func break_rock():
	is_broken = true
	remove_from_group("rock")
	spawn_pebbles()
	queue_free()

func spawn_pebbles():
	var num_pebbles = randi_range(min_pebbles, max_pebbles)
	
	# Load the generic dropped item scene and pebble icon
	var dropped_item_scene = load("res://Scenes/dropped_item.tscn")
	var pebble_icon = load("res://Assets/Icons/pebble.png")  # Adjust path
	
	for i in range(num_pebbles):
		if dropped_item_scene:
			var pebble = dropped_item_scene.instantiate()
			get_parent().add_child(pebble)
			
			var side_offset = Vector3(
				randf_range(-0.3, 0.3),
				0,
				randf_range(-0.3, 0.3)
			)
			
			pebble.global_position = global_position + side_offset
			pebble.global_position.y = 0.3
			
			# Setup the pebble
			if pebble.has_method("setup"):
				pebble.setup("pebble", 1, pebble_icon)
			else:
				print("ERROR: Pebble doesn't have setup method!")
			
			pebble.rotation.y = randf_range(0, TAU)


func shake_rock():
	create_rock_particles(position)
	
	var tween = create_tween()
	tween.tween_property(self, "rotation:z", 0.1, 0.1)
	tween.tween_property(self, "rotation:z", -0.1, 0.1)
	tween.tween_property(self, "rotation:z", 0, 0.1)	
	
	
	
func create_rock_particles(_pos:Vector3 = Vector3(0, 1.2, 0)):
	rock_particles = GPUParticles3D.new()
	add_child(rock_particles)

	rock_particles.amount = 18
	rock_particles.lifetime = 0.6
	rock_particles.one_shot = true
	rock_particles.explosiveness = 1.0
	rock_particles.local_coords = true
	rock_particles.emitting = false
	rock_particles.position = _pos

	var mat = ParticleProcessMaterial.new()
	rock_particles.process_material = mat

	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.15

	mat.direction = Vector3(0, 0.5, 0)
	mat.spread = 120.0

	mat.initial_velocity_min = 2.5
	mat.initial_velocity_max = 5.0

	mat.gravity = Vector3(0, -9.0, 0)

	mat.scale_min = 0.05
	mat.scale_max = 0.12

	mat.angular_velocity_min = -10.0
	mat.angular_velocity_max = 10.0

	# Bark colors
	mat.color = Color(0.177, 0.204, 0.212, 1.0)

	var quad = QuadMesh.new()
	quad.size = Vector2(0.2, 0.2)
	rock_particles.draw_pass_1 = quad

	var draw_mat = StandardMaterial3D.new()
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.vertex_color_use_as_albedo = true
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED

	rock_particles.material_override = draw_mat
