extends BaseAnimal

@onready var body_mesh = $horse/char_grp/rig/Skeleton3D/body
@onready var hair_mesh = $horse/char_grp/rig/Skeleton3D/hair
@onready var animation_player = $horse/AnimationPlayer  # Adjust path if needed

# Animation state
var is_kneeling: bool = false
var has_kneeled: bool = false

func _ready():
	super._ready()  # This loads stats from JSON
	
	# Wait for nodes to be ready
	await get_tree().process_frame
	body_mesh = find_child("body", true, false)
	hair_mesh = find_child("hair", true, false)
	animation_player = find_child("AnimationPlayer", true, false)
	
	if body_mesh or hair_mesh:
		randomize_horse_colors()
	
	if not animation_player:
		push_error("Horse: No AnimationPlayer found!")

func randomize_horse_colors():
	# Create instance-specific RNG for unique colors per horse
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(get_instance_id())
	
	var body_color_index = rng.randi() % 7
	var hair_color_index = rng.randi() % 5
	
	if body_mesh:
		var body_shader = load("res://Shaders/Animals/horse_body.gdshader")
		var body_material = ShaderMaterial.new()
		body_material.shader = body_shader
		body_material.set_shader_parameter("selected_color", body_color_index)
		body_mesh.material_override = body_material
	
	if hair_mesh:
		var hair_shader = load("res://Shaders/Animals/horse_hair.gdshader")
		var hair_material = ShaderMaterial.new()
		hair_material.shader = hair_shader
		hair_material.set_shader_parameter("selected_color", hair_color_index)
		hair_mesh.material_override = hair_material

func _physics_process(delta):
	# Don't move if kneeling or already kneeled
	if has_kneeled or is_kneeling:
		velocity.x = 0.0
		velocity.z = 0.0
		# Still apply gravity
		if not is_on_floor():
			velocity.y -= 9.8 * delta
		else:
			velocity.y = 0.0
		move_and_slide()
		update_animation()
		return
	
	super._physics_process(delta)
	update_animation()

func update_animation():
	if not animation_player:
		return
	
	match current_state:
		State.WANDER, State.FLEE, State.CHASE:
			# Moving - play walk
			if not animation_player.is_playing() or animation_player.current_animation != "walk":
				animation_player.play("walk")
				has_kneeled = false
				is_kneeling = false
		
		State.APPROACH:
			var distance = global_position.distance_to(player.global_position) if player else 999
			
			if distance > 5.0:
				# Still approaching - play walk
				if not animation_player.is_playing() or animation_player.current_animation != "walk":
					animation_player.play("walk")
					has_kneeled = false
					is_kneeling = false
			else:
				# Close enough - kneel sequence
				if not has_kneeled and not is_kneeling:
					# Start kneeling
					is_kneeling = true
					animation_player.play("kneel")
					animation_player.animation_finished.connect(_on_kneel_finished, CONNECT_ONE_SHOT)
				elif has_kneeled:
					# Already kneeled - stay in idle kneel pose
					if not animation_player.is_playing() or animation_player.current_animation != "kneel_idle":
						animation_player.play("kneel_idle")
		
		State.IDLE:
			# Idle on ground - just stop moving animation
			if velocity.length() < 0.1:
				if animation_player.is_playing() and animation_player.current_animation == "walk":
					animation_player.stop()
				has_kneeled = false
				is_kneeling = false
		
		State.DEAD:
			animation_player.stop()

func _on_kneel_finished(_anim_name):
	is_kneeling = false
	has_kneeled = true
	# Will transition to kneel_idle on next frame in update_animation()
