extends CharacterBody3D

@onready var subviewport = get_node("/root/main/SubViewportContainer/SubViewport")

# MOVEMENT
var speed : float = 3.5
var sprint_speed : float = 6.0
var rotation_speed : float = 10.0
var last_direction : Vector3 = Vector3.FORWARD
var placement_item : Node3D = null
var is_placing : bool = false
var interaction_range : float = 5.0  # How far you can interact with something
var inventory_open = false
var building_menu_open = false

func _ready():
	$inventory.visible = false
	$building_menu.visible = false

func _physics_process(delta):
	hot_keys()
	
	# Update placement item position to follow mouse
	if is_placing and placement_item:
		update_placement_position()
	
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
	print("Started placement mode - Move mouse and click to place, ESC to cancel")

func place_item():
	if placement_item:
		# Item is already in world, just finalize its position
		print("Item placed at: ", placement_item.global_position)
		placement_item = null
		is_placing = false

func cancel_placement():
	if placement_item:
		print("Placement cancelled")
		placement_item.queue_free()
		placement_item = null
		is_placing = false
