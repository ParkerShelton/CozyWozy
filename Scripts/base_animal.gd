# base_animal.gd
extends CharacterBody3D
class_name BaseAnimal

# ========== INJECTED BY ANIMAL MANAGER ==========
var animal_definition: Dictionary = {}

# ========== STATS (loaded from animal_definition) ==========
var max_health: float = 100.0
var current_health: float = 100.0
var move_speed: float = 3.0
var wander_speed: float = 1.5
var flee_speed: float = 6.0
var attack_damage: float = 10.0
var attack_range: float = 2.0
var attack_cooldown: float = 1.5
var detection_range: float = 10.0
var flee_range: float = 8.0
var despawn_distance: float = 50.0
var max_idle_time: float = 60.0

# Drops (loaded from animal_definition)
var drop_items: Array = []

# ========== STATE MACHINE ==========
enum State { IDLE, WANDER, FLEE, CHASE, ATTACK, APPROACH, DEAD }
var current_state: State = State.IDLE

# ========== WANDER ==========
var wander_target: Vector3 = Vector3.ZERO
var wander_timer: float = 0.0

# ========== KNOCKBACK ==========
var knockback_velocity: Vector3 = Vector3.ZERO
var knockback_friction: float = 10.0

# ========== REFERENCES ==========
var player: Node3D = null
var dropped_item_scene = preload("res://Scenes/dropped_item.tscn")

# Timers
var idle_timer: float = 0.0
var can_attack: bool = true

# ========== JOURNAL =============
@export var animal_id: String = "wolf"  # Unique identifier
@export var animal_display_name: String = "Wolf"
@export var discovery_range: float = 5.0  # How close to trigger discovery

var is_discovered: bool = false
var player_in_range: bool = false

func _ready():
	add_to_group("animals")
	
	if animal_definition.size() > 0:
		load_stats_from_definition()
	
	current_health = max_health
	
	if AnimalManager.is_animal_discovered(animal_id):
		is_discovered = true
	
	# Setup detection area
	var area = Area3D.new()
	add_child(area)
	area.collision_layer = 0
	area.collision_mask = 8  # Player layer
	
	var collision = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = discovery_range
	collision.shape = sphere
	area.add_child(collision)
	
	area.body_entered.connect(_on_player_nearby)
	area.body_exited.connect(_on_player_left)

	# Find player
	await get_tree().process_frame
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

	# Start wandering
	current_state = State.WANDER
	_pick_new_wander_target()


func load_stats_from_definition():
	max_health = animal_definition.get("max_health", 100.0)
	move_speed = animal_definition.get("move_speed", 3.0)
	wander_speed = animal_definition.get("wander_speed", 1.5)
	flee_speed = animal_definition.get("flee_speed", 6.0)
	attack_damage = animal_definition.get("attack_damage", 10.0)
	attack_range = animal_definition.get("attack_range", 2.0)
	attack_cooldown = animal_definition.get("attack_cooldown", 1.5)
	detection_range = animal_definition.get("detection_range", 10.0)
	flee_range = animal_definition.get("flee_range", 8.0)
	despawn_distance = animal_definition.get("despawn_distance", 50.0)
	max_idle_time = animal_definition.get("max_idle_time", 60.0)
	
	# Load drops
	if animal_definition.has("drops"):
		drop_items = animal_definition["drops"]
	
	print("Loaded animal: ", animal_definition.get("display_name", "Unknown"))


func _physics_process(delta):
	if current_state == State.DEAD:
		return

	_check_despawn(delta)

	# Gravity
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0.0

	# Route to behavior
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
		State.APPROACH:
			_approach_behavior(delta)

	# Knockback
	if knockback_velocity.length() > 0.1:
		velocity += knockback_velocity
		knockback_velocity = knockback_velocity.lerp(Vector3.ZERO, knockback_friction * delta)

	move_and_slide()

# ========== IDLE ==========

func _idle_behavior(delta):
	idle_timer += delta
	if idle_timer > 1.0:
		idle_timer = 0.0
		current_state = State.WANDER
		_pick_new_wander_target()
	_check_player_proximity()

# ========== WANDER ==========

func _wander_behavior(delta):
	wander_timer += delta
	
	var wander_interval = 3.0
	if wander_timer >= wander_interval:
		wander_timer = 0.0
		_pick_new_wander_target()

	var dir = (wander_target - global_position)
	dir.y = 0.0

	if dir.length() > 0.5:
		dir = dir.normalized()
		velocity.x = dir.x * wander_speed
		velocity.z = dir.z * wander_speed
		_face_direction(dir, delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		current_state = State.IDLE
		idle_timer = 0.0

	_check_player_proximity()

func _pick_new_wander_target():
	var angle: float = randf() * TAU
	var wander_radius = animal_definition.get("wander_radius", 8.0)
	var dist: float = randf_range(2.0, wander_radius)
	wander_target = global_position + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)

# ========== FLEE ==========

func _flee_behavior(delta):
	if _player_has_trust_item():
		current_state = State.APPROACH
		return
	
	if not player or not is_instance_valid(player):
		current_state = State.WANDER
		_pick_new_wander_target()
		return

	var distance = global_position.distance_to(player.global_position)

	if distance > flee_range * 1.5:
		current_state = State.WANDER
		_pick_new_wander_target()
		return

	var away_dir = (global_position - player.global_position)
	away_dir.y = 0.0
	away_dir = away_dir.normalized()

	velocity.x = away_dir.x * flee_speed
	velocity.z = away_dir.z * flee_speed
	_face_direction(away_dir, delta)

# ========== CHASE ==========

func _chase_behavior(delta):
	if not player or not is_instance_valid(player):
		current_state = State.WANDER
		_pick_new_wander_target()
		return

	var distance = global_position.distance_to(player.global_position)

	if distance > detection_range * 1.5:
		current_state = State.WANDER
		_pick_new_wander_target()
		return

	if distance <= attack_range:
		current_state = State.ATTACK
		return

	_move_toward(player.global_position, move_speed, delta)

# ========== ATTACK ==========

func _attack_behavior(delta):
	if not player or not is_instance_valid(player):
		current_state = State.WANDER
		_pick_new_wander_target()
		return

	var distance = global_position.distance_to(player.global_position)

	if distance > attack_range * 1.2:
		current_state = State.CHASE
		return

	velocity.x = 0.0
	velocity.z = 0.0
	
	var to_player = (player.global_position - global_position)
	to_player.y = 0.0
	if to_player.length() > 0.1:
		_face_direction(to_player.normalized(), delta)

	if can_attack:
		_perform_attack()
		can_attack = false
		await get_tree().create_timer(attack_cooldown).timeout
		can_attack = true

# ========== APPROACH ==========

func _approach_behavior(delta):
	if not player or not is_instance_valid(player):
		current_state = State.WANDER
		_pick_new_wander_target()
		return

	if not _player_has_trust_item():
		current_state = State.WANDER
		_pick_new_wander_target()
		return

	var distance = global_position.distance_to(player.global_position)

	if distance <= 2.0:
		# Stop completely - don't move at all
		velocity.x = 0.0
		velocity.z = 0.0
		
		# Face the player
		var to_player = (player.global_position - global_position)
		to_player.y = 0.0
		if to_player.length() > 0.1:
			_face_direction(to_player.normalized(), delta)
	else:
		_move_toward(player.global_position, wander_speed, delta)

# ========== PLAYER PROXIMITY CHECK ==========

func _check_player_proximity():
	if not player or not is_instance_valid(player):
		return

	var distance = global_position.distance_to(player.global_position)

	# Check trust item FIRST
	if _player_has_trust_item():
		if current_state != State.APPROACH:
			current_state = State.APPROACH
		return

	var animal_type = animal_definition.get("animal_type", "wild")
	
	
	
	match animal_type:
		#"wild", "farmable", "tameable":
			#if distance <= flee_range:
				#current_state = State.FLEE
		"hostile":
			if distance <= detection_range:
				current_state = State.CHASE

# ========== ATTACK EXECUTION ==========

func _perform_attack():
	if player and player.has_method("take_damage"):
		player.take_damage(attack_damage)

# ========== TRUST ITEM CHECK ==========

func _player_has_trust_item() -> bool:
	var trust_item = animal_definition.get("trust_item", "")
	if trust_item == "":
		return false
	
	if not player or not is_instance_valid(player):
		return false
	
	var trust_range = animal_definition.get("trust_range", 5.0)
	var distance = global_position.distance_to(player.global_position)
	if distance > trust_range:
		return false
	
	if not Hotbar:
		return false
	
	var selected = Hotbar.get_selected_item()
	return selected.get("item_name", "") == trust_item

# ========== DAMAGE / DEATH ==========

func take_damage(amount: float):
	current_health -= amount
	animal_definition["health"] = current_health

	var animal_type = animal_definition.get("animal_type", "wild")
	match animal_type:
		"hostile":
			if current_state == State.IDLE or current_state == State.WANDER:
				current_state = State.CHASE
		"wild", "farmable", "tameable":
			current_state = State.FLEE

	if current_health <= 0.0:
		_die()

func _die():
	current_state = State.DEAD
	_spawn_drops()
	await get_tree().create_timer(0.8).timeout
	queue_free()

# ========== DROPS ==========

func _spawn_drops():
	var drops = animal_definition.get("drops", [])
	for drop in drops:
		if randf() <= drop.get("drop_chance", 0.5):
			var item_name: String = drop.get("item_name", "")
			var amount: int = randi_range(drop.get("min_amount", 1), drop.get("max_amount", 1))

			var item_icon = ItemManager.get_item_icon(item_name)
			if not item_icon:
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

	if current_state == State.IDLE or current_state == State.WANDER:
		idle_timer += delta
		if idle_timer > max_idle_time:
			queue_free()
	else:
		idle_timer = 0.0

# ========== MOVEMENT HELPERS ==========

func _move_toward(target_pos: Vector3, speed: float, delta: float):
	var dir = (target_pos - global_position)
	dir.y = 0.0
	dir = dir.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	_face_direction(dir, delta)

func _face_direction(dir: Vector3, delta: float):
	if dir.length() > 0.1:
		var rotation_speed = animal_definition.get("rotation_speed", 5.0)
		var target_angle = atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, rotation_speed * delta)

func apply_knockback(force: Vector3):
	knockback_velocity = force
	
	
	
func _on_player_nearby(body):
	if body.is_in_group("player") and not is_discovered:
		player_in_range = true
		trigger_discovery(body)

func _on_player_left(body):
	if body.is_in_group("player"):
		player_in_range = false

func trigger_discovery(player):
	if is_discovered:
		return
	
	is_discovered = true
	AnimalManager.discover_animal(animal_id)
	
	# Visual effect - "soul collection"
	spawn_discovery_effect()
	
	# Notify player
	if player.has_method("show_discovery_message"):
		player.show_discovery_message(animal_display_name)

func spawn_discovery_effect():
	# Particle effect rising from animal
	var particles = CPUParticles3D.new()
	add_child(particles)
	
	particles.emitting = true
	particles.amount = 20
	particles.lifetime = 1.5
	particles.one_shot = true
	
	# Upward spiral effect
	particles.direction = Vector3(0, 1, 0)
	particles.spread = 45
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 3.0
	particles.gravity = Vector3(0, 0, 0)
	
	# Glowing white/blue particles
	particles.color = Color(0.8, 0.9, 1.0, 1.0)
	particles.scale_amount_min = 0.1
	particles.scale_amount_max = 0.3
	
	# Cleanup
	await get_tree().create_timer(2.0).timeout
	particles.queue_free()
