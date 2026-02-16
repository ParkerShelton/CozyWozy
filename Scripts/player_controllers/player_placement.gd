class_name PlayerPlacement

var player: Node3D

var placement_item : Node3D = null

func _init(_player: Node3D):
	player = _player

func update_placement_position():
	if not placement_item:
		return

	var camera = player.get_current_camera()
	if !camera:
		return

	var mouse_pos = player.get_viewport().get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000

	var space_state = player.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1

	var result = space_state.intersect_ray(query)

	if result:
		placement_item.global_position = result.position

func place_item():
	if player.inventory_armor_ui.visible:
		return
	
	if placement_item:
		var selected_item = Hotbar.get_selected_item()
		var item_name = selected_item["item_name"]
		var is_tilling = item_name == "wood_hoe"
		
		if is_tilling:
			var tilled_ground_scene = load("res://Scenes/tilled_ground.tscn")
			var placed_tilled = tilled_ground_scene.instantiate()
			player.get_tree().root.add_child(placed_tilled)
			placed_tilled.global_position = placement_item.global_position
			placed_tilled.global_rotation = placement_item.global_rotation
		else:
			var placed_item = ItemManager.get_model(item_name).instantiate()
			player.get_tree().root.add_child(placed_item)
			placed_item.global_position = placement_item.global_position
			placed_item.global_rotation = placement_item.global_rotation
			
			enable_collision_recursive(placed_item)
			
			if placed_item.has_method("enable_light"):
				placed_item.enable_light()
			
			var selected_slot = Hotbar.selected_slot
			var slot_data = Hotbar.get_slot(selected_slot)
			var new_quantity = slot_data["quantity"] - 1
			
			if new_quantity <= 0:
				Hotbar.clear_slot(selected_slot)
			else:
				Hotbar.set_slot(selected_slot, item_name, new_quantity, slot_data["icon"])
			
			placement_item.queue_free()
			placement_item = null
			player.is_placing = false

func enable_collision_recursive(node: Node):
	if node is StaticBody3D or node is Area3D:
		for shape in node.get_children():
			if shape is CollisionShape3D or shape is CollisionPolygon3D:
				shape.disabled = false
	for child in node.get_children():
		enable_collision_recursive(child)
		
func cancel_placement():
	if placement_item:
		placement_item.queue_free()
		placement_item = null
		player.is_placing = false

func check_hotbar_for_placeable():
	player.last_selected_slot = Hotbar.selected_slot
	
	var selected_item = Hotbar.get_selected_item()
	
	update_held_item(selected_item)
	
	if selected_item["item_name"] != "":
		var item_name = selected_item["item_name"]
		
		if item_name == "wood_hoe":
			enter_tilling_mode()
			return
		
		if ItemManager.is_placeable(item_name):
			enter_placement_from_hotbar(item_name)
			
func check_if_slot_changed():
	if Hotbar.selected_slot != player.last_selected_slot:
		cancel_placement()

func enter_placement_from_hotbar(item_name: String):
	if placement_item:
		placement_item.queue_free()
		placement_item = null
	
	var model_scene = ItemManager.get_model(item_name)
	if model_scene:
		placement_item = model_scene.instantiate()
		
		if "is_preview" in placement_item:
			placement_item.is_preview = true
		
		player.add_child(placement_item)
		placement_item.top_level = true
		
		disable_collision_recursive(placement_item)
		
		player.is_placing = true

func disable_collision_recursive(node: Node):
	if node is StaticBody3D or node is Area3D:
		for shape in node.get_children():
			if shape is CollisionShape3D or shape is CollisionPolygon3D:
				shape.disabled = true
	for child in node.get_children():
		disable_collision_recursive(child)

func update_held_item(item_data: Dictionary):
	if player.held_item:
		player.held_item.queue_free()
		player.held_item = null
	
	if item_data["item_name"] == "":
		return
	
	var item_name = item_data["item_name"]
	
	var item_type = ItemManager.get_item_type(item_name)
	var show_in_hand = item_type in ["weapon", "axe", "pickaxe", "hoe"]
	
	if not show_in_hand:
		return
	
	if ItemManager.has_model(item_name):
		var model_scene = ItemManager.get_model(item_name)
		if model_scene:
			player.held_item = model_scene.instantiate()
			player.right_hand.add_child(player.held_item)
			player.held_item.position = Vector3(0, 0, 0)
			player.held_item.rotation_degrees = Vector3(0, 90, 0)
			player.held_item.scale = Vector3(0.5, 0.5, 0.5)

func enter_tilling_mode():
	var tilled_ground_scene = load("res://Scenes/tilled_ground.tscn")
	if tilled_ground_scene:
		var tilled = tilled_ground_scene.instantiate()
		player.add_child(tilled)
		tilled.top_level = true
		var spawn_distance = 3.0
		var forward = -player.transform.basis.x
		var target_pos = player.global_position + (forward * spawn_distance)
		target_pos.y = 0
		tilled.global_position = target_pos
		start_placement_mode(tilled)

func start_placement_mode(item: Node3D):
	placement_item = item
	player.is_placing = true

func update_placement_with_snap():
	if not placement_item or not player.is_placing:
		return
	
	var target_position = placement_item.global_position
	var selected_item = Hotbar.get_selected_item()
	var item_name = selected_item["item_name"]
	
	var snap_group = ""
	var tile_size = 2.0
	var snap_range = 1.5
	var allow_rotation = false
	
	if item_name == "wood_hoe":
		snap_group = "tilled_ground"
		tile_size = 2.0
		snap_range = 1.5
		allow_rotation = false
	elif item_name == "fence":
		snap_group = "fences"
		tile_size = 1.0
		snap_range = 1.0
		allow_rotation = true
	else:
		return
	
	var snap_objects = player.get_tree().get_nodes_in_group(snap_group)
	var best_snap = target_position
	var closest_distance = 999999.0
	var snap_rotation = placement_item.global_rotation
	
	for obj in snap_objects:
		var obj_basis = obj.global_transform.basis
		var potential_snaps = [
			obj.global_position + obj_basis * Vector3(tile_size, 0, 0),
			obj.global_position + obj_basis * Vector3(-tile_size, 0, 0),
			obj.global_position + obj_basis * Vector3(0, 0, tile_size),
			obj.global_position + obj_basis * Vector3(0, 0, -tile_size),
		]
		
		for snap_pos in potential_snaps:
			var distance = target_position.distance_to(snap_pos)
			if distance < closest_distance and distance < snap_range:
				closest_distance = distance
				best_snap = snap_pos
				if not allow_rotation:
					snap_rotation = obj.global_rotation
	
	if closest_distance < snap_range:
		placement_item.global_position = best_snap
		if not allow_rotation:
			placement_item.global_rotation = snap_rotation
