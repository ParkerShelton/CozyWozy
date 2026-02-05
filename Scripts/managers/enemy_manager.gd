# enemy_manager.gd
extends Node

# Enemy scenes
var enemy_types = {
	"robot_basic": preload("res://Scenes/Enemies/robot_basic.tscn"),
	"robot_midget": preload("res://Scenes/Enemies/robot_midget.tscn"),
}


# Spawn settings
var max_enemies: int = 20
var spawn_cooldown: float = 5.0  # Seconds between spawn attempts
var spawn_distance: float = 200.0  # How far from camera to spawn
var can_spawn: bool = false

# Day/night spawn rates
var day_spawn_chance: float = 0.5  # 30% chance to spawn during day
var night_spawn_chance: float = 0.8  # 80% chance to spawn at night

# Enemy pools for day/night
var day_enemies: Array = ["robot_midget"]
var night_enemies: Array = ["robot_basic", "robot_midget"]

# References
var player: Node3D = null
var camera: Camera3D = null

var safe_zone_count: int = 0

func _ready():
	# Start spawn timer
	var spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_cooldown
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)
	spawn_timer.start()

func _on_spawn_timer_timeout():
	if not can_spawn:
		return
	
	# Get player and camera
	if not player:
		player = get_tree().get_first_node_in_group("player")
	
	# Get camera - try multiple methods
	if not camera:
		# Try getting from main scene
		var main = get_node_or_null("/root/main")
		if main:
			# Try direct Camera3D child
			camera = main.get_node_or_null("Camera3D")
			
			# Try SubViewport
			if not camera:
				var subviewport = main.get_node_or_null("SubViewportContainer/SubViewport")
				if subviewport:
					camera = subviewport.get_camera_3d()
			
			# Try finding any Camera3D in the tree
			if not camera:
				camera = main.find_child("Camera3D", true, false)
	
	
	# Check current enemy count
	var current_enemies = get_tree().get_nodes_in_group("enemies")
	
	if current_enemies.size() >= max_enemies:
		return
	
	# Check if we should spawn based on time of day
	var should_spawn = should_spawn_enemy()
	
	if not should_spawn:
		return
	
	# Choose enemy type
	var enemy_type = choose_enemy_type()
	
	spawn_enemy(enemy_type)

func should_spawn_enemy() -> bool:
	# Get the new ColorRect day/night overlay
	var day_night_cycle = get_node_or_null("/root/main/day_night_overlay/ColorRect")
	
	if not day_night_cycle:
		print("No day/night cycle found")
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
	var day_night_cycle = get_node_or_null("/root/main/day_night_overlay/ColorRect")
	var is_night = false
	
	if day_night_cycle and "time_of_day" in day_night_cycle:
		var time_of_day = day_night_cycle.time_of_day
		is_night = time_of_day > 0.75 or time_of_day < 0.25
	
	var enemy_pool = night_enemies if is_night else day_enemies
	return enemy_pool[randi() % enemy_pool.size()]

func spawn_enemy(enemy_type: String):
	
	if not enemy_types.has(enemy_type):
		print("ERROR: Unknown enemy type: ", enemy_type)
		return
	
	# Get spawn position outside camera view
	var spawn_pos = get_spawn_position_outside_camera()
	
	if spawn_pos == Vector3.ZERO:
		print("ERROR: No valid spawn position found (returned Vector3.ZERO)")
		return
	
	# Create enemy
	var enemy_scene = enemy_types[enemy_type]
	var enemy = enemy_scene.instantiate()
	
	# Add to world
	get_tree().root.add_child(enemy)
	
	enemy.global_position = spawn_pos

func get_spawn_position_outside_camera() -> Vector3:
	if not player:
		print("No player for spawn position")
		return Vector3.ZERO
	
	# Calculate spawn distance based on camera size (for orthogonal cameras)
	var dynamic_spawn_distance = spawn_distance
	if camera and camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		# Scale spawn distance with camera size
		dynamic_spawn_distance = camera.size * 2.5  # Adjust multiplier as needed
	
	# Try multiple times to find a good spawn position
	for attempt in range(10):
		var angle = randf() * TAU
		var offset = Vector3(
			cos(angle) * dynamic_spawn_distance,
			0,
			sin(angle) * dynamic_spawn_distance
		)
		
		var potential_pos = player.global_position + offset
		
		# If we have a camera, check if position is outside view
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
	
	# Project world position to screen
	var screen_pos = camera.unproject_position(pos)
	var viewport = camera.get_viewport()
	
	if not viewport:
		return false
	
	var viewport_size = viewport.get_visible_rect().size
	
	# Check if on screen (with small margin to truly be off-screen)
	var margin = 50
	var on_screen = (screen_pos.x >= -margin and 
					 screen_pos.x <= viewport_size.x + margin and
					 screen_pos.y >= -margin and 
					 screen_pos.y <= viewport_size.y + margin)
	
	return on_screen

func find_ground_position(pos: Vector3) -> Vector3:
	# Raycast down from high up to find ground
	var space_state = get_tree().root.get_world_3d().direct_space_state
	var from = Vector3(pos.x, 50, pos.z)
	var to = Vector3(pos.x, -10, pos.z)
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1  # Ground layer
	
	var result = space_state.intersect_ray(query)
	if result:
		return result.position + Vector3(0, 0.5, 0)  # Slightly above ground
	
	return Vector3.ZERO

# Control spawning
func enable_spawning():
	can_spawn = true
	print("Enemy spawning enabled")

func disable_spawning():
	can_spawn = false
	print("Enemy spawning disabled")

func clear_all_enemies():
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		enemy.queue_free()


func enter_safe_zone():
	safe_zone_count += 1
	disable_spawning()
	
	# Optional: clear nearby enemies
	despawn_enemies_near_player(20.0)  # 15 unit radius

func exit_safe_zone():
	safe_zone_count -= 1
	safe_zone_count = max(0, safe_zone_count)  # Don't go negative
	
	# Only re-enable spawning if not in ANY safe zones
	if safe_zone_count == 0:
		enable_spawning()

func despawn_enemies_near_player(radius: float):
	if not player:
		return
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		var dist = enemy.global_position.distance_to(player.global_position)
		if dist < radius:
			print("Despawning enemy in safe zone")
			enemy.queue_free()
