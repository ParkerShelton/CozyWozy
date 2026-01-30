extends CharacterBody3D

@onready var subviewport = get_node("/root/main/SubViewportContainer/SubViewport")
@onready var right_hand = $right_hand

var player_health : float = 100.0
var attack_range : float = 3.0

# HUNGER
var max_hunger: float = 100.0
var current_hunger: float = 100.0
var hunger_drain_rate: float = 0.1  # Hunger lost per second
var hunger_damage_rate: float = 2.0  # Damage per second when starving
var low_hunger_threshold: float = 30.0  # When to show warning
var starving_threshold: float = 0.0  # When to start taking damage

# MOVEMENT
var speed : float = 5.5
var sprint_speed : float = 8.0
var is_dashing: bool = false
var can_dash: bool = true
var dash_speed: float = 15.0
var dash_duration: float = 0.3  # How long the dash lasts
var dash_cooldown: float = 3  # Cooldown between dashes
var dash_direction: Vector3 = Vector3.ZERO

# PLACEMENT
var rotation_speed : float = 10.0
var placement_item : Node3D = null
var is_placing : bool = false
var interaction_range : float = 5.0
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
	mesh.material_override = null
	mesh.set_surface_override_material(0, normal_material)
	mesh.material_overlay = xray_material
	
	current_hunger = max_hunger

func _physics_process(delta):
	hot_keys()
	
	# Gravity
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0
		
	update_hunger(delta)
	
	# Update placement item position to follow mouse
	if is_placing and placement_item:
		update_placement_position()
	
	if not is_placing and $inventory.visible == false:
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
	
	if is_dashing:
		perform_dash(delta)
		return
	
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

func click():
	var selected_item = Hotbar.get_selected_item()
	var item_name = selected_item["item_name"]
	
	# Raycast from player in the direction they're facing
	var from = global_position + Vector3(0, 1.0, 0)  # Start from chest height
	var forward = transform.basis.x  # Player's forward direction
	var to = from + forward * attack_range
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 0xFFFFFFFF  # Check all layers
	
	var result = space_state.intersect_ray(query)
	
	if result:
		var hit_object = result.collider
		var target = hit_object
		
		# Walk up the tree to find a node with groups
		while target and target.get_groups().size() == 0 and target.get_parent():
			target = target.get_parent()
		
		# Calculate damage based on item and target
		var damage = calculate_damage(item_name, target)

		# If damage is 0, don't allow the action
		if damage == 0.0 and (target.is_in_group("enemies") or target.is_in_group("trees") or target.is_in_group("rocks")):
			print("Cannot perform this action with current item!")
			return

		# Check if we hit an enemy
		if target.is_in_group("enemies"):
			if target.has_method("take_damage"):
				target.take_damage(damage)
			return
		
		# Check if holding a seed and clicked on tilled ground
		var plant = PlantManager.get_plant(item_name)
		if plant and target.is_in_group("tilled_ground"):
			var success = target.plant_seed(plant)
			
			if success:
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
				var yields = crop.harvest()
				
				if yields.has("crop"):
					Inventory.add_item(yields.crop.item, yields.crop.icon, yields.crop.amount)
				
				if yields.has("seeds") and yields.seeds.amount > 0:
					Inventory.add_item(yields.seeds.item, yields.seeds.icon, yields.seeds.amount)
			return
		
		# Attack trees, rocks, etc.
		if target.is_in_group("trees") or target.is_in_group("rocks"):
			if target.has_method("take_damage"):
				target.take_damage(damage)
			return


func calculate_damage(item_name: String, target: Node) -> float:
	var base_fist_damage = 2.0
	
	# No item equipped - use fists (can hit anything)
	if item_name == "":
		return base_fist_damage
	
	var item_damage = ItemManager.get_item_damage(item_name)
	var item_type = ItemManager.get_item_type(item_name)
	
	# No damage stat = not a tool/weapon, can't attack with it
	if item_damage == 0.0:
		print("Can't attack with ", item_name)
		return 0.0
	
	# AXES - only work on trees
	if item_type == "axe":
		if target.is_in_group("trees"):
			return item_damage
		else:
			print("Can't use axe on ", target.get_groups())
			return 0.0
	
	# PICKAXES - only work on rocks
	elif item_type == "pickaxe":
		if target.is_in_group("rocks"):
			return item_damage
		else:
			print("Can't use pickaxe on ", target.get_groups())
			return 0.0
	
	# SWORDS/WEAPONS - only work on enemies
	elif item_type == "weapon":
		if target.is_in_group("enemies"):
			return item_damage
		else:
			print("Can't use weapon on ", target.get_groups())
			return 0.0
	
	# HOES - can't attack anything
	elif item_type == "hoe":
		print("Can't attack with a hoe!")
		return 0.0
		
	else:
		return 0.0


func hot_keys():
	if Input.is_action_just_pressed("ui_cancel") and is_placing:
		cancel_placement()
	
	if Input.is_action_just_pressed("dash_roll") and can_dash and not is_placing:
		start_dash()
	
	if Input.is_action_just_pressed("click") and !is_placing:
		click()
		
	if Input.is_action_just_pressed("click") and is_placing:
		place_item()
	
	if Input.is_action_just_pressed("eat"):
		try_eat_selected_item()
	
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
		var selected_item = Hotbar.get_selected_item()
		var item_name = selected_item["item_name"]
		var is_tilling = item_name == "wood_hoe"
		
		if not is_tilling:
			# Create NEW instance for placed object (don't reuse preview)
			var placed_item = ItemManager.get_model(item_name).instantiate()
			get_tree().root.add_child(placed_item)
			placed_item.global_position = placement_item.global_position
			placed_item.global_rotation = placement_item.global_rotation
			
			if placed_item.has_method("enable_light"):
				placed_item.enable_light()
			
			# Remove from hotbar
			var selected_slot = Hotbar.selected_slot
			var slot_data = Hotbar.get_slot(selected_slot)
			var new_quantity = slot_data["quantity"] - 1
			
			if new_quantity <= 0:
				Hotbar.clear_slot(selected_slot)
			else:
				Hotbar.set_slot(selected_slot, item_name, new_quantity, slot_data["icon"])
		
		# Destroy preview
		placement_item.queue_free()
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
		var item_name = selected_item["item_name"]
		
		# Special case: wood hoe for tilling
		if item_name == "wood_hoe":
			enter_tilling_mode()
			return
		
		# Check if this item is placeable using ItemManager
		if ItemManager.is_placeable(item_name):
			# Enter placement mode
			enter_placement_from_hotbar(item_name)
			
func check_if_slot_changed():
	if Hotbar.selected_slot != last_selected_slot:
		# Slot changed while placing - cancel placement
		cancel_placement()
			
func enter_placement_from_hotbar(item_name: String):
	if placement_item:
		placement_item.queue_free()
		placement_item = null
	
	var model_scene = ItemManager.get_model(item_name)
	if model_scene:
		placement_item = model_scene.instantiate()
		
		# Set is_preview BEFORE adding to tree (so _ready() sees it)
		if "is_preview" in placement_item:
			placement_item.is_preview = true
			print("Set is_preview to true before adding to tree")
		
		add_child(placement_item)
		is_placing = true

func update_held_item(item_data: Dictionary):
	# Clear current held item
	if held_item:
		held_item.queue_free()
		held_item = null
	
	# If empty slot, don't hold anything
	if item_data["item_name"] == "":
		return
	
	var item_name = item_data["item_name"]
	
	# Check if this item has a model using ItemManager
	if ItemManager.has_model(item_name):
		var model_scene = ItemManager.get_model(item_name)
		
		if model_scene:
			held_item = model_scene.instantiate()
			right_hand.add_child(held_item)
			
			# Adjust position/rotation/scale for how it looks in hand
			held_item.position = Vector3(0, 0, 0)
			held_item.rotation_degrees = Vector3(0, 90, 0)
			held_item.scale = Vector3(0.5, 0.5, 0.5)

func add_crafting_station(station_name: String):
	if not nearby_crafting_stations.has(station_name):
		nearby_crafting_stations.append(station_name)
		update_building_menu_stations()

func remove_crafting_station(station_name: String):
	nearby_crafting_stations.erase(station_name)
	update_building_menu_stations()
	
func update_building_menu_stations():
	var building_menu = $building_menu
	
	if building_menu.has_method("set_available_stations"):
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


func take_damage(dmg):
	if player_health - dmg > 0:
		player_health -= dmg
		# Visual feedback (screen flash, etc.)
		# TODO: Add health bar UI
		
	else:
		die()
		
	update_hunger_health_ui()


func die():
	print("Player died!")
	# TODO: Respawn or game over


func start_dash():
	# Get mouse position in world
	var camera = subviewport.get_camera_3d()
	if !camera:
		return
	
	var mouse_pos = subviewport.get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000
	
	# Raycast to ground to get target position
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1  # Only ground
	
	var result = space_state.intersect_ray(query)
	
	if result:
		# Calculate dash direction (from player to mouse point)
		dash_direction = (result.position - global_position).normalized()
		dash_direction.y = 0  # Keep on ground
		
		if dash_direction.length() > 0.1:
			is_dashing = true
			can_dash = false
			
			# Start dash duration timer
			get_tree().create_timer(dash_duration).timeout.connect(_on_dash_end)
			
func perform_dash(_delta):
	# Fast movement in dash direction
	velocity.x = dash_direction.x * dash_speed
	velocity.z = dash_direction.z * dash_speed
	velocity.y = 0  # Stay on ground
	
	move_and_slide()

func _on_dash_end():
	is_dashing = false
	
	# Start cooldown
	await get_tree().create_timer(dash_cooldown).timeout
	can_dash = true


func update_hunger(delta):
	# Decrease hunger over time
	current_hunger -= hunger_drain_rate * delta
	current_hunger = clamp(current_hunger, 0.0, max_hunger)
	
	if current_hunger <= starving_threshold:
		# Starving - take damage
		take_damage(hunger_damage_rate * delta)
	elif current_hunger <= low_hunger_threshold:
		# Low hunger - move slower
		speed = 2.5  # Reduced from 3.5
		sprint_speed = 4.5  # Reduced from 6.0
	else:
		# Normal
		speed = 3.5
		sprint_speed = 6.0
	# Update hunger UI
	update_hunger_health_ui()


func eat_food(item_name: String) -> bool:
	var food_value = ItemManager.get_food_value(item_name)
	
	if food_value > 0.0:
		# Restore hunger
		current_hunger += food_value
		current_hunger = clamp(current_hunger, 0.0, max_hunger)
		
		return true
	
	return false
	
	
func try_eat_selected_item():
	var selected_item = Hotbar.get_selected_item()
	var item_name = selected_item["item_name"]
	
	if item_name == "":
		return
	
	# Check if it's food
	if ItemManager.is_food(item_name):
		# Eat the food
		if eat_food(item_name):
			# Remove one from hotbar
			var selected_slot = Hotbar.selected_slot
			var slot_data = Hotbar.get_slot(selected_slot)
			var new_quantity = slot_data["quantity"] - 1
			
			if new_quantity <= 0:
				Hotbar.clear_slot(selected_slot)
			else:
				Hotbar.set_slot(selected_slot, item_name, new_quantity, slot_data["icon"])
	else:
		print(item_name, " is not food!")


func update_hunger_health_ui():
	# Update the hunger bar (we'll create this next)
	var hunger_bar = $health_hunger_ui/MarginContainer/VBoxContainer/ProgressBar
	if hunger_bar:
		hunger_bar.value = current_hunger
		
	var health_bar = $health_hunger_ui/MarginContainer/VBoxContainer2/ProgressBar
	if health_bar:
		health_bar.value = player_health
