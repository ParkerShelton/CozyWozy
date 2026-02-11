extends BaseEnemy

# Flying movement
var fly_speed: float = 4.0
var default_hover_height: float = 3.0
var bob_speed: float = 2.0
var bob_amount: float = 0.3
var sway_amount: float = 0.5
var fly_time: float = 0.0

# Shoot mode states
enum ShootState { NONE, FLYING_TO_POSITION, HOVERING, WARNING, FIRING, COOLDOWN, FALLING }
var shoot_state: ShootState = ShootState.NONE

# Shoot config
var shoot_range: float = 12.0
var shoot_cooldown: float = 15.0
var hover_offset_distance: float = 6.0
var fly_up_speed: float = 5.0
var attack_hover_height: float = 5.0

# Warning beam
var warning_flash_count: int = 3
var warning_flash_duration: float = 0.3
var warning_gap_duration: float = 0.2

# Main beam
var beam_damage_per_tick: float = 2.0
var beam_tick_rate: float = 0.2
var beam_duration: float = 3.0
var beam_lift_speed: float = 3.0
var beam_max_lift: float = 5.0

# Internal
var beam_timer: float = 0.0
var hover_target_pos: Vector3 = Vector3.ZERO
var can_shoot: bool = true
var is_lifting_player: bool = false
var locked_target_pos: Vector3 = Vector3.ZERO
var fall_velocity: float = 0.0
var ground_chase_speed: float = 3.0

# Ground spin attack
enum SpinState { NONE, WARNING, PAUSE, FIRING }
var spin_state: SpinState = SpinState.NONE
var ground_attack_range: float = 8.0
var spin_speed: float = 0.8  # Full rotations per second
var spin_duration: float = 3.0
var spin_beam_length: float = 10.0
var spin_beam_height: float = 1.0  # Height of beam above ground
var spin_damage: float = 5.0
var spin_damage_tick: float = 0.3
var spin_damage_timer: float = 0.0
var ground_attack_cooldown: float = 6.0
var can_ground_attack: bool = true
var is_spin_attacking: bool = false
var spin_timer: float = 0.0
var spin_angle: float = 0.0
var spin_warning_duration: float = 1.5
var spin_warning_flash_speed: float = 8.0  # Flashes per second
var spin_pause_duration: float = 0.3

# Beam meshes
var warning_beam: MeshInstance3D = null
var main_beam: MeshInstance3D = null
var beam_origin: Node3D = null
var spin_warning_circle: MeshInstance3D = null

func _ready():
	await super._ready()
	beam_origin = find_child("BeamOrigin", true, false)
	_create_beam_meshes()

func _create_beam_meshes():
	# Warning beam (thin red)
	warning_beam = MeshInstance3D.new()
	var warn_mesh = CylinderMesh.new()
	warn_mesh.top_radius = 0.02
	warn_mesh.bottom_radius = 0.02
	warn_mesh.height = 1.0
	warning_beam.mesh = warn_mesh

	var warn_mat = StandardMaterial3D.new()
	warn_mat.albedo_color = Color(1.0, 0.0, 0.0, 0.8)
	warn_mat.emission_enabled = true
	warn_mat.emission = Color(1.0, 0.0, 0.0)
	warn_mat.emission_energy_multiplier = 3.0
	warn_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	warning_beam.material_override = warn_mat
	add_child(warning_beam)
	warning_beam.visible = false

	# Main beam (thick blue)
	main_beam = MeshInstance3D.new()
	var main_mesh = CylinderMesh.new()
	main_mesh.top_radius = 0.15
	main_mesh.bottom_radius = 0.15
	main_mesh.height = 1.0
	main_beam.mesh = main_mesh

	var main_mat = StandardMaterial3D.new()
	main_mat.albedo_color = Color(0.2, 0.4, 1.0, 0.7)
	main_mat.emission_enabled = true
	main_mat.emission = Color(0.3, 0.5, 1.0)
	main_mat.emission_energy_multiplier = 5.0
	main_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	main_beam.material_override = main_mat
	add_child(main_beam)
	main_beam.visible = false

	# Spin warning circle (flat red disc on the ground)
	spin_warning_circle = MeshInstance3D.new()
	var circle_mesh = CylinderMesh.new()
	circle_mesh.top_radius = spin_beam_length
	circle_mesh.bottom_radius = spin_beam_length
	circle_mesh.height = 0.05
	spin_warning_circle.mesh = circle_mesh

	var circle_mat = StandardMaterial3D.new()
	circle_mat.albedo_color = Color(1.0, 0.0, 0.0, 0.3)
	circle_mat.emission_enabled = true
	circle_mat.emission = Color(1.0, 0.0, 0.0)
	circle_mat.emission_energy_multiplier = 2.0
	circle_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	circle_mat.no_depth_test = true
	spin_warning_circle.material_override = circle_mat
	add_child(spin_warning_circle)
	spin_warning_circle.visible = false

# Override the entire physics process — no gravity, fully airborne
func _physics_process(delta):
	if current_state == State.DEAD:
		_stop_beam_attack()
		return

	check_despawn(delta)
	fly_time += delta

	# Ground spin attack runs every frame for smooth rotation
	if spin_state != SpinState.NONE:
		_handle_spin_attack(delta)
		move_and_slide()
		return

	if shoot_state != ShootState.NONE:
		_handle_shoot_mode(delta)
		move_and_slide()
		return

	# Normal flying behavior per state
	match current_state:
		State.IDLE:
			_flying_idle(delta)
		State.PATROL:
			_flying_idle(delta)
		State.CHASE:
			_flying_chase(delta)
		State.ATTACK:
			_flying_attack(delta)

	if knockback_velocity.length() > 0.1:
		velocity += knockback_velocity
		knockback_velocity = knockback_velocity.lerp(Vector3.ZERO, knockback_friction * delta)

	move_and_slide()

func _flying_idle(delta):
	# Hover in place with bob
	var bob = sin(fly_time * bob_speed) * bob_amount
	velocity = Vector3(0, bob, 0)
	check_for_player()

func _flying_chase(delta):
	if not player or not is_instance_valid(player):
		current_state = State.IDLE
		return

	var distance_to_player = global_position.distance_to(player.global_position)

	if distance_to_player > detection_range * 1.5:
		current_state = State.IDLE
		return

	if distance_to_player <= shoot_range and can_shoot:
		current_state = State.ATTACK
		return

	if can_shoot:
		# Fly toward player, staying above them
		var target_pos = player.global_position + Vector3(0, default_hover_height, 0)
		var direction = (target_pos - global_position).normalized()
		velocity = direction * fly_speed
		velocity.y += sin(fly_time * bob_speed) * bob_amount
	else:
		# On the ground — chase on foot with gravity
		var direction = (player.global_position - global_position).normalized()
		direction.y = 0
		velocity.x = direction.x * ground_chase_speed
		velocity.z = direction.z * ground_chase_speed

		if not is_on_floor():
			velocity.y -= 9.8 * delta
		else:
			velocity.y = 0

		# Trigger ground spin attack when close enough
		if can_ground_attack and not is_spin_attacking and distance_to_player <= ground_attack_range:
			_start_ground_spin_attack()
			return

	_face_player()

func _flying_attack(_delta):
	if not player or not is_instance_valid(player):
		current_state = State.IDLE
		return

	var distance = global_position.distance_to(player.global_position)

	if distance > shoot_range * 1.3:
		current_state = State.CHASE
		return

	if can_shoot:
		_start_shoot_mode()
		return

	# Hover while waiting for cooldown
	var bob = sin(fly_time * bob_speed) * bob_amount
	velocity = Vector3(0, bob, 0)
	_face_player()

# --- Shoot mode ---

func _start_shoot_mode():
	if not player or not is_instance_valid(player):
		return
	shoot_state = ShootState.FLYING_TO_POSITION
	_calculate_hover_target()

func _calculate_hover_target():
	var dir_from_player = (global_position - player.global_position).normalized()
	dir_from_player.y = 0
	if dir_from_player.length() < 0.1:
		dir_from_player = Vector3.FORWARD

	var right = dir_from_player.cross(Vector3.UP).normalized()
	var random_offset = right * randf_range(-sway_amount, sway_amount)

	hover_target_pos = player.global_position + (dir_from_player * hover_offset_distance) + Vector3(0, attack_hover_height, 0) + random_offset

func _handle_shoot_mode(delta):
	if not player or not is_instance_valid(player):
		_stop_beam_attack()
		return

	match shoot_state:
		ShootState.FLYING_TO_POSITION:
			_fly_to_hover_position(delta)
		ShootState.HOVERING:
			_hover_behavior(delta)
		ShootState.WARNING:
			_hover_behavior(delta)
			_update_beam_to_locked_target()
		ShootState.FIRING:
			_hover_behavior_no_rotate(delta)
			_update_beam_to_locked_target()
		ShootState.COOLDOWN:
			_hover_behavior(delta)
		ShootState.FALLING:
			_fall_to_ground(delta)

func _fly_to_hover_position(delta):
	var direction = hover_target_pos - global_position
	var distance = direction.length()

	if distance < 0.5:
		shoot_state = ShootState.HOVERING
		_start_warning_sequence()
		return

	velocity = direction.normalized() * fly_up_speed
	_face_player()

func _hover_behavior(delta):
	var bob = sin(fly_time * bob_speed) * bob_amount
	var sway_x = sin(fly_time * bob_speed * 0.7) * sway_amount
	var sway_z = cos(fly_time * bob_speed * 0.5) * sway_amount

	var target = hover_target_pos + Vector3(sway_x, bob, sway_z)
	var direction = target - global_position
	velocity = direction * 3.0

	_face_player()

func _hover_behavior_no_rotate(delta):
	var bob = sin(fly_time * bob_speed) * bob_amount
	var sway_x = sin(fly_time * bob_speed * 0.7) * sway_amount
	var sway_z = cos(fly_time * bob_speed * 0.5) * sway_amount

	var target = hover_target_pos + Vector3(sway_x, bob, sway_z)
	var direction = target - global_position
	velocity = direction * 3.0

func _start_warning_sequence():
	shoot_state = ShootState.WARNING

	for i in range(warning_flash_count):
		if current_state == State.DEAD or shoot_state != ShootState.WARNING:
			_stop_beam_attack()
			return

		# Lock onto where the player IS right now for this flash
		_lock_target_position()

		warning_beam.visible = true
		_update_beam_to_locked_target()
		await get_tree().create_timer(warning_flash_duration).timeout

		warning_beam.visible = false
		await get_tree().create_timer(warning_gap_duration).timeout

	# Main beam fires at the LAST locked position — player can dodge after seeing it
	if current_state != State.DEAD and shoot_state == ShootState.WARNING:
		_start_main_beam()

func _lock_target_position():
	if player and is_instance_valid(player):
		locked_target_pos = player.global_position + Vector3(0, 1.0, 0)

func _start_main_beam():
	shoot_state = ShootState.FIRING
	warning_beam.visible = false
	main_beam.visible = true
	beam_timer = 0.0
	is_lifting_player = false

	# Check initial hit — only start lifting if player is near the locked XZ position
	var player_pos_xz = Vector2(player.global_position.x, player.global_position.z)
	var locked_pos_xz = Vector2(locked_target_pos.x, locked_target_pos.z)
	var beam_hit_radius: float = 1.5

	if player_pos_xz.distance_to(locked_pos_xz) > beam_hit_radius:
		# Missed — beam fires at locked position for full duration but doesn't lift
		while beam_timer < beam_duration:
			if current_state == State.DEAD or shoot_state != ShootState.FIRING:
				break
			_update_beam_to_locked_target()
			await get_tree().create_timer(beam_tick_rate).timeout
			beam_timer += beam_tick_rate
		_stop_beam_attack()
		return

	# Hit! Start lifting and tracking player vertically
	is_lifting_player = true

	while beam_timer < beam_duration:
		if current_state == State.DEAD or shoot_state != ShootState.FIRING:
			break
		if not player or not is_instance_valid(player):
			break

		# Track the player's current Y so the beam follows them upward
		locked_target_pos.y = player.global_position.y + 1.0
		_update_beam_to_locked_target()

		if player.has_method("take_damage"):
			player.take_damage(beam_damage_per_tick)

		if player.has_method("apply_beam_lift"):
			player.apply_beam_lift(beam_lift_speed, beam_max_lift)

		await get_tree().create_timer(beam_tick_rate).timeout
		beam_timer += beam_tick_rate

	_stop_beam_attack()

func _get_beam_start() -> Vector3:
	if beam_origin and is_instance_valid(beam_origin):
		return beam_origin.global_position
	return global_position

func _update_beam_to_locked_target():
	var beam_start = _get_beam_start()
	var beam_end = locked_target_pos
	var beam_center = (beam_start + beam_end) / 2.0
	var beam_length = beam_start.distance_to(beam_end)

	var active_beam = main_beam if main_beam.visible else warning_beam
	if not active_beam.visible:
		return

	active_beam.mesh.height = beam_length
	active_beam.global_position = beam_center
	active_beam.look_at(beam_end, Vector3.UP)
	active_beam.rotate_object_local(Vector3.RIGHT, deg_to_rad(90))

func _stop_beam_attack():
	warning_beam.visible = false
	main_beam.visible = false
	is_lifting_player = false

	if player and is_instance_valid(player) and player.has_method("release_beam_lift"):
		player.release_beam_lift()

	# Fall to the ground before resuming chase
	shoot_state = ShootState.FALLING
	fall_velocity = 0.0
	can_shoot = false

func _fall_to_ground(delta):
	fall_velocity += 9.8 * delta
	velocity = Vector3(0, -fall_velocity, 0)
	_face_player()

	if is_on_floor():
		shoot_state = ShootState.NONE
		current_state = State.CHASE
		_start_shoot_cooldown()

func _start_shoot_cooldown():
	await get_tree().create_timer(shoot_cooldown).timeout
	can_shoot = true

# --- Ground spin attack (state-driven, runs every frame) ---

func _start_ground_spin_attack():
	is_spin_attacking = true
	can_ground_attack = false
	velocity = Vector3.ZERO
	spin_timer = 0.0
	spin_angle = rotation.y  # Start from current facing direction
	spin_damage_timer = 0.0
	spin_state = SpinState.WARNING
	spin_warning_circle.visible = true

func _handle_spin_attack(delta):
	if current_state == State.DEAD:
		_stop_ground_spin()
		return

	# Keep grounded
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity = Vector3.ZERO

	spin_timer += delta

	match spin_state:
		SpinState.WARNING:
			# Flashing red circle on the ground
			spin_warning_circle.global_position = global_position + Vector3(0, 0.1, 0)

			# Flash by toggling visibility with sin wave
			var flash = sin(spin_timer * spin_warning_flash_speed * TAU)
			spin_warning_circle.visible = flash > 0

			# Pulse the alpha too for extra effect
			var alpha = remap(flash, -1.0, 1.0, 0.1, 0.5)
			spin_warning_circle.material_override.albedo_color.a = alpha

			if spin_timer >= spin_warning_duration:
				spin_warning_circle.visible = false
				spin_state = SpinState.PAUSE
				spin_timer = 0.0

		SpinState.PAUSE:
			# Brief pause between warning and firing
			if spin_timer >= spin_pause_duration:
				spin_state = SpinState.FIRING
				spin_timer = 0.0
				spin_damage_timer = 0.0
				main_beam.visible = true

		SpinState.FIRING:
			# Blue beam spins smoothly
			spin_angle += spin_speed * TAU * delta
			_update_spin_beam_from_angle(main_beam)

			# Check hit every frame, cooldown prevents rapid damage stacking
			spin_damage_timer -= delta
			if spin_damage_timer <= 0.0:
				if _check_spin_beam_hit_at_angle():
					spin_damage_timer = spin_damage_tick  # Brief cooldown after a hit

			# Cut down trees in the beam's path
			_check_spin_beam_trees()

			if spin_timer >= spin_duration:
				_stop_ground_spin()

func _update_spin_beam_from_angle(beam: MeshInstance3D):
	var direction = Vector3(cos(spin_angle), 0, sin(spin_angle))
	var beam_start = _get_beam_start()
	var beam_end = beam_start + direction * spin_beam_length
	beam_end.y = beam_start.y  # Keep beam level horizontally from origin

	var beam_center = (beam_start + beam_end) / 2.0
	var beam_len = beam_start.distance_to(beam_end)

	beam.mesh.height = beam_len
	beam.global_position = beam_center
	beam.look_at(beam_end, Vector3.UP)
	beam.rotate_object_local(Vector3.RIGHT, deg_to_rad(90))

	# Rotate the robot body to match
	var look_target = global_position + direction
	look_target.y = global_position.y
	if global_position.distance_to(look_target) > 0.1:
		look_at(look_target, Vector3.UP)
		rotation.x = 0
		rotation.z = 0

func _check_spin_beam_hit_at_angle() -> bool:
	if not player or not is_instance_valid(player):
		return false

	var to_player = player.global_position - global_position
	to_player.y = 0

	var player_dist = to_player.length()
	if player_dist > spin_beam_length or player_dist < 0.5:
		return false

	# Get angle of beam and angle to player
	var beam_angle = fmod(spin_angle, TAU)
	var player_angle = atan2(to_player.z, to_player.x)

	# Get shortest angle difference
	var angle_diff = abs(wrapf(beam_angle - player_angle, -PI, PI))

	# Hit if player is within a cone (wider at close range, narrower at far)
	var hit_angle = atan2(1.5, player_dist)  # 1.5 = hit width in meters

	if angle_diff <= hit_angle:
		if player.has_method("take_damage"):
			player.take_damage(spin_damage)
		return true

	return false

func _check_spin_beam_trees():
	var trees = get_tree().get_nodes_in_group("trees")

	for tree in trees:
		if not is_instance_valid(tree):
			continue

		var to_tree = tree.global_position - global_position
		to_tree.y = 0

		var tree_dist = to_tree.length()
		if tree_dist > spin_beam_length or tree_dist < 0.5:
			continue

		var beam_angle = fmod(spin_angle, TAU)
		var tree_angle = atan2(to_tree.z, to_tree.x)
		var angle_diff = abs(wrapf(beam_angle - tree_angle, -PI, PI))

		# Trees are bigger targets than the player
		var hit_angle = atan2(2.0, tree_dist)

		if angle_diff <= hit_angle:
			if tree.has_method("take_damage"):
				tree.take_damage(9999)

func _stop_ground_spin():
	warning_beam.visible = false
	main_beam.visible = false
	spin_warning_circle.visible = false
	is_spin_attacking = false
	spin_state = SpinState.NONE

	# Cooldown before next ground attack
	_start_ground_attack_cooldown()

func _start_ground_attack_cooldown():
	await get_tree().create_timer(ground_attack_cooldown).timeout
	can_ground_attack = true

func _face_player():
	if not player or not is_instance_valid(player):
		return
	var look_target = player.global_position
	look_target.y = global_position.y
	if global_position.distance_to(look_target) > 0.1:
		look_at(look_target, Vector3.UP)
		rotation.x = 0
		rotation.z = 0

func die():
	_stop_beam_attack()
	_stop_ground_spin()
	super.die()
