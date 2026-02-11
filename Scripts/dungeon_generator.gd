# dungeon_generator.gd
extends Node3D

const TILE_SIZE = 10.0

@export var dungeon_scale: float = 2.0

var player_reference: Node3D = null

const BASE_NUM_CORRIDORS = 8
const BASE_CORRIDOR_MIN_LENGTH = 4
const BASE_CORRIDOR_MAX_LENGTH = 5
const ROOM_CHANCE = 0.4
const ROOM_SIZE = 3

var floor_tile_scene = preload("res://Scenes/Explorable_Buildings/dungeon_floor.tscn")
var end_tile_scene = preload("res://Scenes/Explorable_Buildings/dungeon_floor_end.tscn")
var wall_tile_scene = preload("res://Scenes/Explorable_Buildings/dungeon_wall.tscn")
var wall_black_scene = preload("res://Scenes/Explorable_Buildings/dungeon_wall_black.tscn")

var occupied_positions: Array = []
var wall_positions: Array = []  # Track where walls are placed
var dungeon_tiles: Array = []

var enemy_spawn_chance: float = 0.7  # 70% chance to spawn enemies in a room
var min_enemies_per_room: int = 1
var max_enemies_per_room: int = 3

func generate_dungeon() -> Vector3:
	clear_dungeon()
	
	var num_corridors = int(BASE_NUM_CORRIDORS * dungeon_scale)
	var corridor_min = int(BASE_CORRIDOR_MIN_LENGTH * dungeon_scale)
	var corridor_max = int(BASE_CORRIDOR_MAX_LENGTH * dungeon_scale)
	
	var start_pos = Vector3.ZERO
	var current_pos = start_pos
	
	spawn_tile(floor_tile_scene, start_pos)
	occupied_positions.append(start_pos)
	
	for i in range(num_corridors):
		var direction = choose_random_direction()
		var corridor_length = randi_range(corridor_min, corridor_max)
		
		for step in range(corridor_length):
			current_pos += direction * TILE_SIZE
			
			if current_pos in occupied_positions:
				continue
			
			occupied_positions.append(current_pos)
			spawn_tile(floor_tile_scene, current_pos)
		
		if randf() < ROOM_CHANCE:
			create_room(current_pos, ROOM_SIZE)
			current_pos = get_random_room_edge(current_pos, ROOM_SIZE)
	
	spawn_tile(end_tile_scene, current_pos)
	
	# Generate walls after all floors are placed
	generate_walls()
	
	return start_pos

func generate_walls():
	# Find all edge positions where walls should be
	var wall_needed: Dictionary = {}  # position -> rotation
	
	# For each floor tile, mark where walls are needed
	for floor_pos in occupied_positions:
		var directions = [
			{"dir": Vector3(TILE_SIZE, 0, 0), "rot": 90},     # Right
			{"dir": Vector3(-TILE_SIZE, 0, 0), "rot": -90},   # Left
			{"dir": Vector3(0, 0, TILE_SIZE), "rot": 0},      # Forward
			{"dir": Vector3(0, 0, -TILE_SIZE), "rot": 180}    # Back
		]
		
		for d in directions:
			var check_pos = floor_pos + d.dir
			
			# If no floor here, we need a wall
			if check_pos not in occupied_positions:
				# Store this wall position with its rotation
				if not wall_needed.has(check_pos):
					wall_needed[check_pos] = d.rot
	
	# Track where we've placed black walls to avoid duplicates
	var black_wall_positions: Array = []
	
	# Now place all the walls
	for wall_pos in wall_needed.keys():
		var rotation_y = wall_needed[wall_pos]
		
		# Place regular wall
		var wall = wall_tile_scene.instantiate()
		add_child(wall)
		wall.global_position = wall_pos + Vector3(0, 5, 0)
		wall.rotation_degrees.y = rotation_y
		wall.add_to_group("walls")
		dungeon_tiles.append(wall)
	
	# Now place black walls around ALL wall positions (including diagonals)
	for wall_pos in wall_needed.keys():
		# Check all 8 surrounding positions
		var surrounding = [
			Vector3(TILE_SIZE, 0, 0),           # Right
			Vector3(-TILE_SIZE, 0, 0),          # Left
			Vector3(0, 0, TILE_SIZE),           # Forward
			Vector3(0, 0, -TILE_SIZE),          # Back
			Vector3(TILE_SIZE, 0, TILE_SIZE),   # Forward-Right
			Vector3(TILE_SIZE, 0, -TILE_SIZE),  # Back-Right
			Vector3(-TILE_SIZE, 0, TILE_SIZE),  # Forward-Left
			Vector3(-TILE_SIZE, 0, -TILE_SIZE), # Back-Left
		]
		
		for offset in surrounding:
			var black_wall_pos = wall_pos + offset
			
			# Only place if:
			# 1. Not occupied by floor
			# 2. Not occupied by regular wall
			# 3. Haven't already placed a black wall here
			if (black_wall_pos not in occupied_positions and 
				black_wall_pos not in wall_needed and
				black_wall_pos not in black_wall_positions):
				
				var black_wall = wall_black_scene.instantiate()
				add_child(black_wall)
				black_wall.global_position = black_wall_pos + Vector3(0, 5, 0)
				# Black walls don't need specific rotation, they're just backdrop
				dungeon_tiles.append(black_wall)
				black_wall_positions.append(black_wall_pos)

func set_player_reference(player: Node3D):
	player_reference = player

func _process(_delta):
	if not player_reference:
		return

func create_room(center: Vector3, radius: int):
	for x in range(-radius, radius + 1):
		for z in range(-radius, radius + 1):
			var tile_pos = center + Vector3(x * TILE_SIZE, 0, z * TILE_SIZE)
			
			if tile_pos in occupied_positions:
				continue
			
			occupied_positions.append(tile_pos)
			spawn_tile(floor_tile_scene, tile_pos)

func get_random_room_edge(center: Vector3, room_size: int) -> Vector3:
	var side = randi() % 4
	var offset = randi_range(-room_size + 1, room_size - 1)
	
	match side:
		0: return center + Vector3(room_size * TILE_SIZE, 0, offset * TILE_SIZE)
		1: return center + Vector3(-room_size * TILE_SIZE, 0, offset * TILE_SIZE)
		2: return center + Vector3(offset * TILE_SIZE, 0, room_size * TILE_SIZE)
		3: return center + Vector3(offset * TILE_SIZE, 0, -room_size * TILE_SIZE)
	
	return center

func choose_random_direction() -> Vector3:
	var directions = [
		Vector3(1, 0, 0),
		Vector3(-1, 0, 0),
		Vector3(0, 0, 1),
		Vector3(0, 0, -1)
	]
	return directions[randi() % directions.size()]

func spawn_tile(tile_scene: PackedScene, position: Vector3):
	var tile = tile_scene.instantiate()
	add_child(tile)
	tile.global_position = position + Vector3(0, 5, 0)
	dungeon_tiles.append(tile)

func check_and_place_wall(floor_pos: Vector3, direction: Vector3, rotation_y: float):
	var check_pos = floor_pos + direction
	
	# Don't place wall if there's already a floor there
	if check_pos in occupied_positions:
		return
	
	# Calculate wall position
	var wall_pos = floor_pos + direction
	
	# Don't place wall if one already exists here
	if wall_pos in wall_positions:
		return
	
	# Place the regular wall
	var wall = wall_tile_scene.instantiate()
	add_child(wall)
	
	wall.global_position = wall_pos + Vector3(0, 5, 0)
	wall.rotation_degrees.y = rotation_y
	wall.add_to_group("walls")
	
	# Place black wall behind it (one tile further out)
	var black_wall = wall_black_scene.instantiate()
	add_child(black_wall)
	
	black_wall.global_position = wall_pos + direction + Vector3(0, 5, 0)
	black_wall.rotation_degrees.y = rotation_y
	
	# Track this wall position
	wall_positions.append(wall_pos)
	dungeon_tiles.append(wall)
	dungeon_tiles.append(black_wall)

func clear_dungeon():
	for tile in dungeon_tiles:
		tile.queue_free()
	
	dungeon_tiles.clear()
	occupied_positions.clear()
	wall_positions.clear()
