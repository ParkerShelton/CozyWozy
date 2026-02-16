extends Node3D

# --------------------------------------------------
# Campfire Settings
# --------------------------------------------------
@export var light_radius: float = 0.8
@export var light_intensity: float = 1.5
@export var light_color: Color = Color(1.0, 0.7, 0.4)

@export var base_light_energy: float = 2.0
@export var flicker_strength: float = 0.35

# --------------------------------------------------
# Internal
# --------------------------------------------------
var fire_particles: GPUParticles3D
var smoke_particles: GPUParticles3D
var fire_light: OmniLight3D

var is_night: bool = true
var flicker_time: float = 0.0


func _ready():
	enable_light()
	create_fire()
	connect_day_night()


# --------------------------------------------------
# Day/Night Light Registration (your original system)
# --------------------------------------------------
func enable_light():
	call_deferred("register_with_day_night")
	
	var day_night = get_node_or_null("/root/main/DayNightOverlay/ColorRect")
	if day_night and day_night.material:
		day_night.material.set_shader_parameter("falloff_power", 3.5)


func register_with_day_night():
	var day_night = get_node_or_null("/root/main/day_night_overlay/ColorRect")
	if day_night and day_night.has_method("register_light"):
		day_night.register_light(self, light_radius, light_color, light_intensity)


func _exit_tree():
	var day_night = get_node_or_null("/root/main/day_night_overlay/ColorRect")
	if day_night and day_night.has_method("unregister_light"):
		day_night.unregister_light(self)


# --------------------------------------------------
# Create PS1-Style Fire + Smoke (Procedural)
# --------------------------------------------------
func create_fire():
	# ================= FIRE =================
	fire_particles = GPUParticles3D.new()
	add_child(fire_particles)

	fire_particles.amount = 50
	fire_particles.lifetime = 0.9
	fire_particles.local_coords = true
	fire_particles.position = Vector3(0, 0.05, 0)
	fire_particles.emitting = true

	var fire_mat = ParticleProcessMaterial.new()
	fire_particles.process_material = fire_mat

	fire_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	fire_mat.emission_sphere_radius = 0.06

	fire_mat.direction = Vector3(0, 1, 0)
	fire_mat.spread = 15.0
	fire_mat.initial_velocity_min = 0.8
	fire_mat.initial_velocity_max = 1.6
	fire_mat.gravity = Vector3(0, 0.4, 0)

	fire_mat.scale_min = 0.25
	fire_mat.scale_max = 0.5

	# PS1-style hard color steps
	var fire_grad = Gradient.new()
	fire_grad.add_point(0.0, Color(1.0, 0.9, 0.4, 1.0))
	fire_grad.add_point(0.4, Color(1.0, 0.4, 0.0, 1.0))
	fire_grad.add_point(0.8, Color(0.6, 0.0, 0.0, 0.8))
	fire_grad.add_point(1.0, Color(1.0, 0.0, 0.0, 0.0))

	var fire_ramp = GradientTexture1D.new()
	fire_ramp.gradient = fire_grad
	fire_mat.color_ramp = fire_ramp

	# Billboard quad
	var fire_quad = QuadMesh.new()
	fire_quad.size = Vector2(0.25, 0.35)
	fire_particles.draw_pass_1 = fire_quad

	var fire_draw_mat = StandardMaterial3D.new()
	fire_draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fire_draw_mat.vertex_color_use_as_albedo = true

	# Important for fire
	fire_draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fire_draw_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD

	fire_draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fire_draw_mat.albedo_color = Color(1.0, 0.9, 0.4, 1.0)

	fire_particles.material_override = fire_draw_mat




	# ================= LIGHT =================
	fire_light = OmniLight3D.new()
	add_child(fire_light)
	fire_light.light_color = light_color
	fire_light.omni_range = 4.0
	fire_light.light_energy = base_light_energy
	fire_light.position = Vector3(0, 0.4, 0)


# --------------------------------------------------
# Light Flicker (synced to fire)
# --------------------------------------------------
func _process(delta):
	if not is_night:
		return

	flicker_time += delta * 8.0

	var noise = sin(flicker_time) * 0.5 + sin(flicker_time * 2.7) * 0.3
	var flicker = 1.0 + noise * flicker_strength

	if fire_light:
		fire_light.light_energy = base_light_energy * flicker


# --------------------------------------------------
# Night-only activation
# --------------------------------------------------
func connect_day_night():
	var day_night = get_node_or_null("/root/main/day_night_overlay/ColorRect")
	if day_night:
		if day_night.has_signal("night_changed"):
			day_night.connect("night_changed", Callable(self, "_on_night_changed"))

		if day_night.has_method("is_night"):
			_on_night_changed(day_night.is_night())


func _on_night_changed(night: bool):
	is_night = night

	if fire_particles:
		fire_particles.emitting = night

	if smoke_particles:
		smoke_particles.emitting = night

	if fire_light:
		fire_light.visible = night


# --------------------------------------------------
# Safe Zone (unchanged)
# --------------------------------------------------
func _on_safe_zone_body_entered(body):
	if body.is_in_group("player"):
		body.heal_at_campfire()
		EnemyManager.enter_safe_zone()


func _on_safe_zone_body_exited(body):
	if body.is_in_group("player"):
		body.heal_at_campfire()
		EnemyManager.exit_safe_zone()
