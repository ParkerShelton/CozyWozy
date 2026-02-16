extends BaseEnemy

@onready var anim_player = $jumping_robot/AnimationPlayer

var audio_player: AudioStreamPlayer = null

var bullet_scene = preload("res://Scenes/Enemies/enemy_bullet.tscn")
var can_shoot: bool = true
var shoot_cooldown: float = 3.0
var bullet_count: int = 12
var bullet_spacing: float = 2.5

var jump_force: float = 12.0
var jump_cooldown: float = 1.0
var can_jump: bool = true
var is_jumping: bool = false
var was_in_air: bool = false
var jump_target: Vector3 = Vector3.ZERO

var preferred_distance: float = 15.0
var bullet_speed_override: float = 8.0

# Object pool
var bullet_pool: Array = []
var pool_size: int = 48  # double the bullet count so we always have enough
var pool_ready: bool = false

func _ready():
	await super._ready()
	create_bullet_pool()

func create_bullet_pool():
	for i in range(pool_size):
		var bullet = bullet_scene.instantiate()
		get_tree().root.add_child(bullet)
		bullet.global_position = Vector3(0, -100, 0)
		bullet.visible = false
		bullet.set_process(false)
		bullet.set_physics_process(false)
		bullet_pool.append(bullet)
		
		await get_tree().process_frame

func get_pooled_bullet() -> Node:
	for bullet in bullet_pool:
		if not is_instance_valid(bullet):
			# Replace dead bullets
			var new_bullet = bullet_scene.instantiate()
			new_bullet.set_process(false)
			new_bullet.set_physics_process(false)
			new_bullet.visible = false
			new_bullet.global_position = Vector3(0, -100, 0)
			get_tree().root.add_child(new_bullet)
			bullet_pool[bullet_pool.find(bullet)] = new_bullet
			return new_bullet
		
		if not bullet.visible:
			return bullet
	
	# Pool exhausted, create a new one
	var new_bullet = bullet_scene.instantiate()
	new_bullet.set_process(false)
	new_bullet.set_physics_process(false)
	new_bullet.visible = false
	get_tree().root.add_child(new_bullet)
	bullet_pool.append(new_bullet)
	return new_bullet

func activate_bullet(bullet: Node, pos: Vector3, vel: Vector3):
	bullet.global_position = pos
	bullet.visible = true
	bullet.set_process(true)
	bullet.set_physics_process(true)
	bullet.set_velocity(vel)

func _physics_process(delta):
	if current_state == State.DEAD:
		return
	
	check_despawn(delta)
	
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0
	
	if was_in_air and is_on_floor():
		was_in_air = false
		is_jumping = false
		on_landed()
	
	if not is_on_floor():
		was_in_air = true
	
	match current_state:
		State.IDLE:
			idle_behavior(delta)
		State.PATROL:
			patrol_behavior(delta)
		State.CHASE:
			chase_behavior(delta)
		State.ATTACK:
			attack_behavior(delta)
	
	if knockback_velocity.length() > 0.1:
		velocity += knockback_velocity
		knockback_velocity = knockback_velocity.lerp(Vector3.ZERO, knockback_friction * delta)
	
	move_and_slide()

func chase_behavior(delta):
	if not player or not is_instance_valid(player):
		current_state = State.IDLE
		return
	
	var distance = global_position.distance_to(player.global_position)
	
	if distance > detection_range * 1.5:
		current_state = State.IDLE
		return
	
	if is_jumping:
		var dir = (jump_target - global_position)
		dir.y = 0
		dir = dir.normalized()
		velocity.x = dir.x * move_speed * 1.5
		velocity.z = dir.z * move_speed * 1.5
		
		look_at(player.global_position, Vector3.UP)
		rotation.x = 0
		rotation.z = 0
		return
	
	if is_on_floor():
		start_jump()
		return
	
	look_at(player.global_position, Vector3.UP)
	rotation.x = 0
	rotation.z = 0

func start_jump():
	if not player or not is_instance_valid(player):
		return
	
	is_jumping = true
	can_jump = false
	
	jump_target = player.global_position
	
	look_at(player.global_position, Vector3.UP)
	rotation.x = 0
	rotation.z = 0
	
	velocity.y = jump_force
	
	var dir = (jump_target - global_position)
	dir.y = 0
	dir = dir.normalized()
	velocity.x = dir.x * move_speed * 2.0
	velocity.z = dir.z * move_speed * 2.0
	
	if anim_player:
		anim_player.play("jump")

func on_landed():
	if player and is_instance_valid(player) and can_shoot:
		shoot_line()
	
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var dist = global_position.distance_to(players[0].global_position)
		if dist < 15.0:
			CameraShakeManager.shake(0.04, 0.2)
	
	can_jump = true
	
	await get_tree().create_timer(jump_cooldown).timeout
	can_jump = true

func shoot_line():
	if not pool_ready:
		return
		
	can_shoot = false
	
	if audio_player and audio_player.stream:
		audio_player.play()
	
	var direction_to_player = (player.global_position - global_position)
	direction_to_player.y = 0
	direction_to_player = direction_to_player.normalized()
	
	var right = Vector3(-direction_to_player.z, 0, direction_to_player.x).normalized()
	
	for i in range(bullet_count):
		var bullet = get_pooled_bullet()
		var offset = (i - (bullet_count - 1) / 2.0) * bullet_spacing
		var spawn_pos = global_position + Vector3(0, 1.0, 0) + (right * offset)
		activate_bullet(bullet, spawn_pos, direction_to_player * bullet_speed_override)
	
	await get_tree().create_timer(shoot_cooldown).timeout
	can_shoot = true

func setup_audio():
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	
	var shoot_sound = load("res://Assets/SFX/robot_common_shoot.mp3")
	if shoot_sound:
		audio_player.stream = shoot_sound
		audio_player.volume_db = -10.0
