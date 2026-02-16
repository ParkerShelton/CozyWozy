extends Node3D

# =========================
# Settings
# =========================
@export var chunk_world_size: float = 256.0
@export var lod_levels: Array[Dictionary] = [
	{"distance": 100.0, "vertices": 65},
	{"distance": 300.0, "vertices": 33},
	{"distance": 600.0, "vertices": 17},
]

@export var height_scale: float = 10.0
@export var noise_frequency: float = 0.005
@export var terrain_material: Material

var render_distance: int = 5
var unload_distance: int = 8

var loaded_chunks: Dictionary = {}
var noise: FastNoiseLite = FastNoiseLite.new()


# =========================
# Setup
# =========================
func _ready():
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = noise_frequency
	noise.fractal_octaves = 4


# =========================
# Chunk Updating
# =========================
func update_chunks(player_position: Vector3):
	var player_chunk = world_to_chunk(player_position)

	var chunks_to_load = []

	for dx in range(-render_distance, render_distance + 1):
		for dz in range(-render_distance, render_distance + 1):
			var coord = Vector2i(player_chunk.x + dx, player_chunk.y + dz)
			var center = chunk_to_world(coord)
			var distance = player_position.distance_to(center)

			if distance > lod_levels.back()["distance"]:
				continue

			var lod = get_lod_for_distance(distance)

			if not loaded_chunks.has(coord):
				chunks_to_load.append({
					"coord": coord,
					"lod": lod,
					"priority": distance
				})

	chunks_to_load.sort_custom(func(a, b): return a.priority < b.priority)

	var max_per_frame = 4
	for i in range(min(max_per_frame, chunks_to_load.size())):
		var data = chunks_to_load[i]
		load_chunk(data.coord, data.lod)

	# Unload far chunks
	var to_unload = []
	for coord in loaded_chunks.keys():
		var center = chunk_to_world(coord)
		var distance = player_position.distance_to(center)

		if distance > unload_distance * chunk_world_size:
			to_unload.append(coord)

	for coord in to_unload:
		unload_chunk(coord)


func get_lod_for_distance(distance: float) -> int:
	for i in range(lod_levels.size()):
		if distance < lod_levels[i]["distance"]:
			return i
	return lod_levels.size() - 1


# =========================
# Chunk Loading
# =========================
func load_chunk(coord: Vector2i, lod: int):
	if loaded_chunks.has(coord):
		return

	var verts = lod_levels[lod]["vertices"]

	var body = StaticBody3D.new()
	add_child(body)

	var mesh_instance = MeshInstance3D.new()
	body.add_child(mesh_instance)

	var mesh = generate_chunk_mesh(coord, verts)
	mesh_instance.mesh = mesh

	if terrain_material:
		mesh_instance.material_override = terrain_material

	# Original centered system
	body.position = chunk_to_world(coord)

	# Collision only for near LODs (performance)
	if lod <= 1:
		var col = CollisionShape3D.new()
		body.add_child(col)

		var shape = ConcavePolygonShape3D.new()
		shape.data = mesh.get_faces()
		col.shape = shape

	loaded_chunks[coord] = body


# =========================
# Mesh Generation (CENTERED + PRECISION FIX)
# =========================
func generate_chunk_mesh(coord: Vector2i, vertices_per_side: int) -> ArrayMesh:
	var mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)

	var vertices: PackedVector3Array = []
	var normals: PackedVector3Array = []
	var uvs: PackedVector2Array = []
	var indices: PackedInt32Array = []

	var heights = []
	heights.resize(vertices_per_side)
	for i in range(vertices_per_side):
		heights[i] = []
		heights[i].resize(vertices_per_side)

	var step = chunk_world_size / float(vertices_per_side - 1)
	var half = chunk_world_size * 0.5

	# --- Vertices (precise edge alignment) ---
	for i in range(vertices_per_side):
		for j in range(vertices_per_side):
			var local_x = -half + i * step
			var local_z = -half + j * step

			# Global noise position (seamless)
			var noise_x = coord.x * chunk_world_size + local_x
			var noise_z = coord.y * chunk_world_size + local_z

			var h = noise.get_noise_2d(noise_x, noise_z) * height_scale
			heights[i][j] = h

			vertices.append(Vector3(local_x, h, local_z))

			uvs.append(Vector2(
				float(i) / (vertices_per_side - 1),
				float(j) / (vertices_per_side - 1)
			))

	# --- Smooth normals ---
	for i in range(vertices_per_side):
		for j in range(vertices_per_side):
			var hL = heights[max(i - 1, 0)][j]
			var hR = heights[min(i + 1, vertices_per_side - 1)][j]
			var hD = heights[i][max(j - 1, 0)]
			var hU = heights[i][min(j + 1, vertices_per_side - 1)]

			var normal = Vector3(hL - hR, 2.0, hD - hU).normalized()
			normals.append(normal)

	# --- Indices ---
	for i in range(vertices_per_side - 1):
		for j in range(vertices_per_side - 1):
			var base = i * vertices_per_side + j

			indices.append(base)
			indices.append(base + vertices_per_side)
			indices.append(base + 1)

			indices.append(base + 1)
			indices.append(base + vertices_per_side)
			indices.append(base + vertices_per_side + 1)

	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


# =========================
# Utilities
# =========================
func chunk_to_world(coord: Vector2i) -> Vector3:
	return Vector3(coord.x * chunk_world_size, 0, coord.y * chunk_world_size)


func world_to_chunk(world_pos: Vector3) -> Vector2i:
	return Vector2i(
		int(floor(world_pos.x / chunk_world_size)),
		int(floor(world_pos.z / chunk_world_size))
	)


func unload_chunk(coord: Vector2i):
	if loaded_chunks.has(coord):
		var chunk = loaded_chunks[coord]
		if is_instance_valid(chunk):
			chunk.queue_free()
		loaded_chunks.erase(coord)


func clear_all_chunks():
	for chunk in loaded_chunks.values():
		if is_instance_valid(chunk):
			chunk.queue_free()
	loaded_chunks.clear()
