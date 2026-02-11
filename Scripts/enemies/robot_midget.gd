extends BaseEnemy

# Explosion variables
var explosion_damage: float = 30.0
var explosion_radius: float = 3.0
var fuse_time: float = 1.0  # Time before exploding
var is_fusing: bool = false
var fuse_timer: float = 0.0

# Visual warning
var is_flashing: bool = false

# Audio
var audio_player: AudioStreamPlayer = null
var has_played_notice_sound: bool = false
var walk_audio_player: AudioStreamPlayer = null


@onready var anim_player_1 = $robot_midget/AnimationPlayer  # Leg 1
@onready var anim_player_2 = $robot_midget/AnimationPlayer2  # Leg 2
@onready var anim_player_3 = $robot_midget/AnimationPlayer3  # Leg 3
@onready var anim_player_4 = $robot_midget/AnimationPlayer4  # Leg 4

func _ready():
	await super._ready()
	setup_audio()
	
	# Kamikaze stats - fast and fragile
	max_health = 1.0
	current_health = 3.0
	move_speed = 6.0  # Fast!
	attack_damage = 0.0  # Doesn't melee attack
	attack_range = 2.0  # When to start fusing
	detection_range = 22.0
	exp_reward = 8
	
	drop_items = [
		{"item_name": "iron", "drop_chance": 0.5, "min_amount": 1, "max_amount": 2}
	]

# Override to fix kamikaze robot facing backwards
func move_toward_target(target_pos: Vector3, delta):
	var direction = (target_pos - global_position).normalized()
	direction.y = 0
	
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	
	move_and_slide()
	
	# Fixed rotation for kamikaze
	if direction.length() > 0.1:
		var target_rotation = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, 10.0 * delta)
		rotation.x = 0
		rotation.z = 0

# Override chase - just run at player
func chase_behavior(delta):
	if not player or not is_instance_valid(player):
		current_state = State.IDLE
		return
	
	# Play notice sound when first detecting player
	if not has_played_notice_sound:
		play_notice_sound()
		has_played_notice_sound = true
	
	var distance = global_position.distance_to(player.global_position)
	
	# Lost player
	if distance > detection_range * 1.5:
		current_state = State.IDLE
		return
	
	# Close enough - start fusing!
	if distance <= attack_range and not is_fusing:
		start_fuse()
		return
	
	# Chase player at full speed
	move_toward_target(player.global_position, delta)
	update_walk_sound()

# Override attack behavior - handle the fuse countdown
func attack_behavior(delta):
	if not player or not is_instance_valid(player):
		current_state = State.IDLE
		return
	
	if walk_audio_player and walk_audio_player.playing:
		walk_audio_player.stop()
	
	# Face player while fusing
	look_at(player.global_position, Vector3.UP)
	rotation.x = 0
	rotation.z = 0
	
	# Stop moving
	velocity = Vector3.ZERO
	rotation.y += 10
	
	# Count down fuse
	if is_fusing:
		fuse_timer += delta
		
		# Flash faster as explosion approaches
		var flash_speed = 5.0 + (fuse_timer / fuse_time) * 15.0
		handle_flash(delta, flash_speed)
		
		# Explode!
		if fuse_timer >= fuse_time:
			explode()

func start_fuse():
	print(name, " started fusing!")
	is_fusing = true
	fuse_timer = 0.0
	current_state = State.ATTACK
	
	# Visual/audio cue here (beeping sound, etc.)

func handle_flash(_delta, speed):
	# Flash the mesh red to warn player
	var mesh_node = get_node_or_null("MeshInstance3D")  # Adjust to your mesh path
	if mesh_node:
		# Simple flash by modulating opacity
		var flash = abs(sin(fuse_timer * speed))
		mesh_node.modulate = Color(1.0, flash, flash)  # Red flash

func explode():
	
	# Play explosion sound 
	play_explosion_sound()
	
	# Deal damage to player if in range
	if player and is_instance_valid(player):
		var distance = global_position.distance_to(player.global_position)
		
		if distance <= explosion_radius:
			# Damage falls off with distance
			var damage_multiplier = 1.0 - (distance / explosion_radius)
			var actual_damage = explosion_damage * damage_multiplier
			
			if player.has_method("take_damage"):
				player.take_damage(actual_damage)
				print("Hit player for ", actual_damage, " damage!")

	spawn_explosion_effect()
	
	# Die
	current_state = State.DEAD
	queue_free()

# Override perform_attack - don't use base melee
func perform_attack():
	pass  # Kamikaze doesn't melee attack

# If damaged while fusing, reduce fuse time (gets angry)
func take_damage(amount: float):
	super.take_damage(amount)
	
	# Speed up explosion when damaged
	if is_fusing:
		fuse_timer += 0.5  # Jump forward in fuse timer
		print(name, " is damaged - explosion accelerated!")
		
func spawn_explosion_effect():
	# Create explosion container
	var explosion_container = Node3D.new()
	get_tree().root.add_child(explosion_container)
	explosion_container.global_position = global_position
	
	# INNER CORE - bright white/yellow
	var core = MeshInstance3D.new()
	explosion_container.add_child(core)
	var core_sphere = SphereMesh.new()
	core_sphere.radius = 0.5
	core.mesh = core_sphere
	
	var core_mat = StandardMaterial3D.new()
	core_mat.albedo_color = Color(1.0, 1.0, 0.8, 1.0)
	core_mat.emission_enabled = true
	core_mat.emission = Color(1.0, 0.9, 0.5)
	core_mat.emission_energy_multiplier = 10.0
	core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core.material_override = core_mat
	
	# OUTER BLAST - orange/red
	var blast = MeshInstance3D.new()
	explosion_container.add_child(blast)
	var blast_sphere = SphereMesh.new()
	blast_sphere.radius = explosion_radius * 0.8
	blast.mesh = blast_sphere
	
	var blast_mat = StandardMaterial3D.new()
	blast_mat.albedo_color = Color(1.0, 0.4, 0.0, 0.6)
	blast_mat.emission_enabled = true
	blast_mat.emission = Color(1.0, 0.3, 0.0)
	blast_mat.emission_energy_multiplier = 5.0
	blast_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blast.material_override = blast_mat
	
	# SHOCKWAVE RING
	var shockwave = MeshInstance3D.new()
	explosion_container.add_child(shockwave)
	var ring_mesh = TorusMesh.new()
	ring_mesh.inner_radius = explosion_radius * 0.5
	ring_mesh.outer_radius = explosion_radius * 0.7
	shockwave.mesh = ring_mesh
	shockwave.rotation.x = PI / 2  # Make it horizontal
	
	var ring_mat = StandardMaterial3D.new()
	ring_mat.albedo_color = Color(1.0, 0.7, 0.3, 0.8)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(1.0, 0.5, 0.0)
	ring_mat.emission_energy_multiplier = 3.0
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shockwave.material_override = ring_mat
	
	# PARTICLE EFFECT 1: Explosion Sparks (flying outward)
	var sparks = GPUParticles3D.new()
	explosion_container.add_child(sparks)
	sparks.amount = 50
	sparks.lifetime = 0.5
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.emitting = true
	
	var sparks_mat = ParticleProcessMaterial.new()
	sparks_mat.direction = Vector3(0, 1, 0)
	sparks_mat.spread = 180.0  # Emit in all directions
	sparks_mat.initial_velocity_min = 8.0
	sparks_mat.initial_velocity_max = 15.0
	sparks_mat.gravity = Vector3(0, -9.8, 0)
	sparks_mat.scale_min = 0.1
	sparks_mat.scale_max = 0.3
	sparks_mat.color = Color(1.0, 0.7, 0.2)
	sparks.process_material = sparks_mat
	
	# Spark mesh (small spheres)
	var spark_mesh = SphereMesh.new()
	spark_mesh.radius = 0.1
	sparks.draw_pass_1 = spark_mesh
	
	# PARTICLE EFFECT 2: Smoke Cloud (exploding outward, MUCH LARGER)
	var smoke = GPUParticles3D.new()
	explosion_container.add_child(smoke)
	smoke.amount = 40
	smoke.lifetime = 1.5
	smoke.one_shot = true
	smoke.explosiveness = 1.0  # All at once
	smoke.emitting = true
	
	var smoke_mat = ParticleProcessMaterial.new()
	smoke_mat.direction = Vector3(0, 0.3, 0)  # Slightly upward
	smoke_mat.spread = 180.0  # All directions
	smoke_mat.initial_velocity_min = 4.0
	smoke_mat.initial_velocity_max = 8.0
	smoke_mat.gravity = Vector3(0, 0.5, 0)  # Slight upward drift
	smoke_mat.scale_min = 0.8  # Smaller
	smoke_mat.scale_max = 1.5  # Smaller
	smoke_mat.color = Color(0.3, 0.3, 0.3, 0.7)
	smoke_mat.color_ramp = create_smoke_gradient()
	smoke.process_material = smoke_mat
	
	# Smoke mesh (medium spheres)
	var smoke_mesh = SphereMesh.new()
	smoke_mesh.radius = 0.6  # Smaller base size
	smoke.draw_pass_1 = smoke_mesh
	
	# PARTICLE EFFECT 3: Fire Burst (exploding outward)
	var fire = GPUParticles3D.new()
	explosion_container.add_child(fire)
	fire.amount = 60
	fire.lifetime = 0.4
	fire.one_shot = true
	fire.explosiveness = 1.0  # All at once
	fire.emitting = true
	
	var fire_mat = ParticleProcessMaterial.new()
	fire_mat.direction = Vector3(0, 0.2, 0)  # Mostly outward
	fire_mat.spread = 180.0  # All directions
	fire_mat.initial_velocity_min = 6.0
	fire_mat.initial_velocity_max = 12.0
	fire_mat.gravity = Vector3(0, -2.0, 0)  # Slight downward
	fire_mat.scale_min = 0.4
	fire_mat.scale_max = 1.0
	fire_mat.color_ramp = create_fire_gradient()
	fire.process_material = fire_mat
	
	# Fire mesh
	var fire_mesh = SphereMesh.new()
	fire_mesh.radius = 0.3
	fire.draw_pass_1 = fire_mesh
	
	# ANIMATE EXPLOSION
	var tween = explosion_container.create_tween()
	tween.set_parallel(true)
	
	# Core expansion and fade
	tween.tween_property(core, "scale", Vector3(3, 3, 3), 0.2)
	tween.tween_property(core_mat, "albedo_color:a", 0.0, 0.2)
	
	# Blast wave expansion and fade
	tween.tween_property(blast, "scale", Vector3(2.5, 2.5, 2.5), 0.35)
	tween.tween_property(blast_mat, "albedo_color:a", 0.0, 0.35)
	
	# Shockwave ring expansion
	tween.tween_property(shockwave, "scale", Vector3(4, 4, 1), 0.4)
	tween.tween_property(ring_mat, "albedo_color:a", 0.0, 0.4)
	
	# Cleanup after particles finish (wait longer for larger smoke)
	tween.chain().tween_interval(1.5)
	tween.tween_callback(explosion_container.queue_free)

# Helper function to create fire gradient (yellow to red to black)
func create_fire_gradient() -> GradientTexture1D:
	var gradient = Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 0.5, 1.0))  # Bright yellow
	gradient.set_color(1, Color(1.0, 0.2, 0.0, 0.0))  # Red fading out
	
	var grad_texture = GradientTexture1D.new()
	grad_texture.gradient = gradient
	return grad_texture

# Helper function to create smoke gradient (dark gray fading out)
func create_smoke_gradient() -> GradientTexture1D:
	var gradient = Gradient.new()
	gradient.set_color(0, Color(0.4, 0.4, 0.4, 0.8))  # Dark gray
	gradient.set_color(1, Color(0.2, 0.2, 0.2, 0.0))  # Fade to transparent
	
	var grad_texture = GradientTexture1D.new()
	grad_texture.gradient = gradient
	return grad_texture


func setup_audio():
	# Notice sound
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	
	var notice_sound = load("res://Assets/SFX/robot_midget_notice.mp3")
	if notice_sound:
		audio_player.stream = notice_sound
		audio_player.volume_db = -10.0
		print("✓ Notice audio loaded")
	else:
		push_error("✗ Failed to load robot_midget_notice.mp3")
	
	# Walking sound (looping)
	walk_audio_player = AudioStreamPlayer.new()
	add_child(walk_audio_player)
	
	var walk_sound = load("res://Assets/SFX/robot_midget_walk_1.mp3")
	if walk_sound:
		walk_audio_player.stream = walk_sound
		walk_audio_player.volume_db = -20.0  # Adjust as needed
		walk_audio_player.pitch_scale = 2.0  # Play faster for quick footsteps
		print("✓ Walk audio loaded")
	else:
		push_error("✗ Failed to load robot_midget_walk.wav")
		
		
func play_notice_sound():
	if audio_player and audio_player.stream:
		audio_player.play()

func play_explosion_sound():
	# Use 2D audio - simpler and more reliable
	var explosion_player = AudioStreamPlayer.new()
	get_tree().root.add_child(explosion_player)
	
	# Load and play explosion sound
	var explosion_sound = load("res://Assets/SFX/robot_midget_explosion.wav")
	
	if explosion_sound:
		explosion_player.stream = explosion_sound
		explosion_player.volume_db = -6.0  # Adjust as needed
		explosion_player.play()
		
		# Cleanup when done
		explosion_player.finished.connect(explosion_player.queue_free)
	else:
		push_error("✗ Failed to load robot_midget_explosion.wav")
		explosion_player.queue_free()


func update_walk_sound():
	# Only play walk sound when moving and alive
	if current_state == State.DEAD:
		if walk_audio_player and walk_audio_player.playing:
			walk_audio_player.stop()
		return
	
	var is_moving = velocity.length() > 0.1
	
	if is_moving:
		# Start walking sound if not already playing
		if walk_audio_player and not walk_audio_player.playing:
			walk_audio_player.play()
		
		# Check if sound finished and needs to loop
		if walk_audio_player and not walk_audio_player.playing:
			# Add small delay before next loop (adjust this value)
			await get_tree().create_timer(0.5).timeout  # 0.1 second pause between loops
			
			# Only restart if still moving
			if velocity.length() > 0.1 and current_state != State.DEAD:
				walk_audio_player.pitch_scale = randf_range(1.8, 5.2)
				walk_audio_player.play()
	else:
		# Stop walking sound when not moving
		if walk_audio_player and walk_audio_player.playing:
			walk_audio_player.stop()
