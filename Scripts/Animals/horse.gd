extends BaseAnimal

@onready var body_mesh        : MeshInstance3D = $horse/char_grp/rig/Skeleton3D/body
@onready var hair_mesh        : MeshInstance3D = $horse/char_grp/rig/Skeleton3D/hair
@onready var animation_player : AnimationPlayer = $horse/AnimationPlayer
@onready var saddle           : Node3D          = $Saddle

# ── States ────────────────────────────────────────────────────────────────
var is_kneeling      : bool = false
var has_kneeled      : bool = false
var is_tamed         : bool = false
var should_follow    : bool = true
var is_being_ridden  : bool = false
var is_standing_up   : bool = false
var rider            : CharacterBody3D = null

# ── Variables ─────────────────────────────────────────────────────────────
var horse_name           : String = "Unnamed Horse"
var speed                : float = 5.0
var ride_speed_multiplier : float = 1.6
var follow_distance      : float = 7.0

# ── Context menu ──────────────────────────────────────────────────────────
@onready var context_menu_scene : PackedScene = preload("res://Scenes/HorseContextMenu.tscn")  # ← change path if needed
var context_menu_instance : PopupPanel = null

func _ready() -> void:
	super._ready()
	await get_tree().process_frame

	# Fallback node finding in case @onready paths are wrong
	if not body_mesh:     body_mesh     = find_child("body", true, false) as MeshInstance3D
	if not hair_mesh:     hair_mesh     = find_child("hair", true, false) as MeshInstance3D
	if not animation_player: animation_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if not saddle:        saddle        = find_child("Saddle", true, false) as Node3D

	if body_mesh or hair_mesh:
		randomize_horse_colors()

	if not animation_player:
		push_error("Horse: No AnimationPlayer found!")
	if not saddle:
		push_warning("Horse: No Saddle Node3D found – player will mount at (0,0,0) relative to horse!")

	input_ray_pickable = true
	input_event.connect(_on_horse_input)


func _on_horse_input(camera: Camera3D, event: InputEvent, position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return

	if event.button_index == MOUSE_BUTTON_LEFT:
		if has_kneeled and not is_tamed and not is_being_ridden:
			tame_horse()

	elif event.button_index == MOUSE_BUTTON_RIGHT:
		if is_tamed:
			var screen_pos = camera.unproject_position(position)
			_show_context_menu(screen_pos)


func _show_context_menu(screen_pos: Vector2) -> void:
	if context_menu_instance and is_instance_valid(context_menu_instance):
		context_menu_instance.queue_free()

	context_menu_instance = context_menu_scene.instantiate()
	get_viewport().add_child(context_menu_instance)

	# Safe signal connections – prevents crash if signal is missing
	context_menu_instance.follow_toggled.connect(_on_follow_toggled)
	context_menu_instance.rename_requested.connect(_on_rename_requested)

	context_menu_instance.setup(self, horse_name, should_follow, is_being_ridden)

	context_menu_instance.position = screen_pos + Vector2(30, -100)
	context_menu_instance.popup()


func _on_follow_toggled(new_value: bool) -> void:
	should_follow = new_value


func _on_rename_requested(new_name: String) -> void:
	var cleaned = new_name.strip_edges()
	if not cleaned.is_empty():
		horse_name = cleaned
		print("[Horse] Renamed to: ", horse_name)



# ── Taming ────────────────────────────────────────────────────────────────
func tame_horse() -> void:
	is_tamed = true
	should_follow = true
	is_standing_up = true

	if animation_player and animation_player.has_animation("kneel"):
		animation_player.play_backwards("kneel")
		animation_player.animation_finished.connect(_on_stand_up_finished, CONNECT_ONE_SHOT)


func _on_stand_up_finished(anim_name: StringName) -> void:
	if anim_name == "kneel":
		is_standing_up = false
		has_kneeled = false
		is_kneeling = false



# ── Movement ──────────────────────────────────────────────────────────────
func handle_follow(delta: float) -> void:
	if not player: return

	var target_pos = player.global_position
	var dist = global_position.distance_to(target_pos)

	if dist > follow_distance + 1.0:
		var dir = global_position.direction_to(target_pos)
		dir.y = 0
		dir = dir.normalized()

		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		look_at_from_position(global_position, target_pos, Vector3.UP)
	else:
		velocity.x = move_toward(velocity.x, 0, speed * 12 * delta)
		velocity.z = move_toward(velocity.z, 0, speed * 12 * delta)


func trap_horse(trapped: bool):
	if trapped:
		velocity.x = 0
		velocity.z = 0


func _physics_process(delta: float) -> void:
	if is_tamed:
		if is_standing_up:
			velocity.x = 0
			velocity.z = 0
		elif should_follow:
			handle_follow(delta)
		else:
			velocity.x = move_toward(velocity.x, 0, speed * 10 * delta)
			velocity.z = move_toward(velocity.z, 0, speed * 10 * delta)

	elif has_kneeled or is_kneeling:
		velocity.x = 0
		velocity.z = 0
	else:
		super._physics_process(delta)

	# Gravity
	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity", 9.8) * delta
	else:
		velocity.y = 0

	move_and_slide()
	update_animation()


# ── Animations ────────────────────────────────────────────────────────────
func update_animation() -> void:
	if not animation_player:
		return

	if is_being_ridden or (is_tamed and velocity.length() > 0.5):
		if animation_player.current_animation != "walk":
			animation_player.play("walk")
		return

	if is_tamed and velocity.length() < 0.2:
		if animation_player.is_playing() and animation_player.current_animation == "walk":
			animation_player.stop()
		return

	match current_state:
		State.WANDER, State.FLEE, State.CHASE, State.APPROACH when global_position.distance_to(player.global_position if player else Vector3.ZERO) > 5.0:
			if animation_player.current_animation != "walk":
				animation_player.play("walk")
			has_kneeled = false
			is_kneeling = false

		State.APPROACH:
			if not has_kneeled and not is_kneeling and not is_tamed:
				is_kneeling = true
				animation_player.play("kneel")
				animation_player.animation_finished.connect(_on_kneel_finished, CONNECT_ONE_SHOT)
			elif has_kneeled:
				if animation_player.current_animation != "kneel_idle":
					animation_player.play("kneel_idle")

		State.IDLE:
			if velocity.length() < 0.1 and animation_player.is_playing() and animation_player.current_animation == "walk":
				animation_player.stop()
			has_kneeled = false
			is_kneeling = false

		State.DEAD:
			animation_player.stop()


func _on_kneel_finished(_anim: StringName) -> void:
	is_kneeling = false
	has_kneeled = true


# ── Visuals ───────────────────────────────────────────────────────────────
func randomize_horse_colors() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(get_instance_id())

	var body_idx = rng.randi() % 7
	var mane_idx = rng.randi() % 5

	if body_mesh:
		var mat = ShaderMaterial.new()
		mat.shader = load("res://Shaders/Animals/horse_body.gdshader")
		mat.set_shader_parameter("selected_color", body_idx)
		mat.set_shader_parameter("has_spots", rng.randi_range(1,10) > 8)
		mat.set_shader_parameter("spot_color", Color(0.96, 0.96, 0.96))
		mat.set_shader_parameter("spot_seed", rng.randf() * 200.0)
		body_mesh.material_override = mat

	if hair_mesh:
		var mat = ShaderMaterial.new()
		mat.shader = load("res://Shaders/Animals/horse_hair.gdshader")
		mat.set_shader_parameter("selected_color", mane_idx)
		hair_mesh.material_override = mat
