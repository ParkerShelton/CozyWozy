extends CharacterBody3D

@onready var subviewport = get_node("/root/main/SubViewportContainer/SubViewport")
@onready var right_hand = $right_hand

# MOVEMENT
var speed : float = 3.5
var sprint_speed : float = 6.0
var rotation_speed : float = 10.0
var placement_item : Node3D = null
var is_placing : bool = false
var interaction_range : float = 5.0  # How far you can interact with something
var inventory_open = false
var building_menu_open = false

var last_direction : Vector3 = Vector3.FORWARD
var last_selected_slot : int = 0

var held_item : Node3D = null

var nearby_crafting_stations : Array = []

func _ready():
	$inventory.visible = false
	
	var mesh = $temp_body
	var normal_material = mesh.get_active_material(0)
	
	# Create x-ray material
	var xray_shader = load("res://Shaders/player_xray.gdshader")
	var xray_material = ShaderMaterial.new()
	xray_material.shader = xray_shader
	xray_material.set_shader_parameter("xray_color", Color(0, 1, 1, 0.6))
	
	# Set both materials - normal on surface 0, xray as overlay
	mesh.material_override = null  # Clear override
	mesh.set_surface_override_material(0, normal_material)
	mesh.material_overlay = xray_material  # This renders on top

func _physics_process(delta):
	hot_keys()
	
	# Update placement item position to follow mouse
	if is_placing and placement_item:
		update_placement_position()
	
	if not is_placing:
		check_hotbar_for_placeable()
	else:
		# If in placement mode, check if selected slot changed
		check_if_slot_changed()
	
	if is_placing:
		if Input.is_action_pressed("rotate_counter_clockwise"):
			placement_item.rotation.y += 2.0 * delta  
		if Input.is_action_pressed("rotate_clockwise"):
			placement_item.rotation.y -= 2.0 * delta
	
	update_placement_with_snap()
	
	# Get input direction
	var input_dir = Input.get_vector("walk_left", "walk_right", "walk_up", "walk_down")
	var direction = Vector3(-input_dir.y, 0, input_dir.x).normalized()
	
	# Move the character
	if direction != Vector3.ZERO:
		if Input.is_action_pressed("sprint"):
			velocity.x = direction.x * sprint_speed
			velocity.z = direction.z * sprint_speed
		else:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		last_direction = direction
	else:
		velocity.x = 0
		velocity.z = 0
	
	# Rotate to face movement direction
	if last_direction != Vector3.ZERO:
		var target_rotation = atan2(-last_direction.z, last_direction.x)
		rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed * delta)
	
	move_and_slide()

func update_placement_position():
	var camera = subviewport.get_camera_3d()
	
	if !camera:
		print("No camera found in SubViewport!")
		return
	
	# Get mouse position relative to the SubViewport
	var mouse_pos = subviewport.get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1  # Only check layer 1 (ground) for placement
	
	var result = space_state.intersect_ray(query)
	if result:
		placement_item.global_position = result.position
	else:
		print("MISS - From: ", from, " To: ", to)

func click():
	print("Click detected!")
	
	var selected_item = Hotbar.get_selected_item()
	var item_name = selected_item["item_name"]
	
	# Raycast from camera through mouse position
	var camera = subviewport.get_camera_3d()
	if !camera:
		print("No camera found!")
		return
	
	var mouse_pos = subviewport.get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 3  # Check layers 1 and 2
	var result = space_state.intersect_ray(query)
	
	if result:
		var hit_object = result.collider
		var target = hit_object
		
		# Walk up the tree to find a node with groups
		while target and target.get_groups().size() == 0 and target.get_parent():
			target = target.get_parent()
		
		print("Hit: ", hit_object.name, " Target: ", target.name, " Groups: ", target.get_groups())
		
		# Check if holding a seed and clicked on tilled ground
		var plant = PlantManager.get_plant(item_name)
		if plant and target.is_in_group("tilled_ground"):
			print("Planting seed on clicked tilled ground")
			var success = target.plant_seed(plant)
			
			if success:
				# Remove seed from inventory
				var selected_slot = Hotbar.selected_slot
				var slot_data = Hotbar.get_slot(selected_slot)
				var new_quantity = slot_data["quantity"] - 1
				
				if new_quantity <= 0:
					Hotbar.clear_slot(selected_slot)
				else:
					Hotbar.set_slot(selected_slot, item_name, new_quantity, slot_data["icon"])
			return
		
		# Check if clicked on a harvestable crop
		if target.is_in_group("planted_crops"):
			var crop = target
			if crop.is_ready:
				print("Harvesting clicked crop")
				var yields = crop.harvest()
				
				# Add the harvested crop
				if yields.has("crop"):
					Inventory.add_item(yields.crop.item, yields.crop.icon, yields.crop.amount)
				
				# Add seeds back
				if yields.has("seeds") and yields.seeds.amount > 0:
					Inventory.add_item(yields.seeds.item, yields.seeds.icon, yields.seeds.amount)
			return
		
		# Normal attack behavior for trees, rocks, etc.
		if target.has_method("take_damage"):
			target.take_damage()
			return
		elif target.get_parent() and target.get_parent().has_method("take_damage"):
			target.get_parent().take_damage()
			return
			
func hot_keys():
	# Close game on escape
	if Input.is_action_just_pressed("ui_cancel") and !is_placing:
		if inventory_open:
			inventory_open = false
			$inventory.visible = false
		elif building_menu_open:
			building_menu_open = false
			$building_menu.visible = false
		else:
			get_tree().quit()
			
	if Input.is_action_just_pressed("ui_cancel") and is_placing:
		cancel_placement()
	
	if Input.is_action_just_pressed("click") and !is_placing:
		click()
		
	if Input.is_action_just_pressed("click") and is_placing:
		place_item()
		return
	
	if Input.is_action_just_pressed("inventory"):
		if inventory_open:
			inventory_open = false
			$inventory.visible = false
		else:
			inventory_open = true
			$inventory.visible = true

func start_placement_mode(item: Node3D):
	placement_item = item
	is_placing = true

func place_item():
	if placement_item:
		# Unparent from player and place in world
		var world_position = placement_item.global_position
		var world_rotation = placement_item.global_rotation
		
		placement_item.reparent(get_tree().root)
		placement_item.global_position = world_position
		placement_item.global_rotation = world_rotation
		
		print("Item placed at: ", world_position)
		
		var selected_item = Hotbar.get_selected_item()
		var is_tilling = selected_item["item_name"] == "wood_hoe"
		
		if not is_tilling:
			# Remove one from the selected hotbar slot (normal placeable)
			var selected_slot = Hotbar.selected_slot
			var slot_data = Hotbar.get_slot(selected_slot)
			var new_quantity = slot_data["quantity"] - 1
			
			if new_quantity <= 0:
				Hotbar.clear_slot(selected_slot)
			else:
				Hotbar.set_slot(selected_slot, slot_data["item_name"], new_quantity, slot_data["icon"])
		
		placement_item = null
		is_placing = false
  
func cancel_placement():
	if placement_item:
		print("Placement cancelled")
		placement_item.queue_free()
		placement_item = null
		is_placing = false

func check_hotbar_for_placeable():
	last_selected_slot = Hotbar.selected_slot
	
	var selected_item = Hotbar.get_selected_item()
	
	update_held_item(selected_item)
	
	if selected_item["item_name"] != "":
		# Check if this item has a recipe and is placeable
		var recipe = RecipeManager.get_recipe(selected_item["item_name"])
		
		if selected_item["item_name"] == "wood_hoe":
			enter_tilling_mode()
			return
		
		if recipe and recipe.placeable:
			# Enter placement mode
			enter_placement_from_hotbar(recipe, selected_item)
			
func check_if_slot_changed():
	if Hotbar.selected_slot != last_selected_slot:
		# Slot changed while placing - cancel placement
		cancel_placement()
			
func enter_placement_from_hotbar(recipe: Recipe, hotbar_item: Dictionary):
	var model_scene = recipe.get_model(recipe.recipe_name, recipe.type)
	
	if model_scene:
		var item = model_scene.instantiate()
		add_child(item)
		
		var spawn_distance = 3.0
		item.position = Vector3(0, 0, -spawn_distance)
		item.top_level = true  # NEW: Makes it not rotate with parent
		
		start_placement_mode(item)

func update_held_item(item_data: Dictionary):
	# Clear current held item
	if held_item:
		held_item.queue_free()
		held_item = null
	
	# If empty slot, don't hold anything
	if item_data["item_name"] == "":
		return
	
	# Check if this item has a recipe with a model
	var recipe = RecipeManager.get_recipe(item_data["item_name"])
	
	if recipe:
		var model = recipe.get_model(recipe.recipe_name, recipe.type)
		
		if model:
			held_item = model.instantiate()
			right_hand.add_child(held_item)
			
			# Adjust position/rotation/scale for how it looks in hand
			held_item.position = Vector3(0, 0, 0)
			held_item.rotation_degrees = Vector3(0, 90, 0)
			held_item.scale = Vector3(0.5, 0.5, 0.5)

func add_crafting_station(station_name: String):
	if not nearby_crafting_stations.has(station_name):
		nearby_crafting_stations.append(station_name)
		print("Added crafting station: ", station_name)
		update_building_menu_stations()

func remove_crafting_station(station_name: String):
	nearby_crafting_stations.erase(station_name)
	print("Removed crafting station: ", station_name)
	update_building_menu_stations()
	
func update_building_menu_stations():
	# Update the building menu with available stations
	var building_menu = get_node_or_null("../BuildingMenu")  # Adjust path
	if building_menu and building_menu.has_method("set_available_stations"):
		building_menu.set_available_stations(nearby_crafting_stations)

func enter_tilling_mode():
	var tilled_ground_scene = load("res://Scenes/tilled_ground.tscn")
	
	if tilled_ground_scene:
		var tilled = tilled_ground_scene.instantiate()
		add_child(tilled)
		
		var spawn_distance = 3.0
		tilled.position = Vector3(0, 0, -spawn_distance)
		tilled.top_level = true
		
		start_placement_mode(tilled)
		
		print("Entered tilling mode")

func update_placement_with_snap():
	if not placement_item or not is_placing:
		return
	
	# Get the current mouse-raycasted position (set by update_placement_position)
	var target_position = placement_item.global_position
	
	# Check for nearby tilled ground to snap to
	var tile_size = 2.0  # Adjust to your tilled ground size
	var snap_range = 1.5
	
	var tilled_grounds = get_tree().get_nodes_in_group("tilled_ground")
	var best_snap = target_position
	var closest_distance = 999999.0
	var snap_rotation = placement_item.global_rotation  # Track rotation too
	
	for tile in tilled_grounds:
		# Get the tile's basis (rotation matrix) to transform local offsets to world space
		var tile_basis = tile.global_transform.basis
		
		# Check 4 adjacent positions - rotated to match the tile's orientation
		var potential_snaps = [
			tile.global_position + tile_basis * Vector3(tile_size, 0, 0),   # Right
			tile.global_position + tile_basis * Vector3(-tile_size, 0, 0),  # Left
			tile.global_position + tile_basis * Vector3(0, 0, tile_size),   # Forward
			tile.global_position + tile_basis * Vector3(0, 0, -tile_size),  # Back
		]
		
		for snap_pos in potential_snaps:
			var distance = target_position.distance_to(snap_pos)
			if distance < closest_distance and distance < snap_range:
				closest_distance = distance
				best_snap = snap_pos
				snap_rotation = tile.global_rotation  # Capture the tile's rotation
	
	# Only update if we found a valid snap point
	if closest_distance < snap_range:
		placement_item.global_position = best_snap
		placement_item.global_rotation = snap_rotation  # Apply the matching rotation
