class_name PlayerMovement

var player: Node3D

# MOVEMENT
var speed : float = 3.5
var sprint_speed : float = 5.0
var is_running : bool = false
var is_dashing: bool = false
var can_dash: bool = true
var dash_speed: float = 15.0
var dash_duration: float = 0.5  # How long the dash lasts
var dash_cooldown: float = 3  # Cooldown between dashes
var dash_direction: Vector3 = Vector3.ZERO

var is_moving: bool = false
var footstep_timer: float = 0.0
var footstep_interval: float = 0.40  # Time between footsteps when walking
var sprint_footstep_interval: float = 0.35

var rotation_speed : float = 20.0

func _init(_player: Node3D):
	player = _player

func update_footsteps(delta):
	if player.is_on_floor() and player.velocity.length() > 0.1 and not is_dashing:
		footstep_timer -= delta
		if footstep_timer <= 0.0:
			player.audio.play_footstep_sound()
			if Input.is_action_pressed("sprint"):
				footstep_timer = sprint_footstep_interval
			else:
				footstep_timer = footstep_interval
	else:
		footstep_timer = 0.0

func handle_movement(delta):
	# Get input direction
	var input_dir = Input.get_vector("walk_left", "walk_right", "walk_up", "walk_down")
	var direction = Vector3(-input_dir.y, 0, input_dir.x).normalized()
	
	var recoil_x = player.velocity.x
	var recoil_z = player.velocity.z
	
	# Move the character
	if direction != Vector3.ZERO:
		if not is_moving:
			player.audio.play_footstep_sound()
			is_moving = true
		if player.audio.footstep_audio and not player.audio.footstep_audio.playing:
			player.audio.play_footstep_sound()
		
		if Input.is_action_pressed("sprint"):
			is_running = true
			player.velocity.x = direction.x * sprint_speed + recoil_x * 0.5
			player.velocity.z = direction.z * sprint_speed + recoil_z * 0.5
		else:
			is_running = false
			player.velocity.x = direction.x * speed + recoil_x * 0.5
			player.velocity.z = direction.z * speed + recoil_z * 0.5
		player.last_direction = direction
	else:
		if is_moving:
			if player.audio.footstep_audio:
				player.audio.footstep_audio.stop()
			is_moving = false
		
		player.velocity.x = lerp(player.velocity.x, 0.0, 15.0 * delta)
		player.velocity.z = lerp(player.velocity.z, 0.0, 15.0 * delta)
	
	player.move_and_slide()

func get_mouse_world_position() -> Vector3:
	var camera = player.get_current_camera()
	if !camera:
		return player.global_position
	
	var camera_viewport = camera.get_viewport()
	var mouse_pos = camera_viewport.get_mouse_position()
	
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000
	
	var space_state = player.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1  # Ground
	
	var result = space_state.intersect_ray(query)
	if result:
		return result.position
	return player.global_position

func start_dash():
	var camera = player.get_current_camera()
	if !camera:
		return
	
	var camera_viewport = camera.get_viewport()
	var mouse_pos = camera_viewport.get_mouse_position()
	
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000
	
	var space_state = player.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	
	var result = space_state.intersect_ray(query)
	
	if result:
		dash_direction = (result.position - player.global_position).normalized()
		dash_direction.y = 0
		
		if dash_direction.length() > 0.1:
			is_dashing = true
			can_dash = false
			
			if player.audio.dash_roll_sound:
				var dash_audio = AudioStreamPlayer.new()
				player.get_tree().root.add_child(dash_audio)
				dash_audio.stream = player.audio.dash_roll_sound
				dash_audio.volume_db = -5.0
				dash_audio.pitch_scale = randf_range(0.95, 1.05)
				dash_audio.play()
				dash_audio.finished.connect(dash_audio.queue_free)
				
			player.get_tree().create_timer(dash_duration).timeout.connect(_on_dash_end)
			
func perform_dash(_delta):
	player.velocity.x = dash_direction.x * dash_speed
	player.velocity.z = dash_direction.z * dash_speed
	player.velocity.y = 0  # Stay on ground
	
	player.move_and_slide()

func _on_dash_end():
	is_dashing = false
	await player.get_tree().create_timer(dash_cooldown).timeout
	can_dash = true
