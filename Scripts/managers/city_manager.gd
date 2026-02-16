# abandoned_city_manager.gd
extends Node

# PRE-LOAD BUILDING PIECES
const CITY_PIECES = {
	# Streets
	"street_straight": preload("res://Scenes/City/Streets/street_straight.tscn"),
	"street_corner": preload("res://Scenes/City/Streets/street_corner.tscn"),
	"street_intersection": preload("res://Scenes/City/Streets/street_intersection.tscn"),
	"street_t_junction": preload("res://Scenes/City/Streets/street_t_junction.tscn"),
	
	# Filler
	"street_filled": preload("res://Scenes/City/Streets/street_filled.tscn"),
	
	# Buildings (all will look broken/abandoned)
	"house_small": preload("res://Scenes/City/Buildings/house_small.tscn"),
	"house_medium": preload("res://Scenes/City/Buildings/house_medium.tscn"),
	"house_large": preload("res://Scenes/City/Buildings/house_large.tscn"),
	# "apartment": preload("res://Scenes/City/Buildings/apartment.tscn"),
	# "shop": preload("res://Scenes/City/Buildings/shop.tscn"),
	# "office": preload("res://Scenes/City/Buildings/office_building.tscn"),
	
	# Special locations
	# "plaza": preload("res://Scenes/City/plaza.tscn"),
	# "park": preload("res://Scenes/City/park.tscn"),
	# "fountain": preload("res://Scenes/City/fountain.tscn"),
	# "rubble_pile": preload("res://Scenes/City/rubble_pile.tscn"),
}

# City generation settings - HUGE SIZES with TONS of buildings
var city_sizes: Array = [
	{"name": "hamlet", "size": Vector2i(20, 20), "weight": 30},
	{"name": "village", "size": Vector2i(30, 30), "weight": 40},
	{"name": "town", "size": Vector2i(40, 40), "weight": 20},
	{"name": "city", "size": Vector2i(50, 50), "weight": 10},
]

var block_size: float = 40.0
var spawn_chance: float = 0.005
var min_distance_from_spawn: float = 200.0
var min_distance_between_cities: float = 500.0

var _street_positions: Dictionary = {}
var _building_positions: Array = []

# City layout types
enum LayoutType {
	GRID,
	ORGANIC,
	RADIAL,
	MIXED
}

var spawned_cities: Array = []
var city_zones: Array = []

var grass_hider: Node = null

func _ready():
	if CITY_PIECES.has("street_straight"):
		var street = CITY_PIECES["street_straight"].instantiate()
		var mesh_instance = street.find_child("*", true, false)
		if mesh_instance is MeshInstance3D and mesh_instance.mesh:
			var aabb = mesh_instance.mesh.get_aabb()
			var calculated_size = max(aabb.size.x, aabb.size.z)
			if calculated_size > 0:
				block_size = calculated_size
				print("📏 Auto-calculated block_size from street model: ", block_size)
		street.queue_free()

# Check if a position is inside any city
func is_in_city(position: Vector3) -> bool:
	for zone in city_zones:
		if (position.x >= zone["min_x"] and position.x <= zone["max_x"] and
			position.z >= zone["min_z"] and position.z <= zone["max_z"]):
			return true
	return false

func try_spawn_city_in_chunk(chunk_coord: Vector2i, chunk_world_pos: Vector3) -> bool:
	if chunk_world_pos.length() < min_distance_from_spawn:
		return false
	if randf() > spawn_chance:
		return false
	for city in spawned_cities:
		if chunk_world_pos.distance_to(city["position"]) < min_distance_between_cities:
			return false
	
	var city_config = choose_weighted_city_size()
	var city_size = city_config["size"]
	var city_name = city_config["name"]
	var layout = choose_layout_type(city_name)
	
	generate_city(chunk_world_pos, city_size, layout, city_name)
	
	spawned_cities.append({
		"position": chunk_world_pos,
		"size": city_size,
		"name": city_name,
		"layout": layout
	})
	
	return true

func choose_weighted_city_size() -> Dictionary:
	var total_weight = 0
	for city in city_sizes:
		total_weight += city["weight"]
	
	var rand = randf() * total_weight
	var current = 0.0
	
	for city in city_sizes:
		current += city["weight"]
		if rand <= current:
			return city
	
	return city_sizes[0]

func choose_layout_type(city_name: String) -> LayoutType:
	match city_name:
		"hamlet":
			return [LayoutType.ORGANIC, LayoutType.GRID][randi() % 2]
		"village":
			return [LayoutType.GRID, LayoutType.MIXED][randi() % 2]
		"town", "city":
			return LayoutType.GRID
		_:
			return LayoutType.GRID

func generate_city(origin: Vector3, city_size: Vector2i, layout: LayoutType, city_name: String):
	print("🏙️ Generating ", city_name, " at ", origin, " - Layout: ", LayoutType.keys()[layout])
	print("   City size: ", city_size, " blocks (", city_size.x * block_size, "x", city_size.y * block_size, " units)")
	
	var city_width = city_size.x * block_size
	var city_depth = city_size.y * block_size
	city_zones.append({
		"min_x": origin.x,
		"max_x": origin.x + city_width,
		"min_z": origin.z,
		"max_z": origin.z + city_depth
	})
	print("   🚫 Registered no-foliage zone: X(", origin.x, " to ", origin.x + city_width, "), Z(", origin.z, " to ", origin.z + city_depth, ")")
	
	var city_container = Node3D.new()
	city_container.name = "City_" + city_name + "_" + str(origin)
	get_tree().root.add_child(city_container)
	
	# Clear street positions tracker
	_street_positions.clear()
	_building_positions.clear()
	
	# Generate streets and buildings FIRST
	match layout:
		LayoutType.GRID:
			generate_grid_city(origin, city_size, city_container)
		LayoutType.ORGANIC:
			generate_organic_city(origin, city_size, city_container)
		LayoutType.RADIAL:
			generate_radial_city(origin, city_size, city_container)
		LayoutType.MIXED:
			generate_mixed_city(origin, city_size, city_container)
	
	# THEN fill remaining gaps
	fill_city_ground(origin, city_size, city_container)
	
	add_special_locations(origin, city_size, city_container)

func fill_city_ground(origin: Vector3, city_size: Vector2i, parent: Node3D):
	var city_ground_height = get_ground_height(origin)
	var straights_per_block = 5
	var piece_size = block_size / straights_per_block
	
	for x in range((city_size.x - 1) * straights_per_block):
		for z in range((city_size.y - 1) * straights_per_block):
			var world_pos = origin + Vector3(x * piece_size, city_ground_height, z * piece_size)
			
			var key = str(snapped(world_pos.x, 0.1)) + "," + str(snapped(world_pos.z, 0.1))
			if _street_positions.has(key):
				continue
			
			var piece = CITY_PIECES["street_filled"].instantiate()
			parent.add_child(piece)
			piece.global_position = world_pos

# Clear objects at a specific position
func clear_position(position: Vector3, radius: float):
	var trees = get_tree().get_nodes_in_group("trees")
	for tree in trees:
		if tree.global_position.distance_to(position) < radius:
			tree.queue_free()
	
	var rocks = get_tree().get_nodes_in_group("rocks")
	for rock in rocks:
		if rock.global_position.distance_to(position) < radius:
			rock.queue_free()
	
	var apple_trees = get_tree().get_nodes_in_group("apple_tree")
	for apple_tree in apple_trees:
		if apple_tree.global_position.distance_to(position) < radius:
			apple_tree.queue_free()
	
	var grass = get_tree().get_nodes_in_group("grass")
	for grass_item in grass:
		if grass_item.global_position.distance_to(position) < radius:
			grass_item.queue_free()
	
	if ExplorableBuildingsManager:
		for i in range(ExplorableBuildingsManager.spawned_buildings.size() - 1, -1, -1):
			var building = ExplorableBuildingsManager.spawned_buildings[i]
			if building["position"].distance_to(position) < radius:
				if is_instance_valid(building["instance"]):
					building["instance"].queue_free()
				ExplorableBuildingsManager.spawned_buildings.remove_at(i)

func get_ground_height(position: Vector3) -> float:
	var space_state = get_tree().root.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		Vector3(position.x, 50, position.z),
		Vector3(position.x, -10, position.z)
	)
	query.collision_mask = 1
	
	var result = space_state.intersect_ray(query)
	if result:
		return result.position.y + 0.1
	return 0.0

# ========== GRID LAYOUT ==========
func generate_grid_city(origin: Vector3, city_size: Vector2i, parent: Node3D):
	print("📐 GRID LAYOUT - Perfect street grid with straight pieces filling gaps")
	var city_ground_height = get_ground_height(origin)
	
	var straights_per_block = 5
	var street_spacing_blocks = 4
	
	var building_count = 0
	var street_count = 0
	
	var street_piece_size = block_size / straights_per_block
	
	# FIRST PASS - Place all intersections and buildings
	for x in range(city_size.x):
		for z in range(city_size.y):
			var block_pos = origin + Vector3(x * block_size, city_ground_height, z * block_size)
			
			var on_vertical_street = (x % street_spacing_blocks == 0)
			var on_horizontal_street = (z % street_spacing_blocks == 0)
			
			if on_vertical_street and on_horizontal_street:
				spawn_piece_at_height("street_intersection", block_pos, 0, parent)
				street_count += 1
			elif not on_vertical_street and not on_horizontal_street:
				var distance_to_vertical_street = x % street_spacing_blocks
				var distance_to_horizontal_street = z % street_spacing_blocks
				
				var face_direction = 0.0
				if distance_to_vertical_street < distance_to_horizontal_street:
					if distance_to_vertical_street < street_spacing_blocks / 2:
						face_direction = PI/2
					else:
						face_direction = -PI/2
				else:
					if distance_to_horizontal_street < street_spacing_blocks / 2:
						face_direction = 0
					else:
						face_direction = PI
				
				spawn_random_building_at_height(block_pos, parent, face_direction)
				building_count += 1
	
	# SECOND PASS - Fill gaps between intersections with straights
	for x in range(city_size.x):
		for z in range(city_size.y):
			var on_vertical_street = (x % street_spacing_blocks == 0)
			var on_horizontal_street = (z % street_spacing_blocks == 0)
			var is_intersection = on_vertical_street and on_horizontal_street
			
			# VERTICAL STREETS
			if on_vertical_street and not is_intersection:
				var block_pos = origin + Vector3(x * block_size, city_ground_height, z * block_size)
				for i in range(straights_per_block):
					var piece_pos = block_pos + Vector3(0, 0, i * street_piece_size)
					spawn_piece_at_height("street_straight", piece_pos, 0, parent)
					street_count += 1
			
			# HORIZONTAL STREETS
			if on_horizontal_street and not is_intersection:
				var block_pos = origin + Vector3(x * block_size, city_ground_height, z * block_size)
				for i in range(straights_per_block):
					var piece_pos = block_pos + Vector3(i * street_piece_size, 0, 0)
					spawn_piece_at_height("street_straight", piece_pos, PI/2, parent)
					street_count += 1
			
			# FILL THE GAP from intersection to next block edge
			if is_intersection:
				var intersection_pos = origin + Vector3(x * block_size, city_ground_height, z * block_size)
				
				if x < city_size.x - 1:
					for i in range(1, straights_per_block + 1):
						var piece_pos = intersection_pos + Vector3(i * street_piece_size, 0, 0)
						spawn_piece_at_height("street_straight", piece_pos, PI/2, parent)
						street_count += 1
				
				if z < city_size.y - 1:
					for i in range(1, straights_per_block + 1):
						var piece_pos = intersection_pos + Vector3(0, 0, i * street_piece_size)
						spawn_piece_at_height("street_straight", piece_pos, 0, parent)
						street_count += 1
	
	print("✅ GRID COMPLETE - Streets: ", street_count, " pieces, Buildings: ", building_count, " blocks")

# ========== ORGANIC LAYOUT ==========
func generate_organic_city(origin: Vector3, city_size: Vector2i, parent: Node3D):
	var city_ground_height = get_ground_height(origin)
	var center = origin + Vector3(city_size.x * block_size * 0.5, city_ground_height, city_size.y * block_size * 0.5)
	var num_paths = randi_range(4, 6)
	
	var street_positions = []
	
	for path in range(num_paths):
		var angle = (TAU / num_paths) * path + randf_range(-0.3, 0.3)
		var current_pos = center
		var current_angle = angle
		
		for step in range(city_size.x):
			street_positions.append(current_pos)
			current_angle += randf_range(-0.2, 0.2)
			current_pos += Vector3(cos(current_angle), 0, sin(current_angle)) * block_size
			
			if current_pos.distance_to(center) > city_size.x * block_size * 0.5:
				break
	
	for x in range(city_size.x):
		for z in range(city_size.y):
			var block_pos = origin + Vector3(x * block_size, city_ground_height, z * block_size)
			
			var near_street = false
			for street_pos in street_positions:
				if block_pos.distance_to(street_pos) < block_size * 1.2:
					near_street = true
					break
			
			if near_street:
				if randf() < 0.2:
					spawn_piece_at_height("street_straight", block_pos, 0, parent)
				else:
					spawn_random_building_at_height(block_pos, parent)
			else:
				spawn_random_building_at_height(block_pos, parent)

# ========== RADIAL LAYOUT ==========
func generate_radial_city(origin: Vector3, city_size: Vector2i, parent: Node3D):
	var city_ground_height = get_ground_height(origin)
	var center = origin + Vector3(city_size.x * block_size * 0.5, city_ground_height, city_size.y * block_size * 0.5)
	var num_spokes = randi_range(6, 8)
	
	for x in range(city_size.x):
		for z in range(city_size.y):
			var block_pos = origin + Vector3(x * block_size, city_ground_height, z * block_size)
			var dir_offset = block_pos - center
			var angle = atan2(dir_offset.z, dir_offset.x)
			var distance = dir_offset.length()
			
			var is_spoke = false
			for spoke in range(num_spokes):
				var spoke_angle = (TAU / num_spokes) * spoke
				if abs(angle - spoke_angle) < 0.2 or abs(angle - spoke_angle - TAU) < 0.2:
					is_spoke = true
					break
			
			var is_ring = int(distance / block_size) % 5 == 0
			
			if is_spoke or is_ring:
				spawn_piece_at_height("street_straight", block_pos, 0, parent)
			else:
				spawn_random_building_at_height(block_pos, parent)

# ========== MIXED LAYOUT ==========
func generate_mixed_city(origin: Vector3, city_size: Vector2i, parent: Node3D):
	var city_ground_height = get_ground_height(origin)
	
	for x in range(city_size.x):
		for z in range(city_size.y):
			var block_pos = origin + Vector3(x * block_size, city_ground_height, z * block_size)
			
			var in_center = (x >= city_size.x/4 and x <= city_size.x*3/4 and 
							 z >= city_size.y/4 and z <= city_size.y*3/4)
			
			if in_center:
				var is_street_x = (x % 5 == 0)
				var is_street_z = (z % 5 == 0)
				
				if is_street_x or is_street_z:
					spawn_piece_at_height("street_straight", block_pos, 0, parent)
				else:
					spawn_random_building_at_height(block_pos, parent)
			else:
				if randf() < 0.15:
					spawn_piece_at_height("street_straight", block_pos, 0, parent)
				else:
					spawn_random_building_at_height(block_pos, parent)

# ========== BUILDING SPAWNING ==========
func spawn_random_building_at_height(position: Vector3, parent: Node3D, face_direction: float = 0.0):
	if randf() < 0.05:
		if CITY_PIECES.has("rubble_pile"):
			spawn_piece_at_height("rubble_pile", position, randf() * TAU, parent)
		return
	
	var available_buildings = []
	
	var radius = 25
	
	if CITY_PIECES.has("house_small"):
		available_buildings.append({"type": "house_small", "weight": 40, "radius": radius})
	if CITY_PIECES.has("house_medium"):
		available_buildings.append({"type": "house_medium", "weight": 30, "radius": radius})
	if CITY_PIECES.has("house_large"):
		available_buildings.append({"type": "house_large", "weight": 20, "radius": radius})
	if CITY_PIECES.has("apartment"):
		available_buildings.append({"type": "apartment", "weight": 15, "radius": radius})
	if CITY_PIECES.has("shop"):
		available_buildings.append({"type": "shop", "weight": 10, "radius": radius})
	if CITY_PIECES.has("office"):
		available_buildings.append({"type": "office", "weight": 8, "radius": radius})
	
	if available_buildings.size() == 0:
		return
	
	var total_weight = 0
	for b in available_buildings:
		total_weight += b["weight"]
	
	var rand_building = randf() * total_weight
	var current = 0.0
	
	for b in available_buildings:
		current += b["weight"]
		if rand_building <= current:
			# Calculate the actual position with offset
			var actual_pos = position
			actual_pos.y += 0.5
			actual_pos.x += randf_range(-8, 8)
			actual_pos.z += randf_range(-8, 8)
			
			# Check against existing buildings
			var min_dist = b["radius"]
			var too_close = false
			for existing in _building_positions:
				var required = min_dist + existing["radius"]
				if actual_pos.distance_to(existing["position"]) < required:
					too_close = true
					break
			
			if too_close:
				return
			
			_building_positions.append({"position": actual_pos, "radius": min_dist})
			
			# Spawn directly here instead of through spawn_piece_at_height
			var scene = CITY_PIECES.get(b["type"])
			if not scene:
				return
			clear_position(actual_pos, block_size)
			var piece = scene.instantiate()
			parent.add_child(piece)
			piece.global_position = actual_pos
			piece.rotation.y = face_direction
			return

# ========== SPECIAL LOCATIONS ==========
func add_special_locations(origin: Vector3, city_size: Vector2i, parent: Node3D):
	var city_ground_height = get_ground_height(origin)
	var center = origin + Vector3(city_size.x * block_size * 0.5, city_ground_height, city_size.y * block_size * 0.5)
	
	if city_size.x >= 10:
		if CITY_PIECES.has("plaza"):
			spawn_piece_at_height("plaza", center, 0, parent)
		elif CITY_PIECES.has("park"):
			spawn_piece_at_height("park", center, 0, parent)
		elif CITY_PIECES.has("fountain"):
			spawn_piece_at_height("fountain", center, 0, parent)
	
	var num_parks = max(2, city_size.x / 5)
	if CITY_PIECES.has("park"):
		for i in range(num_parks):
			var park_pos = origin + Vector3(
				randf_range(0, city_size.x * block_size),
				city_ground_height,
				randf_range(0, city_size.y * block_size)
			)
			spawn_piece_at_height("park", park_pos, randf() * TAU, parent)

# ========== PIECE SPAWNING ==========
func spawn_piece_at_height(piece_type: String, position: Vector3, rotation_y: float, parent: Node3D):
	var scene = CITY_PIECES.get(piece_type)
	if not scene:
		return
	
	var clear_radius = block_size
	
	var adjusted_position = position
	if piece_type in ["house_small", "house_medium", "house_large", "apartment", "shop", "office"]:
		adjusted_position.y += 0.5
		var offset_x = randf_range(-8, 8)
		var offset_z = randf_range(-8, 8)
		adjusted_position.x += offset_x
		adjusted_position.z += offset_z
	
	if piece_type != "street_filled":
		clear_position(adjusted_position, clear_radius)
	
	# Track street positions
	if piece_type in ["street_straight", "street_corner", "street_intersection", "street_t_junction"]:
		var key = str(snapped(position.x, 0.1)) + "," + str(snapped(position.z, 0.1))
		_street_positions[key] = true
	
	var piece = scene.instantiate()
	parent.add_child(piece)
	piece.global_position = adjusted_position
	piece.rotation.y = rotation_y

# ========== DEBUG/TESTING ==========
func spawn_test_city_near_spawn():
	"""Spawns a test city close to spawn for testing. Remove later!"""
	var test_position = Vector3(100, 0, 100)
	var city_size = Vector2i(5, 5)
	var layout = LayoutType.GRID
	
	print("🧪 ========== TEST CITY DEBUG ==========")
	print("Position: ", test_position)
	print("Size: ", city_size)
	print("Layout: ", LayoutType.keys()[layout])
	print("Block size: ", block_size)
	print("Available pieces: ", CITY_PIECES.keys())
	print("========================================")
	
	generate_city(test_position, city_size, layout, "test_village")
	
	spawned_cities.append({
		"position": test_position,
		"size": city_size,
		"name": "test_village",
		"layout": layout
	})
