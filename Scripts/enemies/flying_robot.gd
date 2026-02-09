extends BaseEnemy

# Flying movement
var fly_speed: float = 4.0
var default_hover_height: float = 3.0
var bob_speed: float = 2.0
var bob_amount: float = 0.3
var sway_amount: float = 0.5
var fly_time: float = 0.0

# Shoot mode states
enum ShootState { NONE, FLYING_TO_POSITION, HOVERING, WARNING, FIRING, COOLDOWN }
var shoot_state: ShootState = ShootState.NONE

# Shoot config
var shoot_range: float = 12.0
var shoot_cooldown: float = 8.0
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
var beam_lift_speed: float = 2.0
var beam_max_lift: float = 3.0

# Internal
var beam_timer: float = 0.0
var hover_target_pos: Vector3 = Vector3.ZERO
var can_shoot: bool = true
var is_lifting_player: bool = false

# Beam meshes
var warning_beam: MeshInstance3D = null
var main_beam: MeshInstance3D = null

func _ready():
	await super._ready()
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

# Override the entire physics process — no gravity, fully airborne
func _physics_process(delta):
	if current_state == State.DEAD:
		_stop_beam_attack()
		return

	check_despawn(delta)
	fly_time += delta

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

	var target_pos = player.global_position + Vector3(0, default_hover_height, 0)
	var distance_to_player = global_position.distance_to(player.global_position)

	if distance_to_player > detection_range * 1.5:
		current_state = State.IDLE
		return

	if distance_to_player <= shoot_range:
		current_state = State.ATTACK
		return

	# Fly toward player, staying above them
	var direction = (target_pos - global_position).normalized()
	velocity = direction * fly_speed

	# Add bob
	velocity.y += sin(fly_time * bob_speed) * bob_amount

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
			_update_beam_aim()
		ShootState.FIRING:
			_hover_behavior(delta)
			_update_beam_aim()
		ShootState.COOLDOWN:
			_hover_behavior(delta)

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

func _start_warning_sequence():
	shoot_state = ShootState.WARNING

	for i in range(warning_flash_count):
		if current_state == State.DEAD or shoot_state != ShootState.WARNING:
			_stop_beam_attack()
			return

		warning_beam.visible = true
		_update_beam_aim()
		await get_tree().create_timer(warning_flash_duration).timeout

		warning_beam.visible = false
		if i < warning_flash_count - 1:
			await get_tree().create_timer(warning_gap_duration).timeout

	if current_state != State.DEAD and shoot_state == ShootState.WARNING:
		_start_main_beam()

func _start_main_beam():
	shoot_state = ShootState.FIRING
	warning_beam.visible = false
	main_beam.visible = true
	beam_timer = 0.0
	is_lifting_player = true

	while beam_timer < beam_duration:
		if current_state == State.DEAD or shoot_state != ShootState.FIRING:
			break
		if not player or not is_instance_valid(player):
			break

		_update_beam_aim()

		if player.has_method("take_damage"):
			player.take_damage(beam_damage_per_tick)

		if is_lifting_player and player.has_method("apply_beam_lift"):
			player.apply_beam_lift(beam_lift_speed, beam_max_lift)

		await get_tree().create_timer(beam_tick_rate).timeout
		beam_timer += beam_tick_rate

	_stop_beam_attack()

func _update_beam_aim():
	if not player or not is_instance_valid(player):
		return

	var beam_start = global_position
	var beam_end = player.global_position + Vector3(0, 1.0, 0)
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

	shoot_state = ShootState.COOLDOWN
	can_shoot = false

	await get_tree().create_timer(shoot_cooldown).timeout
	can_shoot = true
	shoot_state = ShootState.NONE
	current_state = State.CHASE

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
	super.die()
