# animal_manager.gd
# Autoload — add as "AnimalManager" in Project > Autoload
extends Node

# ========== CONFIG ==========
const ANIMALS_FILE = "res://Data/animals.json"

var max_animals: int = 30
var spawn_cooldown: float = 4.0       # Seconds between spawn attempts
var spawn_distance: float = 22.0      # How far from player to spawn
var can_spawn: bool = false

# ========== DATA ==========
# Full definitions loaded from JSON: { "deer": { ... }, "wolf": { ... }, ... }
var animal_definitions: Dictionary = {}

# Preloaded scenes cached at startup so instantiation is instant
# { "deer": <PackedScene>, "wolf": <PackedScene>, ... }
var _scene_cache: Dictionary = {}

# ========== REFERENCES ==========
var player: Node3D = null
var camera: Camera3D = null

# ========== LIFECYCLE ==========

func _ready():
	_load_animal_definitions()
	_cache_scenes()

	var spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_cooldown
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)
	spawn_timer.start()

# ========== LOADING ==========

func _load_animal_definitions():
	if not FileAccess.file_exists(ANIMALS_FILE):
		push_error("AnimalManager: animals.json not found at " + ANIMALS_FILE)
		return

	var file = FileAccess.open(ANIMALS_FILE, FileAccess.READ)
	if not file:
		push_error("AnimalManager: Failed to open animals.json")
		return

	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("AnimalManager: Failed to parse animals.json — " + json.get_error_message())
		file.close()
		return

	file.close()
	animal_definitions = json.data
	print("✓ AnimalManager loaded ", animal_definitions.size(), " animal definitions")

func _cache_scenes():
	for key in animal_definitions:
		var scene_path: String = animal_definitions[key].get("scene", "")
		if scene_path != "" and ResourceLoader.exists(scene_path):
			_scene_cache[key] = load(scene_path)
		else:
			push_error("AnimalManager: Scene not found for '%s' at '%s'" % [key, scene_path])

# ========== SPAWN LOOP ==========

func _on_spawn_timer_timeout():
	if not can_spawn:
		return

	_resolve_player_and_camera()

	if not player:
		return

	# Check current animal count
	var current_count = get_tree().get_nodes_in_group("animals").size()
	if current_count >= max_animals:
		return

	# Build the pool of animals eligible to spawn right now (day/night filtered)
	var eligible = _get_eligible_animals()
	if eligible.is_empty():
		return

	# Weighted random pick from eligible pool
	var chosen_key = _weighted_pick(eligible)
	if chosen_key == "":
		return

	# Find a valid spawn point outside the camera
	var spawn_pos = _get_spawn_position_outside_camera()
	if spawn_pos == Vector3.ZERO:
		return

	_spawn_animal(chosen_key, spawn_pos)

# ========== ELIGIBILITY & SELECTION ==========

# Returns a Dictionary of { "key": definition } for animals eligible this tick.
# Filters by day/night availability.
func _get_eligible_animals() -> Dictionary:
	var is_night = _is_night()
	var eligible: Dictionary = {}

	for key in animal_definitions:
		var def = animal_definitions[key]
		if is_night and def.get("available_night", false):
			eligible[key] = def
		elif not is_night and def.get("available_day", false):
			eligible[key] = def

	return eligible

# Weighted random selection.
# spawn_weight is the direct weight — higher = more likely.
# A weight of 5 among weights totaling 500 gives a ~1% chance per attempt.
func _weighted_pick(eligible: Dictionary) -> String:
	var total_weight: float = 0.0
	for key in eligible:
		total_weight += eligible[key].get("spawn_weight", 1)

	var roll: float = randf() * total_weight
	var cumulative: float = 0.0

	for key in eligible:
		cumulative += eligible[key].get("spawn_weight", 1)
		if roll <= cumulative:
			return key

	# Fallback (shouldn't reach here, but safety net)
	return eligible.keys()[0]

# ========== SPAWNING ==========

func _spawn_animal(animal_key: String, spawn_pos: Vector3):
	if not _scene_cache.has(animal_key):
		push_error("AnimalManager: No cached scene for '%s'" % animal_key)
		return

	var scene: PackedScene = _scene_cache[animal_key]
	var animal = scene.instantiate()

	# Inject the definition so the animal knows its own stats
	# (BaseAnimal reads this in _ready before setting up)
	animal.set("animal_definition", animal_definitions[animal_key])
	animal.set("animal_key", animal_key)

	get_tree().root.add_child(animal)
	animal.global_position = spawn_pos
	print("AnimalManager: Spawned '%s' at %s" % [animal_key, spawn_pos])

# ========== SPAWN POSITION (mirrors EnemyManager logic exactly) ==========

func _get_spawn_position_outside_camera() -> Vector3:
	for _attempt in range(10):
		var angle: float = randf() * TAU
		var offset = Vector3(
			cos(angle) * spawn_distance,
			0.0,
			sin(angle) * spawn_distance
		)

		var potential_pos = player.global_position + offset

		var spawn_here = true
		if camera:
			spawn_here = not _is_position_in_camera_view(potential_pos)

		if spawn_here:
			var ground_pos = _find_ground_position(potential_pos)
			if ground_pos != Vector3.ZERO:
				return ground_pos

	return Vector3.ZERO

func _is_position_in_camera_view(pos: Vector3) -> bool:
	if not camera:
		return false

	var screen_pos = camera.unproject_position(pos)
	var viewport = camera.get_viewport()
	if not viewport:
		return false

	var vp_size = viewport.get_visible_rect().size
	var margin = 50

	return (screen_pos.x >= -margin and
			screen_pos.x <= vp_size.x + margin and
			screen_pos.y >= -margin and
			screen_pos.y <= vp_size.y + margin)

func _find_ground_position(pos: Vector3) -> Vector3:
	var space_state = get_tree().root.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		Vector3(pos.x, 50.0, pos.z),
		Vector3(pos.x, -10.0, pos.z)
	)
	query.collision_mask = 1  # Ground layer

	var result = space_state.intersect_ray(query)
	if result:
		return result.position + Vector3(0.0, 0.5, 0.0)

	return Vector3.ZERO

# ========== DAY/NIGHT HELPER ==========

func _is_night() -> bool:
	var day_night = get_node_or_null("/root/main/day_night_overlay/ColorRect")
	if not day_night or not ("time_of_day" in day_night):
		return false  # Default to day if cycle not found

	var t: float = day_night.time_of_day
	return t > 0.75 or t < 0.25

# ========== PLAYER / CAMERA RESOLUTION ==========

func _resolve_player_and_camera():
	if not player:
		player = get_tree().get_first_node_in_group("player")

	if not camera:
		var main = get_node_or_null("/root/main")
		if main:
			var subviewport = main.get_node_or_null("SubViewportContainer/SubViewport")
			if subviewport:
				camera = subviewport.get_camera_3d()
			if not camera:
				camera = main.find_child("Camera3D", true, false)

# ========== PUBLIC CONTROLS ==========

func enable_spawning():
	can_spawn = true

func disable_spawning():
	can_spawn = false

func clear_all_animals():
	for animal in get_tree().get_nodes_in_group("animals"):
		animal.queue_free()
