extends CharacterBody3D
class_name BaseEnemy

# Stats
var max_health: float = 100.0
var current_health: float = 100.0
var move_speed: float = 3.0
var attack_damage: float = 10.0
var attack_range: float = 2.0
var attack_cooldown: float = 1.5
var detection_range: float = 15.0
var exp_reward: int = 10

var despawn_distance: float = 200.0  # Despawn if this far from player
var max_idle_time: float = 30.0  # Despawn if idle for this long
var idle_timer: float = 0.0

# Drops
var drop_items: Array[Dictionary] = []  # {item_name: String, drop_chance: float, min_amount: int, max_amount: int}

# State
enum State { IDLE, PATROL, CHASE, ATTACK, DEAD }
var current_state: State = State.IDLE
var target: Node3D = null
var can_attack: bool = true

# References
var player: Node3D
var dropped_item_scene = preload("res://Scenes/dropped_item.tscn")

var knockback_velocity: Vector3 = Vector3.ZERO
var knockback_friction: float = 10.0  # How fast knockback decays

func _ready():
	add_to_group("enemies")
	current_health = max_health
	# Find player
	await get_tree().process_frame
	var players = get_tree().get_nodes_in_group("player")
	
	if players.size() > 0:
		player = players[0]
		
	current_state = State.PATROL

func _physics_process(delta):
	if current_state == State.DEAD:
		return
	
	check_despawn(delta)
	
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0
	
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
		# Decay knockback over time
		knockback_velocity = knockback_velocity.lerp(Vector3.ZERO, knockback_friction * delta)

	move_and_slide()

# Override these in child classes for custom behavior
func idle_behavior(_delta):
	check_for_player()

func patrol_behavior(_delta):
	# Basic wandering - override for custom patrol
	check_for_player()

func chase_behavior(delta):
	print(name, " - CHASING player")
	if not player or not is_instance_valid(player):
		current_state = State.IDLE
		return
	
	var distance = global_position.distance_to(player.global_position)
	
	# Lost player
	if distance > detection_range * 1.5:
		current_state = State.IDLE
		return
	
	# In attack range
	if distance <= attack_range:
		current_state = State.ATTACK
		return
	
	# Chase player
	move_toward_target(player.global_position, delta)

func attack_behavior(_delta):
	if not player or not is_instance_valid(player):
		current_state = State.IDLE
		return
	
	var distance = global_position.distance_to(player.global_position)
	
	# Player moved away
	if distance > attack_range * 1.2:
		current_state = State.CHASE
		return
	
	# Face player
	look_at(player.global_position, Vector3.UP)
	rotation.x = 0  # Keep upright
	rotation.z = 0
	
	# Attack
	if can_attack:
		perform_attack()
		can_attack = false
		await get_tree().create_timer(attack_cooldown).timeout
		can_attack = true

func check_for_player():
	if not player or not is_instance_valid(player):
		return
	
	var distance = global_position.distance_to(player.global_position)
	if distance <= detection_range:
		print(name, " - PLAYER DETECTED! Distance: ", distance, " Switching to CHASE")
		current_state = State.CHASE

func move_toward_target(target_pos: Vector3, delta):
	var direction = (target_pos - global_position).normalized()
	direction.y = 0  # Keep on ground
	
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	
	# Apply gravity
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	
	move_and_slide()
	
	# Face movement direction
	if direction.length() > 0.1:
		look_at(global_position + direction, Vector3.UP)
		rotation.x = 0
		rotation.z = 0

func perform_attack():
	# Override in child classes for custom attacks
	print(name, " attacks for ", attack_damage, " damage!")
	
	# Deal damage to player if they have a take_damage method
	if player and player.has_method("take_damage"):
		player.take_damage(attack_damage)

func take_damage(amount: float):
	current_health -= amount
	print(name, " took ", amount, " damage. Health: ", current_health)
	
	# Enter chase state when hit
	if current_state == State.IDLE or current_state == State.PATROL:
		current_state = State.CHASE
	
	if current_health <= 0:
		die()

func die():
	current_state = State.DEAD
	print(name, " died!")
	
	# Drop items
	spawn_drops()
	
	# Give exp to player
	# player.gain_exp(exp_reward)
	
	await get_tree().create_timer(0.8).timeout
	queue_free()

func spawn_drops():
	for drop in drop_items:
		var roll = randf()
		if roll <= drop.get("drop_chance", 0.5):
			var item_name = drop.get("item_name", "")
			var amount = randi_range(drop.get("min_amount", 1), drop.get("max_amount", 1))

			# Get item icon from ItemManager
			var item_icon = ItemManager.get_item_icon(item_name)
			
			if not item_icon:
				print("Warning: No icon found for ", item_name)
				continue
			
			# Create dropped_item item
			var dropped_item = dropped_item_scene.instantiate()
			get_tree().root.add_child(dropped_item)
			
			# Position at enemy location (with slight upward offset)
			dropped_item.global_position = global_position + Vector3(0, 0.5, 0)
			
			# Setup the dropped_item with item data
			dropped_item.setup(item_name, amount, item_icon, true)  # true = from_drop (requires player exit)
			
			print("Dropped ", amount, "x ", item_name)


func check_despawn(_delta):
	if not player or not is_instance_valid(player):
		return
	
	var distance = global_position.distance_to(player.global_position)
	
	# Too far from player - despawn
	if distance > despawn_distance:
		print(name, " despawning - too far from player (", distance, ")")
		queue_free()
		return
	
	# Idle for too long - despawn
	if idle_timer > max_idle_time:
		print(name, " despawning - idle for too long (", idle_timer, "s)")
		queue_free()
		return


func apply_knockback(force: Vector3):
	knockback_velocity = force
