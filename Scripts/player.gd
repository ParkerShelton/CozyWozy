extends CharacterBody3D

var my_steam_id: int = 0
var position_sync_timer: float = 0.0
var position_sync_rate: float = 0.05

#@onready var subviewport = get_node("/root/main/SubViewportContainer/SubViewport")
@onready var right_hand = $vesper/Armature/Skeleton3D/right_hand_attachment/right_hand
@onready var left_hand = $vesper/Armature/Skeleton3D/left_hand_attachment/left_hand
@onready var anim_controller = $vesper
@onready var attack_hit_box = $attack_hit_box

var beam_lifted: bool = false
var beam_lift_height_start: float = 0.0

var player_health : float = 100.0
var attack_range : float = 3.0

var equipped_shield: Node3D = null

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
var is_running : bool = false
var is_dashing: bool = false
var can_dash: bool = true
var dash_speed: float = 15.0
var dash_duration: float = 0.5  # How long the dash lasts
var dash_cooldown: float = 3  # Cooldown between dashes
var dash_direction: Vector3 = Vector3.ZERO

var is_moving: bool = false
var footstep_audio: AudioStreamPlayer = null
var footstep_sounds: Array = []
var sprint_sounds: Array = []
var footstep_timer: float = 0.0
var footstep_interval: float = 0.40  # Time between footsteps when walking
var sprint_footstep_interval: float = 0.35

var zip_open_sound: AudioStream
var zip_closed_sound: AudioStream
var ui_audio: AudioStreamPlayer 

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

var is_blocking: bool = false
var just_closed_box: bool = false

# THROWING
var thrown_rock_scene = preload("res://Scenes/Ranged/Ammo/thrown_rock.tscn")
var can_throw: bool = true
var throw_cooldown: float = 0.5
var base_throw_speed: float = 20.0
var slingshot_throw_speed: float = 35.0
var throw_arc: float = 0.1  # How much upward angle to add


var transparent_walls: Array = []
var wall_tweens: Dictionary = {}

var sword_hit_sounds: Array = []
var dash_roll_sound: AudioStream = null

@onready var attack_audio = $attack_audio

var building_mode: bool = false
var building_preview: Node3D = null
var current_building_piece: String = ""
var placed_pieces: Array = []  # Track all placed pieces for snapping


func get_current_camera() -> Camera3D:
	# Try to get camera from viewport
	var camera = get_viewport().get_camera_3d()
	
	if camera:
		return camera
	
	# Fallback: try to find any Camera3D in the scene
	var cameras = get_tree().get_nodes_in_group("camera")
	if cameras.size() > 0:
		return cameras[0]
	return null
	
	

func _ready():
	current_hunger = max_hunger
	setup_audio()
	var shield_slot = $inventory_armor.get_node_or_null("inventory_container/LeftSection/Panel/VBoxContainer/shield_slot")  # Adjust path
	if shield_slot:
		shield_slot.shield_equipped.connect(_on_shield_equipped)
		shield_slot.shield_unequipped.connect(_on_shield_unequipped)
		
	#if Network.is_multiplayer_active():
		#my_steam_id = Network.get_my_steam_id()
		#Network.register_local_player(self)

func _physics_process(delta):
	hot_keys()
	
	make_walls_transparent_between_camera_and_player()

	if building_mode and building_preview:
		update_building_preview()

	if just_closed_box:
		just_closed_box = false

	# Gravity
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0
		
	if healing_at_campfire:
		player_health += 1 * delta
		
	update_footsteps(delta)
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
	
	# Rotate to face mouse
	var mouse_world_pos = get_mouse_world_position()
	var to_mouse = (mouse_world_pos - global_position)
	to_mouse.y = 0
	if to_mouse.length() > 0.1:
		var target_rotation = atan2(-to_mouse.z, to_mouse.x)
		rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed * delta)
	
	if is_blocking:
		velocity.x = lerp(velocity.x, 0.0, 15.0 * delta)
		velocity.z = lerp(velocity.z, 0.0, 15.0 * delta)
		move_and_slide()
		return
	
	# Get input direction
	var input_dir = Input.get_vector("walk_left", "walk_right", "walk_up", "walk_down")
	var direction = Vector3(-input_dir.y, 0, input_dir.x).normalized()
	
	var recoil_x = velocity.x
	var recoil_z = velocity.z
	

	
	# Move the character
	if direction != Vector3.ZERO:
		# Player started moving - play footstep sound
		if not is_moving:
			play_footstep_sound()
			is_moving = true
		
		# If sound finished, play it again (loop)
		if footstep_audio and not footstep_audio.playing:
			play_footstep_sound()
		
		if Input.is_action_pressed("sprint"):
			is_running = true
			velocity.x = direction.x * sprint_speed + recoil_x * 0.5
			velocity.z = direction.z * sprint_speed + recoil_z * 0.5
		else:
			is_running = false
			velocity.x = direction.x * speed + recoil_x * 0.5
			velocity.z = direction.z * speed + recoil_z * 0.5
		last_direction = direction
	else:
		# Player stopped moving - stop footstep sound
		if is_moving:
			if footstep_audio:
				footstep_audio.stop()
			is_moving = false
		
		velocity.x = lerp(velocity.x, 0.0, 15.0 * delta)
		velocity.z = lerp(velocity.z, 0.0, 15.0 * delta)
	
	move_and_slide()
	
	if Network.steam_initialized:
		position_sync_timer += delta
		if position_sync_timer >= position_sync_rate:
			position_sync_timer = 0.0
			Network.broadcast_player_state(global_position, rotation.y)

func update_placement_position():
	
	if not placement_item:
		return
	
	
	# Get camera the same way you do in click()
	var main = get_node("/root/main")
	var subviewport = main.get_node_or_null("SubViewportContainer/SubViewport")
	
	if not subviewport:
		return
	
	var camera = subviewport.get_camera_3d()
	
	if !camera:
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


# Complete click() function - PRIORITIZE take_damage METHOD

func click():
	if not can_attack:
		return
	
	var selected_item = Hotbar.get_selected_item()
	var item_name = selected_item["item_name"]
	
	var item_type = ItemManager.get_item_type(item_name)
	if item_type == "weapon":
		swing_sword(item_name)
		return
	
	# Raycast from player in the direction they're facing
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
		
		# FIRST PASS: Try to find a node with take_damage() method
		var current = hit_object
		var found_method = false
		while current:
			if current.has_method("take_damage"):
				target = current
				found_method = true
				break
			current = current.get_parent()
		
		# SECOND PASS: If no take_damage found, look for groups
		if not found_method:
			current = hit_object
			while current:
				if current.is_in_group("trees") or current.is_in_group("rocks") or current.is_in_group("enemies"):
					target = current
					break
				current = current.get_parent()
		
		# Calculate damage based on item and target
		var damage = calculate_damage(item_name, target)

		# If damage is 0, don't allow the action
		if damage == 0.0 and (target.is_in_group("enemies") or target.is_in_group("trees") or target.is_in_group("rocks")):
			print("Cannot perform this action with current item!")
			return
		
		# Start cooldown AFTER validation
		can_attack = false
		get_tree().create_timer(attack_cooldown).timeout.connect(func(): can_attack = true)
		
		# Play animation
		if anim_controller.has_method("play_attack"):
			anim_controller.play_attack(item_name)
		
		# Check if we hit an enemy
		if target.is_in_group("enemies"):
			# Play sound for enemies
			SoundManager.play_attack_sound(item_name, attack_audio)
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
		if target.has_method("take_damage") or target.is_in_group("trees") or target.is_in_group("rocks"):
			# Play sound based on tool
			if target.is_in_group("trees") and item_type == "axe":
				SoundManager.play_tree_chop_sound(attack_audio)
			else:
				SoundManager.play_attack_sound(item_name, attack_audio)
			
			# Deal damage
			if target.has_method("take_damage"):
				target.take_damage(damage)
			return



func _on_shield_equipped(shield_name: String):
	print("Equipping shield: ", shield_name)
	
	# Remove old shield if exists
	if equipped_shield:
		equipped_shield.queue_free()
		equipped_shield = null
	
	# Check if shield has a model
	if ItemManager.has_model(shield_name):
		var shield_scene = ItemManager.get_model(shield_name)
		if shield_scene:
			equipped_shield = shield_scene.instantiate()
			left_hand.add_child(equipped_shield)
			
			# Adjust position/rotation/scale for shield (same as sword)
			equipped_shield.position = Vector3(0, 0, 0)
			equipped_shield.rotation_degrees = Vector3(0, 0, 90)
			equipped_shield.scale = Vector3(0.5, 0.5, 0.5)
			
			print("Shield equipped on left hand!")

func _on_shield_unequipped():
	print("Unequipping shield")
	
	if equipped_shield:
		equipped_shield.queue_free()
		equipped_shield = null
		


func swing_sword(item_name: String):
	# Start cooldown
	can_attack = false
	get_tree().create_timer(attack_cooldown).timeout.connect(func(): can_attack = true)
	
	# Play sword sound
	SoundManager.play_sword_sound(attack_audio)
	
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
	
	# AXES - work on trees AND fences
	if item_type == "axe":
		if target.is_in_group("trees") or target.is_in_group("fences"):
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
						# Play close sound
						ui_audio.stream = zip_closed_sound
						ui_audio.volume_db = 1.0
						ui_audio.play()
					else:
						inventory_open = true
						$inventory_armor.visible = true
						# Play open sound
						ui_audio.stream = zip_open_sound
						ui_audio.volume_db = -15.0
						ui_audio.play()
		return
	
	
	if Input.is_action_pressed("block") and not is_running:
		try_block()
	elif Input.is_action_just_released("block"):
		stop_blocking()
	
	if Input.is_action_just_pressed("click") and building_mode:
		place_building()
	
	if Input.is_action_just_pressed("ui_cancel") and building_mode:
		exit_building_mode()
	
	
	if Input.is_action_just_pressed("ui_cancel") and is_placing:
		cancel_placement()
	
	if Input.is_action_just_pressed("dash_roll") and can_dash and not is_placing and is_running:
		start_dash()
	
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
					# Play close sound
					ui_audio.stream = zip_closed_sound
					ui_audio.volume_db = 1.0
					ui_audio.play()
				else:
					inventory_open = true
					$inventory_armor.visible = true
					# Play open sound
					ui_audio.stream = zip_open_sound
					ui_audio.volume_db = -15.0
					ui_audio.play()


func try_block():
	# Only block if we have a shield equipped
	if not equipped_shield:
		return
	
	if not is_blocking:
		is_blocking = true
		
		# Play shield block animation
		if anim_controller.has_method("play_shield_block"):
			anim_controller.play("shield_block")
		
		print("Blocking with shield!")

func stop_blocking():
	if is_blocking:
		is_blocking = false
		
		# Stop blocking animation (return to idle)
		if anim_controller.has_method("stop_shield_block"):
			anim_controller.stop_shield_block()
		
		print("Stopped blocking")

func start_placement_mode(item: Node3D):
	placement_item = item
	is_placing = true

func place_item():
	if $inventory_armor.visible:
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
		else:
			# Create NEW instance for placed object (don't reuse preview)
			var placed_item = ItemManager.get_model(item_name).instantiate()
			get_tree().root.add_child(placed_item)
			placed_item.global_position = placement_item.global_position
			placed_item.global_rotation = placement_item.global_rotation
			
			# Enable collision on the placed item
			enable_collision_recursive(placed_item)
			
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

func enable_collision_recursive(node: Node):
	# Enable collision on all StaticBody3D and Area3D nodes
	if node is StaticBody3D or node is Area3D:
		for shape in node.get_children():
			if shape is CollisionShape3D or shape is CollisionPolygon3D:
				shape.disabled = false
	
	# Recursively check children
	for child in node.get_children():
		enable_collision_recursive(child)
		
		
		
		
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
		
		# Set is_preview BEFORE adding to tree
		if "is_preview" in placement_item:
			placement_item.is_preview = true
			print("Set is_preview to true before adding to tree")
		
		add_child(placement_item)
		placement_item.top_level = true
		
		disable_collision_recursive(placement_item)
		
		is_placing = true




func disable_collision_recursive(node: Node):
	# Disable collision on all StaticBody3D and Area3D nodes
	if node is StaticBody3D or node is Area3D:
		for shape in node.get_children():
			if shape is CollisionShape3D or shape is CollisionPolygon3D:
				shape.disabled = true
	
	# Recursively check children
	for child in node.get_children():
		disable_collision_recursive(child)







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
	
	var target_position = placement_item.global_position
	var selected_item = Hotbar.get_selected_item()
	var item_name = selected_item["item_name"]
	
	# Determine what to snap to based on item type
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
		snap_group = "fences"  # ONLY snap to other fences
		tile_size = 1.0
		snap_range = 1.0
		allow_rotation = true
	else:
		# No snapping for other items
		return
	
	# Get all objects in the snap group
	var snap_objects = get_tree().get_nodes_in_group(snap_group)
	var best_snap = target_position
	var closest_distance = 999999.0
	var snap_rotation = placement_item.global_rotation
	
	for obj in snap_objects:
		# Get the object's basis (rotation matrix)
		var obj_basis = obj.global_transform.basis
		
		# Check 4 adjacent positions
		var potential_snaps = [
			obj.global_position + obj_basis * Vector3(tile_size, 0, 0),   # Right
			obj.global_position + obj_basis * Vector3(-tile_size, 0, 0),  # Left
			obj.global_position + obj_basis * Vector3(0, 0, tile_size),   # Forward
			obj.global_position + obj_basis * Vector3(0, 0, -tile_size),  # Back
		]
		
		for snap_pos in potential_snaps:
			var distance = target_position.distance_to(snap_pos)
			if distance < closest_distance and distance < snap_range:
				closest_distance = distance
				best_snap = snap_pos
				
				# Only copy rotation if rotation is NOT allowed (tilled ground)
				if not allow_rotation:
					snap_rotation = obj.global_rotation
	
	# Only update position if we found a valid snap point
	if closest_distance < snap_range:
		placement_item.global_position = best_snap
		
		# Only apply rotation if we're NOT allowed to rotate freely
		if not allow_rotation:
			placement_item.global_rotation = snap_rotation


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
			
			if dash_roll_sound:
				var dash_audio = AudioStreamPlayer.new()
				get_tree().root.add_child(dash_audio)
				dash_audio.stream = dash_roll_sound
				dash_audio.volume_db = -5.0
				dash_audio.pitch_scale = randf_range(0.95, 1.05)
				dash_audio.play()
				dash_audio.finished.connect(dash_audio.queue_free)
				
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

func make_walls_transparent_between_camera_and_player():
	var camera = get_current_camera()
	if not camera:
		return
	
	# Reset previously transparent objects
	for obj in transparent_walls:
		if is_instance_valid(obj):
			make_object_opaque(obj)
	transparent_walls.clear()
	
	# Raycast from camera to player
	var space_state = get_world_3d().direct_space_state
	var start_pos = camera.global_position
	var end_pos = global_position
	
	var query = PhysicsRayQueryParameters3D.create(start_pos, end_pos)
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	
	# Keep raycasting until we reach the player
	var max_iterations = 20
	var current_pos = start_pos
	
	for i in range(max_iterations):
		query = PhysicsRayQueryParameters3D.create(current_pos, end_pos)
		query.collision_mask = 1
		
		var result = space_state.intersect_ray(query)
		
		if not result:
			break
		
		var hit_object = result.collider
		
		# Check if it's a wall, terrain, OR tree
		if hit_object and (hit_object.is_in_group("walls") or hit_object.is_in_group("terrain") or hit_object.is_in_group("trees")):
			# Get the root node (parent of StaticBody)
			var root = hit_object
			if hit_object.get_parent():
				root = hit_object.get_parent()
			
			make_object_transparent(root)
			transparent_walls.append(root)  # Store root, not collider
		
		# Move start position slightly past the hit point
		current_pos = result.position + (end_pos - start_pos).normalized() * 0.1
		
		# Stop if we're past the player
		if current_pos.distance_to(end_pos) < 0.2:
			break

func make_object_transparent(obj: Node3D):
	# Make all meshes transparent (works for trees and walls)
	make_all_meshes_transparent(obj, 0.3)

func make_object_opaque(obj: Node3D):
	# Make all meshes opaque (works for trees and walls)
	make_all_meshes_transparent(obj, 0.0)

func make_all_meshes_transparent(obj: Node3D, target_transparency: float):
	# Only process Node3D types
	if not (obj is Node3D):
		return
	
	# If it's a MeshInstance3D, fade it
	if obj is MeshInstance3D:
		if wall_tweens.has(obj):
			wall_tweens[obj].kill()
		
		var tween = create_tween()
		tween.tween_property(obj, "transparency", target_transparency, 0.3)
		wall_tweens[obj] = tween
		
		if target_transparency == 0.0:
			tween.finished.connect(func(): 
				if wall_tweens.has(obj):
					wall_tweens.erase(obj)
			)
	
	# Recursively check all children (only Node3D types)
	for child in obj.get_children():
		if child is Node3D:
			make_all_meshes_transparent(child, target_transparency)


func update_footsteps(delta):
	# Only play footsteps when moving on ground and not dashing
	if is_on_floor() and velocity.length() > 0.1 and not is_dashing:
		footstep_timer -= delta
		
		if footstep_timer <= 0.0:
			play_footstep_sound()
			
			# Set interval based on sprint
			if Input.is_action_pressed("sprint"):
				footstep_timer = sprint_footstep_interval
			else:
				footstep_timer = footstep_interval
	else:
		# Reset timer when not moving
		footstep_timer = 0.0


func setup_audio():

	footstep_audio = AudioStreamPlayer.new()
	add_child(footstep_audio)
	footstep_audio.volume_db = -20.0
	
	# Create UI audio player
	ui_audio = AudioStreamPlayer.new()
	add_child(ui_audio)
	ui_audio.volume_db = -10.0
		
	for i in range(1, 6):  # sword_hit_1.mp3 through sword_hit_5.mp3
		var sound = load("res://Assets/SFX/sword_hit_" + str(i) + ".mp3")
		sword_hit_sounds.append(sound)

	# Load walk/run sounds
	for i in range(1, 9):  # run_1.mp3 through run_6.mp3
		var sound = load("res://Assets/SFX/run_" + str(i) + ".mp3")
		footstep_sounds.append(sound)
	
	# Load sprint sounds
	for i in range(1, 5):  # sprint_1.mp3 through sprint_6.mp3
		var sound = load("res://Assets/SFX/sprint_" + str(i) + ".mp3")
		sprint_sounds.append(sound)

	dash_roll_sound = load("res://Assets/SFX/dash_roll.mp3")
	zip_open_sound = load("res://Assets/SFX/zip_open.mp3")
	zip_closed_sound = load("res://Assets/SFX/zip_closed.mp3")

	

func play_footstep_sound():
	# Choose which sound array to use based on sprinting
	if Input.is_action_pressed("sprint"):
		if sprint_sounds.is_empty():
			return
		
		# Weighted selection for sprint sounds
		var rand = randf()  # 0.0 to 1.0
		var random_sound
		
		if rand < 0.15:  # 15% chance - use sprint_1 to sprint_4
			var index = randi() % 2  # Pick from first 4 sounds (indices 0-3)
			random_sound = sprint_sounds[index]
		else:  # 85% chance - use sprint_5 and sprint_6
			var index = 2 + (randi() % 2)  # Pick from last 2 sounds (indices 4-5)
			random_sound = sprint_sounds[index]
		
		footstep_audio.stream = random_sound
		footstep_audio.pitch_scale = randf_range(0.9, 1.1)
		footstep_audio.volume_db = -20.0
		footstep_audio.play()
	else:
		# Walking - just pick random
		if footstep_sounds.is_empty():
			return
		
		var random_sound = footstep_sounds[randi() % footstep_sounds.size()]
		footstep_audio.stream = random_sound
		footstep_audio.pitch_scale = randf_range(0.9, 1.1)
		footstep_audio.volume_db = -15.0
		footstep_audio.play()





func enter_building_mode(piece_name: String):
	current_building_piece = piece_name
	building_mode = true
	
	# Create preview
	var piece_data = BuildingManager.get_piece_data(piece_name)
	if piece_data.is_empty():
		print("No data for building piece: ", piece_name)
		return
	
	var model_path = piece_data.get("model", "")
	if not ResourceLoader.exists(model_path):
		print("Model not found: ", model_path)
		return
	
	var model_scene = load(model_path)
	building_preview = model_scene.instantiate()
	building_preview.is_preview = true
	add_child(building_preview)
	building_preview.top_level = true
	
	print("Entered building mode: ", piece_name)

func exit_building_mode():
	if building_preview:
		building_preview.queue_free()
		building_preview = null
	
	building_mode = false
	current_building_piece = ""
	print("Exited building mode")
	
	
	
func update_building_preview():
	# Get camera from SubViewport (same as your existing code)
	var main = get_node_or_null("/root/main")
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
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1 | 2  # Ground + buildings
	
	var result = space_state.intersect_ray(query)
	
	if result:
		var target_pos = result.position
		
		# Try to snap to nearby pieces
		var snap_result = try_snap_to_nearby(target_pos)
		if snap_result:
			building_preview.global_position = snap_result.position
			building_preview.global_rotation = snap_result.rotation
			building_preview.set_valid(true)
		else:
			# No snap - use grid placement
			target_pos = snap_to_grid(target_pos)
			building_preview.global_position = target_pos
			building_preview.set_valid(is_valid_placement())

func try_snap_to_nearby(target_pos: Vector3) -> Dictionary:
	var snap_distance = BuildingManager.snap_distance
	var best_snap = null
	var closest_distance = snap_distance
	
	# Check all placed pieces
	for piece in placed_pieces:
		if not is_instance_valid(piece):
			continue
		
		var piece_snaps = piece.get_world_snap_points()
		
		for snap_point in piece_snaps:
			var distance = target_pos.distance_to(snap_point.position)
			
			if distance < closest_distance:
				closest_distance = distance
				best_snap = {
					"position": snap_point.position,
					"rotation": piece.global_rotation,  # Match rotation
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
	if not building_preview:
		return false
	
	# Check for overlaps
	var space_state = get_world_3d().direct_space_state
	var shape = BoxShape3D.new()
	shape.size = Vector3(1.9, 2.9, 1.9)  # Slightly smaller than 2x3x2 for tolerance
	
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = building_preview.global_transform
	query.collision_mask = 2  # Only check buildings
	
	var results = space_state.intersect_shape(query)
	return results.size() == 0  # Valid if no overlaps

func place_building():
	if not building_mode or not building_preview:
		return
	
	if not is_valid_placement():
		print("Invalid placement!")
		return
	
	# Create actual building piece
	var piece_data = BuildingManager.get_piece_data(current_building_piece)
	var model_path = piece_data.get("model", "")
	var model_scene = load(model_path)
	var piece = model_scene.instantiate()
	
	get_tree().root.add_child(piece)
	piece.global_position = building_preview.global_position
	piece.global_rotation = building_preview.global_rotation
	piece.is_preview = false
	
	# Track for snapping
	placed_pieces.append(piece)
	
	print("Placed: ", current_building_piece, " at ", piece.global_position)



func apply_beam_lift(lift_speed: float, max_lift: float):
	if not beam_lifted:
		beam_lifted = true
		beam_lift_height_start = global_position.y
	
	if global_position.y - beam_lift_height_start < max_lift:
		velocity.y = lift_speed
	else:
		velocity.y = 0.0

func release_beam_lift():
	beam_lifted = false
