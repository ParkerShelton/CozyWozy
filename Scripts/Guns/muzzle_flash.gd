extends Node3D

var particles: GPUParticles3D
var light: OmniLight3D

func _ready():
	# Create particles
	particles = GPUParticles3D.new()
	add_child(particles)
	
	particles.amount = 12
	particles.one_shot = true
	particles.lifetime = 0.2
	particles.explosiveness = 1.0
	
	# Process material
	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 1)
	mat.spread = 25.0
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 6.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.05
	mat.scale_max = 0.15
	
	# Color ramp: yellow -> orange -> red -> transparent
	var gradient = Gradient.new()
	gradient.set_offset(0, 0.0)
	gradient.set_color(0, Color(1.0, 0.9, 0.3, 1.0))
	gradient.add_point(0.4, Color(1.0, 0.5, 0.1, 1.0))
	gradient.add_point(0.7, Color(0.8, 0.1, 0.0, 0.6))
	gradient.set_offset(1, 1.0)
	gradient.set_color(1, Color(0.3, 0.0, 0.0, 0.0))
	
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	mat.color_ramp = gradient_texture
	
	particles.process_material = mat
	
	# Draw pass - small sphere
	var sphere = SphereMesh.new()
	sphere.radius = 0.05
	sphere.height = 0.1
	
	var sphere_mat = StandardMaterial3D.new()
	sphere_mat.emission_enabled = true
	sphere_mat.emission = Color(1.0, 0.5, 0.0)
	sphere_mat.emission_energy_multiplier = 2.0
	sphere_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sphere_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sphere_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere.material = sphere_mat
	
	particles.draw_pass_1 = sphere
	
	# Light flash
	light = OmniLight3D.new()
	add_child(light)
	light.light_color = Color(1.0, 0.6, 0.2)
	light.light_energy = 3.0
	light.omni_range = 3.0
	light.omni_attenuation = 2.0
	
	# Start
	particles.emitting = true
	
	var tween = create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.15)
	
	await get_tree().create_timer(particles.lifetime + 0.1).timeout
	queue_free()
