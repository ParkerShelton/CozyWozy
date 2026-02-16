class_name PlayerBuilding

var player: Node3D

func _init(_player: Node3D):
	player = _player

func enter_building_mode(piece_name: String):
	player.current_building_piece = piece_name
	player.building_mode = true
	
	var piece_data = BuildingManager.get_piece_data(piece_name)
	if piece_data.is_empty():
		return
	
	var model_path = piece_data.get("model", "")
	if not ResourceLoader.exists(model_path):
		return
	
	var model_scene = load(model_path)
	player.building_preview = model_scene.instantiate()
	player.building_preview.is_preview = true
	player.add_child(player.building_preview)
	player.building_preview.top_level = true

func exit_building_mode():
	if player.building_preview:
		player.building_preview.queue_free()
		player.building_preview = null
	
	player.building_mode = false
	player.current_building_piece = ""

func update_building_preview():
	var main = player.get_node_or_null("/root/main")
	if not main:
		return
	
	var subviewport = main.get_node_or_null("SubViewportContainer/SubViewport")
	if not subviewport:
		return
		
	var camera = subviewport.get_camera_3d()
	if not camera:
		return
	
	var mouse_pos = subviewport.get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000
	
	var space_state = player.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1 | 2  # Ground + buildings
	
	var result = space_state.intersect_ray(query)
	
	if result:
		var target_pos = result.position
		
		var snap_result = try_snap_to_nearby(target_pos)
		if snap_result:
			player.building_preview.global_position = snap_result.position
			player.building_preview.global_rotation = snap_result.rotation
			player.building_preview.set_valid(true)
		else:
			target_pos = snap_to_grid(target_pos)
			player.building_preview.global_position = target_pos
			player.building_preview.set_valid(is_valid_placement())

func try_snap_to_nearby(target_pos: Vector3) -> Dictionary:
	var snap_distance = BuildingManager.snap_distance
	var best_snap = null
	var closest_distance = snap_distance
	
	for piece in player.placed_pieces:
		if not is_instance_valid(piece):
			continue
		
		var piece_snaps = piece.get_world_snap_points()
		
		for snap_point in piece_snaps:
			var distance = target_pos.distance_to(snap_point.position)
			
			if distance < closest_distance:
				closest_distance = distance
				best_snap = {
					"position": snap_point.position,
					"rotation": piece.global_rotation,
					"type": snap_point.type
				}
	
	return best_snap if best_snap else {}

func snap_to_grid(pos: Vector3) -> Vector3:
	var grid = BuildingManager.grid_size
	return Vector3(
		round(pos.x / grid) * grid,
		round(pos.y / grid) * grid,
		round(pos.z / grid) * grid
	)

func is_valid_placement() -> bool:
	if not player.building_preview:
		return false
	
	var space_state = player.get_world_3d().direct_space_state
	var shape = BoxShape3D.new()
	shape.size = Vector3(1.9, 2.9, 1.9)
	
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = player.building_preview.global_transform
	query.collision_mask = 2
	
	var results = space_state.intersect_shape(query)
	return results.size() == 0

func place_building():
	if not player.building_mode or not player.building_preview:
		return
	
	if not is_valid_placement():
		return
	
	var piece_data = BuildingManager.get_piece_data(player.current_building_piece)
	var model_path = piece_data.get("model", "")
	var model_scene = load(model_path)
	var piece = model_scene.instantiate()
	
	player.get_tree().root.add_child(piece)
	piece.global_position = player.building_preview.global_position
	piece.global_rotation = player.building_preview.global_rotation
	piece.is_preview = false
	
	player.placed_pieces.append(piece)
