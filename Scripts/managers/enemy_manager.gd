# enemy_manager.gd
extends Node

const ENEMIES_FILE = "res://Data/enemies.json"
var enemies: Dictionary = {}

# Spawn settings
var max_enemies: int = 20
var spawn_cooldown: float = 5.0
var spawn_distance: float = 25.0
var can_spawn: bool = false

# Day/night spawn rates
var day_spawn_chance: float = 0.5
var night_spawn_chance: float = 0.8

# References
var player: Node3D = null
var camera: Camera3D = null
var safe_zone_count: int = 0

func _ready():
	load_enemies()
	
	# Start spawn timer
	var spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_cooldown
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)
	spawn_timer.start()

func load_enemies():
	if not FileAccess.file_exists(ENEMIES_FILE):
		push_error("Enemies file not found: " + ENEMIES_FILE)
		return
	
	var file = FileAccess.open(ENEMIES_FILE, FileAccess.READ)
	if file == null:
		push_error("Failed to open enemies file")
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_error("Failed to parse enemies JSON")
		return
	
	enemies = json.data

func _on_spawn_timer_timeout():
	if not can_spawn:
		return
	
	# Get player and camera
	if not player:
		player = get_tree().get_first_node_in_group("player")
	
	if not camera:
		var main = get_node_or_null("/root/main")
		if main:
			camera = main.get_node_or_null("Camera3D")
			if not camera:
				camera = main.find_child("Camera3D", true, false)
	
	# Check current enemy count
	var current_enemies = get_tree().get_nodes_in_group("enemies")
	
	if current_enemies.size() >= max_enemies:
		return
	
	# Check if we should spawn based on time of day
	if not should_spawn_enemy():
		return
	
	# Choose enemy type based on weights
	var enemy_id = choose_enemy_type()
	
	# Get spawn position
	var spawn_pos = get_spawn_position_outside_camera()
	
	if spawn_pos == Vector3.ZERO:
		return
	print("Spawning: ", enemy_id, " at ", spawn_pos)
	# Spawn the enemy
	spawn_enemy(enemy_id, spawn_pos)

func should_spawn_enemy() -> bool:
	var day_night_cycle = get_node_or_null("/root/main/day_night_overlay/ColorRect")
	
	if not day_night_cycle:
		return randf() < day_spawn_chance
	
	var time_of_day = 0.5
	if "time_of_day" in day_night_cycle:
		time_of_day = day_night_cycle.time_of_day
	
	var is_night = time_of_day > 0.75 or time_of_day < 0.25
	
	if is_night:
		return randf() < night_spawn_chance
	else:
		return randf() < day_spawn_chance

func choose_enemy_type() -> String:
	# Get eligible enemies based on time of day
	var eligible_enemies = get_eligible_enemies()
	
	if eligible_enemies.size() == 0:
		return ""
	
	# Choose based on spawn weights
	return choose_weighted_enemy(eligible_enemies)

func get_eligible_enemies() -> Array:
	var day_night_cycle = get_node_or_null("/root/main/day_night_overlay/ColorRect")
	var is_night = false
	
	if day_night_cycle and "time_of_day" in day_night_cycle:
		var time_of_day = day_night_cycle.time_of_day
		is_night = time_of_day > 0.75 or time_of_day < 0.25
	
	var eligible = []
	
	for enemy_id in enemies.keys():
		var enemy_data = enemies[enemy_id]
		
		# Check if available during current time of day
		if is_night:
			if enemy_data.get("available_night", true):
				eligible.append(enemy_id)
		else:
			if enemy_data.get("available_day", true):
				eligible.append(enemy_id)
	
	return eligible

func choose_weighted_enemy(eligible_enemies: Array) -> String:
	# Build weighted list using spawn_weight from JSON
	var total_weight = 0.0
	var weights = []
	
	for enemy_id in eligible_enemies:
		var enemy_data = enemies[enemy_id]
		var weight = enemy_data.get("spawn_weight", 100)
		total_weight += weight
		weights.append({"id": enemy_id, "weight": weight})
	
	# Random selection based on weights
	var roll = randf() * total_weight
	var cumulative = 0.0
	
	for entry in weights:
		cumulative += entry.weight
		if roll <= cumulative:
			return entry.id
	
	# Fallback
	return eligible_enemies[0]

func spawn_enemy(enemy_id: String, position: Vector3):
	if not enemies.has(enemy_id):
		push_error("Enemy not found in definitions: " + enemy_id)
		return
	
	var enemy_data = enemies[enemy_id]
	var scene_path = enemy_data.get("scene", "")
	
	if scene_path == "" or not ResourceLoader.exists(scene_path):
		push_error("Enemy scene not found: " + scene_path)
		return
	
	# Load and instantiate enemy
	var enemy_scene = load(scene_path)
	var enemy = enemy_scene.instantiate()
	
	# CRITICAL: Set enemy_definition BEFORE adding to tree (so _ready() can use it)
	if "enemy_definition" in enemy:
		enemy.enemy_definition = enemy_data
	
	# Add to world
	get_tree().root.add_child(enemy)
	enemy.global_position = position


func get_spawn_position_outside_camera() -> Vector3:
	if not player:
		return Vector3.ZERO
	
	# Calculate spawn distance based on camera size (for orthogonal cameras)
	var dynamic_spawn_distance = spawn_distance
	if camera and camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		dynamic_spawn_distance = camera.size * 2.5
	
	# Try multiple times to find a good spawn position
	for attempt in range(10):
		var angle = randf() * TAU
		var offset = Vector3(
			cos(angle) * dynamic_spawn_distance,
			0,
			sin(angle) * dynamic_spawn_distance
		)
		
		var potential_pos = player.global_position + offset
		
		# Check if position is outside view
		var spawn_here = true
		if camera:
			var in_view = is_position_in_camera_view(potential_pos)
			spawn_here = not in_view
		
		if spawn_here:
			# Raycast down to find ground
			var ground_pos = find_ground_position(potential_pos)
			
			if ground_pos != Vector3.ZERO:
				return ground_pos
	print("Failed to find spawn position after 10 attempts")
	return Vector3.ZERO

func is_position_in_camera_view(pos: Vector3) -> bool:
	if not camera:
		return false
	
	var screen_pos = camera.unproject_position(pos)
	var viewport = camera.get_viewport()
	
	if not viewport:
		return false
	
	var viewport_size = viewport.get_visible_rect().size
	
	var margin = 50
	var on_screen = (screen_pos.x >= -margin and 
					 screen_pos.x <= viewport_size.x + margin and
					 screen_pos.y >= -margin and 
					 screen_pos.y <= viewport_size.y + margin)
	
	return on_screen

func find_ground_position(pos: Vector3) -> Vector3:
	var space_state = get_tree().root.get_world_3d().direct_space_state
	var from = Vector3(pos.x, 50, pos.z)
	var to = Vector3(pos.x, -10, pos.z)
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	
	var result = space_state.intersect_ray(query)
	if result:
		return result.position + Vector3(0, 0.5, 0)
	
	return Vector3.ZERO

# Control functions
func enable_spawning():
	can_spawn = true

func disable_spawning():
	can_spawn = false

func clear_all_enemies():
	var enemies_list = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies_list:
		enemy.queue_free()

func enter_safe_zone():
	safe_zone_count += 1
	disable_spawning()
	despawn_enemies_near_player(20.0)

func exit_safe_zone():
	safe_zone_count -= 1
	safe_zone_count = max(0, safe_zone_count)
	
	if safe_zone_count == 0:
		enable_spawning()

func despawn_enemies_near_player(radius: float):
	if not player:
		return
	
	var enemies_list = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies_list:
		var dist = enemy.global_position.distance_to(player.global_position)
		if dist < radius:
			enemy.queue_free()

# Data access functions (similar to AnimalManager)
func get_enemy_data(enemy_id: String) -> Dictionary:
	if enemies.has(enemy_id):
		return enemies[enemy_id]
	return {}

func get_enemy_name(enemy_id: String) -> String:
	var data = get_enemy_data(enemy_id)
	return data.get("display_name", enemy_id)

func get_enemy_description(enemy_id: String) -> String:
	var data = get_enemy_data(enemy_id)
	return data.get("description", "")
