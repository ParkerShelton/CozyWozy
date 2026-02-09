extends BaseEnemy

@onready var anim_player = $robot_basic/AnimationPlayer

var audio_player: AudioStreamPlayer = null

var bullet_scene = preload("res://Scenes/Enemies/enemy_bullet.tscn")
var can_shoot: bool = true
var shoot_cooldown: float = 3.0  # Shoot every 3 seconds
var burst_size: int = 5  # 5 bullets per burst
var bullet_spread: float = 15.0  # Degrees of spread

var circle_distance: float = 7.0  # Stay this far from player
var circle_speed: float = 3.0  # Speed while circling
var circle_direction: int = 1
var can_change_direction: bool = true
var direction_change_cooldown: float = 2.0

func _ready():
	await super._ready()
	
	setup_audio()
	
	max_health = 10.0
	current_health = 10.0
	move_speed = 2.0
	attack_damage = 5.0
	attack_range = 1.5
	detection_range = 20.0
	exp_reward = 5
	
	# Set drops
	drop_items = [
		{"item_name": "iron", "drop_chance": 0.8, "min_amount": 1, "max_amount": 3}
	]
	
	circle_direction = 1 if randf() > 0.5 else -1

func circle_player(delta):
	# Get direction to player
	var to_player = (player.global_position - global_position).normalized()
	
	# Get perpendicular direction (tangent for circling)
	var tangent = Vector3(-to_player.z, 0, to_player.x) * circle_direction
	
	# Move in tangent direction while maintaining distance
	velocity.x = tangent.x * circle_speed
	velocity.z = tangent.z * circle_speed
	
	# Apply gravity
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	
	# Always face the player while circling
	look_at(player.global_position, Vector3.UP)
	rotation.x = 0
	rotation.z = 0

func perform_attack():
	super.perform_attack() 
	# This is for melee. it may not be used

func chase_behavior(delta):
	if not player or not is_instance_valid(player):
		current_state = State.IDLE
		return
	
	var distance = global_position.distance_to(player.global_position)
	
	anim_player.speed_scale = 3
	anim_player.play("walk")
	
	# Lost player
	if distance > detection_range * 1.5:
		current_state = State.IDLE
		return
	
	# Too close - back away
	if distance < circle_distance * 0.8:
		# Move away from player
		var away_direction = (global_position - player.global_position).normalized()
		velocity.x = away_direction.x * move_speed
		velocity.z = away_direction.z * move_speed
		
		# Face player while backing up
		look_at(player.global_position, Vector3.UP)
		rotation.x = 0
		rotation.z = 0
	
	# At good distance - circle the player
	elif distance >= circle_distance * 0.8 and distance <= circle_distance * 1.2:
		circle_player(delta)
		
		# Randomly change direction while circling
		if can_change_direction and randf() < 0.02:  # 2% chance per frame
			change_circle_direction()
			
	# Too far - move closer
	else:
		move_toward_target(player.global_position, delta)
	
	# Try to shoot while chasing/circling (if in range)
	if distance <= 10.0 and can_shoot:
		shoot_burst()


func shoot_burst():
	can_shoot = false
	
	# Calculate direction to player
	var direction_to_player = (player.global_position - global_position).normalized()
	
	# Shoot 5 bullets with spread
	for i in range(burst_size):
		if audio_player and audio_player.stream:
			audio_player.play()
		
		var bullet = bullet_scene.instantiate()
		get_tree().root.add_child(bullet)
		# Position bullet slightly in front of enemy
		bullet.global_position = global_position + Vector3(0, 1.0, 0)
		
		# Add random spread
		var spread_x = randf_range(-bullet_spread, bullet_spread)
		var spread_y = randf_range(-bullet_spread * 0.5, bullet_spread * 0.5)
		
		# Apply spread to direction
		var spread_direction = direction_to_player.rotated(Vector3.UP, deg_to_rad(spread_x))
		spread_direction = spread_direction.rotated(spread_direction.cross(Vector3.UP).normalized(), deg_to_rad(spread_y))
		
		# Set velocity with spread direction
		bullet.set_velocity(spread_direction.normalized() * bullet.speed)
		
		# Small delay between bullets in burst
		if i < burst_size - 1:
			await get_tree().create_timer(0.1).timeout
	
	var random_cooldown = randf_range(2.0, 4.0)  # Between 2-4 seconds
	await get_tree().create_timer(random_cooldown).timeout
	can_shoot = true



func change_circle_direction():
	can_change_direction = false
	circle_direction *= -1  # Flip direction
	print(name, " changed circle direction to ", "clockwise" if circle_direction == 1 else "counter-clockwise")
	
	# Random cooldown before next direction change (2-4 seconds)
	var cooldown = randf_range(2.0, 4.0)
	await get_tree().create_timer(cooldown).timeout
	can_change_direction = true



func setup_audio():
	# Create 2D audio player
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	
	# Load the shoot sound (MP3)
	var shoot_sound = load("res://Assets/SFX/robot_common_shoot.mp3")
	if shoot_sound:
		audio_player.stream = shoot_sound
		audio_player.volume_db = -10.0  # Adjust volume as needed
		print("✓ Shoot audio loaded")
	else:
		push_error("✗ Failed to load robot_common_shoot.mp3")
