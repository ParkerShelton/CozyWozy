extends Area3D

var damage: float = 10.0
var velocity: Vector3 = Vector3.ZERO
var speed: float = 20.0
var is_deflected: bool = false  # Track if deflected

func _ready():
	body_entered.connect(_on_body_entered)
	
	# Set initial collision layers
	# Layer 1: can hit player
	# Layer 2: can be blocked by player
	collision_layer = 1
	collision_mask = 4 | 8  # Detects player
	add_electric_particles()
	add_electric_rings()

func add_electric_particles():
	var particles = GPUParticles3D.new()
	add_child(particles)
	
	particles.emitting = true
	particles.amount = 30
	particles.lifetime = 0.4
	particles.one_shot = false
	particles.explosiveness = 0.0
	particles.randomness = 0.5
	
	# Create process material for particle behavior
	var process_mat = ParticleProcessMaterial.new()
	
	# Emission from a small sphere around bullet
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_mat.emission_sphere_radius = 0.2
	
	# Particles shoot outward in random directions
	process_mat.direction = Vector3(0, 0, 0)
	process_mat.spread = 180.0
	process_mat.initial_velocity_min = 1.0
	process_mat.initial_velocity_max = 3.0
	
	# No gravity - float around
	process_mat.gravity = Vector3.ZERO
	
	# Fade out over lifetime
	process_mat.scale_min = 0.05
	process_mat.scale_max = 0.15
	process_mat.scale_curve = create_fade_curve()
	
	# Electric blue color
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(0.8, 0.9, 1.0, 1.0))  # Bright cyan start
	gradient.add_point(0.5, Color(0.2, 0.5, 1.0, 0.8))  # Blue middle
	gradient.add_point(1.0, Color(0.1, 0.3, 0.8, 0.0))  # Dark blue fade out
	
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	process_mat.color_ramp = gradient_texture
	
	particles.process_material = process_mat
	
	# Use a simple quad mesh for particles
	var quad_mesh = QuadMesh.new()
	quad_mesh.size = Vector2(0.1, 0.1)
	
	# Make particles glow
	var particle_material = StandardMaterial3D.new()
	particle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	particle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	particle_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD  # Additive blending for glow
	particle_material.albedo_color = Color(0.5, 0.7, 1.0)
	particle_material.emission_enabled = true
	particle_material.emission = Color(0.5, 0.7, 1.0)
	particle_material.emission_energy_multiplier = 2.0
	particle_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	
	quad_mesh.material = particle_material
	particles.draw_pass_1 = quad_mesh

func create_fade_curve() -> Curve:
	var curve = Curve.new()
	curve.add_point(Vector2(0.0, 1.0))  # Start full size
	curve.add_point(Vector2(1.0, 0.0))  # Fade to nothing
	return curve
func _physics_process(delta):
	global_position += velocity * delta
	
	for child in get_children():
		if child.has_meta("rotation_speed"):
			var speed = child.get_meta("rotation_speed")
			child.rotate_y(speed * delta)

func set_velocity(new_velocity: Vector3):
	velocity = new_velocity

func _on_body_entered(body):
	print("Bullet hit: ", body.name, " Groups: ", body.get_groups())
	
	# If deflected, only hurt enemies
	if is_deflected:
		if body.is_in_group("enemies"):
			print("Deflected bullet hit enemy!")
			if body.has_method("take_damage"):
				body.take_damage(damage * 1.5)  # Extra damage when deflected
			queue_free()
		return
	
	# Not deflected - check if hitting player
	if body.is_in_group("player"):
		if body.is_blocking and body.equipped_shield:
			deflect_bullet(body)
			return
		else:
			if body.has_method("take_damage"):
				body.take_damage(damage)
			queue_free()
	else:
		# Hit terrain/object
		queue_free()
		
		
		
		
func deflect_bullet(player):
	print("Bullet deflected by shield!")
	
	# Visual feedback
	if player.has_method("_on_bullet_deflected"):
		player._on_bullet_deflected()
	
	# Simple reflection: reverse the bullet direction
	var bullet_direction = velocity.normalized()
	
	# Reflect straight back (opposite direction)
	var deflected_direction = -bullet_direction
	
	# Apply new velocity - send it back where it came from
	velocity = deflected_direction * velocity.length() * 1.5  # Faster on return
	
	# Optional: Add slight randomness so bullets don't all go exactly the same way
	var random_offset = Vector3(randf_range(-0.1, 0.1), randf_range(-0.05, 0.05), randf_range(-0.1, 0.1))
	velocity += random_offset * velocity.length()
	
	# Change collision layers so bullet now hits enemies
	collision_layer = 4  # Different layer
	collision_mask = 4   # Only collide with enemies
	
	# Change monitoring so it only detects enemies now
	set_collision_mask_value(1, false)  # Stop detecting player
	set_collision_mask_value(2, true)   # Start detecting enemies (assuming enemies are on layer 2)


func add_electric_rings():
	# Create 2-3 rotating rings
	for i in range(3):
		var ring = create_electric_ring()
		add_child(ring)
		
		# Offset each ring's rotation axis
		ring.rotation_degrees = Vector3(randf_range(0, 360), randf_range(0, 360), randf_range(0, 360))
		
		# Different speeds for each ring
		var rotation_speed = randf_range(3.0, 6.0) * (1 if i % 2 == 0 else -1)
		ring.set_meta("rotation_speed", rotation_speed)

func create_electric_ring() -> Node3D:
	var ring_node = Node3D.new()
	
	var mesh_instance = MeshInstance3D.new()
	ring_node.add_child(mesh_instance)
	
	var torus = TorusMesh.new()
	torus.inner_radius = 0.35
	torus.outer_radius = 0.37  # Very thin ring
	torus.rings = 48
	torus.ring_segments = 6
	
	mesh_instance.mesh = torus
	
	# Shader material for pulsing rings
	var shader_material = ShaderMaterial.new()
	var shader_code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add;

void fragment() {
	float pulse = sin(TIME * 10.0) * 0.5 + 0.5;
	vec3 color = vec3(0.3, 0.6, 1.0);
	
	ALBEDO = color;
	EMISSION = color * (2.0 + pulse * 2.0);
	ALPHA = 0.7 + pulse * 0.3;
}
"""
	var shader = Shader.new()
	shader.code = shader_code
	shader_material.shader = shader
	
	mesh_instance.material_override = shader_material
	
	return ring_node
