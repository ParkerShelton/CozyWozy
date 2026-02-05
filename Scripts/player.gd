extends CharacterBody3D

#@onready var subviewport = get_node("/root/main/SubViewportContainer/SubViewport")
@onready var right_hand = $vesper/Armature/Skeleton3D/right_hand_attachment/right_hand
@onready var left_hand = $vesper/Armature/Skeleton3D/left_hand_attachment/left_hand
@onready var anim_controller = $vesper
@onready var attack_hit_box = $attack_hit_box

var player_health : float = 100.0
var attack_range : float = 3.0

# HUNGER
var max_hunger: float = 100.0
var current_hunger: float = 100.0
var hunger_drain_rate: float = 0.1  # Hunger lost per second
var hunger_damage_rate: float = 2.0  # Damage per second when starving
var low_hunger_threshold: float = 30.0  # When to show warning
var starving_threshold: float = 0.0  # When to start taking damage

var healing_at_campfire = false

# MOVEMENT
var speed : float = 3.5
var sprint_speed : float = 5.0
var is_dashing: bool = false
var can_dash: bool = true
var dash_speed: float = 15.0
var dash_duration: float = 0.5  # How long the dash lasts
var dash_cooldown: float = 3  # Cooldown between dashes
var dash_direction: Vector3 = Vector3.ZERO

# PLACEMENT
var rotation_speed : float = 20.0
var placement_item : Node3D = null
var is_placing : bool = false
var interaction_range : float = 5.0
var inventory_open = false
var building_menu_open = false

# ATTACK COOLDOWN
var can_attack: bool = true
var attack_cooldown: float = 0.4  # Seconds between attacks

var enemy_knockback_force = 18.0  # Force applied to enemies
var player_recoil_force = 10.0    # Force applied back to player

var last_direction : Vector3 = Vector3.FORWARD
var last_selected_slot : int = 0
var held_item : Node3D = null

var nearby_crafting_stations : Array = []



# THROWING
var thrown_rock_scene = preload("res://Scenes/Ranged/Ammo/thrown_rock.tscn")
var can_throw: bool = true
var throw_cooldown: float = 0.5
var base_throw_speed: float = 20.0
var slingshot_throw_speed: float = 35.0
var throw_arc: float = 0.1  # How much upward angle to add




func get_current_camera() -> Camera3D:
	# Try to get camera from viewport
	var camera = get_viewport().get_camera_3d()
	
	if camera:
		return camera
	
	# Fallback: try to find any Camera3D in the scene
	var cameras = get_tree().get_nodes_in_group("camera")
	if cameras.size() > 0:
		return cameras[0]
	
	print("Warning: No camera found!")
	return null
	
	

func _ready():
	current_hunger = max_hunger

func _physics_process(delta):
	hot_keys()

	# Gravity
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0
		
	if healing_at_campfire:
		player_health += 1 * delta
		
		
	update_hunger(delta)
	
	# Update placement item position to follow mouse
	if is_placing and placement_item:
		print("Calling update_placement_position()")  # ADD THIS
		update_placement_position()
	elif is_placing:
		print("ERROR: is_placing=true but placement_item is null!")
	
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
	
	var recoil_x = velocity.x
	var recoil_z = velocity.z
	

	
	# Move the character
	if direction != Vector3.ZERO:
		if Input.is_action_pressed("sprint"):
			velocity.x = direction.x * sprint_speed + recoil_x * 0.5
			velocity.z = direction.z * sprint_speed + recoil_z * 0.5
		else:
			velocity.x = direction.x * speed + recoil_x * 0.5
			velocity.z = direction.z * speed + recoil_z * 0.5
		last_direction = direction
	else:
		velocity.x = lerp(velocity.x, 0.0, 15.0 * delta)
		velocity.z = lerp(velocity.z, 0.0, 15.0 * delta)
	
	# Rotate to face mouse
	var mouse_world_pos = get_mouse_world_position()
	var to_mouse = (mouse_world_pos - global_position)
	to_mouse.y = 0
	if to_mouse.length() > 0.1:
		var target_rotation = atan2(-to_mouse.z, to_mouse.x)
		rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed * delta)
	
	move_and_slide()

func update_placement_position():
	print("1. update_placement_position() called")
	
	if not placement_item:
		print("ERROR: No placement_item!")
		return
	
	print("2. placement_item exists")
	
	# Get camera the same way you do in click()
	var main = get_node("/root/main")
	var subviewport = main.get_node_or_null("SubViewportContainer/SubViewport")
	
	if not subviewport:
		print("ERROR: No subviewport!")
		return
	
	print("3. Got subviewport")
	
	var camera = subviewport.get_camera_3d()
	
	if !camera:
		print("No camera found in SubViewport!")
		return
	
	print("4. Got camera, getting mouse position")
	
	# Get mouse position relative to the SubViewport
	var mouse_pos = subviewport.get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000
	
	print("5. Creating raycast from ", from, " to ", to)
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1  # Only check layer 1 (ground) for placement
	
	var result = space_state.intersect_ray(query)
	
	if result:
		print("Raycast hit at: ", result.position)
		placement_item.global_position = result.position
	else:
		print("Raycast didn't hit anything!")

func click():
	if not can_attack:
		return
	
	var selected_item = Hotbar.get_selected_item()
	var item_name = selected_item["item_name"]
	
	# Setup mouse raycast (used for planting and harvesting)
	var main = get_node("/root/main")
	var subviewport = main.get_node_or_null("SubViewportContainer/SubViewport")
	var camera = null
	var mouse_from = Vector3.ZERO
	var mouse_to = Vector3.ZERO
	
	if subviewport:
		camera = subviewport.get_camera_3d()
		if camera:
			var mouse_pos = subviewport.get_mouse_position()
			mouse_from = camera.project_ray_origin(mouse_pos)
			mouse_to = mouse_from + camera.project_ray_normal(mouse_pos) * 1000
	
	# First check: Are we holding a seed? If so, plant it
	var plant = PlantManager.get_plant(item_name)
	if plant and camera:
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(mouse_from, mouse_to)
		query.collision_mask = 2  # Layer 2 for tilled ground
		
		var result = space_state.intersect_ray(query)
		
		if result:
			var target = result.collider
			
			while target and not target.is_in_group("tilled_ground") and target.get_parent():
				target = target.get_parent()
			
			if target.is_in_group("tilled_ground"):
				var success = target.plant_seed(plant)
				
				if success:
					can_attack = false
					get_tree().create_timer(attack_cooldown).timeout.connect(func(): can_attack = true)
					
					var selected_slot = Hotbar.selected_slot
					var slot_data = Hotbar.get_slot(selected_slot)
					var new_quantity = slot_data["quantity"] - 1
					
					if new_quantity <= 0:
						Hotbar.clear_slot(selected_slot)
					else:
						Hotbar.set_slot(selected_slot, item_name, new_quantity, slot_data["icon"])
				return
	
	# Second check: Are we clicking on a harvestable crop? (mouse raycast)
	if camera:
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(mouse_from, mouse_to)
		query.collision_mask = 0xFFFFFFFF  # Check all layers
		
		var result = space_state.intersect_ray(query)
		
		if result:
			var target = result.collider
			
			# Walk up tree to find crop
			while target and not target.is_in_group("planted_crops") and target.get_parent():
				target = target.get_parent()
			
			if target.is_in_group("planted_crops"):
				var crop = target
				if crop.is_ready:
					can_attack = false
					get_tree().create_timer(attack_cooldown).timeout.connect(func(): can_attack = true)
					
					var yields = crop.harvest()
					
					if yields.has("crop"):
						Inventory.add_item(yields.crop.item, yields.crop.icon, yields.crop.amount)
					
					if yields.has("seeds") and yields.seeds.amount > 0:
						Inventory.add_item(yields.seeds.item, yields.seeds.icon, yields.seeds.amount)
					
					print("Harvested crop!")
				return
	
	# Third check: weapon swing
	var item_type = ItemManager.get_item_type(item_name)
	if item_type == "weapon":
		swing_sword(item_name)
		return
	
	# Fourth check: short-range raycast for attacking trees/rocks/enemies
	var from = global_position + Vector3(0, 1.0, 0)
	var forward = transform.basis.x
	var to = from + forward * attack_range
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 0xFFFFFFFF
	
	var result = space_state.intersect_ray(query)
	
	if result:
		var hit_object = result.collider
		var target = hit_object
		
		while target and target.get_groups().size() == 0 and target.get_parent():
			target = target.get_parent()
		
		var damage = calculate_damage(item_name, target)
		
		if damage == 0.0 and (target.is_in_group("enemies") or target.is_in_group("trees") or target.is_in_group("rocks")):
			print("Cannot perform this action with current item!")
			return
			
		can_attack = false
		get_tree().create_timer(attack_cooldown).timeout.connect(func(): can_attack = true)
		
		if anim_controller.has_method("play_attack"):
			anim_controller.play_attack(item_name)
		
		if target.is_in_group("enemies"):
			if target.has_method("take_damage"):
				target.take_damage(damage)
			return
		
		if target.is_in_group("trees") or target.is_in_group("rocks"):
			if target.has_method("take_damage"):
				target.take_damage(damage)
			return



func swing_sword(item_name: String):
	# Start cooldown
	can_attack = false
	get_tree().create_timer(attack_cooldown).timeout.connect(func(): can_attack = true)
	
	# Play attack animation
	if anim_controller.has_method("play_attack"):
		anim_controller.play_attack(item_name)
	
	# Get sword damage
	var damage = ItemManager.get_item_damage(item_name)
	
	var hit_any_enemy = false
	
	# Check all enemies in the hitbox
	var enemies_in_range = attack_hit_box.get_overlapping_bodies()
	
	for body in enemies_in_range:
		# Walk up tree to find enemy node
		var target = body
		while target and target.get_groups().size() == 0 and target.get_parent():
			target = target.get_parent()
		
		# Damage if it's an enemy
		if target.is_in_group("enemies"):
			if target.has_method("take_damage"):
				target.take_damage(damage)
				print("Hit enemy with sword for ", damage, " damage!")
				
				# Calculate knockback direction (from player to enemy)
				var knockback_direction = (target.global_position - global_position).normalized()
				knockback_direction.y = 0  # Keep knockback horizontal
				
				# Apply knockback to enemy
				if target.has_method("apply_knockback"):
					target.apply_knockback(knockback_direction * enemy_knockback_force)
				
				# Apply recoil to player (opposite direction)
				velocity -= knockback_direction * player_recoil_force
				
				hit_any_enemy = true





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
	if $inventory.visible or $openable_box_ui.visible or $chest_ui.visible:
		# Only allow closing inventories
		if Input.is_action_just_pressed("inventory"):
			var box_ui = $openable_box_ui
			var chest_ui = $chest_ui
			if box_ui.visible == false and not box_ui.is_closing:
				if chest_ui.visible == false and not chest_ui.is_closing:
					if inventory_open:
						inventory_open = false
						$inventory_armor.visible = false
					else:
						inventory_open = true
						$inventory_armor.visible = true
		return
	
	
	
	if Input.is_action_just_pressed("ui_cancel") and is_placing:
		cancel_placement()
	
	#if Input.is_action_just_pressed("dash_roll") and can_dash and not is_placing:
		#start_dash()
	
	if Input.is_action_just_pressed("click") and !is_placing:
		click()
		
	if Input.is_action_just_pressed("click") and is_placing:
		place_item()
	
	if Input.is_action_just_pressed("eat"):
		try_eat_selected_item()
	
	if Input.is_action_just_pressed("click") and !is_placing and can_throw:
		try_throw_rock()


	if Input.is_action_just_pressed("inventory"):
		var box_ui = $openable_box_ui
		var chest_ui = $chest_ui
		if box_ui.visible == false and not box_ui.is_closing:
			if chest_ui.visible == false and not chest_ui.is_closing:
				if inventory_open:
					inventory_open = false
					$inventory_armor.visible = false
				else:
					inventory_open = true
					$inventory_armor.visible = true





func start_placement_mode(item: Node3D):
	placement_item = item
	is_placing = true

func place_item():
	if $inventory.visible:
		return
	
	if placement_item:
		var selected_item = Hotbar.get_selected_item()
		var item_name = selected_item["item_name"]
		var is_tilling = item_name == "wood_hoe"
		
		if is_tilling:
			# For tilling: create the actual tilled ground at the preview position
			var tilled_ground_scene = load("res://Scenes/tilled_ground.tscn")
			var placed_tilled = tilled_ground_scene.instantiate()
			get_tree().root.add_child(placed_tilled)
			placed_tilled.global_position = placement_item.global_position
			placed_tilled.global_rotation = placement_item.global_rotation
			
			print("Placed tilled ground at: ", placed_tilled.global_position)
			
			# DON'T destroy preview, DON'T exit placement mode
			# Preview continues to follow mouse and you can place more
		else:
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
			
			# Destroy preview and exit placement mode
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
		placement_item.top_level = true
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
	
	# Only show weapons and tools in hand (not placeable items)
	var item_type = ItemManager.get_item_type(item_name)
	var show_in_hand = item_type in ["weapon", "axe", "pickaxe", "hoe"]
	
	if not show_in_hand:
		return
	
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
	print("=== ENTERING TILLING MODE ===")
	var tilled_ground_scene = load("res://Scenes/tilled_ground.tscn")
	
	if tilled_ground_scene:
		var tilled = tilled_ground_scene.instantiate()
		add_child(tilled)
		
		# Set top_level FIRST
		tilled.top_level = true
		
		# THEN set global position
		var spawn_distance = 3.0
		var forward = -transform.basis.x  # Player's forward direction
		var target_pos = global_position + (forward * spawn_distance)
		target_pos.y = 0  # Keep on ground level
		
		print("Player position: ", global_position)
		print("Forward direction: ", forward)
		print("Target position: ", target_pos)
		
		tilled.global_position = target_pos
		
		print("Tilled ground position after set: ", tilled.global_position)
		
		start_placement_mode(tilled)
		
		print("placement_item set to: ", placement_item)
		print("is_placing: ", is_placing)
	else:
		print("ERROR: Could not load tilled_ground scene!")

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
	if player_health - dmg >= 0:
		player_health -= dmg
		# Visual feedback (screen flash, etc.)
		# TODO: Add health bar UI
		
	if player_health  <= 0:
		die()
		
	update_hunger_health_ui()


func die():
	print("Player died!")
	# TODO: Respawn or game over


func start_dash():
	var camera = get_current_camera()
	if !camera:
		return
	
	var camera_viewport = camera.get_viewport()
	var mouse_pos = camera_viewport.get_mouse_position()
	
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	
	var result = space_state.intersect_ray(query)
	
	if result:
		dash_direction = (result.position - global_position).normalized()
		dash_direction.y = 0
		
		if dash_direction.length() > 0.1:
			is_dashing = true
			can_dash = false
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


func get_mouse_world_position() -> Vector3:
	var camera = get_current_camera()
	if !camera:
		return global_position
	
	var camera_viewport = camera.get_viewport()
	var mouse_pos = camera_viewport.get_mouse_position()
	
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1  # Ground
	
	var result = space_state.intersect_ray(query)
	if result:
		return result.position
	
	return global_position


func heal_at_campfire():
	if healing_at_campfire:
		healing_at_campfire = false
	else:
		healing_at_campfire = true
		
	print("healing" + str(healing_at_campfire))
	
	
	
func try_throw_rock():
	if not can_throw:
		return
	
	var selected_item = Hotbar.get_selected_item()
	var item_name = selected_item["item_name"]
	
	# Check if holding a pebble
	if item_name != "pebble":
		print("Need to hold a pebble to throw!")
		return
	
	# Check if we have a slingshot (you can add this item later)
	var has_slingshot = false  # TODO: Check inventory for slingshot
	
	throw_rock(has_slingshot)
	
	# Remove pebble from hotbar
	var selected_slot = Hotbar.selected_slot
	var slot_data = Hotbar.get_slot(selected_slot)
	var new_quantity = slot_data["quantity"] - 1
	
	if new_quantity <= 0:
		Hotbar.clear_slot(selected_slot)
	else:
		Hotbar.set_slot(selected_slot, item_name, new_quantity, slot_data["icon"])

func throw_rock(use_slingshot: bool = false):
	can_throw = false
	
	# Get throw direction (toward mouse)
	var mouse_world_pos = get_mouse_world_position()
	var throw_direction = (mouse_world_pos - global_position).normalized()
	
	# Add upward arc
	throw_direction.y = throw_arc
	throw_direction = throw_direction.normalized()
	
	# Create thrown rock
	var rock = thrown_rock_scene.instantiate()
	get_tree().root.add_child(rock)
	
	# Position slightly in front of player and above
	rock.global_position = global_position + Vector3(0, 1.2, 0) + (transform.basis.x * 0.5)
	
	# Set velocity for RigidBody3D
	var throw_speed = slingshot_throw_speed if use_slingshot else base_throw_speed
	rock.linear_velocity = throw_direction * throw_speed  # Changed from velocity to linear_velocity
	rock.thrown_by_slingshot = use_slingshot
	
	print("Threw rock ", "with slingshot!" if use_slingshot else "by hand!")
	
	# Cooldown
	await get_tree().create_timer(throw_cooldown).timeout
	can_throw = true
