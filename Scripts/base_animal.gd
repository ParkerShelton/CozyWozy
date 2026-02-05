# base_animal.gd
extends CharacterBody3D
class_name BaseAnimal

# ========== INJECTED BY ANIMAL MANAGER ==========
# AnimalManager sets these via .set() before add_child(), so they are
# available when _ready() runs.
var animal_definition: Dictionary = {}
var animal_key: String = ""

# ========== STATS (populated from definition in _ready) ==========
var display_name: String = ""
var animal_type: String = ""   # "wild" | "hostile" | "farmable"
var max_health: float = 100.0
var current_health: float = 100.0
var move_speed: float = 3.0

# Wild / Farmable behavior
var flee_range: float = 8.0
var flee_speed: float = 6.0
var wander_speed: float = 1.5
var detection_range: float = 10.0

# Hostile behavior
var attack_damage: float = 10.0
var attack_range: float = 2.0
var attack_cooldown: float = 1.5
var can_attack: bool = true

# Drops
var drop_items: Array = []

# ========== DESPAWN ==========
var despawn_distance: float = 50.0
var max_idle_time: float = 60.0
var idle_timer: float = 0.0

# ========== STATE MACHINE ==========
enum State { IDLE, WANDER, FLEE, CHASE, ATTACK, DEAD }
var current_state: State = State.IDLE

# ========== WANDER ==========
var wander_target: Vector3 = Vector3.ZERO
var wander_timer: float = 0.0
var wander_interval: float = 3.0   # Seconds between picking a new wander point
var wander_radius: float = 8.0     # Max distance from current pos for new target

# ========== KNOCKBACK ==========
var knockback_velocity: Vector3 = Vector3.ZERO
var knockback_friction: float = 10.0

# ========== REFERENCES ==========
var player: Node3D = null
var dropped_item_scene = preload("res://Scenes/dropped_item.tscn")

# ========== LIFECYCLE ==========

func _ready():
	add_to_group("animals")
	_apply_definition()

	# Find player (same pattern as BaseEnemy)
	await get_tree().process_frame
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

	# Start wandering immediately
	current_state = State.WANDER
	_pick_new_wander_target()

# Reads the injected definition and sets all instance vars.
# This is the only place stats come from — no hardcoding needed in child scenes
# unless they want to override something specific.
func _apply_definition():
	if animal_definition.is_empty():
		push_error("BaseAnimal: animal_definition is empty on '%s'. Did AnimalManager inject it?" % name)
		return

	display_name = animal_definition.get("display_name", "Unknown")
	animal_type  = animal_definition.get("animal_type", "wild")

	max_health       = animal_definition.get("max_health", 100.0)
	current_health   = max_health
	move_speed       = animal_definition.get("move_speed", 3.0)
	detection_range  = animal_definition.get("detection_range", 10.0)

	# Wild / Farmable
	flee_range   = animal_definition.get("flee_range", 8.0)
	flee_speed   = animal_definition.get("flee_speed", 6.0)
	wander_speed = animal_definition.get("wander_speed", 1.5)

	# Hostile
	attack_damage   = animal_definition.get("attack_damage", 10.0)
	attack_range    = animal_definition.get("attack_range", 2.0)
	attack_cooldown = animal_definition.get("attack_cooldown", 1.5)

	# Drops
	drop_items = animal_definition.get("drops", [])

# ========== PHYSICS LOOP ==========

func _physics_process(delta):
	if current_state == State.DEAD:
		return

	_check_despawn(delta)

	# Gravity
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0.0

	# Route to the correct behavior based on current state
	match current_state:
		State.IDLE:
			_idle_behavior(delta)
		State.WANDER:
			_wander_behavior(delta)
		State.FLEE:
			_flee_behavior(delta)
		State.CHASE:
			_chase_behavior(delta)
		State.ATTACK:
			_attack_behavior(delta)

	# Apply and decay knockback
	if knockback_velocity.length() > 0.1:
		velocity += knockback_velocity
		knockback_velocity = knockback_velocity.lerp(Vector3.ZERO, knockback_friction * delta)

	move_and_slide()

# ========== IDLE ==========

func _idle_behavior(delta):
	idle_timer += delta

	# After a short pause, resume wandering
	if idle_timer > 1.0:
		idle_timer = 0.0
		current_state = State.WANDER
		_pick_new_wander_target()

	_check_player_proximity()

# ========== WANDER ==========
# All animal types wander when calm. The speed used is wander_speed.

func _wander_behavior(delta):
	wander_timer += delta

	# Pick a new target periodically
	if wander_timer >= wander_interval:
		wander_timer = 0.0
		_pick_new_wander_target()

	# Move toward wander target
	var dir = (wander_target - global_position)
	dir.y = 0.0

	if dir.length() > 0.5:
		dir = dir.normalized()
		velocity.x = dir.x * wander_speed
		velocity.z = dir.z * wander_speed
		_face_direction(dir)
	else:
		# Reached target — pause briefly before picking a new one
		velocity.x = 0.0
		velocity.z = 0.0
		current_state = State.IDLE
		idle_timer = 0.0

	_check_player_proximity()

func _pick_new_wander_target():
	var angle: float = randf() * TAU
	var dist: float  = randf_range(2.0, wander_radius)
	wander_target = global_position + Vector3(
		cos(angle) * dist,
		0.0,
		sin(angle) * dist
	)

# ========== FLEE (wild & farmable) ==========
# Runs directly away from the player at flee_speed.
# Returns to wandering once the player is outside flee_range.

func _flee_behavior(delta):
	if not player or not is_instance_valid(player):
		current_state = State.WANDER
		_pick_new_wander_target()
		return

	var distance = global_position.distance_to(player.global_position)

	# Player is far enough — stop fleeing
	if distance > flee_range * 1.5:
		current_state = State.WANDER
		_pick_new_wander_target()
		return

	# Run away
	var away_dir = (global_position - player.global_position)
	away_dir.y = 0.0
	away_dir = away_dir.normalized()

	velocity.x = away_dir.x * flee_speed
	velocity.z = away_dir.z * flee_speed
	_face_direction(away_dir)

# ========== CHASE (hostile only) ==========

func _chase_behavior(delta):
	if not player or not is_instance_valid(player):
		current_state = State.WANDER
		_pick_new_wander_target()
		return

	var distance = global_position.distance_to(player.global_position)

	# Lost the player
	if distance > detection_range * 1.5:
		current_state = State.WANDER
		_pick_new_wander_target()
		return

	# Close enough to attack
	if distance <= attack_range:
		current_state = State.ATTACK
		return

	# Move toward player
	_move_toward(player.global_position, move_speed)

# ========== ATTACK (hostile only) ==========

func _attack_behavior(_delta):
	if not player or not is_instance_valid(player):
		current_state = State.WANDER
		_pick_new_wander_target()
		return

	var distance = global_position.distance_to(player.global_position)

	# Player moved out of attack range
	if distance > attack_range * 1.2:
		current_state = State.CHASE
		return

	# Face player and stop moving
	velocity.x = 0.0
	velocity.z = 0.0
	look_at(player.global_position, Vector3.UP)
	rotation.x = 0.0
	rotation.z = 0.0

	if can_attack:
		_perform_attack()
		can_attack = false
		await get_tree().create_timer(attack_cooldown).timeout
		can_attack = true

# ========== PLAYER PROXIMITY CHECK ==========
# Called every tick by idle and wander. Decides whether to flee or chase
# based on animal_type.

func _check_player_proximity():
	if not player or not is_instance_valid(player):
		return

	var distance = global_position.distance_to(player.global_position)

	match animal_type:
		"wild", "farmable":
			# Flee if the player gets within flee_range
			if distance <= flee_range:
				current_state = State.FLEE
		"hostile":
			# Chase if the player enters detection_range
			if distance <= detection_range:
				current_state = State.CHASE

# ========== ATTACK EXECUTION ==========

func _perform_attack():
	if player and player.has_method("take_damage"):
		player.take_damage(attack_damage)

# ========== DAMAGE / DEATH ==========

func take_damage(amount: float):
	current_health -= amount

	# When hit, hostile animals stay aggressive; wild/farmable flee harder
	match animal_type:
		"hostile":
			if current_state == State.IDLE or current_state == State.WANDER:
				current_state = State.CHASE
		"wild", "farmable":
			current_state = State.FLEE

	if current_health <= 0.0:
		_die()

func _die():
	current_state = State.DEAD
	_spawn_drops()

	await get_tree().create_timer(0.8).timeout
	queue_free()

# ========== DROPS (same pattern as BaseEnemy.spawn_drops) ==========

func _spawn_drops():
	for drop in drop_items:
		if randf() <= drop.get("drop_chance", 0.5):
			var item_name: String = drop.get("item_name", "")
			var amount: int = randi_range(drop.get("min_amount", 1), drop.get("max_amount", 1))

			var item_icon = ItemManager.get_item_icon(item_name)
			if not item_icon:
				print("Warning: No icon for drop '%s' on animal '%s'" % [item_name, display_name])
				continue

			var dropped_item = dropped_item_scene.instantiate()
			get_tree().root.add_child(dropped_item)
			dropped_item.global_position = global_position + Vector3(0.0, 0.5, 0.0)
			dropped_item.setup(item_name, amount, item_icon, true)

# ========== DESPAWN ==========

func _check_despawn(delta):
	if not player or not is_instance_valid(player):
		return

	var distance = global_position.distance_to(player.global_position)

	if distance > despawn_distance:
		queue_free()
		return

	# Only count idle time when actually idle or wandering far from player
	if current_state == State.IDLE or current_state == State.WANDER:
		idle_timer += delta
		if idle_timer > max_idle_time:
			queue_free()
			return
	else:
		idle_timer = 0.0  # Reset when the animal is active

# ========== MOVEMENT HELPERS ==========

func _move_toward(target_pos: Vector3, speed: float):
	var dir = (target_pos - global_position)
	dir.y = 0.0
	dir = dir.normalized()

	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	_face_direction(dir)

func _face_direction(dir: Vector3):
	if dir.length() > 0.1:
		look_at(global_position + dir, Vector3.UP)
		rotation.x = 0.0
		rotation.z = 0.0

# ========== KNOCKBACK ==========

func apply_knockback(force: Vector3):
	knockback_velocity = force
