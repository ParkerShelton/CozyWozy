extends CharacterBody3D

@onready var subviewport = get_node("/root/main/SubViewportContainer/SubViewport")

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

func _ready():
	$inventory.visible = false
	$building_menu.visible = false
	
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
	query.collision_mask = 0xFFFFFFFF  # Check ALL layers temporarily for debugging
	
	var result = space_state.intersect_ray(query)
	if result:
		placement_item.global_position = result.position + Vector3(0, 0.3, 0)
	else:
		print("MISS - From: ", from, " To: ", to)

func click():
	# Create a raycast from player position in the direction they're facing
	var space_state = get_world_3d().direct_space_state
	var start = global_position + Vector3(0, 1, 0)  # Start from player center height
	var end = start + last_direction * interaction_range
	
	var query = PhysicsRayQueryParameters3D.create(start, end)
	var result = space_state.intersect_ray(query)
	
	if result:
		var hit_object = result.collider
		if hit_object.get_parent().has_method("take_damage"):
			hit_object.get_parent().take_damage()
			
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
			
	if Input.is_action_just_pressed("building_menu"):
		if building_menu_open:
			building_menu_open = false
			$building_menu.visible = false
		else:
			building_menu_open = true
			$building_menu.visible = true	

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
		
		# Remove one from the selected hotbar slot
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
	
	if selected_item["item_name"] != "":
		# Check if this item has a recipe and is placeable
		var recipe = RecipeManager.get_recipe(selected_item["item_name"])
		
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
