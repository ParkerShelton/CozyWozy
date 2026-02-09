extends CharacterBody3D
class_name BaseEnemy

# This will be set by EnemyManager from JSON data
var enemy_definition: Dictionary = {}

# Stats (loaded from enemy_definition)
var max_health: float = 100.0
var current_health: float = 100.0
var move_speed: float = 3.0
var attack_damage: float = 10.0
var attack_range: float = 2.0
var attack_cooldown: float = 1.5
var detection_range: float = 15.0
var exp_reward: int = 10

var despawn_distance: float = 40.0
var max_idle_time: float = 30.0
var idle_timer: float = 0.0

# Drops (loaded from enemy_definition)
var drop_items: Array = []

# State
enum State { IDLE, PATROL, CHASE, ATTACK, DEAD }
var current_state: State = State.IDLE
var target: Node3D = null
var can_attack: bool = true

# References
var player: Node3D
var dropped_item_scene = preload("res://Scenes/dropped_item.tscn")

var knockback_velocity: Vector3 = Vector3.ZERO
var knockback_friction: float = 10.0

func _ready():
	add_to_group("enemies")
	
	# Load stats from enemy_definition if available
	if enemy_definition.size() > 0:
		load_stats_from_definition()
	
	current_health = max_health
	
	# Find player
	await get_tree().process_frame
	var players = get_tree().get_nodes_in_group("player")
	
	if players.size() > 0:
		player = players[0]

func load_stats_from_definition():
	max_health = enemy_definition.get("max_health", 100.0)
	move_speed = enemy_definition.get("move_speed", 3.0)
	attack_damage = enemy_definition.get("attack_damage", 10.0)
	attack_range = enemy_definition.get("attack_range", 2.0)
	attack_cooldown = enemy_definition.get("attack_cooldown", 1.5)
	detection_range = enemy_definition.get("detection_range", 15.0)
	exp_reward = enemy_definition.get("exp_reward", 10)
	
	# Load drops
	if enemy_definition.has("drops"):
		drop_items = enemy_definition["drops"]
	
	print("Loaded enemy: ", enemy_definition.get("display_name", "Unknown"))

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
		knockback_velocity = knockback_velocity.lerp(Vector3.ZERO, knockback_friction * delta)

	move_and_slide()

# Override these in child classes for custom behavior
func idle_behavior(_delta):
	check_for_player()

func patrol_behavior(_delta):
	check_for_player()

func chase_behavior(delta):
	if not player or not is_instance_valid(player):
		current_state = State.IDLE
		return
	
	var distance = global_position.distance_to(player.global_position)
	
	if distance > detection_range * 1.5:
		current_state = State.IDLE
		return
	
	if distance <= attack_range:
		current_state = State.ATTACK
		return
	
	move_toward_target(player.global_position, delta)

func attack_behavior(_delta):
	if not player or not is_instance_valid(player):
		current_state = State.IDLE
		return
	
	var distance = global_position.distance_to(player.global_position)
	
	if distance > attack_range * 1.2:
		current_state = State.CHASE
		return
	
	# Face player
	look_at(player.global_position, Vector3.UP)
	rotation.x = 0
	rotation.z = 0
	
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
		current_state = State.CHASE

func move_toward_target(target_pos: Vector3, delta):
	var direction = (target_pos - global_position).normalized()
	direction.y = 0
	
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	
	move_and_slide()
	
	if direction.length() > 0.1:
		look_at(global_position + direction, Vector3.UP)
		rotation.x = 0
		rotation.z = 0

func perform_attack():
	# Override in child classes for custom attacks
	if player and player.has_method("take_damage"):
		player.take_damage(attack_damage)

func take_damage(amount: float):
	current_health -= amount
	
	if current_state == State.IDLE or current_state == State.PATROL:
		current_state = State.CHASE
	
	if current_health <= 0:
		die()

func die():
	current_state = State.DEAD
	
	spawn_drops()
	
	await get_tree().create_timer(0.8).timeout
	queue_free()

func spawn_drops():
	for drop in drop_items:
		var roll = randf()
		if roll <= drop.get("drop_chance", 0.5):
			var item_name = drop.get("item_name", "")
			var amount = randi_range(drop.get("min_amount", 1), drop.get("max_amount", 1))

			var item_icon = ItemManager.get_item_icon(item_name)
			
			if not item_icon:
				print("Warning: No icon found for ", item_name)
				continue
			
			var dropped_item = dropped_item_scene.instantiate()
			get_tree().root.add_child(dropped_item)
			
			dropped_item.global_position = global_position + Vector3(0, 0.5, 0)
			
			dropped_item.setup(item_name, amount, item_icon, true)

func check_despawn(_delta):
	if not player or not is_instance_valid(player):
		return
	
	var distance = global_position.distance_to(player.global_position)
	
	if distance > despawn_distance:
		queue_free()
		return
	
	if idle_timer > max_idle_time:
		queue_free()
		return

func apply_knockback(force: Vector3):
	knockback_velocity = force
