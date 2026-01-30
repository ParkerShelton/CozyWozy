extends BaseEnemy

# Explosion variables
var explosion_damage: float = 30.0
var explosion_radius: float = 3.0
var fuse_time: float = 1.0  # Time before exploding
var is_fusing: bool = false
var fuse_timer: float = 0.0

# Visual warning
var is_flashing: bool = false

func _ready():
	await super._ready()
	
	# Kamikaze stats - fast and fragile
	max_health = 1.0
	current_health = 3.0
	move_speed = 6.0  # Fast!
	attack_damage = 0.0  # Doesn't melee attack
	attack_range = 2.0  # When to start fusing
	detection_range = 12.0
	exp_reward = 8
	
	drop_items = [
		{"item_name": "iron", "drop_chance": 0.5, "min_amount": 1, "max_amount": 2}
	]

# Override chase - just run at player
func chase_behavior(delta):
	if not player or not is_instance_valid(player):
		current_state = State.IDLE
		return
	
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

# Override attack behavior - handle the fuse countdown
func attack_behavior(delta):
	if not player or not is_instance_valid(player):
		current_state = State.IDLE
		return
	
	# Face player while fusing
	look_at(player.global_position, Vector3.UP)
	rotation.x = 0
	rotation.z = 0
	
	# Stop moving
	velocity = Vector3.ZERO
	move_and_slide()
	
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
	print(name, " EXPLODED!")
	
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
	
	# TODO: Create explosion visual effect here
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
	# Create a temporary explosion sphere
	var explosion = MeshInstance3D.new()
	get_tree().root.add_child(explosion)
	
	var sphere = SphereMesh.new()
	sphere.radius = explosion_radius
	sphere.height = explosion_radius * 2
	explosion.mesh = sphere
	
	explosion.global_position = global_position
	
	# Glowing orange/red material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.5, 0.0, 0.7)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.3, 0.0)
	material.emission_energy_multiplier = 5.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	explosion.material_override = material
	
	# Animate explosion
	var tween = create_tween()
	tween.tween_property(explosion, "scale", Vector3(2, 2, 2), 0.3)
	tween.parallel().tween_property(material, "albedo_color:a", 0.0, 0.3)
	tween.tween_callback(explosion.queue_free)
